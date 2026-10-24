import 'package:flutter/material.dart';
import 'package:pic_collector/data/app_store.dart';
import 'package:pic_collector/models/friend.dart';
import 'package:pic_collector/screens/main-features/chat_detail_screen.dart';
import 'package:pic_collector/widgets/username_copy_button.dart';

/// Simple profile page of a friend, opened by tapping a friend row
/// in the friends list.
class FriendProfileScreen extends StatelessWidget {
  final Friend friend;

  const FriendProfileScreen({super.key, required this.friend});

  void _openChat(BuildContext context) {
    final chat = AppStore.instance.getOrCreateChat(friend);
    AppStore.instance.markChatRead(chat);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatDetailScreen(chat: chat)),
    );
  }

  /// Whether the current user has set a nickname for this friend.
  bool get _hasNickname =>
      friend.nickname != null && friend.nickname!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // Real name as the headline: the nickname is shown as its own field
    // below instead of replacing the name.
    final headlineName = friend.name.trim().isNotEmpty
        ? friend.name
        : friend.displayUsername;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- Big avatar ---
                CircleAvatar(
                  radius: 56,
                  backgroundColor: friend.color,
                  child: Text(
                    headlineName.isNotEmpty
                        ? headlineName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // --- Real name (headline) ---
                Text(
                  headlineName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                // --- Nickname as its own field, only when set ---
                if (_hasNickname) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Known as “${friend.nickname!.trim()}”',
                    style: const TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 4),
                // --- Username with copy button ---
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        '@${friend.displayUsername}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.blue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (friend.displayUsername.trim().isNotEmpty)
                      UsernameCopyButton(
                        username: friend.displayUsername.trim(),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                // --- Info card ---
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: friend.email,
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.badge_outlined,
                          label: 'Username',
                          value: '@${friend.displayUsername}',
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.label_outline,
                          label: 'Nickname',
                          value: _hasNickname
                              ? friend.nickname!.trim()
                              : 'Not set',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // --- Message button ---
                SizedBox(
                  width: 220,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _openChat(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text(
                      'Send Message',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A label/value row used in the profile info card.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black54),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
