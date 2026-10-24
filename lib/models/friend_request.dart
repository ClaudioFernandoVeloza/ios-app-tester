import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a friend request.
enum FriendRequestStatus { pending, accepted, declined }

/// A friend request between two users, stored in Firestore.
///
/// Collection: `friend_requests/{requestId}`
/// Document ID: '{fromUid}_{toUidLower}' — deterministic so a duplicate
/// request collides on the same doc instead of creating a second one.
class FriendRequest {
  final String id;
  final String fromUid;
  final String fromUsername;
  final String fromName;
  final String toUid;
  final String toUsernameLower;
  final FriendRequestStatus status;
  final DateTime? createdAt;

  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.fromUsername,
    required this.fromName,
    required this.toUid,
    required this.toUsernameLower,
    required this.status,
    this.createdAt,
  });

  /// Builds the deterministic doc ID for a request from A to B.
  static String docIdFor(String fromUid, String toUid) =>
      [fromUid, toUid].join('_');

  Map<String, dynamic> toMap() {
    return {
      'fromUid': fromUid,
      'fromUsername': fromUsername,
      'fromName': fromName,
      'toUid': toUid,
      'toUsernameLower': toUsernameLower,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory FriendRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final statusName = (data['status'] as String?) ?? 'pending';
    final status = FriendRequestStatus.values.asNameMap()[statusName] ??
        FriendRequestStatus.pending;
    final created = data['createdAt'];
    return FriendRequest(
      id: doc.id,
      fromUid: (data['fromUid'] as String?) ?? '',
      fromUsername: (data['fromUsername'] as String?) ?? '',
      fromName: (data['fromName'] as String?) ?? '',
      toUid: (data['toUid'] as String?) ?? '',
      toUsernameLower: (data['toUsernameLower'] as String?) ?? '',
      status: status,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
