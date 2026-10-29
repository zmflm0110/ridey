import 'dart:async';

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
  });

  final String id;
  final double latitude;
  final double longitude;
}

/// Rounded map of the user's area. Red dots are stations that have a suspect
/// bike. The blue pin is the device location. Without a Naver client id the
/// same frame explains where to put the key.
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
  NOverlayImage? _stationIcon;
  NOverlayImage? _userIcon;
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
    if (_stationIcon != null && _userIcon != null) return;
    if (!mounted) return;
    final stationIcon =
        _stationIcon ??
        await NOverlayImage.fromWidget(
          context: context,
          size: const Size(18, 18),
          widget: const _StationDot(),
        );
    if (!mounted) return;
    final userIcon =
        _userIcon ??
        await NOverlayImage.fromWidget(
          context: context,
          size: const Size(36, 36),
          widget: const Icon(
            Icons.location_on,
            color: Color(0xFF2F6BFF),
            size: 36,
          ),
        );
    _stationIcon = stationIcon;
    _userIcon = userIcon;
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
          size: const Size(36, 36),
        ),
      );
    }
    for (final station in widget.stations) {
      final marker = NMarker(
        id: station.id,
        position: NLatLng(station.latitude, station.longitude),
        icon: _stationIcon,
        size: const Size(18, 18),
        anchor: const NPoint(0.5, 0.5),
      );
      marker.setOnTapListener((_) => widget.onStationTap(station.id));
      markers.add(marker);
    }
    await controller.clearOverlays();
    if (markers.isNotEmpty) await controller.addOverlayAll(markers);
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

class _StationDot extends StatelessWidget {
  const _StationDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFF4F1F),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.onZoom});

  final ValueChanged<double> onZoom;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 44,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ZoomButton(
              tooltip: '확대',
              icon: Icons.add,
              onPressed: () => onZoom(1),
            ),
            Divider(height: 1, color: context.ridey.line),
            _ZoomButton(
              tooltip: '축소',
              icon: Icons.remove,
              onPressed: () => onZoom(-1),
            ),
          ],
        ),
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
      icon: Icon(icon, color: const Color(0xFF111317)),
    );
  }
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable();

  @override
  Widget build(BuildContext context) {
    final missingKey = RideyConfig.naverMapClientId.isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          missingKey
              ? '지도를 보려면 app/.env에 NAVER_MAP_CLIENT_ID를 넣어 주세요.'
              : '지도를 불러오지 못했어요. app/.env의 네이버 지도 키를 확인해 주세요.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.ridey.muted),
        ),
      ),
    );
  }
}
