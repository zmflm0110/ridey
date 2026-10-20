import 'dart:convert';

class LiveSnapshot {
  const LiveSnapshot({
    required this.updatedAt,
    required this.date,
    required this.bikes,
    required this.feed,
  });

  final DateTime updatedAt;
  final String date;
  final List<LiveBike> bikes;
  final FeedHealth feed;

  factory LiveSnapshot.fromRow(Map<String, dynamic> row) {
    final body = _body(row['body']);
    final at = row['at'] ?? body['at'];
    if (at is! String) {
      throw const FormatException('실시간 목록의 갱신 시각이 없습니다.');
    }

    final rawBikes = body['bikes'];
    if (rawBikes is! List) {
      throw const FormatException('실시간 목록의 자전거 형식이 올바르지 않습니다.');
    }

    return LiveSnapshot(
      updatedAt: DateTime.parse(at).toLocal(),
      date: body['date'] as String? ?? '',
      bikes: rawBikes
          .whereType<Map>()
          .map((bike) => LiveBike.fromJson(Map<String, dynamic>.from(bike)))
          .toList(growable: false),
      feed: FeedHealth.fromJson(_map(body['feed'])),
    );
  }

  static Map<String, dynamic> _body(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw const FormatException('실시간 목록을 읽을 수 없습니다.');
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};
}

class LiveBike {
  const LiveBike({
    required this.bike,
    required this.station,
    required this.stationName,
    required this.chain,
    required this.isHighAlert,
    required this.lastDud,
    required this.probability,
  });

  final String bike;
  final String station;
  final String stationName;
  final int chain;
  final bool isHighAlert;
  final String lastDud;
  final int? probability;

  factory LiveBike.fromJson(Map<String, dynamic> json) {
    return LiveBike(
      bike: json['bike'] as String? ?? '',
      station: json['station'] as String? ?? '',
      stationName: (json['station_name'] as String? ?? '').trim(),
      chain: (json['chain'] as num?)?.toInt() ?? 0,
      isHighAlert: json['level'] == '빨강',
      lastDud: json['last_dud'] as String? ?? '',
      probability: (json['p_next'] as num?)?.toInt(),
    );
  }
}

class FeedHealth {
  const FeedHealth({required this.isHealthy, this.since, this.ratio});

  final bool isHealthy;
  final String? since;
  final double? ratio;

  factory FeedHealth.fromJson(Map<String, dynamic> json) {
    return FeedHealth(
      isHealthy: json['ok'] as bool? ?? true,
      since: json['since'] as String?,
      ratio: (json['ratio'] as num?)?.toDouble(),
    );
  }
}
