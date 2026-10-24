import 'package:flutter/material.dart';
import 'package:pic_collector/data/app_store.dart';
import 'package:pic_collector/models/chat.dart';
import 'package:pic_collector/models/friend.dart';
import 'package:pic_collector/screens/main-features/chat_detail_screen.dart';
import 'package:pic_collector/utils/formatters.dart';
import 'package:pic_collector/utils/user_notice.dart';

/// Chat tab: list of conversations with search, new-chat picker,
/// and long-press actions (pin/unpin, delete).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _searchController = TextEditingController();

  AppStore get _store => AppStore.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Chat> get _filteredChats {
    final query = _searchController.text.trim().toLowerCase();
    final chats = _store.sortedChats();
    if (query.isEmpty) return chats;
    return chats
        .where(
          (chat) =>
              chat.title.toLowerCase().contains(query) ||
              chat.friend.displayUsername.toLowerCase().contains(query),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _openChat(Chat chat) {
    _store.markChatRead(chat);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(chat: chat),
      ),
    ).then((_) => setState(() {}));
  }

  /// Bottom sheet with chat actions (edit-chat.png).
  void _showChatActions(Chat chat) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                chat.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(chat.isPinned ? 'Unpin Chat' : 'Pin Chat'),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _store.togglePin(chat));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete Chat',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDeleteChat(chat);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Confirmation before deleting a chat.
  void _confirmDeleteChat(Chat chat) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Are you sure you want to delete the chat with '
            '${chat.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() => _store.deleteChat(chat));
              Navigator.pop(dialogContext);
              showSnackBar(context, 'Chat deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// "New chat" dialog: searchable picker over the existing friends.
  void _showNewChatDialog() {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final query = searchController.text.trim().toLowerCase();
          final friends = query.isEmpty
              ? _store.friends
              : _store.friends
                  .where(
                    (friend) =>
                        friend.displayName.toLowerCase().contains(query) ||
                        friend.displayUsername
                            .toLowerCase()
                            .contains(query) ||
                        friend.email.toLowerCase().contains(query),
                  )
                  .toList();

          return AlertDialog(
            title: const Text('New Chat'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search friends...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: friends.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No friends found.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: friends.length,
                              itemBuilder: (context, index) {
                                final friend = friends[index];
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundColor: friend.color,
                                    child: Text(
                                      friend.displayName.isNotEmpty
                                          ? friend.displayName[0]
                                              .toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  title: Text(friend.displayName),
                                  subtitle: Text(
                                    '@${friend.displayUsername}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(dialogContext);
                                    _openChatWith(friend);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Opens (or creates) the chat with the given friend.
  void _openChatWith(Friend friend) {
    final chat = _store.getOrCreateChat(friend);
    _openChat(chat);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final chats = _filteredChats;

    return SafeArea(
      child: Column(
        children: [
          // --- Search bar + new chat button ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search chats...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // --- Plus button (new chat) ---
                IconButton.filled(
                  onPressed: _showNewChatDialog,
                  icon: const Icon(Icons.add),
                  tooltip: 'New chat',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // --- Chats list ---
          Expanded(
            child: chats.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.trim().isEmpty
                          ? 'No chats yet. Tap + to start one!'
                          : 'No chats found.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      return _ChatTile(
                        chat: chat,
                        onTap: () => _openChat(chat),
                        onLongPress: () => _showChatActions(chat),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// A chat rectangle (chat-list.png): avatar with pin badge, name, last
/// message preview, time and unread badge on the right.
class _ChatTile extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChatTile({
    required this.chat,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final lastMessage = chat.lastMessage;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 12),
        color: const Color(0xFFF2F4F8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: chat.friend.color,
                child: Text(
                  chat.title.isNotEmpty ? chat.title[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (chat.isPinned)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.push_pin,
                      size: 12,
                      color: Colors.blue,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            chat.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            lastMessage?.text ?? 'No messages yet',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                lastMessage != null
                    ? formatTime(lastMessage.time)
                    : '',
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
              if (chat.unreadCount > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${chat.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}