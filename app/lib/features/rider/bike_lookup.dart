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

/// 카메라 글자 인식은 번호판 가장자리의 일부 숫자('SPB-123')를 먼저 읽을 수 있다.
/// 짧은 번호를 0 으로 채우면 다른 자전거가 되므로, 숫자가 5자리 이상일 때만 받는다.
String? bikeIdFromRecognizedText(String text) {
  final match = RegExp(
    r'SPB\s*-?\s*\d{5,6}(?!\d)',
    caseSensitive: false,
  ).firstMatch(text);
  return match == null ? null : normalizeBikeId(match.group(0)!);
}
