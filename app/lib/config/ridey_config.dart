/// Public Supabase settings. Override with --dart-define at build time.
abstract final class RideyConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://iqvquwvoljzuvdgtbpnu.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_YFBKlBvyPFAhBpLdS3o8_A_xIeUmTVE',
  );

  static const apiHeaders = {'apikey': publishableKey};

  static Uri rest(String resource) =>
      Uri.parse('$supabaseUrl/rest/v1/$resource');

  static Uri get liveSnapshotUri => rest('live_snapshot?select=at,body');

  static Uri get rescueUri => rest('rescue');

  static Uri get checkedUri => rest('checked?select=bike,verdict,n');
}
