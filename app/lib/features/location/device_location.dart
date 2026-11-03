import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

typedef DeviceLocation = ({double latitude, double longitude});

Future<DeviceLocation?> readDeviceLocation() {
  return _readDeviceLocation().timeout(
    const Duration(seconds: 4),
    onTimeout: () => null,
  );
}

Future<DeviceLocation?> _readDeviceLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    // 안드로이드: 구글 '위치 정확도' 를 켜 달라는 창을 띄우지 않도록 기본 위치 서비스를 쓴다.
    final position = await Geolocator.getCurrentPosition(
      locationSettings: defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(forceLocationManager: true)
          : const LocationSettings(),
    );
    return (latitude: position.latitude, longitude: position.longitude);
  } catch (_) {
    return null;
  }
}

/// For background bookkeeping (lookup habits): never shows a dialog. Uses the
/// last known position only when the permission was already granted — a habit
/// is snapped to a ~500 m grid, so a fresh fix is not worth interrupting the
/// lookup result with a permission or Google location-accuracy dialog.
Future<DeviceLocation?> readDeviceLocationQuietly() async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return null;
    }
    final last = await Geolocator.getLastKnownPosition(
      forceAndroidLocationManager: true,
    );
    if (last == null) return null;
    return (latitude: last.latitude, longitude: last.longitude);
  } catch (_) {
    return null;
  }
}
