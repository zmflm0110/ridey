import 'package:ridey_app/features/live/live_snapshot.dart';

String? normalizeBikeId(String value) {
  final match = RegExp(
    r'SPB\s*-?\s*(\d{3,6})',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) return null;
  return 'SPB-${match.group(1)!.padLeft(5, '0')}';
}

LiveBike? findBike(List<LiveBike> bikes, String value) {
  final bike = normalizeBikeId(value);
  if (bike == null) return null;
  for (final candidate in bikes) {
    if (candidate.bike == bike) return candidate;
  }
  return null;
}
