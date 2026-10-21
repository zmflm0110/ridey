import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ridey_app/features/field/field_verdict.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class FieldVerificationRemote {
  Future<void> record(FieldVerificationRecord record);
  Future<CheckedVerdicts> fetchChecked();
}

abstract interface class FieldVerificationQueue {
  Future<List<FieldVerificationRecord>> load();
  Future<void> save(List<FieldVerificationRecord> records);
}

class SharedPreferencesFieldVerificationQueue
    implements FieldVerificationQueue {
  static const _key = 'field_verification_queue';

  @override
  Future<List<FieldVerificationRecord>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_key);
    if (value == null) return const [];

    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => FieldVerificationRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> save(List<FieldVerificationRecord> records) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }
}

class FieldVerificationRepository {
  FieldVerificationRepository({
    FieldVerificationRemote? remote,
    FieldVerificationQueue? queue,
  }) : _remote = remote ?? SupabaseFieldVerificationRemote(),
       _queue = queue ?? SharedPreferencesFieldVerificationQueue();

  final FieldVerificationRemote _remote;
  final FieldVerificationQueue _queue;

  Future<int> pendingCount() async => (await _queue.load()).length;

  Future<List<FieldVerificationRecord>> pendingRecords() => _queue.load();

  Future<VerificationSubmission> submit(FieldVerificationRecord record) async {
    if (!_isValidRecord(record)) {
      return const VerificationSubmission(
        VerificationSubmissionStatus.rejected,
      );
    }

    try {
      await _remote.record(record);
      return VerificationSubmission(
        VerificationSubmissionStatus.sent,
        pendingCount: await pendingCount(),
      );
    } on FieldVerificationRejectedException {
      return const VerificationSubmission(
        VerificationSubmissionStatus.rejected,
      );
    } catch (_) {
      final queued = await _queue.load();
      await _queue.save([...queued, record]);
      return VerificationSubmission(
        VerificationSubmissionStatus.queued,
        pendingCount: queued.length + 1,
      );
    }
  }

  Future<VerificationSyncResult> sync() async {
    final queued = await _queue.load();
    var sent = 0;
    var rejected = 0;
    final remaining = <FieldVerificationRecord>[];

    for (final record in queued) {
      if (!_isValidRecord(record)) {
        rejected++;
        continue;
      }
      try {
        await _remote.record(record);
        sent++;
      } on FieldVerificationRejectedException {
        rejected++;
      } catch (_) {
        remaining.add(record);
      }
    }

    await _queue.save(remaining);
    return VerificationSyncResult(
      sent: sent,
      rejected: rejected,
      pending: remaining.length,
    );
  }

  Future<CheckedVerdicts> fetchChecked() => _remote.fetchChecked();

  static bool _isValidRecord(FieldVerificationRecord record) {
    return RegExp(r'^SPB-\d{5,6}$').hasMatch(record.bikeId) &&
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(record.day);
  }
}

class SupabaseFieldVerificationRemote implements FieldVerificationRemote {
  SupabaseFieldVerificationRemote({http.Client? client})
    : _client = client ?? http.Client();

  static const _baseUrl = 'https://iqvquwvoljzuvdgtbpnu.supabase.co';
  static const _publishableKey =
      'sb_publishable_YFBKlBvyPFAhBpLdS3o8_A_xIeUmTVE';

  final http.Client _client;

  @override
  Future<void> record(FieldVerificationRecord record) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/rest/v1/rescue'),
          headers: const {
            'apikey': _publishableKey,
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          },
          body: jsonEncode(record.toJson()),
        )
        .timeout(const Duration(seconds: 12));
    _throwForStatus(response.statusCode);
  }

  @override
  Future<CheckedVerdicts> fetchChecked() async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/rest/v1/checked?select=bike,verdict,n'),
          headers: const {'apikey': _publishableKey},
        )
        .timeout(const Duration(seconds: 12));
    _throwForStatus(response.statusCode);

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('현장 확인 집계 형식이 올바르지 않습니다.');
    }

    final result = <String, Map<FieldVerdict, int>>{};
    for (final item in decoded.whereType<Map>()) {
      final row = Map<String, dynamic>.from(item);
      final bike = row['bike'];
      final verdict = row['verdict'];
      final count = row['n'];
      if (bike is! String || verdict is! String || count is! num) continue;
      final parsedVerdict = FieldVerdict.fromApiValue(verdict);
      if (parsedVerdict == null) continue;
      result.putIfAbsent(bike, () => {})[parsedVerdict] = count.toInt();
    }
    return result;
  }

  void _throwForStatus(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return;
    if (const {400, 409, 413, 415, 422}.contains(statusCode)) {
      throw FieldVerificationRejectedException(statusCode);
    }
    throw FieldVerificationRemoteException(statusCode);
  }
}

class FieldVerificationRejectedException implements Exception {
  const FieldVerificationRejectedException(this.statusCode);

  final int statusCode;
}

class FieldVerificationRemoteException implements Exception {
  const FieldVerificationRemoteException(this.statusCode);

  final int statusCode;
}
