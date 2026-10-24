import 'package:flutter/material.dart';

/// A user's friend with a display name, username, email, avatar color,
/// and an optional nickname set by the current user.
class Friend {
  final String name;

  /// Handle shown as @username (e.g. "alexj"). Falls back to the email prefix.
  final String? username;

  final String email;

  /// Nickname assigned by the current user via long-press > Edit Nickname.
  /// When set, it overrides [name] in lists.
  final String? nickname;

  final Color color;

  const Friend({
    required this.name,
    this.username,
    required this.email,
    this.nickname,
    required this.color,
  });

  /// The name to display in lists: the nickname when set, otherwise the name.
  String get displayName =>
      (nickname != null && nickname!.trim().isNotEmpty) ? nickname! : name;

  /// The handle shown with an @ prefix; derived from the email when unset.
  String get displayUsername {
    if (username != null && username!.trim().isNotEmpty) return username!;
    final prefix = email.split('@').first;
    return prefix.isEmpty ? 'user' : prefix;
  }

  Friend copyWith({
    String? name,
    String? username,
    String? email,
    String? nickname,
    bool clearNickname = false,
    Color? color,
  }) {
    return Friend(
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      nickname: clearNickname ? null : (nickname ?? this.nickname),
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Friend && other.email == email;
  }

  @override
  int get hashCode => email.hashCode;
}