import SwiftUI
import CoreText
import HeotgeoleumCore

@main
struct HeotgeoleumApp: App {
    @State private var model = AppModel()
    init() { BrandFont.register() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task {
                    await model.start()
                    while !Task.isCancelled {   // 실시간 목록 1분마다 (서버 주소가 있을 때만 받음)
                        try? await Task.sleep(for: .seconds(60))
                        await model.refreshLive()
                    }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false

    var body: some View {
        Group {
            if let error = model.loadError {
                ContentUnavailableView("자료를 못 읽었어요", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if model.store == nil {
                ProgressView("불러오는 중…")
            } else {
                @Bindable var model = model
                // 아래 탭: 아이콘 + 짧은 이름
                TabView(selection: $model.tab) {
                    MorningView().tabItem { Label("홈", systemImage: "house.fill") }.tag("morning")
                    LookupView().tabItem { Label("조회", systemImage: "magnifyingglass") }.tag("lookup")
                    RescueView().tabItem { Label("확인", systemImage: "checkmark.circle.fill") }.tag("rescue")
                    ReplayView().tabItem { Label("재생", systemImage: "play.rectangle.fill") }.tag("replay")
                    SurveyView().tabItem { Label("조사", systemImage: "square.and.pencil") }.tag("survey")
                }
            }
        }
        .tint(Palette.accent)
        .overlay(alignment: .bottom) {
            if let t = model.toast {
                Text(t)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.accent.opacity(0.96), in: Capsule())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 64)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.easeInOut, value: model.toast)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .environment(\.openSettings, { showSettings = true })
    }
}

/// 새 브랜드 (docs/brand.md) — 잉크·종이(바탕) + 신호 주황(경보) + 차분한 파랑(확인함). 웹앱 web/style.css 와 같은 값.
/// 이름은 그대로 두고 뜻만 바꿈: accent = 잉크(주 단추·강조), red = 신호색 글자, yellow = 옅은 신호(연쇄 2명), good = 파랑(괜찮음·확인함)
enum Palette {
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        func c(_ h: UInt32) -> UIColor { UIColor(red: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: 1) }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? c(dark) : c(light) })
    }
    static let ink = dyn(0x111317, 0xF3F1EC)         // 제목·숫자
    static let body = dyn(0x474B53, 0xB3B7BE)        // 본문
    static let sub = dyn(0x63676F, 0x8A8F98)         // 설명 (모두 4.5:1 넘게)
    static let bg = dyn(0xF7F5F0, 0x0D0F12)          // 화면 바탕 (종이)
    static let card = dyn(0xFFFFFF, 0x16191E)        // 카드
    static let fill = dyn(0xEFECE5, 0x1E2228)        // 카드 안 단추·입력칸
    static let line = dyn(0xE2DFD7, 0x262A31)        // 카드 테두리·나눔선
    static let shadow = Color(UIColor { $0.userInterfaceStyle == .dark ? .clear : UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 0.03) })
    static let accent = dyn(0x111317, 0xF3F1EC)      // 주 단추 (잉크, 어두운 화면은 종이)
    static let accentSoft = dyn(0xEFECE5, 0x1E2228)
    static let onAccent = dyn(0xF7F5F0, 0x111317)
    static let signal = dyn(0xFF4F1F, 0xFF5C2E)      // 경보 점·막대·큰 숫자 (꽉 찬 신호색)
    static let signalSoft = dyn(0xFFE4D9, 0x3A1C12)
    static let calm = dyn(0x2D5BFF, 0x7C9BFF)        // 확인함·괜찮음
    static let red = dyn(0xB82D07, 0xFF7A52)         // 신호색 글자 (흰 바탕 6.2:1)
    static let redSoft = signalSoft
    static let yellow = dyn(0xFF9A73, 0xC7653F)      // 연쇄 2명 — 옅은 신호 (지도 점)
    static let yellowSoft = fill
    static let yellowText = sub
    static let good = dyn(0x2149D6, 0x7C9BFF)        // 괜찮음·확인함 (초록 대신 파랑 — 색각 이상에서도 신호색과 갈라짐)
    static let goodSoft = dyn(0xE4EAFF, 0x17204A)
    static let mint = signal
    static func level(_ red: Bool) -> Color { red ? Palette.signal : Palette.yellow }
    static func levelSoft(_ red: Bool) -> Color { red ? Palette.redSoft : Palette.yellowSoft }
    static func levelText(_ red: Bool) -> Color { red ? Palette.red : Palette.yellowText }
}

