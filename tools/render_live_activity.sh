#!/bin/sh
# 다이내믹 아일랜드 · 잠금 화면 위젯을 위젯 코드 그대로 맥에서 그려 PNG 로 남긴다(발표 자료용).
# 쓰는 법: sh tools/render_live_activity.sh [출력 폴더]   (macOS 13+, Xcode 명령줄 도구)
set -e
cd "$(dirname "$0")/.."
OUT="${1:-docs/img/live_activity}"
mkdir -p "$OUT"
TMP="$(mktemp -d)"
# 위젯 파일에서 SwiftUI 보기 부분만 떼어 온다(ActivityKit 없이 맥에서 컴파일되게).
{ echo "import SwiftUI"; sed -n "/MARK: - views (begin)/,/MARK: - views (end)/p" app/ios/RideyAlertWidget/RideyAlertWidget.swift; } > "$TMP/Views.swift"
cat > "$TMP/main.swift" <<'SWIFT'
import AppKit
import SwiftUI

let sample = RideyAlertContent(text: "고장 의심 자전거: SPB-56296, SPB-66629, SPB-51832, SPB-60160", compact: "4", bikes: ["SPB-56296", "SPB-66629", "SPB-51832"])

struct CompactIsland: View {
  var body: some View {
    HStack {
      RideyAlertCompactLeading()
      Spacer(minLength: 130)
      RideyAlertCount(alert: sample, size: 13)
    }
    .padding(.horizontal, 14)
    .frame(height: 37)
    .background(Capsule().fill(Color.black))
  }
}

struct ExpandedIsland: View {
  var body: some View {
    VStack(spacing: 10) {
      HStack {
        RideyAlertBrand(size: 15).padding(.leading, 4)
        Spacer()
        RideyAlertCount(alert: sample, size: 15).padding(.trailing, 4)
      }
      RideyAlertExpandedBottom(alert: sample)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 18)
    .frame(width: 371)
    .background(RoundedRectangle(cornerRadius: 44, style: .continuous).fill(Color.black))
  }
}

struct LockScreen: View {
  var body: some View {
    RideyAlertLockScreen(alert: sample)
      .frame(width: 360)
      .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(RideyAlertColor.ink))
  }
}

@MainActor func save<V: View>(_ view: V, _ name: String) {
  let renderer = ImageRenderer(content: view.padding(1))
  renderer.scale = 4
  guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("render failed: \(name)")
  }
  try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1] + "/" + name))
  print("wrote", name)
}

MainActor.assumeIsolated {
  save(CompactIsland(), "island_compact.png")
  save(ExpandedIsland(), "island_expanded.png")
  save(LockScreen(), "lock_screen.png")
  save(RideyAlertMinimal(alert: sample).padding(6).background(Capsule().fill(Color.black)), "island_minimal.png")
}
SWIFT
swiftc -O -o "$TMP/render" "$TMP/Views.swift" "$TMP/main.swift"
"$TMP/render" "$OUT"
rm -rf "$TMP"
