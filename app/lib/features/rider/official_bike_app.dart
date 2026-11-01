import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

const officialBikeAndroidPackage = 'com.dki.spb_android';
const officialBikePlayStoreUri =
    'https://play.google.com/store/apps/details?id=$officialBikeAndroidPackage';
const officialBikeSiteUri = 'https://www.bikeseoul.com';
const officialBikeAppStoreUri = 'https://apps.apple.com/app/id1037272004';

/// Opens the official Seoul Bike app when possible. There is no public deep
/// link that starts a rental for a bike number or station.
Future<void> openOfficialBikeApp({
  Future<bool> Function(Uri uri, {LaunchMode mode})? launch,
  Future<bool> Function(Uri uri)? canLaunch,
  TargetPlatform? platform,
}) async {
  final open = launch ?? launchUrl;
  final ready = canLaunch ?? canLaunchUrl;
  final target = platform ?? defaultTargetPlatform;

  Future<bool> tryOpen(String raw) async {
    final uri = Uri.parse(raw);
    if (!await ready(uri)) return false;
    return open(uri, mode: LaunchMode.externalApplication);
  }

  if (target == TargetPlatform.android) {
    if (await tryOpen(
      'intent:#Intent;package=$officialBikeAndroidPackage;end',
    )) {
      return;
    }
    await tryOpen(officialBikePlayStoreUri);
    return;
  }

  if (target == TargetPlatform.iOS) {
    if (await tryOpen(officialBikeSiteUri)) return;
    await tryOpen(officialBikeAppStoreUri);
  }
}
