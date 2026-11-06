import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/rider/nearby_map.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/features/staff/pickup_plan.dart';
import 'package:ridey_app/features/staff/road_route.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

/// 앱 안 길안내: 추천 경로를 차로 따라간다. 지도는 내 위치를 따라가며 가는 방향이 위로 오고,
/// 위에는 다음 갈림길(남은 거리·도는 방향·길 이름), 아래에는 지금 가는 대여소와 거기서 할 일.
/// 대여소 40m 안에 들어오면 '도착' 으로 바뀌고, '다음 곳' 을 누르면 다음 대여소로 이어진다.
/// 도착해서 넘긴 곳은 지도에 체크로 바뀌고, 이번 길에서 거둔·실은·내린 대수가 쌓인다(이 폰에서만 셈).
class StaffNavigationPage extends StatefulWidget {
  const StaffNavigationPage({
    super.key,
    required this.plan,
    required this.start,
    this.road,
    this.positions,
  });

  final PickupPlan plan;
  final DeviceLocation start;
  final RoadRoute? road;

  /// 위치가 바뀔 때마다(시험·시연은 고정 위치). 없으면 폰 GPS.
  final Stream<DeviceLocation>? positions;

  @override
  State<StaffNavigationPage> createState() => _StaffNavigationPageState();
}

class _StaffNavigationPageState extends State<StaffNavigationPage> {
  final _map = MapController();
  StreamSubscription<DeviceLocation>? _sub;
  late DeviceLocation _here = widget.start;
  var _stop = 0;
  var _step = 0;

  /// 도착해서 할 일을 마친 곳(건너뛴 곳은 빠진다).
  final _done = <int>{};
  var _follow = true;
  var _ready = false;
  double _heading = 0;

  static const _arriveMeters = 40.0;
  static const _stepPassMeters = 25.0;

  List<PlanStop> get _stops => widget.plan.stops;
  PlanStop? get _target => _stop < _stops.length ? _stops[_stop] : null;

  List<RouteStep> get _legSteps {
    final legs = widget.road?.legs;
    if (legs == null || _stop >= legs.length) return const [];
    return legs[_stop];
  }

