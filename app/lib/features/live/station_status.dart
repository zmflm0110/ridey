class StationOccupancy {
  const StationOccupancy({
    required this.id,
    required this.name,
    required this.bikes,
    required this.racks,
    this.latitude,
    this.longitude,
    this.updatedAt,
  });

  final String id;
  final String name;
  final int bikes;
  final int racks;
  final double? latitude;
  final double? longitude;
  final DateTime? updatedAt;

  factory StationOccupancy.fromJson(Map<String, dynamic> json) {
    return StationOccupancy(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String? ?? '').trim(),
      bikes: (json['bikes'] as num?)?.toInt() ?? 0,
      racks: (json['racks'] as num?)?.toInt() ?? 0,
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lon'] as num?)?.toDouble(),
      updatedAt: _time(json['at']),
    );
  }

  static DateTime? _time(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}

/// bikeList 이름 `102. 망원역 1번출구 앞` → `00102`. 숫자가 없으면 null.
String? stationIdFromBikeListName(String name) {
  final match = RegExp(r'^(\d+)').firstMatch(name.trim());
  if (match == null) return null;
  return match.group(1)!.padLeft(5, '0');
}
