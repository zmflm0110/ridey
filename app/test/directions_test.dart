import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/rider/directions.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  Future<List<Uri>> tried(TargetPlatform platform, {bool naver = false}) async {
    final uris = <Uri>[];
    await openWalkingDirections(
      latitude: 37.65,
      longitude: 127.07,
      name: '중계역 1번 출구',
      platform: platform,
      launch: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        uris.add(uri);
        return naver && uri.scheme == 'nmap';
      },
    );
    return uris;
  }

  test('opens Naver Map walking directions when it is installed', () async {
    final uris = await tried(TargetPlatform.android, naver: true);
    expect(uris, hasLength(1));
    expect(
      uris.single.toString(),
      startsWith('nmap://route/walk?dlat=37.65&dlng=127.07'),
    );
  });

  test('starts from the location RIDEY measured from', () async {
    final uris = <Uri>[];
    await openWalkingDirections(
      latitude: 37.65,
      longitude: 127.07,
      name: '중계역 1번 출구',
      from: (latitude: 37.5, longitude: 127.0),
      platform: TargetPlatform.iOS,
      launch: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        uris.add(uri);
        return false;
      },
    );
    expect(uris.first.queryParameters['slat'], '37.5');
    expect(uris.first.queryParameters['slng'], '127.0');
    expect(uris.first.queryParameters['sname'], '내 위치');
    expect(uris.last.queryParameters['saddr'], '37.5,127.0');
  });

  test(
    'falls back to Apple Maps on iPhone and Google Maps on Android',
    () async {
      final ios = await tried(TargetPlatform.iOS);
      expect(ios.last.host, 'maps.apple.com');
      expect(ios.last.queryParameters['dirflg'], 'w');
      final android = await tried(TargetPlatform.android);
      expect(android.last.host, 'www.google.com');
      expect(android.last.queryParameters['travelmode'], 'walking');
    },
  );
}
