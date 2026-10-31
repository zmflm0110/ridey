import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/habits/lookup_habits.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
import 'package:ridey_app/features/rider/bike_lookup.dart';
import 'package:ridey_app/features/rider/bike_ocr_scanner_page.dart';
import 'package:ridey_app/features/rider/bike_qr_scanner_page.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class BikeLookupPage extends StatefulWidget {
  const BikeLookupPage({
    super.key,
    required this.snapshot,
    required this.repository,
    this.readLocation,
    this.cameraEnabled = true,
  });

  final LiveSnapshot snapshot;
  final LiveSnapshotRepository repository;
  final Future<DeviceLocation?> Function()? readLocation;
  final bool cameraEnabled;

  @override
  State<BikeLookupPage> createState() => _BikeLookupPageState();
}

class _BikeLookupPageState extends State<BikeLookupPage> {
  final _controller = TextEditingController();
  late LiveSnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.snapshot;
  }

  @override
  void didUpdateWidget(BikeLookupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.snapshot != oldWidget.snapshot) _snapshot = widget.snapshot;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _backToForm() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showMessage({
    required String title,
    required String message,
    String? bikeId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BikeCheckMessagePage(
          title: title,
          message: message,
          bikeId: bikeId,
          onCheckAnother: _backToForm,
        ),
      ),
    );
  }

  void _lookup(LookupKind kind, {String? raw}) {
    FocusScope.of(context).unfocus();
    final bikeId = normalizeBikeId(raw ?? _controller.text);
    if (bikeId == null) {
      _showMessage(
        title: '판단 어려움',
        message: 'SPB-00000 형식의 자전거 번호를 입력해 주세요.',
      );
      return;
    }

    rememberLookup(
      kind: kind,
      subject: bikeId,
      readLocation: widget.readLocation,
    );
    final bike = findBike(_snapshot.bikes, bikeId);
    if (bike == null) {
      _showMessage(
        title: _snapshot.feed.isHealthy ? '경보 없음' : '판단 어려움',
        bikeId: bikeId,
        message: _snapshot.feed.isHealthy
            ? '$bikeId에는 지금 켜진 경보가 없어요. 안전이 확인된 것은 아니니 브레이크·타이어를 직접 살펴보세요.'
            : '$bikeId의 판단에 필요한 대여 기록이 늦고 있어요. 새로고침 후 직접 상태를 확인해 주세요.',
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BikeDetailPage(
          bike: bike,
          updatedAt: _snapshot.updatedAt,
          feed: _snapshot.feed,
          onCheckAnother: _backToForm,
        ),
      ),
    );
  }

  Future<void> _scanQr() async {
    if (!widget.cameraEnabled) {
      _showMessage(title: '판단 어려움', message: '이 화면에서는 카메라를 쓸 수 없어요.');
      return;
    }
    final bikeId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const BikeQrScannerPage()),
    );
    if (!mounted || bikeId == null) return;
    _controller.text = bikeId;
    _lookup(LookupKind.qr, raw: bikeId);
  }

  Future<void> _scanPlate() async {
    if (!widget.cameraEnabled) {
      _showMessage(title: '판단 어려움', message: '이 화면에서는 카메라를 쓸 수 없어요.');
      return;
    }
    final bikeId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const BikeOcrScannerPage()),
    );
    if (!mounted || bikeId == null) return;
    _controller.text = bikeId;
    _lookup(LookupKind.ocr, raw: bikeId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, rideyTabClearance),
      children: [
        Text(
          '자전거 확인',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        Semantics(
          textField: true,
          label: '자전거 번호',
          child: TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _lookup(LookupKind.number),
            style: context
                .rideyNumbers(theme.textTheme.titleLarge)
                ?.copyWith(fontSize: 20),
            decoration: InputDecoration(
              hintText: 'SPB-00000',
              hintStyle: context
                  .rideyNumbers(theme.textTheme.titleLarge)
                  ?.copyWith(
                    fontSize: 20,
                    color: context.ridey.muted.withValues(alpha: .6),
                  ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        RideyButton(
          label: '조회하기',
          onPressed: () => _lookup(LookupKind.number),
        ),
        const SizedBox(height: 10),
        RideyButton.secondary(label: 'QR로 찍기', onPressed: _scanQr),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _scanPlate,
            child: const Text('번호판으로 읽기'),
          ),
        ),
      ],
    );
  }
}

class BikeLookupLoadFailure extends StatelessWidget {
  const BikeLookupLoadFailure({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, rideyTabClearance),
      children: [
        RideyCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RideyIco(icon: Icons.cloud_off_outlined),
              const SizedBox(height: 14),
              Text(
                '확인할 목록을 불러오지 못했어요.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 18),
              RideyButton.secondary(
                label: '다시 시도',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
