import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:pic_collector/models/friend_request.dart';
import 'package:pic_collector/models/user_profile.dart';


/// Result of [FriendService.sendRequest].
enum SendRequestResult {
  /// A new pending request was created.
  sent,

  /// A pending request already exists between the two users.
  alreadyPending,

  /// The two users are already friends.
  alreadyFriends,

  /// The target user does not exist.
  userNotFound,

  /// The user tried to add themselves.
  selfRequest,
}

/// Reads/writes friend requests and friendships in Firestore.
///
/// Schema:
/// - `friend_requests/{fromUid}_{toUid}` -> pending/accepted/declined request
/// - `friendships/{uid}/friends/{friendUid}` -> mirror docs, one per side
class FriendService {
  FriendService._();
  static final FriendService instance = FriendService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('friend_requests');

  CollectionReference<Map<String, dynamic>> _friendsOf(String uid) =>
      _db.collection('friendships').doc(uid).collection('friends');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // Requests
  // ---------------------------------------------------------------------------

  /// Sends a friend request to the user with [usernameOrEmail].
  ///
  /// Resolution order: exact username match (case-insensitive via the
  /// `usernames` reservation collection) first, then email match in `users`.
  Future<SendRequestResult> sendRequest(String usernameOrEmail) async {
    final me = _uid;
    if (me == null) return SendRequestResult.userNotFound;

    final input = usernameOrEmail.trim();
    if (input.isEmpty) return SendRequestResult.userNotFound;

    // 1) Resolve target uid.
    String? toUid;
    if (!input.contains('@')) {
      final normalized = input.toLowerCase();
      final reservation =
          await _db.collection('usernames').doc(normalized).get();
      if (reservation.exists) {
        toUid = reservation.data()?['uid'] as String?;
      }
    } else {
      final snap = await _db
          .collection('users')
          .where('email', isEqualTo: input.toLowerCase())
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        toUid = snap.docs.first.id;
      }
    }

    if (toUid == null || toUid.isEmpty) return SendRequestResult.userNotFound;
    if (toUid == me) return SendRequestResult.selfRequest;

    // 2) Already friends?
    final friendship = await _friendsOf(me).doc(toUid).get();
    if (friendship.exists) return SendRequestResult.alreadyFriends;

    // 3) Pending request either way?
    final mine = await _requests.doc(FriendRequest.docIdFor(me, toUid)).get();
    if (mine.exists && (mine.data()?['status'] as String?) == 'pending') {
      return SendRequestResult.alreadyPending;
    }
    final theirs = await _requests.doc(FriendRequest.docIdFor(toUid, me)).get();
    if (theirs.exists && (theirs.data()?['status'] as String?) == 'pending') {
      return SendRequestResult.alreadyPending;
    }

    // 4) Load profiles for display names.
    final myProfile = await _db.collection('users').doc(me).get();
    final myData = myProfile.data() ?? {};
    final targetDoc = await _db.collection('users').doc(toUid).get();
    if (!targetDoc.exists) return SendRequestResult.userNotFound;
    final target = UserProfile.fromFirestore(targetDoc);

    await _requests.doc(FriendRequest.docIdFor(me, toUid)).set({
      'fromUid': me,
      'fromUsername': (myData['username'] as String?) ?? '',
      'fromName':
          '${(myData['firstName'] as String?) ?? ''} ${(myData['surname'] as String?) ?? ''}'
              .trim(),
      'toUid': toUid,
      'toUsernameLower': target.usernameLower,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return SendRequestResult.sent;
  }

  /// Accepts [request] and creates the two mirror friendship docs.
  Future<void> acceptRequest(FriendRequest request) async {
    final me = _uid;
    if (me == null || request.toUid != me) return;

    final otherDoc = await _db.collection('users').doc(request.fromUid).get();
    final other = otherDoc.exists ? UserProfile.fromFirestore(otherDoc) : null;
    final myDoc = await _db.collection('users').doc(me).get();
    final myData = myDoc.data() ?? {};
    final myName =
        '${(myData['firstName'] as String?) ?? ''} ${(myData['surname'] as String?) ?? ''}'
            .trim();

    final batch = _db.batch();
    batch.update(
      _requests.doc(request.id),
      {'status': FriendRequestStatus.accepted.name},
    );
    batch.set(_friendsOf(me).doc(request.fromUid), {
      'uid': request.fromUid,
      'username': other?.username ?? request.fromUsername,
      'name': other != null ? other.fullName : request.fromName,
      'email': other?.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_friendsOf(request.fromUid).doc(me), {
      'uid': me,
      'username': (myData['username'] as String?) ?? '',
      'name': myName,
      'email': (myData['email'] as String?) ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

  }
  /// Declines [request] (marks declined so it disappears from pending lists).
  Future<void> declineRequest(FriendRequest request) {
    final me = _uid;
    if (me == null || request.toUid != me) {
      return Future.value();
    }
    return _requests.doc(request.id).update({
      'status': FriendRequestStatus.declined.name,
    });
  }

  /// Live incoming pending requests for the current user.
  Stream<List<FriendRequest>> watchIncomingRequests() {
    final me = _uid;
    if (me == null) return Stream.value(const []);
    return _requests
        .where('toUid', isEqualTo: me)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) =>
            snap.docs.map(FriendRequest.fromFirestore).toList(growable: false));
  }

  /// Live outgoing pending requests for the current user.
  Stream<List<FriendRequest>> watchOutgoingRequests() {
    final me = _uid;
    if (me == null) return Stream.value(const []);
    return _requests
        .where('fromUid', isEqualTo: me)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) =>
            snap.docs.map(FriendRequest.fromFirestore).toList(growable: false));
  }

