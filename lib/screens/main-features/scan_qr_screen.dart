import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pic_collector/utils/qr_payload.dart';

/// Full-screen QR scanner for the add-friend flow.
///
/// Pops with the decoded username/email of a valid friend code, or with
/// null when the user closes the screen without scanning one. Sending the
/// request itself stays in the caller so every entry point reports through
/// the shared add-friend messages.
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  /// True once a valid code was found, so a late duplicate detection cannot
  /// pop the screen a second time.
  bool _handled = false;

  /// Keeps the "not a friend code" notice from stacking up while a foreign
  /// QR code stays in view.
  bool _invalidNoticeShown = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Decodes the first scan: pops with the username when the payload is a
  /// friend code, otherwise shows a one-time hint and keeps scanning.
  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    String? target;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      target = QrPayload.decode(raw);
      if (target != null) break;
    }

    if (target != null) {
      _handled = true;
      Navigator.pop(context, target);
      return;
    }

    if (!_invalidNoticeShown && capture.barcodes.isNotEmpty) {
      _invalidNoticeShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That is not a Pic Collector friend QR code'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraErrorView(error: error),
          ),
          const CustomPaint(painter: _ScanWindowPainter()),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Scan QR code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Text(
                    'Point the camera at a friend\'s QR code',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dims everything except a rounded square in the middle of the screen to
/// act as the scan-window guide.
class _ScanWindowPainter extends CustomPainter {
  const _ScanWindowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.shortestSide * 0.7,
      height: size.shortestSide * 0.7,
    );
    final window = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(window);
    canvas.drawPath(scrim, Paint()..color = Colors.black54);
    canvas.drawRRect(
      window,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanWindowPainter oldDelegate) => false;
}

/// Shown instead of the camera preview when it cannot start (most often a
/// denied camera permission).
class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final isPermission = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPermission ? Icons.no_photography : Icons.error_outline,
                color: Colors.white70,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                isPermission
                    ? 'Camera permission is required to scan QR codes. '
                        'Allow it in system settings, then come back here.'
                    : 'Could not start the camera. Try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
