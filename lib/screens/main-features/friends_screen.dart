import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pic_collector/data/app_store.dart';
import 'package:pic_collector/models/friend.dart';
import 'package:pic_collector/models/friend_request.dart';
import 'package:pic_collector/models/user_profile.dart';
import 'package:pic_collector/screens/main-features/chat_detail_screen.dart';
import 'package:pic_collector/screens/main-features/friend_profile_screen.dart';
import 'package:pic_collector/screens/main-features/scan_qr_screen.dart';
import 'package:pic_collector/services/friend_service.dart';
import 'package:pic_collector/utils/user_notice.dart';

/// Friends tab: searchable list of friends with add-friend, quick chat,
/// profile navigation, and long-press actions (nickname/delete).
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();

  /// Live results from the real username search (Firestore).
  List<UserProfile> _searchResults = const [];
  bool _isSearching = false;

  AppStore get _store => AppStore.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Runs a real username-prefix search on every keystroke.
  Future<void> _onSearchChanged(String value) async {
    setState(() {}); // refresh the local friend filter immediately
    final query = value.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = const [];
          _isSearching = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _isSearching = true);
    try {
      final results = await FriendService.instance.searchByUsername(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchResults = const [];
        _isSearching = false;
      });
    }
  }

  /// The search bar filters local friends AND shows real user matches so a
  /// request can be sent to someone who is not a friend yet.
  bool get _showingSearchResults => _searchController.text.trim().isNotEmpty;

  List<Friend> get _filteredFriends {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _store.friends;
    return _store.friends
        .where(
          (friend) =>
              friend.displayName.toLowerCase().contains(query) ||
              friend.displayUsername.toLowerCase().contains(query) ||
              friend.email.toLowerCase().contains(query),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _openFriendProfile(Friend friend) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendProfileScreen(friend: friend),
      ),
    );
  }

  /// Opens (or creates) the chat with the given friend.
  void _openChatWith(Friend friend) {
    final chat = _store.getOrCreateChat(friend);
    _store.markChatRead(chat);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatDetailScreen(chat: chat)),
    );
  }

  /// Maps a Firestore failure to a user-readable message and logs the raw
  /// error so the exact code (permission-denied, failed-precondition, ...)
  /// is visible in the app logs.
  String _sendErrorMessage(Object e) {
    debugPrint('sendRequest failed: $e');
    if (e is FirebaseException) {
      debugPrint('sendRequest code: ${e.code} ${e.message}');
      if (e.code == 'permission-denied') {
        return 'Blocked by security rules — deploy the latest firestore.rules';
      }
      if (e.code == 'failed-precondition') {
        return 'Index still building — try again in a minute';
      }
      if (e.code == 'unavailable') {
        return 'Network unavailable — check connection and retry';
      }
    }
    return 'Could not send the request';
  }

  /// "Add Friend" dialog (add-friend.png)
  void _showAddFriendDialog() {
    final inputController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Friend'),
        content: TextField(
          controller: inputController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter username or email',
            prefixIcon: Icon(Icons.person_add_alt_1),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submitAddFriend(dialogContext, inputController),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 2,
            ),
            onPressed: () => _submitAddFriend(dialogContext, inputController),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAddFriend(
    BuildContext dialogContext,
    TextEditingController inputController,
  ) async {
    final input = inputController.text.trim();
    if (input.isEmpty) {
      showSnackBar(context, 'Please enter a username or email');
      return;
    }

    Navigator.pop(dialogContext);
    await _sendRequestAndNotify(input);
  }

  /// Bottom sheet with friend actions (edit-friend.png).
  void _showFriendActions(Friend friend) {
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
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Nickname'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showEditNicknameDialog(friend);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete Friend',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDeleteFriend(friend);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog to set/clear a friend's nickname.
  void _showEditNicknameDialog(Friend friend) {
    final nicknameController = TextEditingController(text: friend.nickname);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Nickname'),
        content: TextField(
          controller: nicknameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nickname for ${friend.name}',
            prefixIcon: const Icon(Icons.label_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear nickname',
              onPressed: () => nicknameController.clear(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _store.renameFriend(friend, nicknameController.text);
              setState(() {});
              Navigator.pop(dialogContext);
              showSnackBar(context, 'Nickname updated');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Confirmation before deleting a friend.
  void _confirmDeleteFriend(Friend friend) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Friend'),
        content: Text('Are you sure you want to delete ${friend.displayName}?'),
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
              setState(() => _store.removeFriend(friend));
              Navigator.pop(dialogContext);
              showSnackBar(context, 'Friend deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet with actions for a real (Firestore) friend (long-press on
  /// a "My Friends" tile).
  void _showRealFriendActions(UserProfile profile) {
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
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Nickname'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showEditNicknameForProfile(profile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete Friend',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDeleteRealFriend(profile);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog to set/clear the current user's private nickname for a real
  /// (Firestore) friend. Saved to Firestore, then mirrored into any local
  /// chat with them so the chat list shows the new name immediately.
  void _showEditNicknameForProfile(UserProfile profile) {
    final nicknameController = TextEditingController(text: profile.nickname);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Nickname'),
        content: TextField(
          controller: nicknameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nickname for ${_realFriendName(profile)}',
            prefixIcon: const Icon(Icons.label_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear nickname',
              onPressed: () => nicknameController.clear(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _saveNickname(profile, nicknameController.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Persists the nickname for a real friend and syncs local chats.
  Future<void> _saveNickname(UserProfile profile, String nickname) async {
    try {
      await FriendService.instance.setNickname(profile, nickname);
      _store.renameFriendByEmail(profile.email, nickname);
      if (!mounted) return;
      showSnackBar(context, 'Nickname updated');
    } catch (e) {
      debugPrint('setNickname failed: $e');
      if (!mounted) return;
      final message = e is FirebaseException && e.code == 'permission-denied'
          ? 'Blocked by security rules — deploy the latest firestore.rules'
          : 'Could not update the nickname';
      showSnackBar(context, message);
    }
  }

  /// Confirmation before deleting a real (Firestore) friend.
  void _confirmDeleteRealFriend(UserProfile profile) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Friend'),
        content: Text(
          'Are you sure you want to delete ${_realFriendName(profile)}?',
        ),
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
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteRealFriend(profile);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Deletes both friendship mirror docs in Firestore (the live list stream
  /// removes the tile automatically) and drops any local chat with them.
  Future<void> _deleteRealFriend(UserProfile profile) async {
    try {
      await FriendService.instance.deleteFriend(profile);
      _store.removeChatsWithEmail(profile.email);
      if (!mounted) return;
      showSnackBar(context, 'Friend deleted');
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, _deleteErrorMessage(e));
    }
  }

  /// Display name of a real friend: full name, falling back to username.
  String _realFriendName(UserProfile profile) =>
      profile.fullName.trim().isNotEmpty ? profile.fullName : profile.username;

  /// Maps a Firestore failure during friend deletion to a user-readable
  /// message and logs the raw error so the exact code is visible.
  String _deleteErrorMessage(Object e) {
    debugPrint('deleteFriend failed: $e');
    if (e is FirebaseException) {
      debugPrint('deleteFriend code: ${e.code} ${e.message}');
      if (e.code == 'permission-denied') {
        return 'Blocked by security rules — deploy the latest firestore.rules';
      }
      if (e.code == 'unavailable') {
        return 'Network unavailable — check connection and retry';
      }
    }
    return 'Could not delete the friend';
  }

  /// Sends a request to a user found via search.
  Future<void> _sendRequestTo(UserProfile profile) =>
      _sendRequestAndNotify(profile.username);

  /// Opens the full-screen QR scanner and sends a friend request to the
  /// username decoded from the scanned code.
  Future<void> _openQrScanner() async {
    final target = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanQrScreen()),
    );
    if (!mounted || target == null || target.isEmpty) return;
    await _sendRequestAndNotify(target);
  }

  /// Sends a friend request to [target] (username or email) and shows the
  /// shared outcome. Used by the add-friend dialog, search results and the
  /// QR scanner so every entry point reports results the same way.
  Future<void> _sendRequestAndNotify(String target) async {
    String message;
    try {
      final result = await FriendService.instance.sendRequest(target);
      if (!mounted) return;
      message = switch (result) {
        SendRequestResult.sent => 'Request sent to $target',
        SendRequestResult.alreadyPending =>
          'A request is already pending with $target',
        SendRequestResult.alreadyFriends => 'You are already friends with $target',
        SendRequestResult.selfRequest => 'You cannot add yourself',
        SendRequestResult.userNotFound => 'No user found for "$target"',
      };
    } catch (e) {
      if (!mounted) return;
      message = _sendErrorMessage(e);
    }
    showSnackBar(context, message);
  }

  /// Accepts an incoming request found via search (from the requester's
  /// tile in the "People" list).
  Future<void> _acceptFromProfile(
    FriendRequest request,
    UserProfile profile,
  ) async {
    try {
      await FriendService.instance.acceptRequest(request);
      if (!mounted) return;
      showSnackBar(context, 'You are now friends with ${profile.username}');
    } catch (e) {
      debugPrint('acceptRequest failed: $e');
      if (!mounted) return;
      showSnackBar(context, 'Could not accept the request');
    }
  }

  /// Declines an incoming request found via search.
  Future<void> _declineFromProfile(
    FriendRequest request,
    UserProfile profile,
  ) async {
    try {
      await FriendService.instance.declineRequest(request);
      if (!mounted) return;
      showSnackBar(context, 'Request from ${profile.username} declined');
    } catch (e) {
      debugPrint('declineRequest failed: $e');
      if (!mounted) return;
      showSnackBar(context, 'Could not decline the request');
    }
  }

  /// Opens (or creates) the chat with a real (Firestore) friend.
  void _openChatWithProfile(UserProfile profile) {
    final friend = _friendFromProfile(profile);
    final chat = _store.getOrCreateChat(friend);
    _store.markChatRead(chat);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatDetailScreen(chat: chat)),
    );
  }

  /// Builds a [Friend] (the profile/chat model) from a real [UserProfile],
  /// falling back to the username when the full name is empty.
  Friend _friendFromProfile(UserProfile profile) {
    return Friend(
      name: profile.fullName.trim().isNotEmpty
          ? profile.fullName
          : profile.username,
      username: profile.username,
      email: profile.email,
      nickname: profile.nickname,
      color: Colors.blue,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final friends = _filteredFriends;

    return SafeArea(
      child: Column(
        children: [
          // --- Search bar + add friend button ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search friends...',
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
                const SizedBox(width: 4),
                // --- QR scan button (add friend by scanning their code) ---
                IconButton(
                  onPressed: _openQrScanner,
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Scan QR code',
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                // --- Plus button (add friend) ---
                IconButton.filled(
                  onPressed: _showAddFriendDialog,
                  icon: const Icon(Icons.person_add_alt),
                  tooltip: 'Add friend',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // --- Search results + friends list in ONE scroll view so the
          // content can scroll when the keyboard shrinks the screen ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                // --- Real user matches (Firestore username search) ---
                if (_showingSearchResults)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'People',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                        ),
                        const SizedBox(height: 8),
                        if (_isSearching)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        else if (_searchResults.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'No users found.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        else
                          // One subscription per stream for the whole results list
                          // (not one per tile): friendships + pending requests in
                          // both directions, so each tile can show the right state.
                          StreamBuilder<List<UserProfile>>(
                            stream: FriendService.instance.watchFriends(),
                            builder: (context, friendsSnapshot) {
                              final friendUids =
                                  (friendsSnapshot.data ??
                                          const <UserProfile>[])
                                      .map((f) => f.uid)
                                      .toSet();
                              return StreamBuilder<Set<String>>(
                                stream: FriendService.instance
                                    .watchPendingOutgoingUids(),
                                builder: (context, outgoingSnapshot) {
                                  final outgoingUids =
                                      outgoingSnapshot.data ?? const <String>{};
                                  return StreamBuilder<
                                    Map<String, FriendRequest>
                                  >(
                                    stream: FriendService.instance
                                        .watchIncomingRequestsByUid(),
                                    builder: (context, incomingSnapshot) {
                                      final incomingRequests =
                                          incomingSnapshot.data ??
                                          const <String, FriendRequest>{};
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ..._searchResults.map(
                                            (profile) => _SearchResultTile(
                                              profile: profile,
                                              isFriend: friendUids.contains(
                                                profile.uid,
                                              ),
                                              hasOutgoingRequest: outgoingUids
                                                  .contains(profile.uid),
                                              incomingRequest:
                                                  incomingRequests[profile.uid],
                                              onSend: () =>
                                                  _sendRequestTo(profile),
                                              onAccept: () {
                                                final request =
                                                    incomingRequests[profile
                                                        .uid];
                                                if (request != null) {
                                                  _acceptFromProfile(
                                                    request,
                                                    profile,
                                                  );
                                                }
                                              },
                                              onDecline: () {
                                                final request =
                                                    incomingRequests[profile
                                                        .uid];
                                                if (request != null) {
                                                  _declineFromProfile(
                                                    request,
                                                    profile,
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        const Divider(),
                      ],
                    ),
                  ),
                // --- Friends: real friendships from Firestore, followed by
                // any locally held friends (AppStore).
                StreamBuilder<List<UserProfile>>(
                  stream: FriendService.instance.watchFriends(),
                  builder: (context, snapshot) {
                    final realFriends = snapshot.data ?? const <UserProfile>[];
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        realFriends.isEmpty) {
                      return const SizedBox(
                        height: 240,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    if (realFriends.isEmpty && friends.isEmpty) {
                      return SizedBox(
                        height: 240,
                        child: Center(
                          child: Text(
                            _searchController.text.trim().isEmpty
                                ? 'No friends yet. Tap + to add one!'
                                : 'No friends found.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.black54),
                          ),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (realFriends.isNotEmpty) ...[
                          Text(
                            'My Friends',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                          ),
                          const SizedBox(height: 8),
                          ...realFriends.map(
                            (profile) => _RealFriendTile(
                              profile: profile,
                              onTap: () => _openFriendProfile(
                                _friendFromProfile(profile),
                              ),
                              onChatTap: () => _openChatWithProfile(profile),
                              onLongPress: () =>
                                  _showRealFriendActions(profile),
                            ),
                          ),
                          if (friends.isNotEmpty) const Divider(),
                        ],
                        ...friends.map(
                          (friend) => _FriendTile(
                            friend: friend,
                            onTap: () => _openFriendProfile(friend),
                            onChatTap: () => _openChatWith(friend),
                            onLongPress: () => _showFriendActions(friend),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A real friend (Firestore friendship doc): avatar, name, @username and a
/// chat icon. Tap opens the profile; long-press opens the friend actions
/// (delete).
class _RealFriendTile extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onTap;
  final VoidCallback onChatTap;
  final VoidCallback onLongPress;

  const _RealFriendTile({
    required this.profile,
    required this.onTap,
    required this.onChatTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 8),
        color: const Color(0xFFE8F5E9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: CircleAvatar(
            backgroundColor: Colors.green,
            child: Text(
              (name.isNotEmpty ? name[0] : '?').toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('@${profile.username}'),
          trailing: IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
            tooltip: 'Open chat',
            onPressed: onChatTap,
          ),
        ),
      ),
    );
  }
}

/// A single username-search hit. Shows the tile's relationship state:
/// already friends, request pending (sent), request pending (received),
/// or a Send button when there is no request yet.
class _SearchResultTile extends StatelessWidget {
  final UserProfile profile;
  final bool isFriend;
  final bool hasOutgoingRequest;

  /// The pending request this user sent to the current user, or null.
  final FriendRequest? incomingRequest;
  final VoidCallback onSend;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _SearchResultTile({
    required this.profile,
    required this.isFriend,
    required this.hasOutgoingRequest,
    required this.incomingRequest,
    required this.onSend,
    required this.onAccept,
    required this.onDecline,
  });

  /// Right-side widget depending on the relationship with [profile].
  Widget _buildTrailing() {
    // Already friends: green badge (unchanged).
    if (isFriend) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, color: Colors.green, size: 18),
          SizedBox(width: 4),
          Text(
            'Friends',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    // I already sent them a request: not tappable, just an amber "Pending".
    if (hasOutgoingRequest) {
      return Tooltip(
        message: 'Request sent — awaiting response',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.schedule, color: Colors.orange, size: 18),
            SizedBox(width: 4),
            Text(
              'Pending',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // They sent me a request: accept or decline it right here.
    if (incomingRequest != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: onDecline,
            child: const Text('Decline', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: onAccept,
            child: const Text(
              'Accept',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    // No relationship yet: send a request.
    return TextButton(onPressed: onSend, child: const Text('Send'));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFEAF3FE),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            profile.username.isNotEmpty
                ? profile.username[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          profile.fullName.trim().isNotEmpty
              ? profile.fullName
              : profile.username,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('@${profile.username}'),
        trailing: _buildTrailing(),
      ),
    );
  }
}

/// A friend rectangle (friends-screen.png): avatar, name, @username, email
/// and a chat icon on the right.
class _FriendTile extends StatelessWidget {
  final Friend friend;
  final VoidCallback onTap;
  final VoidCallback onChatTap;
  final VoidCallback onLongPress;

  const _FriendTile({
    required this.friend,
    required this.onTap,
    required this.onChatTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 12),
        color: const Color(0xFFF2F4F8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: CircleAvatar(
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
          title: Text(
            friend.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${friend.displayUsername}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              Text(
                friend.email,
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
            tooltip: 'Open chat',
            onPressed: onChatTap,
          ),
        ),
      ),
    );
  }
}
