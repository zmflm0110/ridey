import Flutter
import UIKit

final class OfficialBikeApp {
  static let shared = OfficialBikeApp()
  static let schemes = [
    "spb://",
    "bikeseoul://",
    "seoulbike://",
    "ddarung://",
    "ttareungi://",
    "smartbike://",
  ]

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "ridey/official_bike",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "open" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.open() ?? false)
    }
  }

  func open() -> Bool {
    for raw in Self.schemes {
      if let url = URL(string: raw), UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
        return true
      }
    }
    if let store = URL(string: "itms-apps://itunes.apple.com/app/id1037272004") {
      UIApplication.shared.open(store)
      return true
    }
    return false
  }
}
