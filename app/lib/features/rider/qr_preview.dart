import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ridey_app/features/rider/bike_lookup.dart';

/// Rounded camera card. Reports a normalized bike id and keeps scanning until
/// [active] becomes false, so the tab can pause the camera when it is covered.
class QrPreview extends StatefulWidget {
  const QrPreview({super.key, required this.active, required this.onDetected});

  final bool active;
  final ValueChanged<String> onDetected;

  @override
  State<QrPreview> createState() => _QrPreviewState();
}

class _QrPreviewState extends State<QrPreview> {
  MobileScannerController? _controller;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(QrPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _start();
    } else {
      _stop();
    }
  }

  void _start() {
    _controller ??= MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  void _stop() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _detect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final bikeId = normalizeBikeId(barcode.rawValue ?? '');
      if (bikeId == null) continue;
      widget.onDetected(bikeId);
      if (_message != bikeId) setState(() => _message = bikeId);
      return;
    }
    if (_message == null) {
      setState(() => _message = '따릉이 QR을 찾고 있어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 248,
        child: controller == null
            ? const ColoredBox(
                color: Colors.black,
                child: Center(child: _PreviewCaption(message: null)),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: controller,
                    onDetect: _detect,
                    errorBuilder: (_, error) => _PreviewFailure(error: error),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: IconButton(
                        tooltip: '손전등 켜기 또는 끄기',
                        onPressed: controller.toggleTorch,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: .45),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.flash_on_outlined),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: _PreviewCaption(message: _message),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PreviewCaption extends StatelessWidget {
  const _PreviewCaption({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          message ?? '따릉이 QR을 카드 안에 맞춰 주세요.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _PreviewFailure extends StatelessWidget {
  const _PreviewFailure({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            denied
                ? '카메라 권한이 필요해요. 설정에서 RIDEY의 카메라 접근을 허용한 뒤 다시 시도해 주세요.'
                : '카메라를 시작하지 못했어요. 번호를 직접 입력해서 확인할 수 있어요.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
