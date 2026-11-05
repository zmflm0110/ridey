import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// 대여소까지 걸어가는 길을 지도 앱으로 연다. 네이버 지도가 있으면 도보 길찾기,
/// 없으면 아이폰은 Apple 지도, 안드로이드는 Google 지도(웹이 열려도 길찾기가 된다).
/// 앱 안에서 길을 그리려면 경로 서버가 따로 필요해서, 이미 잘 하는 지도 앱에 맡긴다.
/// [from] 이 있으면 RIDEY 가 거리를 잰 그 '내 위치' 에서 출발한다(없으면 지도 앱이 현재 위치를 쓴다).
Future<void> openWalkingDirections({
  required double latitude,
  required double longitude,
  required String name,
  ({double latitude, double longitude})? from,
  Future<bool> Function(Uri uri, {LaunchMode mode})? launch,
  TargetPlatform? platform,
}) async {
  final go =
      launch ??
      (Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) =>
          launchUrl(uri, mode: mode);
  final place = Uri.encodeComponent(name.trim());
  final start = from == null
      ? ''
      : '&slat=${from.latitude}&slng=${from.longitude}'
            '&sname=${Uri.encodeComponent('내 위치')}';
  final naver = Uri.parse(
    'nmap://route/walk?dlat=$latitude&dlng=$longitude&dname=$place$start'
    '&appname=kr.bikedoctor.ridey',
  );
  try {
    if (await go(naver, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  final os = platform ?? defaultTargetPlatform;
  final fallback = os == TargetPlatform.iOS
      ? Uri.parse(
          'https://maps.apple.com/?daddr=$latitude,$longitude&dirflg=w&q=$place'
          '${from == null ? '' : '&saddr=${from.latitude},${from.longitude}'}',
        )
      : Uri.parse(
          'https://www.google.com/maps/dir/?api=1'
          '&destination=$latitude,$longitude&travelmode=walking'
          '${from == null ? '' : '&origin=${from.latitude},${from.longitude}'}',
        );
  try {
    await go(fallback, mode: LaunchMode.externalApplication);
  } catch (_) {}
}
