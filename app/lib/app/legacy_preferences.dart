import 'package:shared_preferences/shared_preferences.dart';

/// Keys written by the old purpose switch and field-check queue.
const legacyPreferenceKeys = <String>[
  'app_purpose',
  'field_verification_queue',
];

Future<void> clearLegacyPreferences() async {
  final preferences = await SharedPreferences.getInstance();
  for (final key in legacyPreferenceKeys) {
    await preferences.remove(key);
  }
}
