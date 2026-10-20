import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:ridey_app/features/rider/bike_lookup.dart';

class BikeOcrScannerPage extends StatefulWidget {
  const BikeOcrScannerPage({super.key});

  @override
  State<BikeOcrScannerPage> createState() => _BikeOcrScannerPageState();
}

class _BikeOcrScannerPageState extends State<BikeOcrScannerPage>
    with WidgetsBindingObserver {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  CameraController? _cameraController;
  CameraDescription? _camera;
  String? _error;
  String _hint = '번호판의 SPB- 글자가 네모 안에 오게 맞춰 주세요.';
  bool _initializing = true;
  bool _processing = false;
  bool _completed = false;

  static const _orientations = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cameraController?.dispose() ?? Future<void>.value());
    _recognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(controller.stopImageStream());
    } else if (state == AppLifecycleState.resumed && !_completed) {
      unawaited(_startStream());
    }
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      _camera =
          cameras
              .where(
                (camera) => camera.lensDirection == CameraLensDirection.back,
              )
              .firstOrNull ??
          cameras.firstOrNull;
      if (_camera == null) {
        throw CameraException('no-camera', '사용 가능한 카메라가 없습니다.');
      }
      final controller = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      _cameraController = controller;
      await controller.initialize();
      await _startStream();
      if (mounted) setState(() => _initializing = false);
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = error.code == 'CameraAccessDenied'
              ? '카메라 권한이 필요해요. 설정에서 권한을 허용한 뒤 다시 시도해 주세요.'
              : '카메라를 시작하지 못했어요. 번호를 직접 입력해 주세요.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = '카메라를 시작하지 못했어요. 번호를 직접 입력해 주세요.';
        });
      }
    }
  }

  Future<void> _startStream() async {
    final controller = _cameraController;
    if (controller == null || controller.value.isStreamingImages) return;
    await controller.startImageStream(_processImage);
  }

  Future<void> _processImage(CameraImage image) async {
    if (_processing || _completed) return;
    final inputImage = _inputImage(image);
    if (inputImage == null) return;

    _processing = true;
    try {
      final recognized = await _recognizer.processImage(inputImage);
      final bikeId = bikeIdFromRecognizedText(recognized.text);
      if (bikeId != null && mounted) {
        _completed = true;
        await _cameraController?.stopImageStream();
        if (mounted) Navigator.of(context).pop(bikeId);
        return;
      }
      if (mounted && _hint != '번호판에서 SPB 번호를 찾고 있어요.') {
        setState(() => _hint = '번호판에서 SPB 번호를 찾고 있어요.');
      }
    } catch (_) {
      if (mounted && _hint != '번호판을 더 가까이 비춰 주세요.') {
        setState(() => _hint = '번호판을 더 가까이 비춰 주세요.');
      }
    } finally {
      _processing = false;
    }
  }

  InputImage? _inputImage(CameraImage image) {
    final camera = _camera;
    final controller = _cameraController;
    if (camera == null || controller == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888) ||
        image.planes.length != 1) {
      return null;
    }

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    } else {
      var compensation = _orientations[controller.value.deviceOrientation];
      if (compensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        compensation = (camera.sensorOrientation + compensation) % 360;
      } else {
        compensation = (camera.sensorOrientation - compensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(compensation);
    }
    if (rotation == null) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    return Scaffold(
      backgroundColor: Colors.black,
      body: _initializing
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _error != null
          ? _OcrFailure(
              message: _error!,
              onClose: () => Navigator.of(context).pop(),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller!),
                const _OcrGuide(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        tooltip: '카메라 닫기',
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: .5),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: _OcrHint(hint: _hint),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _OcrGuide extends StatelessWidget {
  const _OcrGuide();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 290,
          height: 128,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
    );
  }
}

class _OcrHint extends StatelessWidget {
  const _OcrHint({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        hint,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _OcrFailure extends StatelessWidget {
  const _OcrFailure({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.document_scanner_outlined,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onClose, child: const Text('번호 직접 입력')),
          ],
        ),
      ),
    );
  }
}

extension on Iterable<CameraDescription> {
  CameraDescription? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
