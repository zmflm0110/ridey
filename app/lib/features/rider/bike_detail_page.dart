import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/widgets/ridey_status.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class BikeDetailPage extends StatelessWidget {
  const BikeDetailPage({
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
    final label = bike.isHighAlert ? '피하세요.' : '주의해서 확인하세요.';
    final detail = bike.isHighAlert
        ? '서로 다른 사람들이 빌리자마자 반납한 기록이 여러 번 이어졌어요. 옆 자전거를 골라 주세요.'
        : '빌리자마자 반납한 기록이 이어져 경보가 켜졌어요. 타기 전에 브레이크·타이어를 살펴보세요.';
    final station = bike.stationName.isEmpty ? bike.station : bike.stationName;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            RideyPopIn(
              child: RideyCard(
                padding: const EdgeInsets.all(22),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.signalSoft, theme.colorScheme.surface],
                  stops: const [0, .55],
                ),
                borderColor: Color.lerp(c.line, c.signal, .35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 34,
                          color: c.signalText,
                        ),
                        const Spacer(),
                        RideyTag(
                          bike.isHighAlert ? '강한 경보' : '경보',
                          background: bike.isHighAlert
                              ? c.signal
                              : c.signalSoft,
                          foreground: bike.isHighAlert
                              ? RideyColors.ink
                              : c.signalText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      bike.bike,
                      style: context
                          .rideyNumbers(theme.textTheme.headlineLarge)
                          ?.copyWith(fontSize: 24, letterSpacing: -0.7),
                    ),
                    const SizedBox(height: 2),
                    Text(label, style: theme.textTheme.headlineLarge),
                    const SizedBox(height: 8),
                    Text(
                      detail,
                      style: theme.textTheme.bodyLarge?.copyWith(color: c.body),
                    ),
                    const SizedBox(height: 14),
                    _Facts(
                      rows: [
                        if (bike.probability != null)
                          ('다음 사람도 바로 반납할 확률', '${bike.probability}%', true),
                        ('연쇄', '서로 다른 ${bike.chain}명', false),
                        if (bike.lastDud.isNotEmpty)
                          ('마지막 바로 반납', bike.lastDud, false),
                        ('대여소', station, false),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: RideyDataConfidence(
                updatedAt: updatedAt,
                isHealthy: feed?.isHealthy ?? true,
                ratio: feed?.ratio,
              ),
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
            if (bike.reasons.isNotEmpty) ...[
              const RideySectionTitle('판단 근거', note: '확률을 올리고 내린 것'),
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
                                color: theme.colorScheme.onSurface,
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
            const SizedBox(height: 18),
            RideyButton.secondary(
              label: '다른 자전거 확인',
              icon: Icons.qr_code_scanner_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grey fact box inside the result card (web `.facts`); rows rise in turn.
class _Facts extends StatelessWidget {
  const _Facts({required this.rows});

  final List<(String, String, bool)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.ridey.fill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            RideyEnter(
              index: i + 2,
              step: const Duration(milliseconds: 60),
              offset: 8,
              child: Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        rows[i].$1,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          color: context.ridey.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (rows[i].$3)
                      RideyNumber(
                        rows[i].$2,
                        size: 18,
                        color: context.ridey.signalText,
                      )
                    else
                      Flexible(
                        child: Text(
                          rows[i].$2,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
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
        borderRadius: BorderRadius.circular(18),
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