  /// Live set of uids the current user has sent a pending request to.
  ///
  /// Lets the search results show a "Pending" state instead of "Send".
  Stream<Set<String>> watchPendingOutgoingUids() {
    return watchOutgoingRequests().map(
      (requests) => requests.map((r) => r.toUid).toSet(),
    );
  }

  /// Live map of requester uid -> incoming pending request for the current
  /// user. The full [FriendRequest] is kept so the caller can accept or
  /// decline it directly.
  Stream<Map<String, FriendRequest>> watchIncomingRequestsByUid() {
    return watchIncomingRequests().map(
      (requests) => {for (final r in requests) r.fromUid: r},
    );
  }

  /// Live number of pending requests addressed to the current user.
  ///
  /// Drives the red notification dots on the menu button and on the
  /// drawer's "Friend Requests" entry.
  Stream<int> watchIncomingRequestCount() {
    return watchIncomingRequests().map((requests) => requests.length);
  }

  /// Removes the friendship with [friend]: deletes BOTH mirror docs in one
  /// batch so each side's friends list stays consistent.
  ///
  /// Security rules allow this because the writer is a participant of both
  /// docs (same pattern as the accept flow writing both mirrors at once).
  Future<void> deleteFriend(UserProfile friend) async {
    final me = _uid;
    if (me == null || friend.uid.isEmpty || friend.uid == me) return;

    final batch = _db.batch();
    batch.delete(_friendsOf(me).doc(friend.uid));
    batch.delete(_friendsOf(friend.uid).doc(me));
    await batch.commit();
  }

  /// Sets (or clears when [nickname] is blank) the current user's private
  /// nickname for [friend]. Stored ONLY in the current user's own mirror
  /// doc, so other friends of [friend] can never see it.
  Future<void> setNickname(UserProfile friend, String nickname) async {
    final me = _uid;
    if (me == null || friend.uid.isEmpty || friend.uid == me) return;

    final trimmed = nickname.trim();
    await _friendsOf(me)
        .doc(friend.uid)
        .update(
          trimmed.isEmpty
              ? {'nickname': FieldValue.delete()}
              : {'nickname': trimmed},
        );
  }

  /// Live friendship docs for the current user.
  Stream<List<UserProfile>> watchFriends() {
    final me = _uid;
    if (me == null) return Stream.value(const []);
    return _friendsOf(me).snapshots().map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            return UserProfile(
              uid: doc.id,
              username: (data['username'] as String?) ?? '',
              firstName: '',
              surname: (data['name'] as String?) ?? '',
              email: (data['email'] as String?) ?? '',
              nickname: data['nickname'] as String?,
            );
          }).toList(growable: false),
        );
  }

  /// Searches real users by username prefix (case-insensitive).
  ///
  /// Uses the `usernameLower` field on `users`. Firestore has no
  /// "contains" query, so this is a prefix search; results exclude self.
  Future<List<UserProfile>> searchByUsername(String query) async {
    final me = _uid;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final snap = await _db
        .collection('users')
        .where('usernameLower', isGreaterThanOrEqualTo: q)
        .where('usernameLower', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(10)
        .get();
    return snap.docs
        .map(UserProfile.fromFirestore)
        .where((p) => p.uid != me)
        .toList(growable: false);
  }
}
