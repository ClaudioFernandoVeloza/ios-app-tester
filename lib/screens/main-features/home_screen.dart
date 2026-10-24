import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pic_collector/data/static_data.dart';
import 'package:pic_collector/models/friend.dart';
import 'package:pic_collector/models/group.dart';
import 'package:pic_collector/screens/main-features/group_screen.dart';
import 'package:pic_collector/utils/formatters.dart';
import 'package:pic_collector/utils/user_notice.dart';

/// Home Screen: lists the user's groups with search + create/edit/delete.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();

  // TODO(firebase): fill from FriendService.instance.watchFriends().
  final List<Friend> _friends = [];

  // TODO(firebase): load the user's groups once groups are persisted.
  final List<Group> _groups = [];

  static const List<String> _categories = StaticData.categories;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Group> get _filteredGroups {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _groups;
    return _groups
        .where((group) => group.name.toLowerCase().contains(query))
        .toList();
  }

  /// show group description
  void _showGroupDescription(Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(group.description),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.category_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Category: ${group.category}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Created: ${formatDate(group.createdAt)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Members (${group.members.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              // --- List ALL members with avatars ---
              ...group.members.map(
                    (member) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: member.color,
                        child: Text(
                          member.name.isNotEmpty
                              ? member.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              member.email,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// create group
  void _createGroup() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final friendSearchController = TextEditingController();
    String? selectedCategory;
    final selectedFriends = <Friend>{};

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Create New Group'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Group name ---
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Group name',
                      hintText: 'e.g. Summer Party 2025',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // --- Description ---
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Short description of the group',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // --- Category ---
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map(
                          (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  // --- Friends search ---
                  Text(
                    'Include friends',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: friendSearchController,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search friends...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // --- Friends list (searchable) ---
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: _buildFriendPicker(
                      searchController: friendSearchController,
                      selectedFriends: selectedFriends,
                      onChanged: () => setDialogState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final description = descriptionController.text.trim();

                  if (name.isEmpty) {
                    Navigator.pop(dialogContext);
                    showSnackBar(context, 'Please enter a group name');
                    return;
                  }
                  if (description.isEmpty) {
                    Navigator.pop(dialogContext);
                    showSnackBar(context, 'Please enter a description');
                    return;
                  }
                  if (selectedCategory == null) {
                    Navigator.pop(dialogContext);
                    showSnackBar(context, 'Please select a category');
                    return;
                  }

                  setState(() {
                    _groups.add(
                      Group(
                        name: name,
                        description: description,
                        category: selectedCategory!,
                        members: selectedFriends.toList(),
                        createdAt: DateTime.now(),
                        icon: Icons.photo_library,
                        color: Colors.blueGrey,
                      ),
                    );
                  });
                  Navigator.pop(dialogContext);
                  showSnackBar(context, 'Group created!');
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Builds the searchable friend picker list.
  Widget _buildFriendPicker({
    TextEditingController? searchController,
    required Set<Friend> selectedFriends,
    required VoidCallback onChanged,
  }) {
    // Use a local search controller if none is provided.
    final controller = searchController ?? TextEditingController();
    final query = controller.text.trim().toLowerCase();
    final filteredFriends = query.isEmpty
        ? _friends
        : _friends
        .where(
          (friend) =>
      friend.name.toLowerCase().contains(query) ||
          friend.email.toLowerCase().contains(query),
    )
        .toList();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: filteredFriends.map((friend) {
          final isSelected = selectedFriends.contains(friend);
          return CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: isSelected,
            title: Text(friend.name),
            subtitle: Text(friend.email),
            secondary: CircleAvatar(
              backgroundColor: friend.color,
              child: Text(
                friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            onChanged: (checked) {
              if (checked == true) {
                selectedFriends.add(friend);
              } else {
                selectedFriends.remove(friend);
              }
              onChanged();
            },
          );
        }).toList(),
      ),
    );
  }

  /// opens a group when you tab/click on it
  void _openGroup(Group group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupScreen(
          groupName: group.name,
          groupDescription: group.description,
          groupCategory: group.category,
          groupCreatedAt: group.createdAt,
          members: group.members,
        ),
      ),
    );
  }

  /// Shows the action dialog when a group is long-pressed.
  void _showGroupActions(Group group) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(group.name),
        content: const Text('What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _editGroup(group);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteGroup(group);
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// delete group after clicking delete after long-press
  void _deleteGroup(Group group) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Are you sure you want to delete "${group.name}"?'),
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
              setState(() {
                _groups.remove(group);
              });
              Navigator.pop(dialogContext);
              showSnackBar(context, 'Group deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Opens a pre-filled dialog to edit an existing group after group long-press.
  void _editGroup(Group group) {
    final nameController = TextEditingController(text: group.name);
    final descriptionController = TextEditingController(text: group.description);
    final friendSearchController = TextEditingController();
    String? selectedCategory = group.category;
    final selectedFriends = <Friend>{...group.members};

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Group'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Group name ---
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Group name',
                      hintText: 'e.g. Summer Party 2025',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // --- Description ---
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Short description of the group',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // --- Category ---
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map(
                          (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  // --- Friends search ---
                  Text(
                    'Include friends',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: friendSearchController,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search friends...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // --- Friends list (searchable) ---
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: _buildFriendPicker(
                      searchController: friendSearchController,
                      selectedFriends: selectedFriends,
                      onChanged: () => setDialogState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final description = descriptionController.text.trim();

                  if (name.isEmpty) {
                    Navigator.pop(dialogContext);
                    showSnackBar(context, 'Please enter a group name');
                    return;
                  }
                  if (description.isEmpty) {
                    Navigator.pop(dialogContext);
                    showSnackBar(context, 'Please enter a description');
                    return;
                  }
                  if (selectedCategory == null) {
                    Navigator.pop(dialogContext);
                    showSnackBar(context, 'Please select a category');
                    return;
                  }

                  setState(() {
                    final index = _groups.indexOf(group);
                    if (index != -1) {
                      _groups[index] = Group(
                        name: name,
                        description: description,
                        category: selectedCategory!,
                        members: selectedFriends.toList(),
                        createdAt: group.createdAt,
                        icon: group.icon,
                        color: group.color,
                      );
                    }
                  });
                  Navigator.pop(dialogContext);
                  showSnackBar(context, 'Group updated!');
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // --- Search bar + plus button ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search groups...',
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
                // --- Plus button (create new group) ---
                IconButton.filled(
                  onPressed: _createGroup,
                  icon: const Icon(Icons.add),
                  tooltip: 'Create new group',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // --- Groups list ---
          Expanded(
            child: _filteredGroups.isEmpty
                ? Center(
              child: Text(
                _searchController.text.trim().isEmpty
                    ? 'No groups yet. Tap + to create one!'
                    : 'No groups found.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _filteredGroups.length,
              itemBuilder: (context, index) {
                final group = _filteredGroups[index];
                return _GroupTile(
                  group: group,
                  onTap: () => _openGroup(group),
                  onInfoTap: () => _showGroupDescription(group),
                  onLongPress: () => _showGroupActions(group),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;
  final VoidCallback onLongPress;

  const _GroupTile({
    required this.group,
    required this.onTap,
    required this.onInfoTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        LongPressGestureRecognizer:
        GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
            duration: const Duration(seconds: 2),
          ),
              (recognizer) {
            recognizer.onLongPress = onLongPress;
          },
        ),
      },
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: group.color,
            child: Icon(group.icon, color: Colors.white),
          ),
          title: Text(
            group.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            '${group.category} · ${formatMemberNames(group.members.map((m) => m.name).toList())}',
            style: const TextStyle(color: Colors.black54),
          ),
          onTap: onTap,
          trailing: IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.grey),
            tooltip: 'Group info',
            onPressed: onInfoTap,
          ),
        ),
      ),
    );
  }
}
