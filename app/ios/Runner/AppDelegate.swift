import Flutter
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 앱을 보고 있을 때도 습관 알림 배너가 뜨게(FlutterAppDelegate 가 플러그인에 넘겨 준다).
    UNUserNotificationCenter.current().delegate = self
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "ridey.habit-notification",
      earliestBeginInSeconds: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RideyAlertActivity") {
      RideyAlertActivity.shared.register(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OfficialBikeApp") {
      OfficialBikeApp.shared.register(messenger: registrar.messenger())
    }
  }
}
