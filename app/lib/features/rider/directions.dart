import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// 대여소까지 걸어가는 길을 지도 앱으로 연다. 네이버 지도가 있으면 도보 길찾기,
/// 없으면 아이폰은 Apple 지도, 안드로이드는 Google 지도(웹이 열려도 길찾기가 된다).
/// 앱 안에서 길을 그리려면 경로 서버가 따로 필요해서, 이미 잘 하는 지도 앱에 맡긴다.
Future<void> openWalkingDirections({
  required double latitude,
  required double longitude,
  required String name,
  Future<bool> Function(Uri uri, {LaunchMode mode})? launch,
  TargetPlatform? platform,
}) async {
  final go =
      launch ??
      (Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) =>
          launchUrl(uri, mode: mode);
  final place = Uri.encodeComponent(name.trim());
  final naver = Uri.parse(
    'nmap://route/walk?dlat=$latitude&dlng=$longitude&dname=$place'
    '&appname=kr.bikedoctor.ridey',
  );
  try {
    if (await go(naver, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  final os = platform ?? defaultTargetPlatform;
  final fallback = os == TargetPlatform.iOS
      ? Uri.parse(
          'https://maps.apple.com/?daddr=$latitude,$longitude&dirflg=w&q=$place',
        )
      : Uri.parse(
          'https://www.google.com/maps/dir/?api=1'
          '&destination=$latitude,$longitude&travelmode=walking',
        );
  try {
    await go(fallback, mode: LaunchMode.externalApplication);
  } catch (_) {}
}
