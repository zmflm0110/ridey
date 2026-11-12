import ActivityKit
import Foundation

// 앱(Runner)과 위젯(RideyAlertWidget)에 같은 내용으로 두 벌 있다 — 한쪽을 고치면 다른 쪽도 고칠 것.
struct RideyAlertAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var text: String
    var compact: String
    /// 칩으로 보여 줄 번호(앞의 몇 대만). 옛 앱이 보내지 않으면 nil 이고, 그때는 text 를 보여 준다.
    var bikes: [String]?
  }
}
