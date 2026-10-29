import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/habits/lookup_habits.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
import 'package:ridey_app/features/rider/bike_lookup.dart';
import 'package:ridey_app/features/rider/bike_ocr_scanner_page.dart';
import 'package:ridey_app/features/rider/qr_preview.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class BikeLookupPage extends StatefulWidget {
  const BikeLookupPage({
    super.key,
    required this.snapshot,
    required this.repository,
    required this.routeObserver,
    this.readLocation,
    this.cameraEnabled = true,
    this.visible = true,
  });

  final LiveSnapshot snapshot;
  final LiveSnapshotRepository repository;
  final RouteObserver<PageRoute<dynamic>> routeObserver;
  final Future<DeviceLocation?> Function()? readLocation;
  final bool cameraEnabled;
  final bool visible;

  @override
  State<BikeLookupPage> createState() => _BikeLookupPageState();
}

class _BikeLookupPageState extends State<BikeLookupPage> with RouteAware {
  final _controller = TextEditingController();
  late LiveSnapshot _snapshot;
  String? _detectedId;
  var _covered = false;
  PageRoute<dynamic>? _route;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    if (_route != null) widget.routeObserver.unsubscribe(this);
    _route = route is PageRoute<dynamic> ? route : null;
    if (_route != null) widget.routeObserver.subscribe(this, _route!);
  }

  @override
  void dispose() {
    widget.routeObserver.unsubscribe(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    if (mounted) setState(() => _covered = true);
  }

  @override
  void didPopNext() {
    if (mounted) setState(() => _covered = false);
  }

  void _backToScanner() {
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
          onCheckAnother: _backToScanner,
        ),
      ),
    );
  }

  void _lookup(LookupKind kind) {
    FocusScope.of(context).unfocus();
    final bikeId = normalizeBikeId(_controller.text);
    if (bikeId == null) {
      _showMessage(title: '판단 어려움', message: 'SPB-00000 형식의 자전거 번호를 입력해 주세요.');
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
          onCheckAnother: _backToScanner,
        ),
      ),
    );
  }

  Future<void> _typeNumber() async {
    final entered =
        await showModalBottomSheet<({String text, LookupKind kind})>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          builder: (context) => _NumberSheet(
            onScanPlate: () async {
              final bikeId = await Navigator.of(context, rootNavigator: true)
                  .push<String>(
                    MaterialPageRoute<String>(
                      builder: (_) => const BikeOcrScannerPage(),
                    ),
                  );
              if (!context.mounted || bikeId == null) return;
              Navigator.of(context).pop((text: bikeId, kind: LookupKind.ocr));
            },
          ),
        );
    if (!mounted || entered == null) return;
    _controller.text = entered.text;
    _lookup(entered.kind);
  }

  void _lookupDetected() {
    final bikeId = _detectedId;
    if (bikeId == null) {
      _showMessage(title: '판단 어려움', message: '따릉이 QR을 카드 안에 맞춰 주세요.');
      return;
    }
    _controller.text = bikeId;
    _lookup(LookupKind.qr);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scanning = widget.cameraEnabled && widget.visible && !_covered;

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
        QrPreview(
          active: scanning,
          onDetected: (bikeId) {
            if (_detectedId == bikeId) return;
            setState(() => _detectedId = bikeId);
          },
        ),
        const SizedBox(height: 22),
        RideyButton.signal(label: '이 자전거 조회하기', onPressed: _lookupDetected),
        const SizedBox(height: 18),
        Center(
          child: RideyPressable(
            onTap: _typeNumber,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                '자전거 번호 직접 입력하기',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  decoration: TextDecoration.underline,
                  decorationColor: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NumberSheet extends StatefulWidget {
  const _NumberSheet({required this.onScanPlate});

  final Future<void> Function() onScanPlate;

  @override
  State<_NumberSheet> createState() => _NumberSheetState();
}

class _NumberSheetState extends State<_NumberSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(
      context,
    ).pop((text: _controller.text, kind: LookupKind.number));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('자전거 번호', style: theme.textTheme.titleLarge),
          const SizedBox(height: 14),
          Semantics(
            textField: true,
            label: '자전거 번호',
            child: TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
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
          RideyButton(label: '조회하기', onPressed: _submit),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.onScanPlate,
            child: const Text('번호판으로 읽기'),
          ),
        ],
      ),
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
