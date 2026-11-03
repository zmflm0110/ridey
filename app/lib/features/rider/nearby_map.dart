import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:ridey_app/config/ridey_config.dart';
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

/// Rounded map of the user's area. Signal dots are stations with an alert bike
/// (filled = strong, soft = 2 people). The calm-blue dot is the device
/// location. Without a Naver client id the same frame explains where to put
/// the key.
class NearbyMap extends StatefulWidget {
  const NearbyMap({
    super.key,
    required this.stations,
    required this.onStationTap,
    this.location,
  });

  final List<NearbyMapStation> stations;
  final DeviceLocation? location;
  final ValueChanged<String> onStationTap;

  @override
  State<NearbyMap> createState() => _NearbyMapState();
}

class _NearbyMapState extends State<NearbyMap> {
  NaverMapController? _controller;
  final _countIcons = <String, NOverlayImage>{};
  NOverlayImage? _userIcon;
  Brightness? _iconBrightness;
  var _syncing = 0;

  NCameraPosition get _camera {
    final location = widget.location;
    if (location != null) {
      return NCameraPosition(
        target: NLatLng(location.latitude, location.longitude),
        zoom: 15,
      );
    }
    final station = widget.stations.firstOrNull;
    if (station != null) {
      return NCameraPosition(
        target: NLatLng(station.latitude, station.longitude),
        zoom: 14,
      );
    }
    return NaverMapViewOptions.seoulCityHall;
  }

  @override
  void didUpdateWidget(NearbyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller != null) unawaited(_syncMarkers());
  }

  Future<void> _ensureIcons() async {
    final brightness = Theme.of(context).brightness;
    if (_iconBrightness == brightness && _userIcon != null) return;
    Future<NOverlayImage> draw(Widget widget, double size) =>
        NOverlayImage.fromWidget(
          context: context,
          size: Size.square(size),
          widget: widget,
        );
    final user = await draw(const _UserDot(), 22);
    if (!mounted) return;
    _userIcon = user;
    _iconBrightness = brightness;
    _countIcons.clear();
  }

  Future<void> _syncMarkers() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final generation = ++_syncing;
    await _ensureIcons();
    if (!mounted || generation != _syncing || _controller != controller) return;

    final markers = <NMarker>{};
    final location = widget.location;
    if (location != null && _userIcon != null) {
      markers.add(
        NMarker(
          id: 'ridey-user',
          position: NLatLng(location.latitude, location.longitude),
          icon: _userIcon,
          size: const Size(22, 22),
          anchor: const NPoint(0.5, 0.5),
        ),
      );
    }
    for (final station in widget.stations) {
      final icon = await _stationIcon(station);
      if (!mounted || generation != _syncing || _controller != controller) {
        return;
      }
      final marker = NMarker(
        id: station.id,
        position: NLatLng(station.latitude, station.longitude),
        icon: icon,
        size: const Size(28, 28),
        anchor: const NPoint(0.5, 0.5),
      );
      marker.setOnTapListener((_) => widget.onStationTap(station.id));
      markers.add(marker);
    }
    await controller.clearOverlays();
    if (markers.isNotEmpty) await controller.addOverlayAll(markers);
    await _fitStations();
  }

  Future<void> _fitStations() async {
    final controller = _controller;
    if (controller == null || widget.location != null) return;
    final stations = widget.stations;
    if (stations.isEmpty) return;
    if (stations.length == 1) {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(stations.first.latitude, stations.first.longitude),
          zoom: 14,
        ),
      );
      return;
    }
    var south = stations.first.latitude;
    var north = south;
    var west = stations.first.longitude;
    var east = west;
    for (final station in stations.skip(1)) {
      south = math.min(south, station.latitude);
      north = math.max(north, station.latitude);
      west = math.min(west, station.longitude);
      east = math.max(east, station.longitude);
    }
    await controller.updateCamera(
      NCameraUpdate.fitBounds(
        NLatLngBounds(
          southWest: NLatLng(south, west),
          northEast: NLatLng(north, east),
        ),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  Future<NOverlayImage> _stationIcon(NearbyMapStation station) async {
    final key =
        '${station.parkedBikes ?? 'x'}-${station.alertCount}-${station.isHighAlert}';
    final cached = _countIcons[key];
    if (cached != null) return cached;
    final image = await NOverlayImage.fromWidget(
      context: context,
      size: const Size.square(28),
      widget: _StationCountDot(
        count: station.parkedBikes,
        alert: station.alertCount > 0,
        strong: station.isHighAlert,
      ),
    );
    _countIcons[key] = image;
    return image;
  }

  void _zoom(double delta) {
    final controller = _controller;
    if (controller == null) return;
    unawaited(controller.updateCamera(NCameraUpdate.zoomBy(delta)));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.ridey.fill,
          border: Border.all(color: context.ridey.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SizedBox(
          height: 312,
          child: RideyConfig.naverMapReady
              ? Stack(
                  children: [
                    NaverMap(
                      forceGesture: true,
                      options: NaverMapViewOptions(
                        initialCameraPosition: _camera,
                        indoorEnable: false,
                        scaleBarEnable: false,
                        locationButtonEnable: false,
                        indoorLevelPickerEnable: false,
                        tiltGesturesEnable: false,
                        rotationGesturesEnable: false,
                        logoAlign: NLogoAlign.rightBottom,
                        logoClickEnable: false,
                      ),
                      onMapReady: (controller) {
                        _controller = controller;
                        unawaited(_syncMarkers());
                      },
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _ZoomControls(onZoom: _zoom),
                    ),
                  ],
                )
              : const _MapUnavailable(),
        ),
      ),
    );
  }
}

/// 거치 대수를 그린 점. 고장 의심이 있으면 신호색, 없으면 차분한 파랑.
class _StationCountDot extends StatelessWidget {
  const _StationCountDot({
    required this.count,
    required this.alert,
    required this.strong,
  });

  final int? count;
  final bool alert;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    final fill = !alert
        ? c.calm
        : strong
        ? c.signal
        : c.signalSoft;
    final ink = !alert
        ? Colors.white
        : strong
        ? RideyColors.ink
        : c.signalText;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          count == null ? '·' : '$count',
          style: TextStyle(
            color: ink,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// 내 위치: 차분한 파랑 점(확인·사람 = 파랑)에 면 색 테.
class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.ridey.calm,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 3,
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
          _ZoomButton(
            tooltip: '확대',
            icon: Icons.add,
            onPressed: () => onZoom(1),
          ),
          Divider(height: 1, color: c.line),
          _ZoomButton(
            tooltip: '축소',
            icon: Icons.remove,
            onPressed: () => onZoom(-1),
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
    );
  }
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable();

  @override
  Widget build(BuildContext context) {
    final missingKey = RideyConfig.naverMapClientId.isEmpty;
    // 설정 안내(app/.env)는 개발자에게만. 설치한 앱을 쓰는 사람에게는 무엇을 대신 볼 수 있는지만 말한다.
    final message = !kReleaseMode
        ? (missingKey
              ? '지도를 보려면 app/.env에 NAVER_MAP_CLIENT_ID를 넣어 주세요.'
              : '지도를 불러오지 못했어요. app/.env의 네이버 지도 키를 확인해 주세요.')
        : '지금은 지도를 불러오지 못했어요.\n아래 목록에서 가까운 경보를 볼 수 있어요.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.ridey.muted),
        ),
      ),
    );
  }
}
