import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:ridey_app/config/ridey_config.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/notifications/habit_notifier.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 세로 전용 앱(아이폰 Info.plist 와 같게). 가로에서는 첫 화면 로고와 숫자가 겹쳤다(에뮬레이터 확인).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await RideyConfig.loadLocalEnv();
  try {
    await Workmanager().initialize(habitNotificationDispatcher);
  } catch (_) {}
  // 시연용: --dart-define=RIDEY_DEMO_LOCATION=위도,경도 로 빌드하면 '내 위치' 가 그 자리로 고정된다(평소 빌드는 그대로).
  final demo = demoLocation(RideyConfig.demoLocation);
  runApp(
    RideyApp(
      showIntro: true,
      readLocation: demo == null ? null : () async => demo,
    ),
  );
}

/// '37.5061,126.8986' → 위치. 비었거나 형식이 틀리면 null(진짜 위치를 쓴다).
DeviceLocation? demoLocation(String raw) {
  final parts = raw.split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0].trim());
  final lon = double.tryParse(parts[1].trim());
  if (lat == null || lon == null) return null;
  return (latitude: lat, longitude: lon);
}
