import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
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
  });

  final LiveBike bike;
  final DateTime updatedAt;
  final FeedHealth? feed;
  final VoidCallback? onCheckAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, rideyTabClearance),
        children: [
          const _CheckBackTitle(),
          const SizedBox(height: 28),
          Text(
            bike.bike,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '고장이 의심되는 자전거예요.',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: context.ridey.signal,
              fontSize: 26,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '서로 다른 ${bike.chain}명이 짧은 시간 안에 반납한 이력이 확인된 자전거예요.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          RideyButton.signal(
            label: '다른 자전거 확인하기',
            onPressed: onCheckAnother ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 18),
          Center(
            child: _UnderlinedAction(
              label: '판단 근거 확인하기',
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
  });

  final String title;
  final String message;
  final String? bikeId;
  final VoidCallback? onCheckAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: ListView(
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
          RideyButton.signal(
            label: '다른 자전거 확인하기',
            onPressed: onCheckAnother ?? () => Navigator.of(context).maybePop(),
          ),
        ],
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
      body: ListView(
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
