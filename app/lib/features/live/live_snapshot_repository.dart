import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ridey_app/config/ridey_config.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LiveSnapshotRepository {
  Future<LiveSnapshot> fetch();
}

class SupabaseLiveSnapshotRepository implements LiveSnapshotRepository {
  SupabaseLiveSnapshotRepository({
    http.Client? client,
    LiveSnapshotCache cache = const LiveSnapshotCache(),
  }) : _client = client ?? http.Client(),
       _cache = cache;

  final http.Client _client;
  final LiveSnapshotCache _cache;

  /// Falls back to the last snapshot this phone received, marked offline, so
  /// a dropped connection shows dated alerts instead of an empty screen.
  @override
  Future<LiveSnapshot> fetch() async {
    try {
      final row = await _fetchRow();
      final snapshot = LiveSnapshot.fromRow(row);
      await _cache.save(row);
      return snapshot;
    } catch (_) {
      final cached = await _cache.load();
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<Map<String, dynamic>> _fetchRow() async {
    final response = await _client
        .get(RideyConfig.liveSnapshotUri, headers: RideyConfig.apiHeaders)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LiveSnapshotException(response.statusCode);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty || decoded.first is! Map) {
      throw const FormatException('실시간 목록이 비어 있습니다.');
    }
    return Map<String, dynamic>.from(decoded.first as Map);
  }
}

/// The last live row, kept only on this phone.
class LiveSnapshotCache {
  const LiveSnapshotCache();

  static const key = 'live_snapshot_last';

  Future<void> save(Map<String, dynamic> row) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, jsonEncode(row));
    } catch (_) {
      // A full or unavailable store only costs the offline fallback.
    }
  }

  Future<LiveSnapshot?> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw == null) return null;
      return LiveSnapshot.fromRow(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      ).asOffline();
    } catch (_) {
      return null;
    }
  }
}

class LiveSnapshotException implements Exception {
  const LiveSnapshotException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'LiveSnapshotException($statusCode)';
}
