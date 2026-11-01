import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const officialBikeChannel = MethodChannel('ridey/official_bike');
const officialBikeAndroidPackage = 'com.dki.spb_android';
const officialBikePlayStoreUri =
    'https://play.google.com/store/apps/details?id=$officialBikeAndroidPackage';
const officialBikeAppStoreUri = 'itms-apps://itunes.apple.com/app/id1037272004';
const officialBikeIosSchemes = [
  'spb://',
  'bikeseoul://',
  'seoulbike://',
  'ddarung://',
  'ttareungi://',
  'smartbike://',
];

/// Opens the official Seoul Bike mobile app. There is no public deep link
/// that starts a rental for a bike number or station.
Future<void> openOfficialBikeApp({
  Future<bool> Function(Uri uri, {LaunchMode mode})? launch,
  Future<bool> Function(Uri uri)? canLaunch,
  TargetPlatform? platform,
}) async {
  if (launch == null && canLaunch == null) {
    try {
      final opened = await officialBikeChannel.invokeMethod<bool>('open');
      if (opened == true) return;
    } on MissingPluginException {
      // Widget tests and unsupported platforms fall through to URL launch.
    }
  }

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
    for (final scheme in officialBikeIosSchemes) {
      if (await tryOpen(scheme)) return;
    }
    await tryOpen(officialBikeAppStoreUri);
  }
}
