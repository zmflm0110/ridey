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
