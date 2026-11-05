import 'dart:convert';

import 'package:ridey_app/features/live/live_snapshot.dart';

/// 따릉이 번호표 QR 의 내용: 'SPB-00072627' 을 base64 로 바꾼 뒤, 글자판을 섞은 것.
/// 섞인 글자판은 대문자·소문자·숫자를 차례로(A a 0 B b 1 … J j 9), 숫자가 끝나면 대문자·소문자(K k … Z z)를
/// 놓고, 이것이 표준 base64 글자판(A–Z a–z 0–9)의 같은 자리에 대응한다.
/// 실제 번호표 5장으로 확인(예: 6va03gATEBjUem2w → SPB-00072627).
const _qrAlphabet =
    'Aa0Bb1Cc2Dd3Ee4Ff5Gg6Hh7Ii8Jj9KkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz';
const _base64Alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// 번호표 QR 을 풀어 자전거 번호로. 따릉이 QR 이 아니면 null.
String? bikeIdFromQr(String raw) {
  final text = raw.trim();
  if (text.isEmpty || text.length % 4 != 0) return null;
  final std = StringBuffer();
  for (final ch in text.split('')) {
    final i = _qrAlphabet.indexOf(ch);
    if (i < 0) return null;
    std.write(_base64Alphabet[i]);
  }
  final String decoded;
  try {
    decoded = String.fromCharCodes(base64.decode(std.toString()));
  } on FormatException {
    return null;
  }
  final match = RegExp(r'^SPB-(\d{4,10})$').firstMatch(decoded);
  if (match == null) return null;
  final number = int.parse(match.group(1)!);
  if (number <= 0 || number > 999999) return null;
  return 'SPB-${number.toString().padLeft(5, '0')}';
}

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
