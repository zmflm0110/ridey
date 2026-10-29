import 'package:flutter/widgets.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:ridey_app/config/ridey_config.dart';
import 'package:ridey_app/features/notifications/habit_notifier.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RideyConfig.loadLocalEnv();
  if (RideyConfig.naverMapClientId.isNotEmpty) {
    try {
      await FlutterNaverMap().init(
        clientId: RideyConfig.naverMapClientId,
        onAuthFailed: (_) {},
      );
      RideyConfig.naverMapReady = true;
    } catch (_) {}
  }
  try {
    await Workmanager().initialize(habitNotificationDispatcher);
  } catch (_) {}
  runApp(const RideyApp());
}
