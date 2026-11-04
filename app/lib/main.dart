import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:ridey_app/config/ridey_config.dart';
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
  runApp(const RideyApp(showIntro: true));
}
