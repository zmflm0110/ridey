import 'package:flutter/services.dart';

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

  /// `--dart-define=NAVER_MAP_CLIENT_ID=...` wins over [loadLocalEnv].
  static const naverMapClientIdFromDefine = String.fromEnvironment(
    'NAVER_MAP_CLIENT_ID',
  );

  static String naverMapClientId = naverMapClientIdFromDefine;

  /// True after [FlutterNaverMap.init] succeeds. Widget tests leave this false.
  static var naverMapReady = false;

  static Future<void> loadLocalEnv() async {
    if (naverMapClientId.isNotEmpty) return;
    try {
      final raw = await rootBundle.loadString('.env');
      naverMapClientId = naverMapClientIdFromEnv(raw);
    } catch (_) {}
  }
}

/// Reads `NAVER_MAP_CLIENT_ID` from a `.env` file. Empty when the key is absent.
String naverMapClientIdFromEnv(String raw) {
  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final index = trimmed.indexOf('=');
    if (index <= 0) continue;
    if (trimmed.substring(0, index).trim() != 'NAVER_MAP_CLIENT_ID') continue;
    var value = trimmed.substring(index + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    return value;
  }
  return '';
}
