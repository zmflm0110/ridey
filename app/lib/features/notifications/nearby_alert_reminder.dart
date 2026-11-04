import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const nearbyAlertNotificationId = 711;
const nearbyAlertChannel = MethodChannel('ridey/nearby_alert');

const _androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
const _darwinSettings = DarwinInitializationSettings(
  requestAlertPermission: false,
  requestBadgePermission: false,
  requestSoundPermission: false,
);

String nearbyAlertReminderText(List<String> bikes, {int limit = 4}) {
  if (bikes.isEmpty) return '';
  final head = bikes.take(limit).join(', ');
  if (bikes.length <= limit) return '고장 의심 자전거: $head';
  return '고장 의심 자전거: $head 외 ${bikes.length - limit}대';
}

String nearbyAlertCompactText(List<String> bikes) => '${bikes.length}';

abstract interface class NearbyAlertReminder {
  Future<void> sync(List<String> bikeIds);
}

class SilentNearbyAlertReminder implements NearbyAlertReminder {
  const SilentNearbyAlertReminder();

  @override
  Future<void> sync(List<String> bikeIds) async {}
}

class PlatformNearbyAlertReminder implements NearbyAlertReminder {
  PlatformNearbyAlertReminder({
    FlutterLocalNotificationsPlugin? plugin,
    MethodChannel? channel,
    TargetPlatform? platform,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _channel = channel ?? nearbyAlertChannel,
       _platform = platform;

  final FlutterLocalNotificationsPlugin _plugin;
  final MethodChannel _channel;
  final TargetPlatform? _platform;

  @override
  Future<void> sync(List<String> bikeIds) async {
    if (bikeIds.isEmpty) {
      await _hide();
      return;
    }
    final text = nearbyAlertReminderText(bikeIds);
    final compact = nearbyAlertCompactText(bikeIds);
    final target = _platform ?? defaultTargetPlatform;
    if (target == TargetPlatform.iOS) {
      try {
        await _channel.invokeMethod<void>('show', {
          'text': text,
          'compact': compact,
        });
        return;
      } catch (_) {}
    }
    await _showNotification(text);
  }

  Future<void> _hide() async {
    try {
      await _channel.invokeMethod<void>('hide');
    } catch (_) {}
    await _plugin.cancel(id: nearbyAlertNotificationId);
  }

  Future<void> _showNotification(String text) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: _androidSettings,
        iOS: _darwinSettings,
      ),
    );
    await _plugin.show(
      id: nearbyAlertNotificationId,
      title: 'RIDEY',
      body: text,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nearby-alerts',
          '주변 고장 의심',
          channelDescription: '따릉이 앱에서 피할 자전거 번호를 보여 줘요.',
          // 대여소 앞에서 공식 앱으로 넘어가 빌리는 동안만 쓸모 있다 — 밀어서 지울 수 있게, 30분 뒤엔 저절로 사라지게.
          ongoing: false,
          autoCancel: true,
          timeoutAfter: 30 * 60 * 1000,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
