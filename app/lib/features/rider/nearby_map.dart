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

/// The map: OpenStreetMap's standard tiles (no key, Korean labels) seen
/// through a colour filter — near-grey by day, inverted and dark at night — so
/// the brand's signal markers stand out. It can hold every station in Seoul:
/// suspect stations are widgets (a filled orange disc with the count for a
/// strong alert, a soft disc otherwise), plain stations are cheap circles until
/// you zoom in on the station tab, where they become count discs. Numbers stay
/// upright when the map is rotated. Works the same on iPhone and Android.
class NearbyMap extends StatefulWidget {
  const NearbyMap({
    super.key,
    required this.stations,
    required this.onStationTap,
    this.location,
    this.focus,
    this.fullBleed = false,
    this.showCounts = false,
    this.focusMeters = 500,
    this.routePoints = const [],
    this.fitPoints,
    this.viewKey,
    this.favoriteIds = const {},
    this.stopNumbers = const {},
    this.controlsTop = 12,
  });

  /// 확대·내 위치 단추와 출처 표시의 위 여백(지도 위에 검색 칸이 떠 있으면 그 아래로).
  final double controlsTop;

  /// 처음 볼 곳(검색한 장소 등). 없으면 [location].
  final DeviceLocation? focus;

  /// 처음 켰을 때(와 '내 위치' 단추) [focus] 둘레로 보여 줄 범위(m).
  final double focusMeters;

  /// 경로 선(도로를 따라간 길 또는 들를 곳을 이은 직선). 비어 있으면 안 그린다.
  final List<LatLng> routePoints;

  /// 있으면 처음 모습을 이 점들이 다 보이게 맞춘다(직원의 들를 곳·담당 구).
  final List<LatLng>? fitPoints;

  /// 바뀌면 처음 모습을 다시 맞춘다(장소 검색·담당 구 바꾸기).
  final Object? viewKey;

  /// 즐겨찾는 대여소 — 별 고리로 따로 보인다.
  final Set<String> favoriteIds;

  /// 들를 순서 번호(대여소 id → 1부터). 핀 옆 파란 원.
  final Map<String, int> stopNumbers;

