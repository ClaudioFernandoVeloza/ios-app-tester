import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser download of the given bytes.
void downloadInBrowser(Uint8List bytes, String fileName) {
  final jsBytes = bytes.toJS;
  final blob = web.Blob(
    [jsBytes].toJS,
    web.BlobPropertyBag(type: 'application/zip'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

/// Not used on web; kept for interface parity.
Future<String> saveToDevice(Uint8List bytes, String fileName) async {
  throw UnsupportedError('Device save is not available on the web');
}