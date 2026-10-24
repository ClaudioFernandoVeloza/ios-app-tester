import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pic_collector/models/sub_group.dart';
import 'package:pic_collector/services/download/download_service.dart';
import 'package:pic_collector/utils/formatters.dart';
import 'package:flutter/gestures.dart';

/// Shows the inside of a subgroup: info, photo upload, and gallery.
class SubGroupScreen extends StatefulWidget {
  final SubGroup subGroup;
  final ValueChanged<SubGroup> onSubGroupChanged;

  const SubGroupScreen({
    super.key,
    required this.subGroup,
    required this.onSubGroupChanged,
  });

  @override
  State<SubGroupScreen> createState() => _SubGroupScreenState();
}

class _SubGroupScreenState extends State<SubGroupScreen> {
  late SubGroup _subGroup;
  final Set<String> _selectedPictures = {};

  bool get _isSelecting => _selectedPictures.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _subGroup = widget.subGroup;
  }

  void _syncSubGroup(SubGroup updated) {
    setState(() => _subGroup = updated);
    widget.onSubGroupChanged(updated);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Picks images from the phone's gallery and adds them to the subgroup.
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      imageQuality: 85,
    );

    if (pickedFiles.isEmpty) return;

    final newPaths = pickedFiles.map((file) => file.path).toList();

    _syncSubGroup(
      SubGroup(
        title: _subGroup.title,
        description: _subGroup.description,
        members: _subGroup.members,
        pictures: [..._subGroup.pictures, ...newPaths],
      ),
    );

    _showSnackBar('${newPaths.length} photo(s) added');
  }

  /// Downloads all photos of this subgroup as a ZIP file.
  Future<void> _downloadSubGroup() async {
    try {
      final message = await downloadSubGroupAsZip(_subGroup);
      if (!mounted) return;
      _showSnackBar(message);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString());
    }
  }

  /// Enters selection mode and selects the long-pressed photo.
  void _startSelection(String path) {
    setState(() => _selectedPictures.add(path));
  }

  /// Toggles selection of a photo while in selection mode.
  void _toggleSelection(String path) {
    setState(() {
      if (!_selectedPictures.remove(path)) {
        _selectedPictures.add(path);
      }
    });
  }

  /// Exits selection mode, clearing all selected photos.
  void _exitSelection() {
    setState(() => _selectedPictures.clear());
  }

  /// Selects every photo of the subgroup.
  void _selectAll() {
    setState(() => _selectedPictures.addAll(_subGroup.pictures));
  }

  /// Handles taps on a grid photo depending on the selection mode.
  void _onPhotoTap(String path, int index) {
    if (_isSelecting) {
      _toggleSelection(path);
    } else {
      _openImageViewer(index);
    }
  }

  /// Downloads the currently selected photos as a ZIP file.
  Future<void> _downloadSelected() async {
    try {
      final message = await downloadPhotosAsZip(
        _subGroup.title,
        _selectedPictures.toList(),
      );
      if (!mounted) return;
      _exitSelection();
      _showSnackBar(message);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString());
    }
  }

  /// Removes a specific image from the subgroup.
  void _deleteImage(String path) {
    _selectedPictures.remove(path);
    _syncSubGroup(
      SubGroup(
        title: _subGroup.title,
        description: _subGroup.description,
        members: _subGroup.members,
        pictures: _subGroup.pictures.where((p) => p != path).toList(),
      ),
    );
  }

  /// Opens a full-screen gallery viewer for the subgroup's pictures.
  void _openImageViewer(int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) => _ImageViewerDialog(
        pictures: _subGroup.pictures,
        initialIndex: initialIndex,
        onDelete: _deleteImage,
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
        leading: _isSelecting
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black87),
                tooltip: 'Exit selection',
                onPressed: _exitSelection,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
        title: _isSelecting
            ? Text(
                '${_selectedPictures.length} selected',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              )
            : Text(
                _subGroup.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
        centerTitle: true,
        actions: [
          if (_isSelecting &&
              _selectedPictures.length < _subGroup.pictures.length)
            IconButton(
              icon: const Icon(Icons.select_all, color: Colors.black87),
              tooltip: 'Select all',
              onPressed: _selectAll,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Subgroup info card ---
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
                      _subGroup.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subGroup.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                    const SizedBox(height: 12),
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
                            'Members: ${formatMemberNames(_subGroup.members.map((m) => m.name).toList())}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // --- Upload button ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Upload photos'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // --- Download subgroup button ---
            if (_subGroup.pictures.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _downloadSubGroup,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download photos (ZIP)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // --- Download selected photos button ---
            if (_isSelecting)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _downloadSelected,
                  icon: const Icon(Icons.download),
                  label: Text('Download selected (${_selectedPictures.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (_isSelecting) const SizedBox(height: 16),
            // --- Pictures grid ---
            if (_subGroup.pictures.isEmpty)
              Text(
                'No photos yet. Tap "Upload photos" to add from your gallery.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _subGroup.pictures.length,
                itemBuilder: (context, index) {
                  final path = _subGroup.pictures[index];
                  final isSelected = _selectedPictures.contains(path);
                  return GestureDetector(
                    onTap: () => _onPhotoTap(path, index),
                    onLongPress: () => _startSelection(path),
                    child: Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildImage(path),
                          ),
                        ),
                        if (isSelected)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue,
                                  width: 3,
                                ),
                                color: Colors.blue.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                        if (isSelected)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen gallery viewer with swipe navigation and image deletion.
class _ImageViewerDialog extends StatefulWidget {
  final List<String> pictures;
  final int initialIndex;
  final void Function(String path) onDelete;

  const _ImageViewerDialog({
    required this.pictures,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  late List<String> _pictures;
  late int _currentIndex;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pictures = List.of(widget.pictures);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() {
    if (_currentIndex < _pictures.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _confirmDelete() {
    final path = _pictures[_currentIndex];
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
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
              Navigator.pop(dialogContext);
              setState(() {
                _pictures.removeAt(_currentIndex);
                if (_currentIndex >= _pictures.length) {
                  _currentIndex = _pictures.length - 1;
                }
              });
              widget.onDelete(path);
              if (_pictures.isEmpty) {
                Navigator.pop(context);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // --- PageView wrapped in ScrollConfiguration ---
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
              },
            ),
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pictures.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return Center(
                  child: InteractiveViewer(
                    panEnabled: false,
                    child: _buildImage(
                      _pictures[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),

          // --- Previous button (Left Arrow) ---
          if (_currentIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.chevron_left, size: 36),
                  tooltip: 'Previous photo',
                  onPressed: _previousPage,
                ),
              ),
            ),

          // --- Next button (Right Arrow) ---
          if (_currentIndex < _pictures.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.chevron_right, size: 36),
                  tooltip: 'Next photo',
                  onPressed: _nextPage,
                ),
              ),
            ),

          // --- Close button ---
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // --- Delete button ---
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 28,
              ),
              tooltip: 'Delete photo',
              onPressed: _confirmDelete,
            ),
          ),

          // --- Counter (e.g. 2 / 5) ---
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${_currentIndex + 1} / ${_pictures.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds an image widget from either an asset path or a file path.
/// Asset paths start with 'assets/', file paths are regular filesystem paths.
Widget _buildImage(String path, {BoxFit fit = BoxFit.cover}) {
  if (path.startsWith('assets/')) {
    return Image.asset(
      path,
      fit: fit,
    );
  }
  return Image.file(
    File(path),
    fit: fit,
  );
}