  /// '주변 대여소 현황' 일 때: 가까이 확대하면 대여소마다 탈 만한 자전거 수를 흰 원에 보여 준다.
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
  static bool get tilesEnabled {
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

/// 앱 지도 바탕(OpenStreetMap + 브랜드 색 필터). 직원 길안내 화면도 같이 쓴다.
Widget rideyTileLayer(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return TileLayer(
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
  );
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
  MapCamera? _camera;

  /// 지금 카드가 열려 있는 대여소 — 지도에서 어느 것을 보고 있는지 테두리로 보여 준다.
  String? _selected;

  static const _seoul = LatLng(37.5665, 126.9780);

  /// 이만큼 확대하면 '대여소 현황' 의 흰 원(탈 만한 자전거 수)을 그린다 — 멀리서 2천여 개를 다 그리면 무겁고 읽을 수도 없다.
  static const _countZoom = 14.5;

  Future<void> _tap(String id) async {
    setState(() => _selected = id);
    try {
      await widget.onStationTap(id);
    } finally {
      if (mounted && _selected == id) setState(() => _selected = null);
    }
  }

  /// 작은 점(위젯이 아닌 원)으로 그린 대여소는 지도 누름으로 찾는다 — 손가락 둘레 24px 안에서 가장 가까운 곳.
  void _tapMap(TapPosition position, LatLng _) {
    final at = position.relative;
    final camera = _camera;
    if (at == null || camera == null) return;
    NearbyMapStation? best;
    var bestD = 24.0;
    for (final s in widget.stations) {
      final p = camera.latLngToScreenOffset(LatLng(s.latitude, s.longitude));
      final d = (p - at).distance;
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    if (best != null) _tap(best.id);
  }

  DeviceLocation? get _focusPoint => widget.focus ?? widget.location;

  LatLng get _center {
    final f = _focusPoint;
    if (f != null) return LatLng(f.latitude, f.longitude);
    final station = widget.stations.where((s) => s.alertCount > 0).firstOrNull;
    if (station != null) return LatLng(station.latitude, station.longitude);
    return _seoul;
  }

  double get _zoom => _focusPoint != null ? 15 : 11;

  double _height = 0;

  EdgeInsets get _fitPadding => EdgeInsets.fromLTRB(
    20,
    widget.controlsTop + 52,
    20,
    widget.fullBleed ? _height * .52 + 16 : 20,
  );

  CameraFit _around(DeviceLocation here, double meters) {
    final dLat = meters / 111320;
    final dLon = meters / (111320 * math.cos(here.latitude * math.pi / 180));
    return CameraFit.bounds(
      bounds: LatLngBounds(
        LatLng(here.latitude - dLat, here.longitude - dLon),
        LatLng(here.latitude + dLat, here.longitude + dLon),
      ),
      padding: _fitPadding,
    );
  }

  /// 처음 맞출 범위: 정해 준 점들([NearbyMap.fitPoints]) → 볼 곳 둘레 500m → 서울의 고장 의심 전부.
  CameraFit? _initialFit() {
    final points = widget.fitPoints;
    if (points != null && points.length >= 2) {
      return CameraFit.coordinates(
        coordinates: points,
        padding: _fitPadding + const EdgeInsets.all(24),
        maxZoom: 16,
      );
    }
    if (points != null && points.length == 1) {
      return _around((
        latitude: points.first.latitude,
        longitude: points.first.longitude,
      ), widget.focusMeters);
    }
    final f = _focusPoint;
    if (f != null) return _around(f, widget.focusMeters);
    final alerts = [
      for (final s in widget.stations)
        if (s.alertCount > 0) LatLng(s.latitude, s.longitude),
    ];
    if (alerts.length > 1) {
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
    } else {
      _map.move(_center, _zoom);
    }
    _camera = _map.camera;
  }

  /// '내 위치' 단추: 검색한 곳이 있어도 내 자리로.
  void _focusMe() {
    final here = widget.location;
    if (!_ready || here == null) return;
    _map.fitCamera(_around(here, widget.focusMeters));
    setState(() => _camera = _map.camera);
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
    final viewChanged = old.viewKey != widget.viewKey;
    // 위치를 늦게 찾으면 그 자리로 옮긴다(따로 볼 곳을 고르지 않았을 때).
    final locationArrived =
        old.location == null && widget.location != null && widget.focus == null;
    if (_ready && (viewChanged || locationArrived)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_focus);
      });
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

  void _onEvent(MapEvent event) {
    final r = event.camera.rotation;
    final settled =
        event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventDoubleTapZoomEnd ||
        event is MapEventRotateEnd ||
        event is MapEventScrollWheelZoom ||
        event.source == MapEventSource.mapController ||
        event.source == MapEventSource.fitCamera;
    final rotated = (r - _rotation).abs() > .5;
    _camera = event.camera;
    if (settled || rotated) {
      setState(() => _rotation = r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = context.ridey;
    final surface = Theme.of(context).colorScheme.surface;
    final radius = widget.fullBleed ? 0.0 : 20.0;
    final camera = _camera;
    final zoom = camera?.zoom ?? _zoom;
    final view = camera?.visibleBounds;
    // 확대해서 보이는 곳만 흰 원(수)으로 — 나머지 대여소는 가벼운 점.
    final countsHere = widget.showCounts && zoom >= _countZoom && view != null;
    bool inView(NearbyMapStation s) =>
        view == null || view.contains(LatLng(s.latitude, s.longitude));

    final widgets = <NearbyMapStation>[];
    final dots = <NearbyMapStation>[];
    for (final s in widget.stations) {
      final asWidget =
          s.alertCount > 0 ||
          widget.favoriteIds.contains(s.id) ||
          widget.stopNumbers.containsKey(s.id) ||
          s.id == _selected ||
          (countsHere && inView(s));
      (asWidget ? widgets : dots).add(s);
    }
    // 경보가 없는 대여소를 먼저, 강한 경보를 위에, 누른 대여소를 맨 위에 그린다.
    int rank(NearbyMapStation s) => s.id == _selected
        ? 3
        : s.alertCount <= 0
        ? 0
        : (s.isHighAlert ? 2 : 1);
    widgets.sort((a, b) => rank(a).compareTo(rank(b)));
    final here = widget.location;
    final dotRadius = zoom < 12 ? 2.5 : (zoom < 14 ? 4.0 : 5.5);

    Widget buildMap() => FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: _zoom,
        // 처음 모습은 지도를 만들 때 정한다(다 만든 뒤 옮기면 첫 타일을 못 받는 경우가 있었다).
        initialCameraFit: _initialFit(),
        minZoom: 9,
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
        onMapEvent: _onEvent,
        onTap: _tapMap,
        onMapReady: () {
          _ready = true;
          _camera = _map.camera;
          if (_initialFit() == null) _focus();
          if (mounted) setState(() {});
        },
      ),
      children: [
        if (NearbyMap.tilesEnabled) rideyTileLayer(context),
        if (widget.routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePoints,
                color: c.calm,
                strokeWidth: 4,
                borderColor: surface,
                borderStrokeWidth: 1.5,
              ),
            ],
          ),
        // 경보 없는 대여소: 흰 점 + 회색 테(가벼운 원 — 서울 전체 2천여 곳을 그려도 버벅이지 않게).
        CircleLayer(
          circles: [
            for (final s in dots)
              CircleMarker(
                point: LatLng(s.latitude, s.longitude),
                radius: dotRadius,
                color: surface,
                borderColor: c.muted,
                borderStrokeWidth: zoom < 12 ? 1 : 2,
              ),
          ],
        ),
        MarkerLayer(
          // 지도를 돌려도 숫자는 똑바로 선다(지도 앱의 글자처럼).
          rotate: true,
          markers: [
            for (final s in widgets)
              Marker(
                point: LatLng(s.latitude, s.longitude),
                width: 64,
                height: 64,
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
                      showCount: widget.showCounts && countsHere,
                      selected: _selected == s.id,
                      favorite: widget.favoriteIds.contains(s.id),
                      stop: widget.stopNumbers[s.id],
                    ),
                  ),
                ),
              ),
            if (here != null)
              Marker(
                point: LatLng(here.latitude, here.longitude),
                width: 44,
                height: 44,
                // 내 위치 점은 누르는 것이 아니다 — 바로 옆 대여소를 누를 때 가로막지 않게.
                child: const IgnorePointer(child: _UserDot()),
              ),
            if (widget.focus != null &&
                (here == null ||
                    widget.focus!.latitude != here.latitude ||
                    widget.focus!.longitude != here.longitude))
              Marker(
                point: LatLng(widget.focus!.latitude, widget.focus!.longitude),
                width: 36,
                height: 36,
                alignment: Alignment.topCenter,
                child: IgnorePointer(
                  child: Icon(Icons.place_rounded, size: 36, color: c.calm),
                ),
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
                    top: widget.controlsTop,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ZoomControls(onZoom: _zoomBy),
                        if (here != null) ...[
                          const SizedBox(height: 8),
                          _RoundButton(
                            tooltip: '내 위치',
                            icon: Icons.my_location_rounded,
                            onPressed: _focusMe,
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
                    top: widget.controlsTop - 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: surface.withValues(alpha: .8),
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
    this.favorite = false,
    this.stop,
  });

  final NearbyMapStation station;
  final Animation<double> ping;
  final bool showCount;

  /// 카드가 열린 대여소: 잉크 테두리 고리.
  final bool selected;

  /// 즐겨찾는 대여소: 파란 고리.
  final bool favorite;

  /// 들를 순서 번호(1부터): 오른쪽 위 파란 원.
  final int? stop;

  @override
  Widget build(BuildContext context) {
    final pin = _pin(context);
    if (!selected && !favorite && stop == null) return pin;
    final ink = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (selected || favorite)
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surface.withValues(alpha: .7),
              border: Border.all(
                color: selected ? ink : context.ridey.calm,
                width: 3,
              ),
            ),
          ),
        pin,
        if (stop != null)
          Align(
            alignment: const Alignment(.62, -.62),
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.ridey.calm,
                shape: BoxShape.circle,
                border: Border.all(color: surface, width: 1.5),
              ),
              child: Text(
                '$stop',
                style: context
                    .rideyNumbers(const TextStyle())
                    ?.copyWith(fontSize: 10, height: 1, color: Colors.white),
              ),
            ),
          ),
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
