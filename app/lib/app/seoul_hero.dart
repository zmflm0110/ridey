import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/stations/bike_station.dart';

/// Full-screen first-launch story, told once (the site's "점 하나 → 서울"):
/// one signal dot drops and bounces, bursts into Seoul's bike stations which
/// spring into place, then stations with a suspect bike right now light up and
/// ping while [overlay] shows the count. Only real data lights anything up.
/// The map sits in the upper part of the screen so the [overlay] panel below
/// never covers it. Reduce motion shows the end state at once.
class SeoulHero extends StatefulWidget {
  const SeoulHero({
    super.key,
    required this.stations,
    required this.snapshot,
    required this.overlay,
  });

  final Future<List<BikeStation>> stations;
  final Future<LiveSnapshot?> snapshot;

  /// Drawn over the map. [story] runs 0..1 (drop, then burst); [lit] runs
  /// 0..1 once the live data is in; [count] is null without live data.
  final Widget Function(
    BuildContext context,
    double story,
    double lit,
    int? count,
  )
  overlay;

  @override
  State<SeoulHero> createState() => _SeoulHeroState();
}

class _SeoulHeroState extends State<SeoulHero> with TickerProviderStateMixin {
  // 0.00–0.24 점이 떨어져 튀며 앉음 · 0.24–1.00 서울로 퍼짐
  late final AnimationController _story = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final AnimationController _lit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final AnimationController _ping = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  List<BikeStation> _stations = const [];
  Set<String> _alertIds = const {};
  int? _count;
  var _snapshotIn = false;
  var _begun = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_begun) return;
    _begun = true;
    final reduced = RideyMotion.reduced(context);
    if (reduced) {
      _story.value = 1;
    } else {
      _story.forward();
      _story.addListener(_maybeLight);
    }
    widget.stations
        .then((s) {
          if (mounted) setState(() => _stations = s);
        })
        .catchError((_) {});
    widget.snapshot
        .then((snap) {
          if (!mounted || snap == null) return;
          setState(() {
            _alertIds = {for (final b in snap.bikes) b.station};
            _count = snap.bikes.length;
            _snapshotIn = true;
          });
          if (reduced) {
            _lit.value = 1;
          } else {
            _maybeLight();
          }
        })
        .catchError((_) {});
  }

  /// 경보 대여소는 지도가 다 퍼진 뒤에, 실제 자료가 왔을 때만 켠다.
  void _maybeLight() {
    if (!_snapshotIn || _lit.isAnimating || _lit.value > 0) return;
    if (_story.value < .7) return;
    _story.removeListener(_maybeLight);
    _lit.forward().then((_) async {
      // 고리는 세 번만 퍼진다 — 계속 돌면 산만하고 배터리를 쓴다.
      for (var i = 0; i < 3 && mounted; i++) {
        await _ping.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _story.dispose();
    _lit.dispose();
    _ping.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: RideyColors.hero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _SeoulPainter(
                stations: _stations,
                alertIds: _alertIds,
                story: _story,
                lit: _lit,
                ping: _ping,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: Listenable.merge([_story, _lit]),
            builder: (context, _) =>
                widget.overlay(context, _story.value, _lit.value, _count),
          ),
        ],
      ),
    );
  }
}

class _SeoulPainter extends CustomPainter {
  _SeoulPainter({
    required this.stations,
    required this.alertIds,
    required this.story,
    required this.lit,
    required this.ping,
  }) : super(repaint: Listenable.merge([story, lit, ping]));

  final List<BikeStation> stations;
  final Set<String> alertIds;
  final Animation<double> story;
  final Animation<double> lit;
  final Animation<double> ping;

  /// 지도는 화면 위쪽(상태 표시줄 아래 ~ 높이의 58%)에만 — 아래 패널이 가리지 않게.
  static Rect mapBox(Size size) =>
      Rect.fromLTRB(18, 96, size.width - 18, size.height * .58);

