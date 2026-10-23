import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ridey_app/features/rider/bike_lookup.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  late final MobileScannerController _controller;
  String? _message;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _detect(BarcodeCapture capture) {
    if (_completed) return;

    for (final barcode in capture.barcodes) {
      final bikeId = normalizeBikeId(barcode.rawValue ?? '');
      if (bikeId == null) continue;
      _completed = true;
      Navigator.of(context).pop(bikeId);
      return;
    }

    if (_message == null) {
      setState(() => _message = '따릉이 QR을 찾고 있어요.');
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
            onDetect: _detect,
            errorBuilder: (_, error) => _ScannerFailure(
              error: error,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
          const _ScannerGuide(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ScannerControl(
                      tooltip: '손전등 켜기 또는 끄기',
                      icon: Icons.flash_on_outlined,
                      onPressed: _controller.toggleTorch,
                    ),
                    const SizedBox(width: 8),
                    _ScannerControl(
                      tooltip: '카메라 닫기',
                      icon: Icons.close_rounded,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 62),
                child: _ScannerMessage(message: _message),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.keyboard_outlined),
                  label: const Text('번호 직접 입력'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerGuide extends StatelessWidget {
  const _ScannerGuide();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }
}

class _ScannerControl extends StatelessWidget {
  const _ScannerControl({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: .5),
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon),
    );
  }
}

class _ScannerMessage extends StatelessWidget {
  const _ScannerMessage({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message ?? '따릉이 QR을 네모 안에 맞춰 주세요.',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _ScannerFailure extends StatelessWidget {
  const _ScannerFailure({required this.error, required this.onClose});

  final MobileScannerException error;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white,
                size: 40,
              ),
              const SizedBox(height: 20),
              Text(
                denied ? '카메라 권한이 필요해요.' : '카메라를 시작하지 못했어요.',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                denied
                    ? '설정에서 RIDEY의 카메라 접근을 허용한 뒤 다시 시도해 주세요.'
                    : '번호를 직접 입력해서 확인할 수 있어요.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onClose, child: const Text('번호 직접 입력')),
            ],
          ),
        ),
      ),
    );
  }
}
