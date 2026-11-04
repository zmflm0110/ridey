import 'dart:io' show Platform;

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

/// The area map. Tiles are OpenStreetMap data drawn in CARTO's quiet styles
/// (Positron by day, Dark Matter at night) so the brand's signal dots stand
/// out: a filled orange disc with the number of suspect bikes for a strong
/// alert (it pings a few times), a soft disc for a 2-person chain, a small
/// grey dot for a station without alerts, and a calm-blue dot for the phone.
/// No key or sign-up — it works the same on iPhone and Android.
class NearbyMap extends StatefulWidget {
  const NearbyMap({
    super.key,
    required this.stations,
    required this.onStationTap,
    this.location,
    this.fullBleed = false,
  });

  /// 홈처럼 화면을 채울 때: 둥근 카드·테두리·고정 높이 없이 부모 크기를 그대로 쓴다.
  final bool fullBleed;

  final List<NearbyMapStation> stations;
  final DeviceLocation? location;
  final ValueChanged<String> onStationTap;

  /// 테스트에서는 지도 그림(타일)을 받지 않는다 — 네트워크가 막혀 있고 화면 확인에 필요 없다.
  static bool get _tilesEnabled {
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
  var _pinged = false;

  static const _seoul = LatLng(37.5665, 126.9780);

  LatLng get _center {
    final location = widget.location;
    if (location != null) return LatLng(location.latitude, location.longitude);
    final station = widget.stations.firstOrNull;
    if (station != null) return LatLng(station.latitude, station.longitude);
    return _seoul;
  }

  double get _zoom =>
      widget.location != null || widget.stations.isNotEmpty ? 15 : 12;

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
      _map.move(_center, 15);
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

    final map = FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: _zoom,
        minZoom: 10,
        maxZoom: 18,
        backgroundColor: dark ? const Color(0xFF1B1D21) : c.fill,
        interactionOptions: const InteractionOptions(
          flags:
              InteractiveFlag.drag |
              InteractiveFlag.pinchZoom |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.flingAnimation,
        ),
        onMapReady: () => _ready = true,
      ),
      children: [
        if (NearbyMap._tilesEnabled)
          TileLayer(
            urlTemplate: dark
                ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            retinaMode: RetinaMode.isHighDensity(context),
            userAgentPackageName: 'kr.bikedoctor.ridey',
            maxNativeZoom: 19,
          ),
        MarkerLayer(
          markers: [
            for (final s in ordered)
              Marker(
                point: LatLng(s.latitude, s.longitude),
                width: s.alertCount > 0 ? 64 : 14,
                height: s.alertCount > 0 ? 64 : 14,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onStationTap(s.id),
                  child: Semantics(
                    button: true,
                    label: s.alertCount > 0
                        ? '고장 의심 ${s.alertCount}대가 있는 대여소'
                        : '대여소',
                    child: _StationPin(station: s, ping: _ping),
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
                child: const _UserDot(),
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
          child: Stack(
            children: [
              Positioned.fill(child: map),
              Positioned(
                left: 12,
                top: 12,
                child: _ZoomControls(onZoom: _zoomBy),
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
                      '© OpenStreetMap © CARTO',
                      style: TextStyle(fontSize: 9, color: c.muted),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 대여소 표시. 강한 경보 = 꽉 찬 신호 원 + 숫자 + 퍼지는 고리, 경보 = 옅은 원 + 숫자,
/// 경보 없음 = 작은 회색 점(대여소 자리만 알려 준다).
class _StationPin extends StatelessWidget {
  const _StationPin({required this.station, required this.ping});

  final NearbyMapStation station;
  final Animation<double> ping;

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    final surface = Theme.of(context).colorScheme.surface;
    if (station.alertCount <= 0) {
      return Center(
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: c.muted.withValues(alpha: .55),
            shape: BoxShape.circle,
            border: Border.all(color: surface, width: 1.5),
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
