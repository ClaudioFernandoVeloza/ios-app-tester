import 'dart:io';
import 'dart:typed_data';

import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';

bool _mediaStoreInitialized = false;

/// Saves the ZIP to a user-visible location:
/// - Android: public Downloads folder via MediaStore (no permissions prompt
///   needed for the app's own files on Android 10+).
/// - iOS: app Documents folder, which appears in the Apple Files app
///   (enabled via UIFileSharingEnabled in Info.plist).
///
/// Returns a short user-friendly description of where the file was saved
/// (without a "Saved to" prefix).
Future<String> saveToDevice(Uint8List bytes, String fileName) async {
  if (Platform.isAndroid) {
    return _saveToAndroidDownloads(bytes, fileName);
  }

  // iOS (and desktop fallback): save into the app Documents directory.
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return 'the app folder (visible in the Files app): ${file.path}';
}

/// Saves via Android MediaStore into `Download/PicCollector/<fileName>`.
Future<String> _saveToAndroidDownloads(Uint8List bytes, String fileName) async {
  if (!_mediaStoreInitialized) {
    await MediaStore.ensureInitialized();
    _mediaStoreInitialized = true;
  }
  MediaStore.appFolder = 'PicCollector';

  // MediaStore.saveFile copies from a temp file, then deletes it.
  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/$fileName');
  await tempFile.writeAsBytes(bytes, flush: true);

  final mediaStore = MediaStore();
  final saveInfo = await mediaStore.saveFile(
    tempFilePath: tempFile.path,
    dirType: DirType.download,
    dirName: DirName.download,
    relativePath: FilePath.root,
  );

  final savedName = saveInfo?.name ?? fileName;
  return 'Downloads/PicCollector/$savedName';
}

/// Not used on native platforms; kept for interface parity.
void downloadInBrowser(Uint8List bytes, String fileName) {
  throw UnsupportedError('Browser download is not available on this platform');
}