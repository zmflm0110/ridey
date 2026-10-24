import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/rider/bike_lookup.dart';
import 'package:ridey_app/features/rider/bike_ocr_scanner_page.dart';
import 'package:ridey_app/features/rider/qr_scanner_page.dart';
import 'package:ridey_app/widgets/ridey_status.dart';

class BikeLookupDestination extends StatefulWidget {
  const BikeLookupDestination({super.key, this.repository});

  final LiveSnapshotRepository? repository;

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
  });

  final LiveSnapshot snapshot;
  final LiveSnapshotRepository repository;
  final bool showAppBar;

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

  void _lookup() {
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

    final bike = findBike(_snapshot.bikes, bikeId);
    if (bike == null) {
      setState(
        () => _outcome = _LookupOutcome(
          _snapshot.feed.isHealthy
              ? RideySignalState.noSignal
              : RideySignalState.uncertain,
          _snapshot.feed.isHealthy
              ? '$bikeId에서 반복 반납 신호를 찾지 못했어요. 안전이 확인된 것은 아니니 브레이크·타이어를 직접 살펴보세요.'
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
    _lookup();
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
    _lookup();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('자전거 확인'),
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            const RideyPageHeading(
              title: '자전거 확인',
              description: 'QR을 찍거나 번호를 입력하면 반복 반납 신호를 찾아요.',
            ),
            const SizedBox(height: 32),
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
                decoration: InputDecoration(
                  hintText: 'SPB-00000',
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: context.ridey.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: context.ridey.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: context.ridey.calm, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _lookup, child: const Text('경보 기록 확인')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _scanQr,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('QR로 찍기'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _scanNumberPlate,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('번호판으로 읽기'),
            ),
            if (_outcome != null) ...[
              const SizedBox(height: 22),
              _LookupMessage(outcome: _outcome!),
            ],
            const SizedBox(height: 40),
            Text('알아두세요', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              '경보가 없다고 자전거가 정상이라는 뜻은 아니에요. RIDEY는 서로 다른 사람들이 바로 반납한 기록이 이어진 자전거만 알려 줘요.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.ridey.muted,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 36),
            const SizedBox(height: 14),
            const Text('확인할 목록을 불러오지 못했어요.'),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

class _LookupMessage extends StatelessWidget {
  const _LookupMessage({required this.outcome});

  final _LookupOutcome outcome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: outcome.state == RideySignalState.noSignal
            ? context.ridey.calmSoft
            : context.ridey.signalSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RideySignalBadge(state: outcome.state),
          const SizedBox(height: 10),
          Text(
            outcome.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: outcome.state == RideySignalState.noSignal
                  ? context.ridey.calm
                  : context.ridey.signalText,
            ),
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
