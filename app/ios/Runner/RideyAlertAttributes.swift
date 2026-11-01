import ActivityKit
import Foundation

struct RideyAlertAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var text: String
    var compact: String
  }
}
