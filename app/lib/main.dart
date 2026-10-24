import 'package:flutter/widgets.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:ridey_app/features/notifications/habit_notifier.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Workmanager().initialize(habitNotificationDispatcher);
  } catch (_) {}
  runApp(const RideyApp());
}
