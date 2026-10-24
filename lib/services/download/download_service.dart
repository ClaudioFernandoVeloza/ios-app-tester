import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pic_collector/models/sub_group.dart';

import 'download_service_io.dart'
    if (dart.library.js_interop) 'download_service_web.dart' as platform;

/// Detects the current platform: browser, iOS, or Android.
enum DownloadPlatform { browser, ios, android }

DownloadPlatform get currentPlatform {
  if (kIsWeb) return DownloadPlatform.browser;
  if (Platform.isIOS) return DownloadPlatform.ios;
  if (Platform.isAndroid) return DownloadPlatform.android;
  // Fallback: treat desktop as browser-like (download to file).
  return DownloadPlatform.browser;
}

/// Reads the bytes of a picture from either an asset path or a file path.
Future<Uint8List> _readPictureBytes(String path) async {
  if (path.startsWith('assets/')) {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }
  final file = File(path);
  return file.readAsBytes();
}

/// Adds pictures to the archive under the given folder path.
Future<void> _addPicturesToArchive(
  Archive archive,
  String folderPath,
  List<String> picturePaths,
) async {
  for (var i = 0; i < picturePaths.length; i++) {
    final picturePath = picturePaths[i];
    final bytes = await _readPictureBytes(picturePath);
    final fileName = _pictureFileName(picturePath, i);
    archive.addFile(
      ArchiveFile('$folderPath$fileName', bytes.length, bytes),
    );
  }
}

/// Builds a ZIP archive containing one folder per subgroup.
///
/// Structure:
///   `groupName/`
///     `subgroupTitle/`
///       photo1.jpg
///       photo2.jpg
///     `subgroupTitle2/`
///       photo1.jpg
Future<Uint8List> _buildGroupZip(
  String groupName,
  List<SubGroup> subGroups,
) async {
  final archive = Archive();
  final safeGroupName = _sanitizeName(groupName);

  for (final subGroup in subGroups) {
    if (subGroup.pictures.isEmpty) continue;

    final safeSubGroupName = _sanitizeName(subGroup.title);
    final folderPath = '$safeGroupName/$safeSubGroupName/';

    // Add a folder entry for the subgroup.
    archive.addFile(ArchiveFile(folderPath, 0, Uint8List(0)));

    await _addPicturesToArchive(archive, folderPath, subGroup.pictures);
  }

  return _encodeZip(archive);
}

/// Builds a ZIP archive containing a single subgroup's photos.
///
/// Structure:
///   `subgroupTitle/`
///     photo1.jpg
///     photo2.jpg
Future<Uint8List> _buildSubGroupZip(SubGroup subGroup) async {
  final archive = Archive();
  final safeSubGroupName = _sanitizeName(subGroup.title);
  final folderPath = '$safeSubGroupName/';

  // Add a folder entry for the subgroup.
  archive.addFile(ArchiveFile(folderPath, 0, Uint8List(0)));

  await _addPicturesToArchive(archive, folderPath, subGroup.pictures);

  return _encodeZip(archive);
}

/// Encodes the archive into ZIP bytes.
Uint8List _encodeZip(Archive archive) {
  final encoder = ZipEncoder();
  final zipData = encoder.encode(archive);
  return Uint8List.fromList(zipData);
}

/// Sanitizes a folder/file name for use inside a ZIP.
String _sanitizeName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.isEmpty ? 'Group' : cleaned;
}

/// Produces a clean file name for a picture inside the ZIP.
String _pictureFileName(String path, int index) {
  final uri = Uri.tryParse(path);
  final rawName = uri != null && uri.pathSegments.isNotEmpty
      ? uri.pathSegments.last
      : path.split(Platform.pathSeparator).last;

  final cleaned = _sanitizeName(rawName);
  if (cleaned.isNotEmpty && cleaned.contains('.')) return cleaned;

  // Fallback: use a numbered name with a .jpg extension.
  return 'photo_${index + 1}.jpg';
}

/// Downloads all photos of a group as a ZIP with subfolders per subgroup.
///
/// - Browser: triggers a browser download.
/// - Android: saves the ZIP to the public Downloads folder
///   (Download/PicCollector) via MediaStore.
/// - iOS: saves the ZIP to the app Documents folder, visible in the
///   Apple Files app.
/// Returns a message describing where the file was saved.
Future<String> downloadGroupAsZip(
  String groupName,
  List<SubGroup> subGroups,
) async {
  final hasPhotos = subGroups.any((sg) => sg.pictures.isNotEmpty);
  if (!hasPhotos) {
    throw Exception('No photos to download');
  }

  final zipBytes = await _buildGroupZip(groupName, subGroups);
  final safeName = _sanitizeName(groupName);
  final fileName = '$safeName.zip';

  return _deliverZip(zipBytes, fileName);
}

/// Downloads all photos of a single subgroup as a ZIP.
///
/// Structure inside the ZIP: `<subgroupTitle>/photo1.jpg`, ...
/// Returns a message describing where the file was saved.
Future<String> downloadSubGroupAsZip(SubGroup subGroup) async {
  if (subGroup.pictures.isEmpty) {
    throw Exception('No photos to download in this subgroup');
  }

  final zipBytes = await _buildSubGroupZip(subGroup);
  final safeName = _sanitizeName(subGroup.title);
  final fileName = '$safeName.zip';

  return _deliverZip(zipBytes, fileName);
}

/// Downloads the selected photos of a subgroup as a ZIP.
///
/// Structure inside the ZIP: `<subgroupTitle>/photo1.jpg`, ...
/// Returns a message describing where the file was saved.
Future<String> downloadPhotosAsZip(
  String subGroupName,
  List<String> picturePaths,
) async {
  if (picturePaths.isEmpty) {
    throw Exception('No photos selected');
  }

  final archive = Archive();
  final safeSubGroupName = _sanitizeName(subGroupName);
  final folderPath = '$safeSubGroupName/';

  // Add a folder entry for the subgroup.
  archive.addFile(ArchiveFile(folderPath, 0, Uint8List(0)));

  await _addPicturesToArchive(archive, folderPath, picturePaths);

  final zipBytes = _encodeZip(archive);
  final zipName = '$safeSubGroupName-selection.zip';

  return _deliverZip(zipBytes, zipName);
}

/// Delivers the ZIP bytes to the user according to the current platform.
Future<String> _deliverZip(Uint8List zipBytes, String fileName) {
  switch (currentPlatform) {
    case DownloadPlatform.browser:
      platform.downloadInBrowser(zipBytes, fileName);
      return Future.value('Downloading $fileName');
    case DownloadPlatform.ios:
    case DownloadPlatform.android:
      return platform
          .saveToDevice(zipBytes, fileName)
          .then((path) => 'Saved to $path');
  }
}