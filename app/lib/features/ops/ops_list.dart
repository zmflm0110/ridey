import 'package:ridey_app/features/live/live_snapshot.dart';

class OpsList {
  const OpsList({required this.day, required this.bikes});

  final String day;
  final List<LiveBike> bikes;

  factory OpsList.fromRow(String day, Map<String, dynamic> row) {
    final body = _body(row['body']);
    final rawBikes = body['bikes'];
    if (rawBikes is! List) {
      throw const FormatException('아침 목록의 자전거 형식이 올바르지 않습니다.');
    }
    return OpsList(
      day: _dayText(body['date']) ?? day,
      bikes: rawBikes
          .whereType<Map>()
          .map((bike) => LiveBike.fromJson(Map<String, dynamic>.from(bike)))
          .toList(growable: false),
    );
  }

  static String? _dayText(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return value.length >= 10 ? value.substring(0, 10) : value;
  }

  static Map<String, dynamic> _body(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('아침 목록을 읽을 수 없습니다.');
  }
}

String opsListDay(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value.length >= 10 ? value.substring(0, 10) : value;
  }
  return '';
}

/// 아침 목록 채점 한 날치(공개 뷰 ops_scores): 그날 07:00 목록 [listed]대 중 다음 사람이 탄 [rode]대,
/// 그중 그 사람도 바로 반납한(또 헛대여) [firstDud]대. 매일 06:10 에 DB 가 어제 것을 스스로 채점한다.
class OpsScore {
  const OpsScore({
    required this.day,
    required this.listed,
    required this.rode,
    required this.firstDud,
  });

  final String day;
  final int listed;
  final int rode;
  final int firstDud;

  /// 다음 사람도 헛대여한 비율(0~1). 아무도 안 탔으면 null.
  double? get hitRate => rode == 0 ? null : firstDud / rode;

  static OpsScore? fromRow(Map<String, dynamic> row) {
    final day = opsListDay(row['day']);
    int? n(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
    final listed = n(row['listed']), rode = n(row['rode']);
    final dud = n(row['first_dud']);
    if (day.isEmpty || listed == null || rode == null || dud == null) {
      return null;
    }
    return OpsScore(day: day, listed: listed, rode: rode, firstDud: dud);
  }
}

/// 여러 날을 합친 적중률(날마다 평균이 아니라 대수로 합침). 탄 자전거가 없으면 null.
double? pooledHitRate(Iterable<OpsScore> scores) {
  var rode = 0, dud = 0;
  for (final s in scores) {
    rode += s.rode;
    dud += s.firstDud;
  }
  return rode == 0 ? null : dud / rode;
}
