import 'package:flutter/material.dart';
import 'package:pic_collector/models/friend.dart';
import 'package:pic_collector/models/sub_group.dart';
import 'package:pic_collector/screens/main-features/subgroup_screen.dart';
import 'package:pic_collector/services/download/download_service.dart';
import 'package:pic_collector/utils/formatters.dart';
import 'package:pic_collector/utils/user_notice.dart';

/// A group's screen showing its info and a compact list of subgroups.
class GroupScreen extends StatefulWidget {
  final String groupName;
  final String groupDescription;
  final String groupCategory;
  final DateTime groupCreatedAt;
  final List<Friend> members;

  const GroupScreen({
    super.key,
    required this.groupName,
    required this.groupDescription,
    required this.groupCategory,
    required this.groupCreatedAt,
    required this.members,
  });

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  late List<SubGroup> _subGroups;
  final _subGroupSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _subGroups = [
      SubGroup(
        title: 'Beach Day',
        description: 'Photos from the beach party on Saturday.',
        members: widget.members.take(2).toList(),
        pictures: [
          'assets/images/1.jpg',
          'assets/images/oniro.jpeg',
          'assets/images/ploio-onirou.jpg',
        ],
      ),
      SubGroup(
        title: 'Night Out',
        description: 'Evening photos and dancing.',
        members: widget.members,
        pictures: [
          'assets/images/1.jpg',
          'assets/images/2.jpg',
          'assets/images/3.jpg',
        ],
      ),
      SubGroup(
        title: 'Group Photo',
        description: 'The official group picture.',
        members: widget.members,
        pictures: [
          'assets/images/2.jpg',
          'assets/images/oniro.jpeg',
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _subGroupSearchController.dispose();
    super.dispose();
  }

  List<SubGroup> get _filteredSubGroups {
    final query = _subGroupSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _subGroups;
    return _subGroups
        .where((subGroup) => subGroup.title.toLowerCase().contains(query))
        .toList();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Updates a subgroup in the list after it changes inside SubGroupScreen.
  void _onSubGroupChanged(SubGroup updated) {
    setState(() {
      final index = _subGroups.indexOf(updated);
      if (index != -1) {
        _subGroups[index] = updated;
      }
    });
  }

  /// Downloads all photos of the group as a ZIP with subfolders per subgroup.
  Future<void> _downloadGroup() async {
    try {
      final message = await downloadGroupAsZip(widget.groupName, _subGroups);
      if (!mounted) return;
      showSnackBar(context, message);
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, e.toString());
    }
  }

  /// Opens the inside of a subgroup.
  void _openSubGroup(SubGroup subGroup) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubGroupScreen(
          subGroup: subGroup,
          onSubGroupChanged: _onSubGroupChanged,
        ),
      ),
    );
  }

  /// Shows the action dialog when a subgroup tile is long-pressed.
  void _showSubGroupActions(SubGroup subGroup) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(subGroup.title),
        content: const Text('What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _editSubGroup(subGroup);
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
              _deleteSubGroup(subGroup);
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteSubGroup(SubGroup subGroup) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Subgroup'),
        content: Text('Are you sure you want to delete "${subGroup.title}"?'),
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
                _subGroups.remove(subGroup);
              });
              Navigator.pop(dialogContext);
              showSnackBar(context, 'Subgroup deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Opens a pre-filled dialog to edit a subgroup (title, description, members).
  void _editSubGroup(SubGroup subGroup) {
    final titleController = TextEditingController(text: subGroup.title);
    final descriptionController =
        TextEditingController(text: subGroup.description);
    final friendSearchController = TextEditingController();
    final selectedFriends = <Friend>{...subGroup.members};

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Subgroup'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Subgroup title ---
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Subgroup title',
                      hintText: 'e.g. Beach Day',
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
                      hintText: 'Short description of the subgroup',
                      border: OutlineInputBorder(),
                    ),
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
                  final title = titleController.text.trim();
                  final description = descriptionController.text.trim();

                  if (title.isEmpty) {
                    Navigator.pop(dialogContext);
                    showSnackBar(context, 'Please enter a subgroup title');
                    return;
                  }
                  if (description.isEmpty) {
                    Navigator.pop(dialogContext);
                    showSnackBar(context, 'Please enter a description');
                    return;
                  }

                  setState(() {
                    final index = _subGroups.indexOf(subGroup);
                    if (index != -1) {
                      _subGroups[index] = SubGroup(
                        title: title,
                        description: description,
                        members: selectedFriends.toList(),
                        pictures: subGroup.pictures,
                      );
                    }
                  });
                  Navigator.pop(dialogContext);
                  showSnackBar(context, 'Subgroup updated!');
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Opens a dialog to create a new subgroup.
  void _createSubGroup() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final friendSearchController = TextEditingController();
    final selectedFriends = <Friend>{};

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Create Subgroup'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Subgroup title ---
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Subgroup title',
                      hintText: 'e.g. Beach Day',
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
                      hintText: 'Short description of the subgroup',
                      border: OutlineInputBorder(),
                    ),
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
                  final title = titleController.text.trim();
                  final description = descriptionController.text.trim();

                  if (title.isEmpty) {
                    Navigator.pop(dialogContext);
                    showSnackBar(context, 'Please enter a subgroup title');
                    return;
                  }
                  if (description.isEmpty) {
                    Navigator.pop(dialogContext);
                    showSnackBar(context, 'Please enter a description');
                    return;
                  }

                  setState(() {
                    _subGroups.add(
                      SubGroup(
                        title: title,
                        description: description,
                        members: selectedFriends.toList(),
                        pictures: const [],
                      ),
                    );
                  });
                  Navigator.pop(dialogContext);
                  showSnackBar(context, 'Subgroup created!');
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
    final controller = searchController ?? TextEditingController();
    final query = controller.text.trim().toLowerCase();
    final filteredFriends = query.isEmpty
        ? widget.members
        : widget.members
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.groupName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Group info card ---
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.groupName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.groupDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
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
                          'Category: ${widget.groupCategory}',
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
                          'Created: ${_formatDate(widget.groupCreatedAt)}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Members: ${formatMemberNames(widget.members.map((m) => m.name).toList())}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // --- Download all photos button ---
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _downloadGroup,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Download all photos'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // --- Search bar + plus button (like the groups search) ---
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subGroupSearchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search subgroups...',
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
                  // --- Plus button (create new subgroup) ---
                  IconButton.filled(
                    onPressed: _createSubGroup,
                    icon: const Icon(Icons.add),
                    tooltip: 'Create subgroup',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // --- Subgroups list (compact tiles like groups) ---
            if (_filteredSubGroups.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _subGroupSearchController.text.trim().isEmpty
                        ? 'No subgroups yet. Tap + to create one!'
                        : 'No subgroups found.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        ),
                  ),
                ),
              )
            else
              ..._filteredSubGroups.map(
                (subGroup) => _SubGroupTile(
                  subGroup: subGroup,
                  onTap: () => _openSubGroup(subGroup),
                  onLongPress: () => _showSubGroupActions(subGroup),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact subgroup tile, styled like the group tiles on the home screen.
class _SubGroupTile extends StatelessWidget {
  final SubGroup subGroup;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SubGroupTile({
    required this.subGroup,
    required this.onTap,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: Colors.blue,
            child: const Icon(Icons.photo_library, color: Colors.white),
          ),
          title: Text(
            subGroup.title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            '${subGroup.pictures.length} photos · ${subGroup.members.length} members',
            style: const TextStyle(color: Colors.black54),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        ),
      ),
    );
  }
}

