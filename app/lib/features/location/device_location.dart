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
    final position = await Geolocator.getCurrentPosition();
    return (latitude: position.latitude, longitude: position.longitude);
  } catch (_) {
    return null;
  }
}
