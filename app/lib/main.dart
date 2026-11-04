import 'package:flutter/widgets.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:ridey_app/config/ridey_config.dart';
import 'package:ridey_app/features/notifications/habit_notifier.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RideyConfig.loadLocalEnv();
  try {
    await Workmanager().initialize(habitNotificationDispatcher);
  } catch (_) {}
  runApp(const RideyApp(showIntro: true));
}
