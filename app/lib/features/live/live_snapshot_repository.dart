import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ridey_app/features/live/live_snapshot.dart';

abstract interface class LiveSnapshotRepository {
  Future<LiveSnapshot> fetch();
}

class SupabaseLiveSnapshotRepository implements LiveSnapshotRepository {
  SupabaseLiveSnapshotRepository({http.Client? client})
    : _client = client ?? http.Client();

  static final _uri = Uri.parse(
    'https://iqvquwvoljzuvdgtbpnu.supabase.co/rest/v1/live_snapshot'
    '?select=at,body',
  );

  static const _publishableKey =
      'sb_publishable_YFBKlBvyPFAhBpLdS3o8_A_xIeUmTVE';

  final http.Client _client;

  @override
  Future<LiveSnapshot> fetch() async {
    final response = await _client
        .get(_uri, headers: const {'apikey': _publishableKey})
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LiveSnapshotException(response.statusCode);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty || decoded.first is! Map) {
      throw const FormatException('실시간 목록이 비어 있습니다.');
    }
    return LiveSnapshot.fromRow(
      Map<String, dynamic>.from(decoded.first as Map),
    );
  }
}

class LiveSnapshotException implements Exception {
  const LiveSnapshotException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'LiveSnapshotException($statusCode)';
}
