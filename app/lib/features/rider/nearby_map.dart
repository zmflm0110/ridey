import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/location/device_location.dart';

class NearbyMapStation {
  const NearbyMapStation({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.isHighAlert = false,
    this.alertCount = 0,
    this.parkedBikes,
  });

  final String id;
  final double latitude;
  final double longitude;

  /// 이 대여소에 연쇄 3명 이상 자전거가 있으면 꽉 찬 신호 점, 아니면 옅은 점.
  final bool isHighAlert;
  final int alertCount;
  final int? parkedBikes;
}

/// The area map: OpenStreetMap's standard tiles (no key, Korean labels) seen
/// through a colour filter — near-grey by day, inverted and dark at night — so
/// the brand's signal markers stand out: a filled orange disc with the number
/// of suspect bikes for a strong alert (it pings a few times), a soft disc for
/// a 2-person chain, a small grey dot for a station without alerts, and a
/// calm-blue dot for the phone. Works the same on iPhone and Android.
class NearbyMap extends StatefulWidget {
  const NearbyMap({
    super.key,
    required this.stations,
    required this.onStationTap,
    this.location,
    this.fullBleed = false,
    this.showCounts = false,
    this.radiusMeters,
    this.focusMeters = 500,
    this.route = const [],
  });

  /// 들를 순서(대여소 id). 있으면 내 위치에서 시작해 그 순서로 잇는 파란 점선을 그리고, 처음 화면에 다 보이게 맞춘다.
  final List<String> route;

  /// 처음 켰을 때(와 '내 위치' 단추) 보여 줄 범위. 범위 원([radiusMeters])보다 좁게 — 가까운 곳부터 크게 본다.
  final double focusMeters;

  /// 내 위치 둘레의 범위(예: 2km). 있으면 처음에 그 원이 다 보이게 맞추고 얇은 원으로 그려 준다.
  final double? radiusMeters;

  /// '주변 대여소 현황' 일 때: 고장 의심이 없는 대여소도 탈 만한 자전거 수를 흰 원에 보여 준다.
  final bool showCounts;

  /// 홈처럼 화면을 채울 때: 둥근 카드·테두리·고정 높이 없이 부모 크기를 그대로 쓴다.
  final bool fullBleed;

  final List<NearbyMapStation> stations;
  final DeviceLocation? location;

  /// 대여소를 눌렀을 때. 돌려준 Future(보통 열린 카드)가 끝날 때까지 그 대여소를 강조해 둔다.
  final FutureOr<void> Function(String id) onStationTap;

  /// 화면 미리보기 테스트에서만 켠다(실제 타일을 받아 그려 본다).
  @visibleForTesting
  static bool forceTiles = false;

  /// 테스트에서는 지도 그림(타일)을 받지 않는다 — 네트워크가 막혀 있고 화면 확인에 필요 없다.
  static bool get _tilesEnabled {
    if (forceTiles) return true;
    try {
      return !Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return true;
    }
  }

  @override
  State<NearbyMap> createState() => _NearbyMapState();
}

