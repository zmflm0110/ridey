import 'package:shared_preferences/shared_preferences.dart';

enum AppPurpose {
  rider('이용자'),
  worker('업무');

  const AppPurpose(this.label);

  final String label;
}

abstract interface class AppPurposeStore {
  Future<AppPurpose?> load();
  Future<void> save(AppPurpose purpose);
}

class SharedPreferencesAppPurposeStore implements AppPurposeStore {
  static const _key = 'app_purpose';

  @override
  Future<AppPurpose?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_key);
    for (final purpose in AppPurpose.values) {
      if (purpose.name == value) return purpose;
    }
    return null;
  }

  @override
  Future<void> save(AppPurpose purpose) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, purpose.name);
  }
}
