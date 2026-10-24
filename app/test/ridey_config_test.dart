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
    expect(
      RideyConfig.rescueUri.toString(),
      '${RideyConfig.supabaseUrl}/rest/v1/rescue',
    );
    expect(
      RideyConfig.checkedUri.toString(),
      '${RideyConfig.supabaseUrl}/rest/v1/checked?select=bike,verdict,n',
    );
  });
}
