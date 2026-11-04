import 'package:url_launcher/url_launcher.dart';

/// 서울시 공식 따릉이 고장 신고 화면(공단이 실제로 받는 곳).
final officialReportUri = Uri.parse(
  'https://www.bikeseoul.com/app/err/moveErrReportPage.do',
);

/// 고장 신고: RIDEY 는 받지 않고 서울시 공식 신고 화면으로 이어 주기만 한다. 신고는 그 화면에서 이용자가 직접 마친다.
Future<void> openOfficialReport({Future<bool> Function(Uri uri)? open}) async {
  try {
    await (open ?? (uri) => launchUrl(uri, mode: LaunchMode.inAppBrowserView))(
      officialReportUri,
    );
  } catch (_) {}
}