/// 큰 숫자 글꼴 — Unbounded(SIL OFL) 굵기 800 일부(숫자·대문자·기호), 앱 자료(Assets 의 UnboundedNumbers)에서 시작할 때 등록 (tools/make_brand.py)
enum BrandFont {
    static let name = "UnboundedRIDEY-ExtraBold"
    static func register() {
        guard let data = NSDataAsset(name: "UnboundedNumbers")?.data, let provider = CGDataProvider(data: data as CFData),
              let font = CGFont(provider) else { return }
        CTFontManagerRegisterGraphicsFont(font, nil)
    }
}
extension Font {
    /// 칸 너비가 같은 큰 숫자 (등록 못 하면 시스템 글꼴로)
    static func num(_ size: CGFloat) -> Font { .custom(BrandFont.name, size: size) }
}

extension View {
    /// 카드 — 1px 선 테두리, 그림자 거의 없이(브랜드: 선으로 나눔). tint 를 주면 위쪽만 그 색으로 번짐
    func card(padding: CGFloat = 20, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(stops: [.init(color: tint ?? Palette.card, location: 0), .init(color: Palette.card, location: tint == nil ? 0 : 0.45)],
                                       startPoint: .top, endPoint: .bottom), in: shape)
            .overlay(shape.strokeBorder(Palette.line, lineWidth: 1))
            .shadow(color: Palette.shadow, radius: 10, y: 4)
    }
    /// 처음 나타날 때 아래에서 살짝 떠오름 (스프링, '동작 줄이기' 면 그냥)
    func rise(_ delay: Double = 0) -> some View { modifier(Rise(delay: delay)) }
    /// 지도 위에 떠 있는 단추 — iOS 26 리퀴드 글래스, 그 전은 옅은 재질 (CI 의 Xcode 16 도 빌드되게 컴파일러로 나눔)
    @ViewBuilder func floatingGlass() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { self.glassEffect(.regular.interactive(), in: Capsule()) }
        else { self.background(.regularMaterial, in: Capsule()) }
        #else
        self.background(.regularMaterial, in: Capsule())
        #endif
    }
    /// 화면 바탕
    func screenBackground() -> some View { background(Palette.bg.ignoresSafeArea()) }
}

/// 홈 맨 위 카드 바탕 — 잉크 위에 점 무늬(서울 대여소 점 지도 느낌)가 오른쪽 위에서 번지고 아주 천천히 흐름
struct HeroBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduce)) { tl in
            let t = reduce ? 0 : tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let step: CGFloat = 13, shift = CGFloat((t * 4).truncatingRemainder(dividingBy: Double(step)))
                var y: CGFloat = -step + shift / 2
                while y < size.height + step {
                    var x: CGFloat = -step + shift
                    while x < size.width + step {
                        let d = hypot((x - size.width) / size.width, (y - size.height * 0.15) / size.height)   // 오른쪽 위에서 멀수록 옅게
                        let a = max(0, 0.22 * (1 - d / 0.95))
                        if a > 0.01 { ctx.fill(Path(ellipseIn: CGRect(x: x - 1.1, y: y - 1.1, width: 2.2, height: 2.2)), with: .color(.white.opacity(a))) }
                        x += step
                    }
                    y += step
                }
            }
        }
        .background(scheme == .dark ? Color(red: 0.094, green: 0.106, blue: 0.129) : Color(red: 0.067, green: 0.075, blue: 0.09))
    }
}

