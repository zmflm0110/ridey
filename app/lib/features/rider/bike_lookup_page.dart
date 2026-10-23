import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/field/field_verdict.dart';
import 'package:ridey_app/features/field/field_verification_repository.dart';
import 'package:ridey_app/features/field/quick_verdict_sheet.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
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
        builder: (_) =>
            BikeDetailPage(
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

class BikeDetailPage extends StatelessWidget {
  const BikeDetailPage({
    super.key,
    required this.bike,
    required this.updatedAt,
    this.feed,
    this.isWorkContext = false,
    this.fieldRepository,
    this.checkedVerdicts = const {},
  });

  final LiveBike bike;
  final DateTime updatedAt;
  final FeedHealth? feed;
  final bool isWorkContext;
  final FieldVerificationRepository? fieldRepository;
  final Map<FieldVerdict, int> checkedVerdicts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = bike.isHighAlert ? '피하세요.' : '주의해서 확인하세요.';
    final detail = bike.isHighAlert
        ? '서로 다른 사람들이 바로 반납한 기록이 여러 번 이어졌어요.'
        : '바로 반납한 기록이 이어져 경보가 켜졌어요.';

    return Scaffold(
      appBar: AppBar(title: const Text('자전거 경보')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.ridey.signal,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      bike.isHighAlert ? '강한 경보' : '경보',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: RideyColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    label,
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: theme.colorScheme.surface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    detail,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.surface.withValues(alpha: .78),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            RideyDataConfidence(
              updatedAt: updatedAt,
              isHealthy: feed?.isHealthy ?? true,
              ratio: feed?.ratio,
            ),
            const SizedBox(height: 24),
            Text(
              bike.bike,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bike.stationName.isEmpty ? bike.station : bike.stationName,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: context.ridey.muted,
              ),
            ),
            const SizedBox(height: 32),
            Text('왜 경보가 켜졌나요?', style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            _EvidenceCard(bike: bike),
            if (checkedVerdicts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _CheckedVerdictsCard(verdicts: checkedVerdicts),
            ],
            const SizedBox(height: 16),
            _DataNote(updatedAt: updatedAt, feed: feed),
            const SizedBox(height: 30),
            if (isWorkContext) ...[
              FilledButton.icon(
                onPressed: () => showQuickVerdictSheet(
                  context,
                  bikeId: bike.bike,
                  repository: fieldRepository ?? FieldVerificationRepository(),
                ),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('현장에서 확인하기'),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('다른 자전거 확인'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckedVerdictsCard extends StatelessWidget {
  const _CheckedVerdictsCard({required this.verdicts});

  final Map<FieldVerdict, int> verdicts;

  @override
  Widget build(BuildContext context) {
    final total = verdicts.values.fold(0, (sum, value) => sum + value);
    final rows = FieldVerdict.values
        .where((verdict) => (verdicts[verdict] ?? 0) > 0)
        .map((verdict) => '${verdict.label} ${verdicts[verdict]}건')
        .join(' · ');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: context.ridey.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('현장 확인 $total건', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            rows,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.ridey.muted),
          ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.bike});

  final LiveBike bike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: context.ridey.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _EvidenceRow(
            icon: Icons.radio_button_unchecked_rounded,
            text: '첫 번째 사람이 빌리자마자 반납',
            color: context.ridey.muted,
          ),
          const _EvidenceLine(),
          _EvidenceRow(
            icon: Icons.radio_button_checked_rounded,
            text: '다른 사람도 바로 반납',
            color: context.ridey.signal,
          ),
          const _EvidenceLine(),
          _EvidenceRow(
            icon: Icons.notifications_active_outlined,
            text: '서로 다른 ${bike.chain}명의 기록으로 경보',
            color: context.ridey.signal,
            strong: true,
          ),
          if (bike.probability != null) ...[
            const SizedBox(height: 18),
            Divider(color: context.ridey.line),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '다음 사람도 바로 반납할 가능성 ${bike.probability}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: context.ridey.signalText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.icon,
    required this.text,
    required this.color,
    this.strong = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: strong
                  ? Theme.of(context).colorScheme.onSurface
                  : context.ridey.muted,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.only(left: 9, top: 5, bottom: 5),
      color: context.ridey.line,
    );
  }
}

class _DataNote extends StatelessWidget {
  const _DataNote({required this.updatedAt, this.feed});

  final DateTime updatedAt;
  final FeedHealth? feed;

  @override
  Widget build(BuildContext context) {
    final minutes = DateTime.now()
        .difference(updatedAt)
        .inMinutes
        .clamp(0, 999);
    final freshness = minutes == 0 ? '방금' : '$minutes분 전';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.ridey.calmSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '${feed?.isHealthy == false ? '자료가 지연되고 있어 판단을 보수적으로 해 주세요. ' : ''}$freshness 갱신된 대여 기록을 기준으로 했어요. 고장 확정이 아니므로, 직접 상태도 확인해 주세요.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.ridey.calm),
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