class _NearbyMapState extends State<NearbyMap>
    with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final AnimationController _ping = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  var _ready = false;
  double _rotation = 0;
  var _pinged = false;

  /// 지금 카드가 열려 있는 대여소 — 지도에서 어느 것을 보고 있는지 테두리로 보여 준다.
  String? _selected;

  Future<void> _tap(String id) async {
    setState(() => _selected = id);
    try {
      await widget.onStationTap(id);
    } finally {
      if (mounted && _selected == id) setState(() => _selected = null);
    }
  }

  static const _seoul = LatLng(37.5665, 126.9780);

  LatLng get _center {
    final location = widget.location;
    if (location != null) return LatLng(location.latitude, location.longitude);
    final station = widget.stations.firstOrNull;
    if (station != null) return LatLng(station.latitude, station.longitude);
    return _seoul;
  }

  double get _zoom =>
      widget.location != null || widget.stations.isNotEmpty ? 14 : 12;

  double _height = 0;

  /// 화면을 채운 지도는 아래 절반을 시트가 덮는다 — 내 위치가 보이는 위쪽 가운데에 오도록 올린다.
  Offset get _focusOffset =>
      widget.fullBleed ? Offset(0, -_height * .26) : Offset.zero;

  EdgeInsets get _fitPadding => EdgeInsets.fromLTRB(
    20,
    64,
    20,
    widget.fullBleed ? _height * .52 + 16 : 20,
  );

  /// 처음 맞출 범위: 내 위치 둘레 [NearbyMap.focusMeters](기본 500m), 위치가 없으면 경보 대여소 전부.
  CameraFit? _initialFit() {
    final here = widget.location;
    // 들를 순서가 있으면 내 위치와 들를 곳이 다 보이게.
    final stops = [
      for (final id in widget.route)
        for (final s in widget.stations)
          if (s.id == id) LatLng(s.latitude, s.longitude),
    ];
    if (here != null && stops.isNotEmpty) {
      return CameraFit.coordinates(
        coordinates: [LatLng(here.latitude, here.longitude), ...stops],
        padding: _fitPadding + const EdgeInsets.all(24),
        maxZoom: 16,
      );
    }
    if (here != null && widget.radiusMeters != null) {
      final radius = math.min(widget.focusMeters, widget.radiusMeters!);
      final dLat = radius / 111320;
      final dLon = radius / (111320 * math.cos(here.latitude * math.pi / 180));
      return CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(here.latitude - dLat, here.longitude - dLon),
          LatLng(here.latitude + dLat, here.longitude + dLon),
        ),
        padding: _fitPadding,
      );
    }
    final alerts = [
      for (final s in widget.stations)
        if (s.alertCount > 0) LatLng(s.latitude, s.longitude),
    ];
    if (here == null && alerts.length > 1) {
      return CameraFit.coordinates(
        coordinates: alerts,
        padding: _fitPadding,
        maxZoom: 15,
      );
    }
    return null;
  }

  void _focus() {
    if (!_ready) return;
    final fit = _initialFit();
    if (fit != null) {
      _map.fitCamera(fit);
      return;
    }
    _map.move(_center, _zoom, offset: _focusOffset);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pinged) return;
    _pinged = true;
    if (!RideyMotion.reduced(context)) _pingFewTimes();
  }

  /// 강한 경보 고리는 세 번만 퍼진다 — 계속 돌면 산만하고 배터리를 쓴다.
  Future<void> _pingFewTimes() async {
    for (var i = 0; i < 3 && mounted; i++) {
      await _ping.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(NearbyMap old) {
    super.didUpdateWidget(old);
    // 위치를 늦게 찾으면 그 자리로 옮긴다(첫 화면은 대여소 근처로 열려 있음).
    if (_ready && old.location == null && widget.location != null) {
      _focus();
    }
  }

  @override
  void dispose() {
    _ping.dispose();
    super.dispose();
  }

  void _zoomBy(double delta) {
    final camera = _map.camera;
    _map.move(camera.center, (camera.zoom + delta).clamp(10, 18).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = context.ridey;
    final radius = widget.fullBleed ? 0.0 : 20.0;
    // 경보가 없는 대여소를 먼저, 강한 경보를 맨 위에 그린다.
    int rank(NearbyMapStation s) =>
        s.alertCount <= 0 ? 0 : (s.isHighAlert ? 2 : 1);
    final ordered = [...widget.stations]
      ..sort((a, b) => rank(a).compareTo(rank(b)));
    // 누른 대여소는 맨 위에(다른 핀에 가리지 않게).
    if (_selected != null) {
      final i = ordered.indexWhere((s) => s.id == _selected);
      if (i >= 0) ordered.add(ordered.removeAt(i));
    }
    final byId = {for (final s in widget.stations) s.id: s};
    final routeIds = [
      for (final id in widget.route)
        if (byId.containsKey(id)) id,
    ];
    final here = widget.location;

    Widget buildMap() => FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: _zoom,
        // 처음 모습은 지도를 만들 때 정한다(다 만든 뒤 옮기면 첫 타일을 못 받는 경우가 있었다).
        initialCameraFit: _initialFit(),
        minZoom: 10,
        maxZoom: 18,
        backgroundColor: dark ? const Color(0xFF1B1D21) : c.fill,
        interactionOptions: const InteractionOptions(
          flags:
              InteractiveFlag.drag |
              InteractiveFlag.pinchZoom |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.flingAnimation |
              // 두 손가락으로 돌릴 수 있다(진짜 지도 앱처럼). 돌아가면 나침반 단추가 북쪽으로 되돌린다.
              InteractiveFlag.rotate,
        ),
        onMapEvent: (event) {
          final r = event.camera.rotation;
          if ((r - _rotation).abs() > .5) setState(() => _rotation = r);
        },
        onMapReady: () {
          _ready = true;
          if (_initialFit() == null) _focus();
        },
      ),
      children: [
        if (NearbyMap._tilesEnabled)
          TileLayer(
            // OpenStreetMap 기본 지도(키 없음, 한글 지명). CARTO 는 앱에서 키를 요구해서 쓰지 않는다.
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'kr.bikedoctor.ridey',
            maxNativeZoom: 19,
            // 원래 색은 알록달록해 신호 주황이 묻힌다 — 밝을 땐 거의 회색으로, 어두울 땐 뒤집어 어둡게.
            tileBuilder: (context, tile, _) => ColorFiltered(
              colorFilter: ColorFilter.matrix(dark ? _darkTiles : _lightTiles),
              child: tile,
            ),
            // flutter_map 의 디스크 캐시는 시작할 때 저장 폴더를 찾다 실패하면 타일이 하나도 안 그려진다
            // (테스트에서 재현). 지도 그림은 앱이 켜져 있는 동안 메모리에 남으니 디스크 캐시는 끈다.
            tileProvider: NetworkTileProvider(
              cachingProvider: const DisabledMapCachingProvider(),
            ),
          ),
        if (widget.location != null && widget.radiusMeters != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: LatLng(
                  widget.location!.latitude,
                  widget.location!.longitude,
                ),
                radius: widget.radiusMeters!,
                useRadiusInMeter: true,
                color: c.calm.withValues(alpha: dark ? .07 : .05),
                borderColor: c.calm.withValues(alpha: .45),
                borderStrokeWidth: 1.5,
              ),
            ],
          ),
        if (here != null && routeIds.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  LatLng(here.latitude, here.longitude),
                  for (final id in routeIds)
                    LatLng(byId[id]!.latitude, byId[id]!.longitude),
                ],
                color: c.calm,
                strokeWidth: 3,
                pattern: StrokePattern.dashed(segments: const [8, 6]),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final s in ordered)
              Marker(
                point: LatLng(s.latitude, s.longitude),
                width:
                    s.alertCount > 0 || widget.showCounts || _selected == s.id
                    ? 64
                    : 28,
                height:
                    s.alertCount > 0 || widget.showCounts || _selected == s.id
                    ? 64
                    : 28,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _tap(s.id),
                  child: Semantics(
                    button: true,
                    label: s.alertCount > 0
                        ? '고장 의심 ${s.alertCount}대가 있는 대여소'
                        : s.parkedBikes != null
                        ? '자전거 ${s.parkedBikes}대가 있는 대여소'
                        : '대여소',
                    child: _StationPin(
                      station: s,
                      ping: _ping,
                      showCount: widget.showCounts,
                      selected: _selected == s.id,
                    ),
                  ),
                ),
              ),
            if (widget.location != null)
              Marker(
                point: LatLng(
                  widget.location!.latitude,
                  widget.location!.longitude,
                ),
                width: 44,
                height: 44,
                // 내 위치 점은 누르는 것이 아니다 — 바로 옆 대여소를 누를 때 가로막지 않게.
                child: const IgnorePointer(child: _UserDot()),
              ),
          ],
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.fill,
          border: widget.fullBleed ? null : Border.all(color: c.line),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: SizedBox(
          height: widget.fullBleed ? double.infinity : 312,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _height = constraints.maxHeight;
              return Stack(
                children: [
                  Positioned.fill(child: buildMap()),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ZoomControls(onZoom: _zoomBy),
                        if (widget.location != null) ...[
                          const SizedBox(height: 8),
                          _RoundButton(
                            tooltip: '내 위치',
                            icon: Icons.my_location_rounded,
                            onPressed: _focus,
                          ),
                        ],
                        if (_rotation.abs() % 360 > .5) ...[
                          const SizedBox(height: 8),
                          _RoundButton(
                            tooltip: '북쪽 위로',
                            // 나침반 바늘이 지도의 북쪽을 가리킨다.
                            icon: Icons.navigation_rounded,
                            angle: _rotation * math.pi / 180,
                            onPressed: () => _map.rotate(0),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 지도 자료 출처(라이선스 조건) — 작게, 위쪽에(아래는 시트가 덮는다).
                  Positioned(
                    right: 8,
                    top: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: .8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          '© OpenStreetMap',
                          style: TextStyle(fontSize: 9, color: c.muted),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 밝은 화면: 채도를 15%로 낮추고 살짝 밝게(종이색 바탕과 어울리게).
const _lightTiles = <double>[
  0.3313, 0.6079, 0.0614, 0, 14, //
  0.1807, 0.7585, 0.0614, 0, 14, //
  0.1807, 0.6079, 0.2120, 0, 14, //
  0, 0, 0, 1, 0,
];

/// 어두운 화면: 뒤집고 채도를 낮추고 어둡게(잉크 바탕과 어울리게).
const _darkTiles = <double>[
  -0.2650, -0.4863, -0.0491, 0, 200, //
  -0.1446, -0.6068, -0.0491, 0, 200, //
  -0.1446, -0.4863, -0.1696, 0, 205, //
  0, 0, 0, 1, 0,
];

/// 대여소 표시. 강한 경보 = 꽉 찬 신호 원 + 숫자 + 퍼지는 고리, 경보 = 옅은 원 + 숫자,
/// 경보 없음 = 작은 회색 점(대여소 자리만 알려 준다).
class _StationPin extends StatelessWidget {
  const _StationPin({
    required this.station,
    required this.ping,
    this.showCount = false,
    this.selected = false,
  });

  final NearbyMapStation station;
  final Animation<double> ping;
  final bool showCount;

  /// 카드가 열린 대여소: 잉크 테두리 고리.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final pin = _pin(context);
    if (!selected) return pin;
    final ink = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (selected)
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surface.withValues(alpha: .7),
              border: Border.all(color: ink, width: 3),
            ),
          ),
        pin,
      ],
    );
  }

  Widget _pin(BuildContext context) {
    final c = context.ridey;
    final surface = Theme.of(context).colorScheme.surface;
    if (station.alertCount <= 0 && showCount) {
      // 탈 만한 자전거 수: 면 색 원 + 1px 선 + 잉크 숫자(0대면 흐리게). 실시간 대수가 없으면 '·'.
      final parked = station.parkedBikes;
      final empty = parked == 0;
      return Center(
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: surface,
            shape: BoxShape.circle,
            border: Border.all(color: empty ? c.line : c.muted, width: 1.5),
          ),
          child: Text(
            parked == null ? '·' : '$parked',
            style: context
                .rideyNumbers(const TextStyle())
                ?.copyWith(
                  fontSize: 11,
                  height: 1,
                  color: empty
                      ? c.muted
                      : Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ),
      );
    }
    if (station.alertCount <= 0) {
      // 대여소 자리: 흰 점 + 회색 테(지도 위에서 '여기 대여소' 만 알린다).
      return Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: surface,
            shape: BoxShape.circle,
            border: Border.all(color: c.muted, width: 2),
          ),
        ),
      );
    }
    final strong = station.isHighAlert;
    final size = strong ? 30.0 : 26.0;
    final disc = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: strong ? c.signal : c.signalSoft,
        shape: BoxShape.circle,
        border: Border.all(
          color: strong ? surface : c.signal,
          width: strong ? 2.5 : 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '${station.alertCount}',
        style: context
            .rideyNumbers(const TextStyle())
            ?.copyWith(
              fontSize: 12,
              height: 1,
              color: strong ? RideyColors.ink : c.signalText,
            ),
      ),
    );
    if (!strong) return Center(child: disc);
    return AnimatedBuilder(
      animation: ping,
      builder: (context, child) {
        final q = ping.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            if (q > 0 && q < 1)
              Container(
                width: size + q * 34,
                height: size + q * 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c.signal.withValues(alpha: (1 - q) * .6),
                    width: 2,
                  ),
                ),
              ),
            child!,
          ],
        );
      },
      child: disc,
    );
  }
}

/// 내 위치: 차분한 파랑 점(확인·사람 = 파랑)에 면 색 테와 옅은 후광.
class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.calm.withValues(alpha: .16),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: c.calm,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.surface,
              width: 3,
            ),
          ),
        ),
      ],
    );
  }
}

/// 지도 위 둥근 단추(내 위치·나침반): 확대 단추와 같은 면 색 + 1px 선.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.angle = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: c.line),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Transform.rotate(
          angle: angle,
          child: Icon(
            icon,
            size: 20,
            color: angle == 0
                ? Theme.of(context).colorScheme.onSurface
                : c.signal,
          ),
        ),
      ),
    );
  }
}

/// 확대·축소: 그림자 없이 면 색 + 1px 선의 세로 알약(어두운 화면에서도 맞춤).
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.onZoom});

  final ValueChanged<double> onZoom;

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    final ink = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '확대',
            onPressed: () => onZoom(1),
            icon: Icon(Icons.add, color: ink),
          ),
          Divider(height: 1, color: c.line),
          IconButton(
            tooltip: '축소',
            onPressed: () => onZoom(-1),
            icon: Icon(Icons.remove, color: ink),
          ),
        ],
      ),
    );
  }
}
