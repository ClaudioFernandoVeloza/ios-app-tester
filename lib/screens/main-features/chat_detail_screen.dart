import 'package:flutter/material.dart';
import 'package:pic_collector/data/app_store.dart';
import 'package:pic_collector/models/chat.dart';
import 'package:pic_collector/screens/main-features/friend_profile_screen.dart';
import 'package:pic_collector/utils/formatters.dart';
import 'package:pic_collector/utils/user_notice.dart';

/// Full-screen 1-to-1 conversation with a friend (chat-screen.png).
class ChatDetailScreen extends StatefulWidget {
  final Chat chat;

  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  Chat get _chat => widget.chat;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      AppStore.instance.sendMessage(_chat, text);
      _messageController.clear();
    });
    _scrollToBottom();
  }

  void _showComingSoon(String feature) {
    showSnackBar(context, '$feature is not available in this demo yet');
  }

  /// Opens the friend's profile page. When it comes back (e.g. after a
  /// nickname change) the AppBar refreshes with the latest name.
  Future<void> _openFriendProfile() async {
    // Look up the freshest friend from the store (nickname may have changed).
    final friend = AppStore.instance.findFriendByEmail(_chat.friend.email);
    if (friend == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendProfileScreen(friend: friend),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final friend = _chat.friend;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: _openFriendProfile,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: friend.color,
                child: Text(
                  friend.displayName.isNotEmpty
                      ? friend.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Colors.black87),
            tooltip: 'Video call',
            onPressed: () => _showComingSoon('Video call'),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.black87),
            tooltip: 'View profile',
            onPressed: _openFriendProfile,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- Messages list ---
            Expanded(
              child: _chat.messages.isEmpty
                  ? Center(
                      child: Text(
                        'Say hi to ${friend.displayName}!',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _chat.messages.length,
                      itemBuilder: (context, index) {
                        final message = _chat.messages[index];
                        return _MessageBubble(
                          text: message.text,
                          isMe: message.isMe,
                          time: formatTime(message.time),
                        );
                      },
                    ),
            ),
            // --- Input bar ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.blue,
                    ),
                    tooltip: 'Send a photo',
                    onPressed: () => _showComingSoon('Photo messages'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: _messageController.text.trim().isEmpty
                          ? Colors.grey
                          : Colors.blue,
                    ),
                    tooltip: 'Send',
                    onPressed: _messageController.text.trim().isEmpty
                        ? null
                        : _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single chat bubble, aligned left (received) or right (sent).
class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.black38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}