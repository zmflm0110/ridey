import ActivityKit
import SwiftUI
import WidgetKit

@main
struct RideyAlertWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RideyAlertAttributes.self) { context in
      Text(context.state.text)
        .font(.caption)
        .padding(12)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text("RIDEY")
            .font(.caption.weight(.bold))
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(context.state.text)
            .font(.caption)
            .lineLimit(2)
        }
      } compactLeading: {
        Text("의심")
          .font(.caption2.weight(.semibold))
      } compactTrailing: {
        Text(context.state.compact)
          .font(.caption2.weight(.bold))
      } minimal: {
        Text(context.state.compact)
      }
    }
  }
}
