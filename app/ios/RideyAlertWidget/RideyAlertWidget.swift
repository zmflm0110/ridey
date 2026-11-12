import ActivityKit
import SwiftUI
import WidgetKit

@main
struct RideyAlertWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RideyAlertAttributes.self) { context in
      RideyAlertLockScreen(alert: RideyAlertContent(context.state))
        .activityBackgroundTint(RideyAlertColor.ink)
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      let alert = RideyAlertContent(context.state)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          RideyAlertBrand(size: 15)
            .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          RideyAlertCount(alert: alert, size: 15)
            .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.bottom) {
          RideyAlertExpandedBottom(alert: alert)
        }
      } compactLeading: {
        RideyAlertCompactLeading()
      } compactTrailing: {
        RideyAlertCount(alert: alert, size: 13)
      } minimal: {
        RideyAlertMinimal(alert: alert)
      }
      .keylineTint(RideyAlertColor.signal)
    }
  }
}

extension RideyAlertContent {
  init(_ state: RideyAlertAttributes.ContentState) {
    self.init(text: state.text, compact: state.compact, bikes: state.bikes ?? [])
  }
}

// MARK: - views (begin)
// 아래 보기는 ActivityKit 없이 SwiftUI 만 쓴다 — 발표 자료용 그림도 이 코드로 그린다(tools/render_live_activity.sh).

/// 다이내믹 아일랜드·잠금 화면에 보여 줄 내용. 옛 앱이 번호 목록 없이 보내도 문장으로 보여 준다.
struct RideyAlertContent {
  var text: String
  var compact: String
  var bikes: [String]

  var count: Int { Int(compact) ?? bikes.count }
  var shown: [String] { Array(bikes.prefix(3)) }
  var more: Int { max(0, count - shown.count) }
}

enum RideyAlertColor {
  static let ink = Color(red: 17 / 255, green: 19 / 255, blue: 23 / 255)
  static let signal = Color(red: 1, green: 79 / 255, blue: 31 / 255)
}

/// 'RIDEY' 글자 + 주황 신호 점(로고의 마침표).
struct RideyAlertBrand: View {
  var size: CGFloat
  var body: some View {
    HStack(alignment: .lastTextBaseline, spacing: size * 0.18) {
      Text("RIDEY")
        .font(.system(size: size, weight: .heavy))
        .foregroundColor(.white)
      Circle()
        .fill(RideyAlertColor.signal)
        .frame(width: size * 0.42, height: size * 0.42)
    }
  }
}

struct RideyAlertCount: View {
  var alert: RideyAlertContent
  var size: CGFloat
  var body: some View {
    Text("\(alert.count)대")
      .font(.system(size: size, weight: .bold))
      .foregroundColor(RideyAlertColor.signal)
      .monospacedDigit()
  }
}

/// 피해야 할 번호를 칩으로. 3개 넘으면 '+N'.
struct RideyAlertChips: View {
  var alert: RideyAlertContent
  var size: CGFloat = 14
  var body: some View {
    HStack(spacing: 6) {
      ForEach(alert.shown, id: \.self) { bike in
        Text(bike)
          .font(.system(size: size, weight: .bold, design: .monospaced))
          .foregroundColor(.white)
          .lineLimit(1)
          .padding(.horizontal, 9)
          .padding(.vertical, 5)
          .background(Capsule().fill(Color.white.opacity(0.13)))
      }
      if alert.more > 0 {
        Text("+\(alert.more)")
          .font(.system(size: size, weight: .bold))
          .foregroundColor(.white.opacity(0.6))
      }
    }
  }
}

struct RideyAlertCompactLeading: View {
  var body: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(RideyAlertColor.signal)
        .frame(width: 7, height: 7)
      Text("의심")
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white)
    }
  }
}

struct RideyAlertMinimal: View {
  var alert: RideyAlertContent
  var body: some View {
    ZStack {
      Circle().fill(RideyAlertColor.signal)
      Text("\(alert.count)")
        .font(.system(size: 11, weight: .heavy))
        .foregroundColor(RideyAlertColor.ink)
    }
    .frame(width: 20, height: 20)
  }
}

struct RideyAlertExpandedBottom: View {
  var alert: RideyAlertContent
  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("이 근처 고장 의심 따릉이")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.6))
      if alert.shown.isEmpty {
        Text(alert.text)
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.white)
          .lineLimit(2)
      } else {
        RideyAlertChips(alert: alert)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 4)
    .padding(.bottom, 4)
  }
}

struct RideyAlertLockScreen: View {
  var alert: RideyAlertContent
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        RideyAlertBrand(size: 17)
        Spacer()
        Text("근처 고장 의심 \(alert.count)대")
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(RideyAlertColor.signal)
      }
      if alert.shown.isEmpty {
        Text(alert.text)
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.white)
          .lineLimit(2)
      } else {
        RideyAlertChips(alert: alert, size: 14)
      }
      Text("빌리기 전에 자전거 번호를 확인하세요")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.55))
    }
    .padding(16)
  }
}
// MARK: - views (end)
