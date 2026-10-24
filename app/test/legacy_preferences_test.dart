import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/app/legacy_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('removes the old purpose and field queue without other keys', () async {
    SharedPreferences.setMockInitialValues({
      'app_purpose': 'worker',
      'field_verification_queue': '[]',
      'my_stations': ['02720'],
    });

    await clearLegacyPreferences();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_purpose'), isNull);
    expect(preferences.getString('field_verification_queue'), isNull);
    expect(preferences.getStringList('my_stations'), ['02720']);
  });
}
