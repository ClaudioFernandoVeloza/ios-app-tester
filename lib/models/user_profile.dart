import 'package:cloud_firestore/cloud_firestore.dart';

/// The profile of a Pic Collector user, stored in Firestore.
///
/// Username uniqueness is enforced case-insensitively. Every stored profile
/// keeps a normalized copy (`usernameLower`) that acts as the document-ID
/// of the `usernames/{usernameLower}` reservation document used to claim a
/// username atomically.
class UserProfile {
  final String uid;
  final String username;
  final String firstName;
  final String surname;
  final String email;

  /// Private nickname the current user gave this person (read from their
  /// own friendship mirror doc). Null for public `users` docs — nicknames
  /// are per-user labels and are never part of [toMap].
  final String? nickname;

  const UserProfile({
    required this.uid,
    required this.username,
    required this.firstName,
    required this.surname,
    required this.email,
    this.nickname,
  });

  /// "Firstname Surname"
  String get fullName => '$firstName $surname'.trim();

  /// Name shown in lists: nickname when set, otherwise the full name,
  /// falling back to the username.
  String get displayName {
    if (nickname != null && nickname!.trim().isNotEmpty) return nickname!;
    if (fullName.isNotEmpty) return fullName;
    return username;
  }

  /// Normalized (lowercased) username used for uniqueness lookups.
  String get usernameLower => username.trim().toLowerCase();

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'usernameLower': usernameLower,
      'firstName': firstName,
      'surname': surname,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfile(
      uid: doc.id,
      username: (data['username'] as String?) ?? '',
      firstName: (data['firstName'] as String?) ?? '',
      surname: (data['surname'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      nickname: data['nickname'] as String?,
    );
  }
}
