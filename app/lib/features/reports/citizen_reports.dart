import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ridey_app/config/ridey_config.dart';
import 'package:url_launcher/url_launcher.dart';

/// 서울시 공식 따릉이 고장 신고 화면(공단이 실제로 받는 곳).
final officialReportUri = Uri.parse(
  'https://www.bikeseoul.com/app/err/moveErrReportPage.do',
);

/// 자전거별 최근 72시간 시민 신고(RIDEY 앱에서 누른 것).
class ReportCount {
  const ReportCount({
    required this.bike,
    required this.count,
    this.lastAt,
    this.station,
  });

  final String bike;
  final int count;
  final DateTime? lastAt;
  final String? station;
}

abstract interface class CitizenReportRepository {
  /// 신고 한 줄을 남긴다(자전거 번호·대여소 번호만). 실패해도 공식 신고는 이어서 연다.
  Future<bool> submit({required String bike, String? station});

  Future<Map<String, ReportCount>> counts();
}

class SupabaseCitizenReportRepository implements CitizenReportRepository {
  SupabaseCitizenReportRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<bool> submit({required String bike, String? station}) async {
    try {
      final response = await _client
          .post(
            RideyConfig.rest('citizen_reports'),
            headers: {
              ...RideyConfig.apiHeaders,
              'Content-Type': 'application/json',
              'Prefer': 'return=minimal',
            },
            body: jsonEncode({'bike': bike, 'station': ?station}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, ReportCount>> counts() async {
    final response = await _client
        .get(
          RideyConfig.rest('report_counts?select=bike,n,last_at,station'),
          headers: RideyConfig.apiHeaders,
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return {};
    return {
      for (final row in decoded.whereType<Map>())
        if (row['bike'] is String)
          row['bike'] as String: ReportCount(
            bike: row['bike'] as String,
            count: (row['n'] as num?)?.toInt() ?? 0,
            lastAt: DateTime.tryParse('${row['last_at']}')?.toLocal(),
            station: row['station'] as String?,
          ),
    };
  }
}

class NoCitizenReports implements CitizenReportRepository {
  const NoCitizenReports();

  @override
  Future<bool> submit({required String bike, String? station}) async => false;

  @override
  Future<Map<String, ReportCount>> counts() async => const {};
}

/// 시민 신고: RIDEY 에 한 줄 남기고(직원 화면에 바로 보이게) 공식 신고 화면을 연다.
/// 공식 신고는 서울시 화면에서 이용자가 직접 마친다 — RIDEY 가 대신 보내지는 않는다.
Future<bool> reportBike({
  required String bike,
  String? station,
  CitizenReportRepository? repository,
  Future<bool> Function(Uri uri)? open,
}) async {
  final recorded = await (repository ?? SupabaseCitizenReportRepository())
      .submit(bike: bike, station: station);
  try {
    await (open ?? (uri) => launchUrl(uri, mode: LaunchMode.inAppBrowserView))(
      officialReportUri,
    );
  } catch (_) {}
  return recorded;
}
