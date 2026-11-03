import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/stations/bike_station.dart';

/// First-launch hero, the app's version of the site's "점 하나 → 서울":
/// one signal dot bursts into Seoul's bike stations, which spring into place;
/// stations with a suspect bike right now light up nearest-first and ping, and
/// the number of suspect bikes counts up. Real data only — without a snapshot
/// nothing lights up and the tagline shows instead of a number.
class SeoulHero extends StatefulWidget {
  const SeoulHero({
    super.key,
    required this.stations,
    required this.snapshot,
    this.startDelay = Duration.zero,
  });

  final Future<List<BikeStation>> stations;
  final Future<LiveSnapshot?> snapshot;
  final Duration startDelay;

  @override
  State<SeoulHero> createState() => _SeoulHeroState();
}

class _SeoulHeroState extends State<SeoulHero> with TickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _ping = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  List<BikeStation> _stations = const [];
  Set<String> _alertIds = const {};
  int? _count;
  var _started = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object?>([
      widget.stations.catchError((_) => <BikeStation>[]),
      widget.snapshot.catchError((_) => null),
    ]);
    if (!mounted) return;
    final stations = results[0] as List<BikeStation>;
    final snapshot = results[1] as LiveSnapshot?;
    setState(() {
      _stations = stations;
      _alertIds = {
        for (final b in snapshot?.bikes ?? const <LiveBike>[]) b.station,
      };
      _count = snapshot?.bikes.length;
    });
    if (RideyMotion.reduced(context)) {
      _burst.value = 1;
      return;
    }
    await Future<void>.delayed(widget.startDelay);
    if (!mounted || _started) return;
    _started = true;
    await _burst.forward();
    // 고리는 세 번만 퍼진다 — 계속 돌면 화면이 산만하고 배터리를 쓴다.
    for (var i = 0; i < 3 && mounted; i++) {
      await _ping.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    _ping.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: ColoredBox(
        color: RideyColors.hero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _SeoulPainter(
                  stations: _stations,
                  alertIds: _alertIds,
                  burst: _burst,
                  ping: _ping,
                ),
              ),
            ),
            // 숫자와 글이 점 위에서 읽히도록 아래쪽을 잉크로 흐리게 덮는다(사이트 첫 화면과 같은 처리).
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 150,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00111317), Color(0xE6111317)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 22,
              child: AnimatedBuilder(
                animation: _burst,
                builder: (context, _) {
                  final t = Curves.easeOut.transform(
                    ((_burst.value - .45) / .45).clamp(0.0, 1.0),
                  );
                  final count = _count;
                  return Opacity(
                    opacity: t,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (count != null && count > 0) ...[
                          Text(
                            '${(count * t).round()}',
                            style: context
                                .rideyNumbers(theme.textTheme.displayLarge)
                                ?.copyWith(
                                  color: RideyColors.heroSignal,
                                  fontSize: 56,
                                  height: 1,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '지금 서울의 고장 의심 따릉이',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: RideyColors.heroText,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '서울시 공개 대여 기록으로 5분마다',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: RideyColors.heroMuted,
                            ),
                          ),
                        ] else
                          Text(
                            '타기 전에,\n고장 난 따릉이를 먼저',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: RideyColors.heroText,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                      ],
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

class _SeoulPainter extends CustomPainter {
  _SeoulPainter({
    required this.stations,
    required this.alertIds,
    required this.burst,
    required this.ping,
  }) : super(repaint: Listenable.merge([burst, ping]));

  final List<BikeStation> stations;
  final Set<String> alertIds;
  final Animation<double> burst;
  final Animation<double> ping;

  @override
  void paint(Canvas canvas, Size size) {
    if (stations.isEmpty) return;
    var minLat = double.infinity, maxLat = -double.infinity;
    var minLon = double.infinity, maxLon = -double.infinity;
    for (final s in stations) {
      minLat = math.min(minLat, s.latitude);
      maxLat = math.max(maxLat, s.latitude);
      minLon = math.min(minLon, s.longitude);
      maxLon = math.max(maxLon, s.longitude);
    }
    // 위도에 따라 경도 1도의 길이가 줄어드는 것을 맞춘 뒤 상자에 넣는다(지도가 옆으로 늘어나지 않게).
    final kx = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    // 대여소가 하나뿐이면 폭·높이가 0 이라 배율이 NaN 이 된다 — 최소 범위를 둔다.
    final w = math.max((maxLon - minLon) * kx, .01),
        h = math.max(maxLat - minLat, .01);
    const pad = 18.0;
    final box = Rect.fromLTWH(
      pad,
      pad + 26,
      size.width - pad * 2,
      size.height - pad * 2 - 26,
    );
    final scale = math.min(box.width / w, box.height / h);
    final ox = box.left + (box.width - w * scale) / 2;
    final oy = box.top + (box.height - h * scale) / 2;
    Offset at(BikeStation s) => Offset(
      ox + (s.longitude - minLon) * kx * scale,
      oy + (maxLat - s.latitude) * scale,
    );
    final origin = Offset(size.width / 2, size.height * .42);
    final maxDist =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;

    final t = burst.value;
    final dotPaint = Paint()
      ..color = RideyColors.heroText.withValues(alpha: .26);
    final alerts = <(Offset, double)>[];
    for (final s in stations) {
      final target = at(s);
      final d = (target - origin).distance / maxDist; // 0..~1
      // 가까운 대여소부터 퍼져 나가 스프링으로 앉는다.
      final local = ((t - d * .35) / .45).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final p = Offset.lerp(
        origin,
        target,
        RideyMotion.spring.transform(local),
      )!;
      canvas.drawCircle(p, 1.3, dotPaint);
      if (alertIds.contains(s.id)) alerts.add((target, d));
    }
    // 첫 순간: 가운데 신호 점 하나(시작 애니메이션의 점)가 커졌다가 터진다.
    if (t < .2) {
      final r = 7 * (1 - t / .2) + 2;
      canvas.drawCircle(origin, r, Paint()..color = RideyColors.heroSignal);
    }
    final signal = Paint()..color = RideyColors.heroSignal;
    for (final (p, d) in alerts) {
      final on = ((t - .55 - d * .3) / .12).clamp(0.0, 1.0);
      if (on <= 0) continue;
      canvas.drawCircle(p, 3.2 * RideyMotion.spring.transform(on), signal);
      final q = ping.value;
      if (q > 0 && q < 1) {
        canvas.drawCircle(
          p,
          3.2 + q * 14,
          Paint()
            ..color = RideyColors.heroSignal.withValues(alpha: (1 - q) * .55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SeoulPainter old) =>
      old.stations != stations || old.alertIds != alertIds;
}
