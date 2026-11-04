import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/rider/official_bike_app.dart';
import 'package:ridey_app/widgets/ridey_status.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class BikeDetailPage extends StatelessWidget {
  const BikeDetailPage({
    super.key,
    required this.bike,
    required this.updatedAt,
    this.feed,
    this.onCheckAnother,
    this.forStaff = false,
  });

  final LiveBike bike;
  final DateTime updatedAt;
  final FeedHealth? feed;
  final VoidCallback? onCheckAnother;

  /// 직원 모드: 안내를 '타기 전에' 가 아니라 '겉보기엔 멀쩡해도 직접 확인' 으로, 단추는 목록으로 돌아가기.
  final bool forStaff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.ridey;
    final station = bike.stationName.isEmpty ? bike.station : bike.stationName;

    return Scaffold(
      // 세부 화면은 시민 탭 안이 아니라 화면 전체로도 열린다(직원 모드·지도 카드) — 상태 표시줄·다이내믹 아일랜드 아래로 내려 뒤로 단추가 눌리게.
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, rideyTabClearance),
          children: [
            const _CheckBackTitle(),
            const SizedBox(height: 24),
            Text(
              bike.bike,
              style: context
                  .rideyNumbers(theme.textTheme.titleLarge)
                  ?.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text(
              station,
              style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
            ),
            const SizedBox(height: 14),
            Text(
              bike.isHighAlert ? '강한 경보가 켜졌어요.' : '경보가 켜졌어요.',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: c.signalText,
                fontSize: 28,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              forStaff
                  ? '서로 다른 ${bike.chain}명이 빌리자마자 반납했어요. 겉보기엔 멀쩡해도 타 봐야 아는 고장일 수 있어요 — 브레이크·타이어·체인·안장을 직접 확인해 주세요.'
                  : '서로 다른 ${bike.chain}명이 빌리자마자 반납했어요. 타기 전에 브레이크와 타이어를 살펴보세요.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            RideyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChainStrip(chain: bike.chain),
                  const SizedBox(height: 14),
                  _Fact(label: '연쇄', value: '${bike.chain}명', strong: true),
                  if (bike.lastDud.isNotEmpty)
                    _Fact(label: '마지막 헛대여', value: bike.lastDud),
                  if (bike.probability != null)
                    _Fact(
                      label: '다음 사람도 바로 반납할 확률',
                      value: '${bike.probability}%',
                      strong: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RideyDataConfidence(
              updatedAt: updatedAt,
              isHealthy: feed?.isHealthy ?? true,
              ratio: feed?.ratio,
            ),
            const SizedBox(height: 20),
            RideyButton(
              label: forStaff ? '목록으로 돌아가기' : '다른 자전거 확인하기',
              onPressed:
                  onCheckAnother ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 14),
            Center(
              child: _UnderlinedAction(
                label: '판단 근거 자세히 보기',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BikeEvidencePage(
                        bike: bike,
                        updatedAt: updatedAt,
                        feed: feed,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BikeCheckMessagePage extends StatelessWidget {
  const BikeCheckMessagePage({
    super.key,
    required this.title,
    required this.message,
    this.bikeId,
    this.onCheckAnother,
    this.offerOfficialApp = false,
    this.onOpenOfficialApp,
  });

  final String title;
  final String message;
  final String? bikeId;
  final VoidCallback? onCheckAnother;
  final bool offerOfficialApp;
  final Future<void> Function()? onOpenOfficialApp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // 세부 화면은 시민 탭 안이 아니라 화면 전체로도 열린다(직원 모드·지도 카드) — 상태 표시줄·다이내믹 아일랜드 아래로 내려 뒤로 단추가 눌리게.
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, rideyTabClearance),
          children: [
            const _CheckBackTitle(),
            const SizedBox(height: 28),
            if (bikeId != null) ...[
              Text(
                bikeId!,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(title, style: theme.textTheme.headlineLarge),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            if (offerOfficialApp) ...[
              RideyButton(
                label: '따릉이 앱에서 대여하기',
                onPressed: onOpenOfficialApp ?? openOfficialBikeApp,
              ),
              const SizedBox(height: 8),
              Text(
                '공식 앱이 열립니다. 해당 번호로 바로 대여되지는 않아요.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.ridey.muted,
                ),
              ),
              const SizedBox(height: 14),
            ],
            // 대여하기가 있으면 그것이 주 동작이고, 다른 자전거 확인은 한 단 낮춘다(검은 단추 둘이면 무엇을 누를지 흐려짐).
            if (offerOfficialApp)
              RideyButton.secondary(
                label: '다른 자전거 확인하기',
                onPressed:
                    onCheckAnother ?? () => Navigator.of(context).maybePop(),
              )
            else
              RideyButton(
                label: '다른 자전거 확인하기',
                onPressed:
                    onCheckAnother ?? () => Navigator.of(context).maybePop(),
              ),
          ],
        ),
      ),
    );
  }
}

class BikeEvidencePage extends StatelessWidget {
  const BikeEvidencePage({
    super.key,
    required this.bike,
    required this.updatedAt,
    this.feed,
  });

  final LiveBike bike;
  final DateTime updatedAt;
  final FeedHealth? feed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.ridey;
    final station = bike.stationName.isEmpty ? bike.station : bike.stationName;

    return Scaffold(
      // 세부 화면은 시민 탭 안이 아니라 화면 전체로도 열린다(직원 모드·지도 카드) — 상태 표시줄·다이내믹 아일랜드 아래로 내려 뒤로 단추가 눌리게.
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, rideyTabClearance),
          children: [
            const _CheckBackTitle(title: '판단 근거'),
            const SizedBox(height: 22),
            Text(
              bike.bike,
              style: context
                  .rideyNumbers(theme.textTheme.titleLarge)
                  ?.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              station,
              style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
            ),
            const SizedBox(height: 16),
            RideyDataConfidence(
              updatedAt: updatedAt,
              isHealthy: feed?.isHealthy ?? true,
              ratio: feed?.ratio,
            ),
            const RideySectionTitle('왜 경보가 켜졌나요?'),
            RideyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChainStrip(chain: bike.chain),
                  const SizedBox(height: 16),
                  Text(
                    '서로 다른 ${bike.chain}명의 기록으로 경보',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '빌리자마자 반납한 사람 하나하나가 점이에요. 첫 점은 실수일 수 있어 비워 두고, '
                    '서로 다른 다음 사람이 이어 반납하면 고리를 두른 점 — 경보가 돼요.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            if (bike.probability != null) ...[
              const SizedBox(height: 14),
              RideyCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '다음 사람도 바로 반납할 확률',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    RideyNumber(
                      '${bike.probability}%',
                      size: 18,
                      color: c.signalText,
                    ),
                  ],
                ),
              ),
            ],
            if (bike.reasons.isNotEmpty) ...[
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '확률을 올리고 내린 것',
                  style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                ),
              ),
              const SizedBox(height: 8),
              RideyListCard(
                children: [
                  for (final reason in bike.reasons)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              reason.text,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          RideyNumber(
                            reason.deltaLabel,
                            size: 13,
                            color: (reason.deltaPoints ?? 0) < 0
                                ? c.calmText
                                : c.signalText,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _DataNote(updatedAt: updatedAt, feed: feed),
          ],
        ),
      ),
    );
  }
}

