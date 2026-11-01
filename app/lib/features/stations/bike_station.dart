class BikeStation {
  const BikeStation({
    required this.id,
    required this.name,
    required this.district,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String district;
  final double latitude;
  final double longitude;

  factory BikeStation.fromJson(Map<String, dynamic> json) {
    return BikeStation(
      id: json['id'] as String,
      name: (json['name'] as String? ?? '').trim(),
      district: json['gu'] as String? ?? '',
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
    );
  }
}
