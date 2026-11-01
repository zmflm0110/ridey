import 'package:shared_preferences/shared_preferences.dart';

enum UserMode { rider, staff }

const userModeKey = 'user_mode';

UserMode? userModeFrom(String? raw) {
  return switch (raw) {
    'rider' => UserMode.rider,
    'staff' => UserMode.staff,
    _ => null,
  };
}

Future<UserMode?> readUserMode() async {
  final preferences = await SharedPreferences.getInstance();
  return userModeFrom(preferences.getString(userModeKey));
}

Future<void> writeUserMode(UserMode mode) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(userModeKey, mode.name);
}
