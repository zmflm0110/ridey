import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/config/ridey_config.dart';

void main() {
  test('points at the public project when no dart-define is set', () {
    expect(RideyConfig.supabaseUrl, 'https://iqvquwvoljzuvdgtbpnu.supabase.co');
    expect(
      RideyConfig.publishableKey,
      'sb_publishable_YFBKlBvyPFAhBpLdS3o8_A_xIeUmTVE',
    );
    expect(RideyConfig.apiHeaders['apikey'], RideyConfig.publishableKey);
    expect(
      RideyConfig.liveSnapshotUri.toString(),
      '${RideyConfig.supabaseUrl}/rest/v1/live_snapshot?select=at,body',
    );
  });

  test('bundles the naver env file for the map key', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString('.env');
    expect(raw, contains('NAVER_MAP_CLIENT_ID'));
  });

  test('reads the naver map client id from an env file', () {
    expect(naverMapClientIdFromEnv(''), '');
    expect(
      naverMapClientIdFromEnv('''
# comment
NAVER_MAP_CLIENT_ID=
OTHER=nope
'''),
      '',
    );
    expect(
      naverMapClientIdFromEnv('NAVER_MAP_CLIENT_ID="map-client"\n'),
      'map-client',
    );
  });
}