  @override
  void initState() {
    super.initState();
    _sub = (widget.positions ?? watchDeviceLocation()).listen(_moved);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _moved(DeviceLocation next) {
    final moved = metersBetween(
      _here.latitude,
      _here.longitude,
      next.latitude,
      next.longitude,
    );
    if (moved > 3) _heading = _bearing(_here, next);
    setState(() {
      _here = next;
      // 지나간 갈림길은 넘긴다.
      final steps = _legSteps;
      while (_step < steps.length - 1 &&
          _distTo(steps[_step].location) < _stepPassMeters) {
        _step++;
      }
    });
    _followCamera();
  }

  void _followCamera() {
    if (!_follow || !_ready) return;
    _map.moveAndRotate(
      LatLng(_here.latitude, _here.longitude),
      math.max(_map.camera.zoom, 16.5),
      -_heading,
    );
  }

  double _distTo(LatLng p) =>
      metersBetween(_here.latitude, _here.longitude, p.latitude, p.longitude);

  double _bearing(DeviceLocation a, DeviceLocation b) {
    final p1 = a.latitude * math.pi / 180, p2 = b.latitude * math.pi / 180;
    final dl = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dl) * math.cos(p2);
    final x =
        math.cos(p1) * math.sin(p2) -
        math.sin(p1) * math.cos(p2) * math.cos(dl);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  bool get _arrived {
    final t = _target;
    return t != null &&
        _distTo(LatLng(t.station.latitude, t.station.longitude)) <
            _arriveMeters;
  }

  /// 이번 길에서 마친 곳들의 합.
  ({int suspects, int pickedUp, int dropped}) get _tally {
    var suspects = 0, pickedUp = 0, dropped = 0;
    for (final i in _done) {
      suspects += _stops[i].suspects.length;
      pickedUp += _stops[i].pickUp;
      dropped += _stops[i].dropOff;
    }
    return (suspects: suspects, pickedUp: pickedUp, dropped: dropped);
  }

  void _next() {
    setState(() {
      if (_arrived) _done.add(_stop);
      _stop++;
      _step = 0;
    });
    if (_target == null) return;
    _followCamera();
  }

  /// 도로 길이 없을 때: 대여소까지 방향(북동쪽 등)과 직선거리.
  String _compass(LatLng to) {
    final b = _bearing(_here, (latitude: to.latitude, longitude: to.longitude));
    const names = ['북', '북동', '동', '남동', '남', '남서', '서', '북서'];
    return '${names[((b + 22.5) % 360 ~/ 45)]}쪽';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    final theme = Theme.of(context);
    final target = _target;
    final targetPoint = target == null
        ? null
        : LatLng(target.station.latitude, target.station.longitude);
    final arrived = targetPoint != null && _distTo(targetPoint) < _arriveMeters;
    final steps = _legSteps;
    final step = _step < steps.length ? steps[_step] : null;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: LatLng(_here.latitude, _here.longitude),
                initialZoom: 16.5,
                minZoom: 9,
                maxZoom: 18.5,
                backgroundColor: c.fill,
                onMapReady: () {
                  _ready = true;
                  _followCamera();
                },
                onPositionChanged: (camera, hasGesture) {
                  // 손으로 지도를 움직이면 따라가기를 멈춘다('내 위치' 로 다시 켬).
                  if (hasGesture && _follow) setState(() => _follow = false);
                },
              ),
              children: [
                if (NearbyMap.tilesEnabled) rideyTileLayer(context),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points:
                          widget.road?.points ??
                          [
                            LatLng(
                              widget.start.latitude,
                              widget.start.longitude,
                            ),
                            for (final s in _stops)
                              LatLng(s.station.latitude, s.station.longitude),
                          ],
                      color: c.calm,
                      strokeWidth: 6,
                      borderColor: theme.colorScheme.surface,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  rotate: true,
                  markers: [
                    for (var i = 0; i < _stops.length; i++)
                      Marker(
                        point: LatLng(
                          _stops[i].station.latitude,
                          _stops[i].station.longitude,
                        ),
                        width: 34,
                        height: 34,
                        child: _StopDot(
                          number: i + 1,
                          done: i < _stop,
                          checked: _done.contains(i),
                          current: i == _stop,
                          suspects: _stops[i].suspects.isNotEmpty,
                        ),
                      ),
                    Marker(
                      point: LatLng(_here.latitude, _here.longitude),
                      width: 44,
                      height: 44,
                      rotate: false,
                      child: Transform.rotate(
                        angle: _heading * math.pi / 180,
                        child: Icon(
                          Icons.navigation_rounded,
                          size: 36,
                          color: c.calm,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 위: 다음 갈림길
          Positioned(
            left: 12,
            right: 12,
            top: MediaQuery.paddingOf(context).top + 8,
            child: _Banner(
              icon: target == null
                  ? Icons.flag_rounded
                  : arrived
                  ? Icons.flag_rounded
                  : _stepIcon(step),
              distance: target == null || arrived
                  ? null
                  : step != null
                  ? navDistance(_distTo(step.location))
                  : navDistance(_distTo(targetPoint!)),
              text: target == null
                  ? '모든 곳을 들렀어요'
                  : arrived
                  ? '${target.station.name} 도착'
                  : step != null
                  ? stepText(step)
                  : '${_compass(targetPoint!)}으로 ${target.station.name}',
              onClose: () => Navigator.of(context).maybePop(),
            ),
          ),
          if (!_follow)
            Positioned(
              right: 16,
              bottom: 200,
              child: FloatingActionButton.small(
                heroTag: 'follow',
                tooltip: '내 위치 따라가기',
                backgroundColor: theme.colorScheme.surface,
                onPressed: () {
                  setState(() => _follow = true);
                  _followCamera();
                },
                child: Icon(Icons.my_location_rounded, color: c.calm),
              ),
            ),
          // 아래: 지금 가는 대여소와 할 일
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StopPanel(
              index: _stop,
              total: _stops.length,
              stop: target,
              remaining: targetPoint == null ? null : _distTo(targetPoint),
              arrived: arrived,
              tally: _tally,
              onNext: _next,
              onFinish: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _stepIcon(RouteStep? step) {
    if (step == null) return Icons.navigation_rounded;
    if (step.type == 'roundabout' || step.type == 'rotary') {
      return Icons.roundabout_right_rounded;
    }
    if (step.type == 'merge') return Icons.merge_rounded;
    if (step.type == 'arrive') return Icons.flag_rounded;
    return switch (step.modifier) {
      'left' => Icons.turn_left_rounded,
      'right' => Icons.turn_right_rounded,
      'slight left' => Icons.turn_slight_left_rounded,
      'slight right' => Icons.turn_slight_right_rounded,
      'sharp left' => Icons.turn_sharp_left_rounded,
      'sharp right' => Icons.turn_sharp_right_rounded,
      'uturn' => Icons.u_turn_left_rounded,
      _ => Icons.straight_rounded,
    };
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    required this.onClose,
    this.distance,
  });

  final IconData icon;
  final String text;
  final String? distance;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: RideyColors.ink,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
        child: Row(
          children: [
            Icon(icon, color: RideyColors.heroText, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (distance != null)
                    Text(
                      distance!,
                      style: context
                          .rideyNumbers(theme.textTheme.titleLarge)
                          ?.copyWith(color: RideyColors.heroText, fontSize: 24),
                    ),
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: RideyColors.heroText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '길안내 끝내기',
              onPressed: onClose,
              icon: const Icon(
                Icons.close_rounded,
                color: RideyColors.heroMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopPanel extends StatelessWidget {
  const _StopPanel({
    required this.index,
    required this.total,
    required this.stop,
    required this.remaining,
    required this.arrived,
    required this.tally,
    required this.onNext,
    required this.onFinish,
  });

  final ({int suspects, int pickedUp, int dropped}) tally;
  final int index;
  final int total;
  final PlanStop? stop;
  final double? remaining;
  final bool arrived;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.ridey;
    final s = stop;
    final sum = [
      if (tally.suspects > 0) '고장 의심 ${tally.suspects}대 거둠',
      if (tally.pickedUp > 0) '${tally.pickedUp}대 실음',
      if (tally.dropped > 0) '${tally.dropped}대 내림',
    ].join(' · ');
    final tallyLine = sum.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: c.calm),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '이번 길: $sum',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: c.calmText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: s == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?tallyLine,
                    Text(
                      '추천 경로를 모두 돌았어요',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '거둔 고장 의심 자전거는 정비센터로 가져가 주세요.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    RideyButton(label: '길안내 끝내기', onPressed: onFinish),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?tallyLine,
                    Text(
                      '${index + 1} / $total곳'
                      '${remaining == null || arrived ? '' : ' · ${navDistance(remaining!)} 남음'}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.station.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.task,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: s.suspects.isNotEmpty
                            ? c.signalText
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (s.suspects.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        s.suspects.map((b) => b.bike).join(', '),
                        style: context
                            .rideyNumbers(theme.textTheme.bodyMedium)
                            ?.copyWith(color: c.muted, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 14),
                    arrived
                        ? RideyButton(
                            label: index + 1 < total ? '다음 곳으로' : '마치기',
                            onPressed: onNext,
                          )
                        : RideyButton.secondary(
                            label: '이곳 건너뛰기',
                            onPressed: onNext,
                          ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StopDot extends StatelessWidget {
  const _StopDot({
    required this.number,
    required this.done,
    required this.current,
    required this.suspects,
    this.checked = false,
  });

  final int number;
  final bool done;

  /// 도착해서 마친 곳(건너뛴 곳은 번호만 흐리게).
  final bool checked;
  final bool current;
  final bool suspects;

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    final surface = Theme.of(context).colorScheme.surface;
    final fill = done
        ? c.muted
        : suspects
        ? c.signal
        : c.calm;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(
          color: current ? RideyColors.ink : surface,
          width: 3,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
          : Text(
              '$number',
              style: context
                  .rideyNumbers(const TextStyle())
                  ?.copyWith(
                    fontSize: 13,
                    height: 1,
                    color: suspects && !done ? RideyColors.ink : Colors.white,
                  ),
            ),
    );
  }
}