/// One labelled number on the detail card: label on the left, Unbounded value
/// on the right (signal text for the alert numbers).
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: c.body, fontSize: 15),
            ),
          ),
          RideyNumber(
            value,
            size: strong ? 18 : 15,
            color: strong ? c.signalText : null,
          ),
        ],
      ),
    );
  }
}

class _CheckBackTitle extends StatelessWidget {
  const _CheckBackTitle({this.title = '자전거 확인'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: '뒤로',
          onPressed: () => Navigator.of(context).maybePop(),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: const Icon(Icons.chevron_left_rounded, size: 30),
        ),
        const SizedBox(width: 2),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _UnderlinedAction extends StatelessWidget {
  const _UnderlinedAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return RideyPressable(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            decoration: TextDecoration.underline,
            decorationColor: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// The brand's line-and-dot picture of a chain (docs/brand.md): one dot per
/// person who returned the bike at once. The first is hollow — one person
/// can be a mistake — and from the second different person each dot wears a
/// ring. The line draws across and the dots spring in one after another.
class _ChainStrip extends StatefulWidget {
  const _ChainStrip({required this.chain});

  final int chain;

  @override
  State<_ChainStrip> createState() => _ChainStripState();
}

class _ChainStripState extends State<_ChainStrip>
    with SingleTickerProviderStateMixin {
  static const _maxDots = 8;
  late final int _dots = math.max(2, math.min(widget.chain, _maxDots));
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 500 + _dots * 140),
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (RideyMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    final extra = widget.chain - _dots;
    return Semantics(
      label: '서로 다른 ${widget.chain}명이 차례로 빌리자마자 반납',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 28,
              child: CustomPaint(
                painter: _ChainPainter(
                  t: _controller,
                  dots: _dots,
                  line: c.line,
                  hollow: c.muted,
                  signal: c.signal,
                  surface: Theme.of(context).colorScheme.surface,
                ),
              ),
            ),
          ),
          if (extra > 0) ...[
            const SizedBox(width: 10),
            RideyNumber('+$extra', size: 13, color: c.signalText),
          ],
        ],
      ),
    );
  }
}

