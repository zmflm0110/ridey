import 'package:flutter/material.dart';
import 'package:ridey_app/features/rider/qr_preview.dart';

/// Full-screen QR scan. Pops the first normalized bike id it reads.
class BikeQrScannerPage extends StatefulWidget {
  const BikeQrScannerPage({super.key});

  @override
  State<BikeQrScannerPage> createState() => _BikeQrScannerPageState();
}

class _BikeQrScannerPageState extends State<BikeQrScannerPage> {
  var _done = false;

  void _onDetected(String bikeId) {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop(bikeId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR로 찍기')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: QrPreview(active: true, onDetected: _onDetected),
      ),
    );
  }
}