  @override
  void paint(Canvas canvas, Size size) {
    final box = mapBox(size);
    final origin = box.center;
    final t = story.value;
    final signal = Paint()..color = RideyColors.heroSignal;

    // 1) 떨어지는 점 — 위에서 떨어져 두 번 작게 튀고 앉는다(로고·사이트의 '떨어져 앉는 점').
    const dropEnd = .24;
    if (t < dropEnd + .06) {
      final d = (t / dropEnd).clamp(0.0, 1.0);
      final y = origin.dy - _height(d) * 260;
      final fade = t <= dropEnd ? 1.0 : 1 - (t - dropEnd) / .06;
      canvas.drawCircle(
        Offset(origin.dx, y),
        7 * fade + .01,
        Paint()..color = RideyColors.heroSignal.withValues(alpha: fade),
      );
    }
    if (stations.isEmpty) return;

    // 2) 서울로 퍼짐 — 가까운 대여소부터 스프링으로 제자리에 앉는다.
    var minLat = double.infinity, maxLat = -double.infinity;
    var minLon = double.infinity, maxLon = -double.infinity;
    for (final s in stations) {
      minLat = math.min(minLat, s.latitude);
      maxLat = math.max(maxLat, s.latitude);
      minLon = math.min(minLon, s.longitude);
      maxLon = math.max(maxLon, s.longitude);
    }
    // 위도에 따라 경도 1도의 길이가 줄어드는 것을 맞춘다. 대여소가 하나뿐이면 범위가 0 이라 최소 범위를 둔다.
    final kx = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final w = math.max((maxLon - minLon) * kx, .01);
    final h = math.max(maxLat - minLat, .01);
    final scale = math.min(box.width / w, box.height / h);
    final ox = box.left + (box.width - w * scale) / 2;
    final oy = box.top + (box.height - h * scale) / 2;
    Offset at(BikeStation s) => Offset(
      ox + (s.longitude - minLon) * kx * scale,
      oy + (maxLat - s.latitude) * scale,
    );
    final reach = box.longestSide / 2;
    final b = ((t - dropEnd) / (1 - dropEnd)).clamp(0.0, 1.0);
    final dot = Paint()..color = RideyColors.heroText.withValues(alpha: .28);
    final alerts = <(Offset, double)>[];
    // 2,789개 점을 원 하나씩 그리면 프레임마다 그리기 호출이 수천 번이라 끊긴다 — 좌표를 모아 한 번에 그린다.
    final points = Float32List(stations.length * 2);
    var n = 0;
    for (final s in stations) {
      final target = at(s);
      final d = ((target - origin).distance / reach).clamp(0.0, 1.0);
      final local = ((b - d * .4) / .5).clamp(0.0, 1.0);
      if (alertIds.contains(s.id)) alerts.add((target, d));
      if (local <= 0) continue;
      final k = RideyMotion.spring.transform(local);
      points[n++] = origin.dx + (target.dx - origin.dx) * k;
      points[n++] = origin.dy + (target.dy - origin.dy) * k;
    }
    if (n > 0) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(points, 0, n),
        dot
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round,
      );
    }

    // 3) 지금 고장 의심이 있는 대여소 — 가까운 곳부터 켜지고 고리가 퍼진다.
    for (final (p, d) in alerts) {
      final on = ((lit.value - d * .6) / .4).clamp(0.0, 1.0);
      if (on <= 0) continue;
      canvas.drawCircle(p, 3.2 * RideyMotion.spring.transform(on), signal);
      final q = ping.value;
      if (q > 0 && q < 1) {
        canvas.drawCircle(
          p,
          3.2 + q * 14,
          Paint()
            ..color = RideyColors.heroSignal.withValues(alpha: (1 - q) * .5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
  }

  /// 0 = 앉음, 1 = 처음 높이. 떨어진 뒤 0.22, 0.06 높이로 두 번 튐.
  static double _height(double t) {
    if (t <= 0) return 1;
    if (t < .45) {
      final p = t / .45;
      return 1 - p * p;
    }
    if (t < .75) {
      final p = (t - .45) / .3;
      return .22 * (1 - math.pow(2 * p - 1, 2));
    }
    if (t < .92) {
      final p = (t - .75) / .17;
      return .06 * (1 - math.pow(2 * p - 1, 2));
    }
    return 0;
  }

  @override
  bool shouldRepaint(_SeoulPainter old) =>
      old.stations != stations || old.alertIds != alertIds;
}