/// 처음 나타날 때 아래에서 살짝 떠오르는 움직임
struct Rise: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown || reduce ? 1 : 0)
            .offset(y: shown || reduce ? 0 : 14)
            .onAppear { withAnimation(.spring(duration: 0.7, bounce: 0.18).delay(delay)) { shown = true } }
    }
}

/// 동그란 링 (애플 피트니스처럼) — 가운데 %
struct Ring: View {
    let value: Double
    @State private var shown = 0.0
    var body: some View {
        ZStack {
            Circle().stroke(Palette.fill, lineWidth: 10)
            Circle().trim(from: 0, to: shown).stroke(Palette.signal, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
            Text("\(Int((100 * shown).rounded()))%").font(.num(17)).monospacedDigit().foregroundStyle(Palette.ink)
                .contentTransition(.numericText(value: shown))
        }
        .frame(width: 84, height: 84)
        .onAppear { withAnimation(.spring(duration: 1.4, bounce: 0.1).delay(0.15)) { shown = value } }
        .onChange(of: value) { withAnimation(.spring(duration: 0.8, bounce: 0.1)) { shown = value } }
    }
}

/// 카드 위 제목 (카드 밖, 바탕 위)
struct SectionTitle: View {
    let title: String
    var sub: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.weight(.bold)).foregroundStyle(Palette.ink)
            if let sub { Text(sub).font(.subheadline).foregroundStyle(Palette.sub) }
        }
        .padding(.horizontal, 4)
        .padding(.top, 16)
    }
}

/// 목록 한 줄 — 왼쪽 동그란 아이콘, 제목·설명, 오른쪽 값 (토스 목록 모양)
struct ListRow<Trailing: View>: View {
    let icon: String
    var tint: Color = Palette.accent
    var soft: Color = Palette.accentSoft
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 42, height: 42).background(soft, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Palette.sub).lineLimit(1) }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// 빨강·노랑 표시 — 옅은 바탕에 진한 글자
struct LevelTag: View {
    let text: String
    let red: Bool
    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Palette.levelSoft(red), in: Capsule())
            .foregroundStyle(Palette.levelText(red))
    }
}

/// 큰 단추 (화면 아래 한 개) — 꽉 찬 청록
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Palette.onAccent)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Palette.accent, in: Capsule())
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.35), value: configuration.isPressed)
    }
}

/// 회색 단추 — 판정·보조 동작
struct SoftButtonStyle: ButtonStyle {
    var tint: Color = Palette.body
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Palette.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.35), value: configuration.isPressed)
    }
}

/// 로고 'RIDEY.' — docs/brand.md (Assets 의 Wordmark: 밝은·어두운 화면 SVG, tools/make_brand.py 가 만듦)
struct BrandTitle: View {
    var height: CGFloat = 21
    var body: some View {
        Image("Wordmark").resizable().scaledToFit().frame(height: height)
            .accessibilityLabel("RIDEY")
    }
}

/// 어느 탭에서든 설정(서버 주소)을 여는 동작
private struct OpenSettingsKey: EnvironmentKey { static let defaultValue: () -> Void = {} }
extension EnvironmentValues {
    var openSettings: () -> Void {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}

/// 탭마다 오른쪽 위 톱니바퀴
struct SettingsButton: View {
    @Environment(\.openSettings) private var open
    var body: some View {
        Button(action: open) { Image(systemName: "gearshape") }.tint(Palette.sub).accessibilityLabel("설정")
    }
}

/// 굵게(**…**)가 들어간 문장 — 문자열 끼워 넣기가 있으면 Text 가 마크다운을 안 읽어서 직접 바꾼다
func md(_ s: String) -> Text {
    Text((try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s))
}
