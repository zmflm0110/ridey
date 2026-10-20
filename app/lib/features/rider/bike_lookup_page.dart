import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/rider/bike_lookup.dart';
import 'package:ridey_app/features/rider/bike_ocr_scanner_page.dart';
import 'package:ridey_app/features/rider/qr_scanner_page.dart';

class BikeLookupPage extends StatefulWidget {
  const BikeLookupPage({
    super.key,
    required this.snapshot,
    required this.repository,
  });

  final LiveSnapshot snapshot;
  final LiveSnapshotRepository repository;

  @override
  State<BikeLookupPage> createState() => _BikeLookupPageState();
}

class _BikeLookupPageState extends State<BikeLookupPage> {
  final _controller = TextEditingController();
  late LiveSnapshot _snapshot;
  String? _message;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.snapshot;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      _snapshot = await widget.repository.fetch();
      if (!mounted) return;
      setState(() {
        _message = null;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = '실시간 목록을 새로 불러오지 못했어요.';
        _refreshing = false;
      });
    }
  }

  void _lookup() {
    FocusScope.of(context).unfocus();
    final bikeId = normalizeBikeId(_controller.text);
    if (bikeId == null) {
      setState(() => _message = 'SPB-00000 형식의 자전거 번호를 입력해 주세요.');
      return;
    }

    final bike = findBike(_snapshot.bikes, bikeId);
    if (bike == null) {
      setState(() => _message = '$bikeId의 경보 기록을 찾지 못했어요.');
      return;
    }

    setState(() => _message = null);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BikeDetailPage(bike: bike, updatedAt: _snapshot.updatedAt),
      ),
    );
  }

  Future<void> _scanQr() async {
    final bikeId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScannerPage()),
    );
    if (!mounted || bikeId == null) return;
    _controller.text = bikeId;
    _lookup();
  }

  Future<void> _scanNumberPlate() async {
    final bikeId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const BikeOcrScannerPage()),
    );
    if (!mounted || bikeId == null) return;
    _controller.text = bikeId;
    _lookup();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('자전거 확인'),
        actions: [
          IconButton(
            tooltip: '실시간 목록 새로고침',
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            Text('번호로\n확인하세요.', style: theme.textTheme.displayLarge),
            const SizedBox(height: 12),
            Text(
              '대여소에서 본 자전거 번호를 입력하면 현재 경보 기록을 찾아요.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: context.ridey.muted,
              ),
            ),
            const SizedBox(height: 32),
            Semantics(
              textField: true,
              label: '자전거 번호',
              child: TextField(
                controller: _controller,
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
            if (_message != null) ...[
              const SizedBox(height: 22),
              _LookupMessage(message: _message!),
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

class BikeDetailPage extends StatelessWidget {
  const BikeDetailPage({
    super.key,
    required this.bike,
    required this.updatedAt,
  });

  final LiveBike bike;
  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = bike.isHighAlert ? '타지 마세요.' : '주의하세요.';
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
            const SizedBox(height: 16),
            _DataNote(updatedAt: updatedAt),
            const SizedBox(height: 30),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.search_rounded),
              label: const Text('다른 자전거 확인'),
            ),
          ],
        ),
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
  const _DataNote({required this.updatedAt});

  final DateTime updatedAt;

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
        '$freshness 갱신된 대여 기록을 기준으로 했어요. 고장 확정이 아니므로, 직접 상태도 확인해 주세요.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.ridey.calm),
      ),
    );
  }
}

class _LookupMessage extends StatelessWidget {
  const _LookupMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.ridey.calmSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$message 경보가 없다고 정상이라는 뜻은 아니에요.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.ridey.calm),
      ),
    );
  }
}
