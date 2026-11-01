import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/rider/official_bike_app.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test('opens the android package then the play store', () async {
    final opened = <String>[];
    await openOfficialBikeApp(
      platform: TargetPlatform.android,
      canLaunch: (uri) async => uri.toString().contains('play.google.com'),
      launch: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        opened.add(uri.toString());
        return true;
      },
    );

    expect(opened, [officialBikePlayStoreUri]);
  });

  test('opens the official ios app scheme before the app store', () async {
    final opened = <String>[];
    await openOfficialBikeApp(
      platform: TargetPlatform.iOS,
      canLaunch: (uri) async => uri.toString() == officialBikeIosSchemes.first,
      launch: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        opened.add(uri.toString());
        return true;
      },
    );

    expect(opened, [officialBikeIosSchemes.first]);
  });

  test('opens the app store when no ios scheme is available', () async {
    final opened = <String>[];
    await openOfficialBikeApp(
      platform: TargetPlatform.iOS,
      canLaunch: (uri) async => uri.toString() == officialBikeAppStoreUri,
      launch: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        opened.add(uri.toString());
        return true;
      },
    );

    expect(opened, [officialBikeAppStoreUri]);
  });
}
