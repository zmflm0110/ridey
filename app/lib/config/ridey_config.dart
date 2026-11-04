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

  /// 시연 영상·발표용 고정 위치('위도,경도'). 비어 있으면 진짜 위치.
  static const demoLocation = String.fromEnvironment('RIDEY_DEMO_LOCATION');

  static Uri rest(String resource) =>
      Uri.parse('$supabaseUrl/rest/v1/$resource');

  static Uri get liveSnapshotUri => rest('live_snapshot?select=at,body');

  static Uri get liveStationStatusUri =>
      rest('live_station_status?select=id,name,bikes,racks,lat,lon,at');

  static Uri get opsListDaysUri =>
      rest('ops_lists?select=day&order=day.desc&limit=14');

  static Uri get opsScoresUri => rest(
    'ops_scores?select=day,listed,rode,first_dud&order=day.desc&limit=7',
  );

  static Uri opsListDayUri(String day) =>
      rest('ops_lists?select=body&day=eq.$day');
}