class _ChainPainter extends CustomPainter {
  _ChainPainter({
    required this.t,
    required this.dots,
    required this.line,
    required this.hollow,
    required this.signal,
    required this.surface,
  }) : super(repaint: t);

  final Animation<double> t;
  final int dots;
  final Color line;
  final Color hollow;
  final Color signal;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 6.0;
    final y = size.height / 2;
    final step = (size.width - 2 * (r + 4)) / (dots - 1);
    final x0 = r + 4;
    final drawn = RideyMotion.ease.transform(math.min(1.0, t.value * 1.25));
    canvas.drawLine(
      Offset(x0, y),
      Offset(x0 + (size.width - 2 * x0) * drawn, y),
      Paint()
        ..color = line
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < dots; i++) {
      final start = .12 + i * (.7 / dots);
      final local = ((t.value - start) / .3).clamp(0.0, 1.0).toDouble();
      if (local <= 0) continue;
      final s = RideyMotion.spring.transform(local);
      final center = Offset(x0 + step * i, y);
      if (i == 0) {
        canvas.drawCircle(center, r * s, Paint()..color = surface);
        canvas.drawCircle(
          center,
          r * s,
          Paint()
            ..color = hollow
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        continue;
      }
      canvas.drawCircle(
        center,
        (r + 5) * s,
        Paint()
          ..color = signal.withValues(alpha: .35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(center, r * s, Paint()..color = signal);
    }
  }

  @override
  bool shouldRepaint(_ChainPainter old) =>
      old.dots != dots || old.signal != signal || old.line != line;
}

class _DataNote extends StatelessWidget {
  const _DataNote({required this.updatedAt, this.feed});

  final DateTime updatedAt;
  final FeedHealth? feed;

  @override
  Widget build(BuildContext context) {
    final freshness = rideyAgo(updatedAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.ridey.calmSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${feed?.isHealthy == false ? '자료가 지연되고 있어 판단을 보수적으로 해 주세요. ' : ''}$freshness 갱신된 대여 기록을 기준으로 했어요. 고장 확정이 아니므로, 직접 상태도 확인해 주세요.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.ridey.calmText),
      ),
    );
  }
}
