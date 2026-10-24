import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pic_collector/models/user_profile.dart';

/// Custom exception thrown when a sign-up is rejected because the chosen
/// username is already taken.
class UsernameTakenException implements Exception {
  final String username;

  UsernameTakenException(this.username);

  @override
  String toString() => 'UsernameTakenException: $username is already taken';
}

/// Reads/writes user profiles in the users collection.
///
/// Username uniqueness is enforced case-insensitively and atomically:
/// - the usernames/{lowercaseUsername} reservation doc holds the owning uid
/// - [createUserProfile] runs everything inside a Firestore transaction so no
///   two users can ever claim the same normalized username.
class UserProfileService {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection('usernames');

  /// Creates the profile document for the given auth user.
  ///
  /// Runs a transaction that atomically:
  /// 1. claims the normalized username reservation doc
  /// 2. writes the users/{uid} profile doc
  ///
  /// Throws [UsernameTakenException] if the normalized username is already
  /// claimed by another user. The caller must delete the (orphaned) Auth user
  /// before returning.
  Future<void> createUserProfile({
    required User user,
    required String username,
    required String firstName,
    required String surname,
  }) async {
    final normalized = username.trim().toLowerCase();

    // Fast pre-check outside the transaction so a taken username can never be
    // retried indefinitely by Firestore.
    if (!await isUsernameAvailable(username)) {
      throw UsernameTakenException(normalized);
    }

    // Atomically claim the reservation and write the profile. The transaction
    // guard on `usernames/{normalized}` is the last line of defense against a
    // race where two devices pick the same username at the same instant.
    await _db.runTransaction(
      (Transaction tx) async {
        final reservationRef = _usernames.doc(normalized);
        final reservation = await tx.get(reservationRef);

        if (reservation.exists) {
          final existingUsername =
              (reservation.data() as Map<String, dynamic>)['username'] as String?;
          throw UsernameTakenException(existingUsername ?? normalized);
        }

        final profile = UserProfile(
          uid: user.uid,
          username: username.trim(),
          firstName: firstName,
          surname: surname,
          email: user.email ?? '',
        );

        tx.set(reservationRef, {
          'uid': user.uid,
          'username': username.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(_users.doc(user.uid), profile.toMap());
      },
    );
  }

  /// Checks whether [username] is available.
  ///
  /// Runs a single lightweight read. Case-insensitive: 'Alex' and 'alex' both
  /// resolve to the same normalized value.
  Future<bool> isUsernameAvailable(String username) async {
    final normalized = username.trim().toLowerCase();
    final doc = await _usernames.doc(normalized).get();
    return !doc.exists;
  }

  /// One-shot read of a user profile (null when the doc doesn't exist).
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }

  /// Live stream of a user profile (null when the doc doesn't exist).
  Stream<UserProfile?> watchUserProfile(String uid) {
    return _users.doc(uid).snapshots().map(
          (doc) => doc.exists ? UserProfile.fromFirestore(doc) : null,
        );
  }
}