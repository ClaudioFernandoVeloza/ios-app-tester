import 'package:pic_collector/models/chat.dart';
import 'package:pic_collector/models/friend.dart';

/// App-level mutable store for friends and chats.
///
/// Singleton so state survives tab switches and navigation while the app
/// is running. It starts EMPTY: no demo friends or chats are seeded any more.
///
/// TODO(firebase): populate [friends] from `FriendService.watchFriends()` and
/// [chats] from a Firestore chats collection, and make the mutating methods
/// below (rename/remove friend, send message, pin, delete, mark read) write
/// to Firestore instead of only changing local state.
class AppStore {
  AppStore._();

  static final AppStore instance = AppStore._();

  /// Live friends list.
  final List<Friend> friends = [];

  /// Live chats list.
  final List<Chat> chats = [];

  // ---------------------------------------------------------------------------
  // Friends
  // ---------------------------------------------------------------------------

  /// Finds a friend by email, or null when not found.
  Friend? findFriendByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    for (final friend in friends) {
      if (friend.email.toLowerCase() == normalized) return friend;
    }
    return null;
  }

  /// Removes a friend and any chat with them.
  void removeFriend(Friend friend) {
    friends.remove(friend);
    chats.removeWhere((chat) => chat.friend == friend);
  }

  /// Removes any local chat with the user owning [email].
  ///
  /// Used when a real (Firestore) friend is deleted: there is no [Friend]
  /// entry in [friends] for them, but a local chat may still exist.
  void removeChatsWithEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return;
    chats.removeWhere((chat) => chat.friend.email.toLowerCase() == normalized);
  }

  /// Updates the nickname used for chats with the user owning [email]
  /// (blank clears it). Called after a Firestore nickname save so
  /// already-open chats reflect the new name immediately.
  void renameFriendByEmail(String email, String nickname) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final trimmed = nickname.trim();
    for (final chat in chats) {
      if (chat.friend.email.toLowerCase() == normalized) {
        chat.friend = chat.friend.copyWith(
          nickname: trimmed,
          clearNickname: trimmed.isEmpty,
        );
      }
    }
  }

  /// Updates a friend's nickname (null/empty clears it).
  void renameFriend(Friend friend, String? nickname) {
    final index = friends.indexOf(friend);
    if (index == -1) return;
    final updated = friend.copyWith(
      nickname: nickname?.trim(),
      clearNickname: nickname == null || nickname.trim().isEmpty,
    );
    friends[index] = updated;
    _replaceFriendInChats(friend, updated);
  }

  // ---------------------------------------------------------------------------
  // Chats
  // ---------------------------------------------------------------------------

  /// Returns the chat with [friend], creating an empty one when missing.
  Chat getOrCreateChat(Friend friend) {
    for (final chat in chats) {
      if (chat.friend == friend) return chat;
    }
    final chat = Chat(friend: friend);
    chats.add(chat);
    return chat;
  }

  /// Deletes a chat.
  void deleteChat(Chat chat) {
    chats.remove(chat);
  }

  /// Toggles the pinned state of a chat.
  void togglePin(Chat chat) {
    chat.isPinned = !chat.isPinned;
  }

  /// Marks all messages of a chat as read.
  void markChatRead(Chat chat) {
    chat.unreadCount = 0;
  }

  /// Appends a message sent by the current user to the chat.
  void sendMessage(Chat chat, String text) {
    chat.messages.add(
      ChatMessage(text: text, isMe: true, time: DateTime.now()),
    );
  }

  /// Chats sorted for the list: pinned first, then by latest activity.
  List<Chat> sortedChats() {
    final list = List.of(chats);
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final aTime = a.lastMessage?.time;
      final bTime = b.lastMessage?.time;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return list;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Keeps chat friend references in sync after a friend update.
  void _replaceFriendInChats(Friend oldFriend, Friend newFriend) {
    for (final chat in chats) {
      if (chat.friend == oldFriend) {
        chat.friend = newFriend;
      }
    }
  }
}
