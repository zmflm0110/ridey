import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/habits/lookup_habits.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/rider/bike_lookup.dart';
import 'package:ridey_app/features/rider/bike_ocr_scanner_page.dart';
import 'package:ridey_app/features/rider/qr_scanner_page.dart';
import 'package:ridey_app/widgets/ridey_status.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class BikeLookupDestination extends StatefulWidget {
  const BikeLookupDestination({super.key, this.repository, this.readLocation});

  final LiveSnapshotRepository? repository;
  final Future<DeviceLocation?> Function()? readLocation;

  @override
  State<BikeLookupDestination> createState() => _BikeLookupDestinationState();
}

class _BikeLookupDestinationState extends State<BikeLookupDestination> {
  late final LiveSnapshotRepository _repository;
  late Future<LiveSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseLiveSnapshotRepository();
    _snapshot = _repository.fetch();
  }

  void _retry() => setState(() => _snapshot = _repository.fetch());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LiveSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError) {
          return _LookupLoadFailure(onRetry: _retry);
        }
        return BikeLookupPage(
          snapshot: snapshot.requireData,
          repository: _repository,
          showAppBar: false,
          readLocation: widget.readLocation,
        );
      },
    );
  }
}

class BikeLookupPage extends StatefulWidget {
  const BikeLookupPage({
    super.key,
    required this.snapshot,
    required this.repository,
    this.showAppBar = true,
    this.readLocation,
  });

  final LiveSnapshot snapshot;
  final LiveSnapshotRepository repository;
  final bool showAppBar;
  final Future<DeviceLocation?> Function()? readLocation;

  @override
  State<BikeLookupPage> createState() => _BikeLookupPageState();
}

class _BikeLookupPageState extends State<BikeLookupPage> {
  final _controller = TextEditingController();
  final _inputFocus = FocusNode();
  late LiveSnapshot _snapshot;
  _LookupOutcome? _outcome;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.snapshot;
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      _snapshot = await widget.repository.fetch();
      if (!mounted) return;
      setState(() {
        _outcome = null;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _outcome = const _LookupOutcome(
          RideySignalState.uncertain,
          '실시간 목록을 새로 불러오지 못했어요. 네트워크를 확인한 뒤 다시 시도해 주세요.',
        );
        _refreshing = false;
      });
    }
  }

  void _lookup([LookupKind kind = LookupKind.number]) {
    FocusScope.of(context).unfocus();
    final bikeId = normalizeBikeId(_controller.text);
    if (bikeId == null) {
      setState(
        () => _outcome = const _LookupOutcome(
          RideySignalState.uncertain,
          'SPB-00000 형식의 자전거 번호를 입력해 주세요.',
        ),
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
      setState(
        () => _outcome = _LookupOutcome(
          _snapshot.feed.isHealthy
              ? RideySignalState.noSignal
              : RideySignalState.uncertain,
          _snapshot.feed.isHealthy
              ? '$bikeId에는 지금 켜진 경보가 없어요. 안전이 확인된 것은 아니니 브레이크·타이어를 직접 살펴보세요.'
              : '$bikeId의 판단에 필요한 대여 기록이 늦고 있어요. 새로고침 후 직접 상태를 확인해 주세요.',
        ),
      );
      return;
    }

    setState(() => _outcome = null);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BikeDetailPage(
          bike: bike,
          updatedAt: _snapshot.updatedAt,
          feed: _snapshot.feed,
        ),
      ),
    );
  }

  Future<void> _scanQr() async {
    final bikeId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScannerPage()),
    );
    if (!mounted) return;
    if (bikeId == null) {
      _inputFocus.requestFocus();
      return;
    }
    _controller.text = bikeId;
    _lookup(LookupKind.qr);
  }

  Future<void> _scanNumberPlate() async {
    final bikeId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const BikeOcrScannerPage()),
    );
    if (!mounted) return;
    if (bikeId == null) {
      _inputFocus.requestFocus();
      return;
    }
    _controller.text = bikeId;
    _lookup(LookupKind.ocr);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              actions: [
                IconButton(
                  tooltip: '실시간 목록 새로고침',
                  onPressed: _refreshing ? null : _refresh,
                  icon: _refreshing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            )
          : null,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '타기 전에\n자전거 번호를 확인해 보세요',
                style: theme.textTheme.displayLarge,
              ),
            ),
            const SizedBox(height: 14),
            RideyEnter(
              child: RideyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      textField: true,
                      label: '자전거 번호',
                      child: TextField(
                        controller: _controller,
                        focusNode: _inputFocus,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _lookup(),
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
                    const SizedBox(height: 10),
                    RideyButton(label: '경보 기록 확인', onPressed: () => _lookup()),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: RideyButton.secondary(
                            label: 'QR로 찍기',
                            icon: Icons.qr_code_scanner_rounded,
                            onPressed: _scanQr,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RideyButton.secondary(
                            label: '번호판으로 읽기',
                            icon: Icons.document_scanner_outlined,
                            onPressed: _scanNumberPlate,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_outcome != null) ...[
              const SizedBox(height: 12),
              RideyPopIn(
                key: ObjectKey(_outcome),
                child: _LookupMessage(outcome: _outcome!),
              ),
            ],
            const RideySectionTitle('알아두세요'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '경보가 없다고 자전거가 정상이라는 뜻은 아니에요. RIDEY는 서로 다른 사람들이 바로 반납한 기록이 이어진 자전거만 알려 줘요.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  color: context.ridey.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LookupLoadFailure extends StatelessWidget {
  const _LookupLoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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

/// Result card like the web `.result`: soft color fading into the card,
/// a line icon, the verdict in big type, then the reason.
class _LookupMessage extends StatelessWidget {
  const _LookupMessage({required this.outcome});

  final _LookupOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    final theme = Theme.of(context);
    final calm = outcome.state == RideySignalState.noSignal;
    final soft = calm ? c.calmSoft : c.signalSoft;
    final accent = calm ? c.calm : c.signal;
    final (title, icon) = switch (outcome.state) {
      RideySignalState.noSignal => ('경보 없음', Icons.check_rounded),
      RideySignalState.avoid => ('피하기', Icons.warning_amber_rounded),
      RideySignalState.completed => ('현장 확인 완료', Icons.check_rounded),
      RideySignalState.uncertain => ('판단 어려움', Icons.help_outline_rounded),
    };
    return RideyCard(
      padding: const EdgeInsets.all(22),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [soft, theme.colorScheme.surface],
        stops: const [0, .8],
      ),
      borderColor: Color.lerp(c.line, accent, .35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 34, color: calm ? c.calmText : c.signalText),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            outcome.message,
            style: theme.textTheme.bodyLarge?.copyWith(color: c.body),
          ),
        ],
      ),
    );
  }
}

class _LookupOutcome {
  const _LookupOutcome(this.state, this.message);

  final RideySignalState state;
  final String message;
}
