import 'package:pic_collector/models/friend.dart';

/// A single message inside a chat.
class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime time;

  const ChatMessage({
    required this.text,
    required this.isMe,
    required this.time,
  });
}

/// A 1-to-1 conversation with a friend.
class Chat {
  /// Mutable so nickname updates can propagate to existing chats.
  Friend friend;
  final List<ChatMessage> messages;
  bool isPinned;
  int unreadCount;

  Chat({
    required this.friend,
    List<ChatMessage>? messages,
    this.isPinned = false,
    this.unreadCount = 0,
  }) : messages = messages ?? [];

  /// The most recent message, or null when the chat is empty.
  ChatMessage? get lastMessage =>
      messages.isNotEmpty ? messages.last : null;

  /// The friend's display name (nickname-aware).
  String get title => friend.displayName;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Chat && other.friend == friend;
  }

  @override
  int get hashCode => friend.hashCode;
}