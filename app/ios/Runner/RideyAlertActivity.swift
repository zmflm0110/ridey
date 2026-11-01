import ActivityKit
import Flutter
import UIKit

final class RideyAlertActivity {
  static let shared = RideyAlertActivity()
  private var activityId: String?

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "ridey/nearby_alert", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "show":
        let args = call.arguments as? [String: Any]
        self.show(
          text: args?["text"] as? String ?? "",
          compact: args?["compact"] as? String ?? ""
        )
        result(nil)
      case "hide":
        self.hide()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func show(text: String, compact: String) {
    guard #available(iOS 16.1, *) else { return }
    hide()
    let attributes = RideyAlertAttributes()
    let state = RideyAlertAttributes.ContentState(text: text, compact: compact)
    do {
      if #available(iOS 16.2, *) {
        let activity = try Activity<RideyAlertAttributes>.request(
          attributes: attributes,
          content: .init(state: state, staleDate: nil)
        )
        activityId = activity.id
      } else {
        let activity = try Activity<RideyAlertAttributes>.request(
          attributes: attributes,
          contentState: state
        )
        activityId = activity.id
      }
    } catch {}
  }

  private func hide() {
    guard #available(iOS 16.1, *) else { return }
    for activity in Activity<RideyAlertAttributes>.activities {
      if activityId == nil || activity.id == activityId {
        Task {
          if #available(iOS 16.2, *) {
            await activity.end(nil, dismissalPolicy: .immediate)
          } else {
            await activity.end(dismissalPolicy: .immediate)
          }
        }
      }
    }
    activityId = nil
  }
}
