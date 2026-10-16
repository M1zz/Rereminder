//
//  FoldLayout.swift
//  Rereminder
//
//  ⚠️ 클립키보드(`ClipKeyboard/DesignSystem/FoldLayout.swift`)에서 옮겨 온 것이다. 두 앱이 같은 규칙을
//     따라야 하므로 고칠 때는 양쪽을 함께 보고, 언젠가 LeeoKit 으로 합친다.
//
//  **접히는 화면에서 어디가 어디인가.** 아이폰 듀오를 위한 자리 셈.
//
//  듀오는 접으면 바깥 화면(466 x 678pt), 펴면 안쪽 화면(669 x 951pt)이다.
//  바깥 화면은 안쪽 화면을 반으로 접은 크기와 같다. 그래서 규칙 하나로 다 정한다.
//
//  - 접힌 선은 '하기 전'과 '한 뒤'의 경계다.
//    고르는 쪽(다이얼 · 조작)과 결과 쪽(계획 · 남은 시간)이 선을 사이에 두고 선다.
//  - 가로로 펴면 왼쪽이 고르는 쪽, 오른쪽이 결과 쪽. 세로로 펴면 아래가 고르는 쪽, 위가 결과 쪽.
//    손은 아래와 왼쪽에서 일하고 눈은 위와 오른쪽에서 확인한다.
//  - 접으면 고르는 쪽만 남는다. 바깥 화면은 **지금 아이폰 화면 그대로**이고,
//    펴면 그 옆(위)에 결과 쪽이 더해진다. 펴고 접어도 고르던 것이 그대로 이어진다.
//  - 접힌 선 앞뒤 `hingeGap / 2` 안에는 **아무것도 두지 않는다.** 누를 것만이 아니라 글 · 카드 ·
//    탭바 · 시트 · 알림 전부다. 펼친 화면의 모든 판은 선의 어느 한쪽에만 선다.
//
//  - 접힌 선의 자리는 **시스템에 묻는다**(iOS 27.1 `UIView.reservedRegions(kind: .division)`).
//    창 뒤에 깐 `DivisionProbe` 가 창을 다시 그릴 때마다 묻는다. 펴고 접으면 창 크기가 바뀌므로 그때 다시 묻는다.
//    시스템이 답하지 않으면(27.0 이하 · 미리보기 틀) 창 크기로 어림한다: 폰인데 짧은 변이
//    `minInnerSide` 이상이면 안쪽 화면으로 보고, 긴 변의 가운데에 선이 있다고 본다.
//  ⚠️ Xcode 27.0 으로 빌드한 앱은 듀오에서 호환 틀(아이폰 크기)로 뜬다. 듀오 배치는 27.1 빌드부터 켜진다.
//  ⚠️ API 는 ObjC 이름으로 부른다. 27.0 SDK 로도 빌드되게 하려는 것이다(같은 Swift 6.4 라 컴파일 조건으로 못 가른다).
//
//  ⚠️ 판단은 창 크기로만 한다. `userInterfaceIdiom` 은 "폰인가" 하나에만 쓴다
//     (아이패드는 이 셈을 타지 않는다).
//

import SwiftUI
import UIKit

// MARK: - 자세

enum FoldPosture: Equatable {
    /// 접힌 바깥 화면, 또는 접히지 않는 보통 아이폰 · 아이패드. 지금 화면 그대로.
    case single
    /// 세로로 편 안쪽 화면. 높이 가운데에 가로로 접힌 선.
    case innerPortrait
    /// 가로로 편 안쪽 화면. 폭 가운데에 세로로 접힌 선.
    case innerLandscape
}

// MARK: - 자리 셈

struct FoldLayout: Equatable {
    let posture: FoldPosture
    /// 창 크기(pt).
    let windowSize: CGSize
    /// 창의 왼쪽 위가 화면 좌표(.global)로 어디인가. 보통은 0, 미리보기 틀이면 틀의 자리.
    var windowOrigin: CGPoint = .zero
    /// 시스템이 알려 준 접힌 선 가운데(창 좌표). 없으면 긴 변의 가운데로 본다.
    var reportedCenter: CGFloat?
    /// 비우는 띠의 두께(pt). 시스템이 알려 준 띠가 더 두꺼우면 그쪽을 따른다.
    var band: CGFloat = FoldLayout.hingeGap

    /// 접힌 선이 비우는 **가장 얇은** 폭(pt). 선 앞뒤로 반씩.
    static let hingeGap: CGFloat = 24
    /// 이보다 짧은 변이 길면 펼친 안쪽 화면으로 본다. 바깥 화면은 466pt, 안쪽은 669pt.
    static let minInnerSide: CGFloat = 600
    /// 실측 안쪽 화면 크기(iPhone Duo 시뮬레이터, 27.1). 미리보기 틀에만 쓴다.
    static let innerScreenSize = CGSize(width: 669, height: 951)
    static let single = FoldLayout(posture: .single, windowSize: .zero)

    var isUnfolded: Bool { posture != .single }

    /// 접힌 선의 가운데(창 좌표). 세로면 y, 가로면 x.
    var hingeCenter: CGFloat {
        if let reportedCenter { return reportedCenter }
        switch posture {
        case .single: return 0
        case .innerPortrait: return windowSize.height / 2
        case .innerLandscape: return windowSize.width / 2
        }
    }

    /// 고르는 쪽 · 결과 쪽 중 앞쪽 판이 끝나는 자리(창 좌표). 가로면 x, 세로면 y.
    var leadEnd: CGFloat { hingeCenter - band / 2 }
    /// 뒤쪽 판이 시작하는 자리(창 좌표).
    var trailStart: CGFloat { hingeCenter + band / 2 }

    /// 자세를 정한다.
    ///
    /// - Parameters:
    ///   - isPhone: 폰인가. 아이패드는 넓어도 접히지 않는다.
    ///   - division: 시스템이 알려 준 접힌 선 띠(창 좌표, iOS 27.1 `reservedRegions(kind: .division)`).
    ///     있으면 이것이 정답이다. 없으면(27.0 이하 · 미리보기) 창 크기로 어림한다.
    static func resolve(windowSize size: CGSize, isPhone: Bool, division: CGRect? = nil) -> FoldLayout {
        if let division, isPhone, !division.isEmpty {
            // 가로로 긴 띠 = 높이 가운데를 지나는 선 = 세로로 편 화면
            let horizontalLine = division.width >= division.height
            return FoldLayout(posture: horizontalLine ? .innerPortrait : .innerLandscape,
                              windowSize: size,
                              reportedCenter: horizontalLine ? division.midY : division.midX,
                              band: max(hingeGap, horizontalLine ? division.height : division.width))
        }
        guard isPhone, min(size.width, size.height) >= minInnerSide else {
            return FoldLayout(posture: .single, windowSize: size)
        }
        let posture: FoldPosture = size.height >= size.width ? .innerPortrait : .innerLandscape
        return FoldLayout(posture: posture, windowSize: size)
    }

    /// 어떤 판이 창 안에서 `frame` 자리에 있을 때, 그 판을 고르는 쪽과 결과 쪽으로 나누는 크기.
    ///
    /// 판이 창 전체가 아니어도(안전 영역 · 탭바 아래) 접힌 선은 창 기준으로 맞춘다.
    /// 그래야 두 쪽의 경계가 진짜 선 위에 온다.
    func split(of frame: CGRect) -> (lead: CGFloat, trail: CGFloat) {
        switch posture {
        case .single:
            return (frame.width, 0)
        case .innerLandscape:
            let lead = (leadEnd - frame.minX).clamped(0, frame.width)
            return (lead, max(0, frame.width - lead - band))
        case .innerPortrait:
            let lead = (leadEnd - frame.minY).clamped(0, frame.height)
            return (lead, max(0, frame.height - lead - band))
        }
    }
}

private extension CGFloat {
    func clamped(_ low: CGFloat, _ high: CGFloat) -> CGFloat { Swift.min(Swift.max(self, low), high) }
}

// MARK: - 환경

private struct FoldLayoutKey: EnvironmentKey {
    static let defaultValue = FoldLayout.single
}

private struct FoldPaneTopKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// 지금 창이 접혔는가, 펴졌다면 어느 쪽으로. 루트의 `foldAware()` 가 넣는다.
    var foldLayout: FoldLayout {
        get { self[FoldLayoutKey.self] }
        set { self[FoldLayoutKey.self] = newValue }
    }

    /// 이 판의 위 끝이 창 위 끝에서 얼마나 내려와 있나(pt). 세로로 편 화면의 아래 쪽이면
    /// 접힌 선 바로 밑, 그 밖에는 0.
    ///
    /// 창 맨 위를 기준으로 자리를 재는 화면(목록의 제목줄 아래 여백)이 이 값을 빼서
    /// **자기 판의 맨 위**를 기준으로 다시 잰다. 아래 쪽 판에는 상태 막대도 없다.
    var foldPaneTop: CGFloat {
        get { self[FoldPaneTopKey.self] }
        set { self[FoldPaneTopKey.self] = newValue }
    }
}

// MARK: - 두 쪽으로 나누기

/// 고르는 쪽과 결과 쪽을 접힌 선에 맞춰 세운다. 접혀 있으면 고르는 쪽만 그린다.
///
/// ⚠️ **고르는 쪽은 자세가 바뀌어도 같은 뷰로 남는다.** 접힘에 따라 HStack 과 VStack 을
///    갈아 끼우면 SwiftUI 가 안쪽을 새로 만들어서, 펴는 순간 보던 카테고리 · 스크롤이 처음으로
///    돌아간다. 그래서 틀은 `AnyLayout` 하나로 바꾸고, 고르는 쪽은 늘 같은 칸(가운데)에 둔다.
struct FoldSplitView<Choose: View, Result: View>: View {
    @Environment(\.foldLayout) private var fold
    private let choose: Choose
    private let result: Result

    init(@ViewBuilder choose: () -> Choose, @ViewBuilder result: () -> Result) {
        self.choose = choose()
        self.result = result()
    }

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
                .offsetBy(dx: -fold.windowOrigin.x, dy: -fold.windowOrigin.y)
            let sizes = fold.split(of: frame)
            let layout: AnyLayout = fold.posture == .innerPortrait
                ? AnyLayout(VStackLayout(spacing: 0))
                : AnyLayout(HStackLayout(spacing: 0))

            layout {
                // 세로: 결과 쪽이 위
                if fold.posture == .innerPortrait {
                    result.frame(width: frame.width, height: sizes.lead)
                    hinge
                }

                choose
                    .environment(\.foldPaneTop,
                                 fold.posture == .innerPortrait ? fold.trailStart : 0)
                    .frame(
                        width: fold.posture == .innerLandscape ? sizes.lead : frame.width,
                        height: fold.posture == .innerPortrait ? sizes.trail : frame.height
                    )

                // 가로: 결과 쪽이 오른쪽
                if fold.posture == .innerLandscape {
                    hinge
                    result.frame(width: sizes.trail, height: frame.height)
                }
            }
        }
    }

    /// 접힌 선 자리. 비워 두되, 세로일 때 위아래 크기를 맞추려고 판 하나를 앉힌다.
    @ViewBuilder
    private var hinge: some View {
        Color.clear
            .frame(width: fold.posture == .innerLandscape ? fold.band : nil,
                   height: fold.posture == .innerPortrait ? fold.band : nil)
            .accessibilityHidden(true)
    }
}

// MARK: - 창 가득 덮는 화면은 고르는 쪽에

extension View {
    /// `fullScreenCover` 안의 화면에 건다. 펼친 화면에서는 고르는 쪽 판에만 서고,
    /// 다른 쪽은 비워 둔다. 접혀 있으면 지금 그대로다.
    ///
    /// 안쪽에는 접히지 않은 화면이라고 알린다. 바깥 화면에서 보던 그 모양 그대로 선다.
    func foldConfined() -> some View {
        modifier(FoldConfinedModifier(result: nil))
    }

    /// 위와 같고, 비어 있던 다른 쪽 판에 `result` 를 세운다(안내 | 따라 하기).
    func foldConfined<Result: View>(@ViewBuilder result: () -> Result) -> some View {
        modifier(FoldConfinedModifier(result: AnyView(result())))
    }
}

private struct FoldConfinedModifier: ViewModifier {
    @Environment(\.foldLayout) private var fold
    let result: AnyView?

    func body(content: Content) -> some View {
        if fold.isUnfolded {
            FoldSplitView {
                content.environment(\.foldLayout, .single)
            } result: {
                if let result {
                    result
                } else {
                    Color(.systemBackground).opacity(0.6)
                }
            }
            .background(Color(.systemBackground).ignoresSafeArea())
        } else {
            content
        }
    }
}

// MARK: - 루트에서 재기

extension View {
    /// 창 크기로 접힘을 재서 아래로 흘린다. 앱 루트에 한 번 건다.
    func foldAware() -> some View {
        modifier(FoldAwareModifier())
    }
}

private struct FoldAwareModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if DEBUG
        if FoldPreview.isOn {
            FoldPreviewFrame { content }
        } else {
            measured(content)
        }
        #else
        measured(content)
        #endif
    }

    private func measured(_ content: Content) -> some View {
        MeasuredWindow(content: content)
    }
}

/// 창 크기를 **배경에서** 잰다. 앱 전체를 GeometryReader 안에 넣으면 탭바 · 안전 영역의
/// 자리 잡기가 달라지므로, 재는 일은 뒤에 깐 투명한 판이 맡는다.
private struct MeasuredWindow<Content: View>: View {
    let content: Content
    @State private var windowSize: CGSize = .zero
    /// 시스템이 알려 준 접힌 선 띠(창 좌표). 접혀 있거나 시스템이 모르면 nil.
    @State private var division: CGRect?

    private var layout: FoldLayout {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        #if DEBUG
        // 폰 시뮬레이터 창을 펼친 화면으로 친다. 아이패드 틀(`-FoldPreview`)에서는 시트 · 알림이
        // 아이패드 모양으로 떠서, 폰에서만 생기는 시트 높이 · 알림 자리를 볼 수 없다.
        if FoldPreview.pretends, isPhone, windowSize != .zero {
            return FoldLayout(posture: windowSize.height >= windowSize.width ? .innerPortrait : .innerLandscape,
                              windowSize: windowSize)
        }
        #endif
        return FoldLayout.resolve(windowSize: windowSize, isPhone: isPhone, division: division)
    }

    var body: some View {
        content
            .environment(\.foldLayout, layout)
            .onChange(of: layout, initial: true) { _, now in
                FoldState.current = now
                FoldSheetGuard.install()
            }
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { windowSize = proxy.size }
                        .onChange(of: proxy.size) { _, size in windowSize = size }
                }
                .ignoresSafeArea()
            }
            .background {
                DivisionProbe { division = $0 }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
    }
}

/// 시스템에게 접힌 선 띠를 묻는 투명한 판.
///
/// 창이 다시 그려질 때(`layoutSubviews`) 창 전체를 기준으로 `.division` 띠를 읽는다.
/// 펴고 접으면 창 크기가 바뀌어 다시 그려지므로 따로 경첩을 지켜보지 않는다.
private struct DivisionProbe: UIViewRepresentable {
    let onChange: (CGRect?) -> Void

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.onChange = onChange
    }

    final class ProbeView: UIView {
        var onChange: ((CGRect?) -> Void)?
        private var last: CGRect?? = .none

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        private func report() {
            guard let window else { return }
            let now = Self.division(in: window)
            if let last, last == now { return }
            last = .some(now)
            if let now {
                print("📐 [DivisionProbe] 시스템이 알려 준 접힌 선 띠: \(now)")
            }
            DispatchQueue.main.async { [onChange] in onChange?(now) }
        }

        /// `window.reservedRegions(kind: .division)` 중 켜져 있는 첫 띠(창 좌표).
        static func division(in window: UIWindow) -> CGRect? {
            guard let kindClass = NSClassFromString("UIViewReservedRegionKind") as? NSObject.Type,
                  kindClass.responds(to: NSSelectorFromString("divisionRegionKind")),
                  let kind = kindClass.perform(NSSelectorFromString("divisionRegionKind"))?.takeUnretainedValue(),
                  window.responds(to: NSSelectorFromString("reservedRegionsOfKind:")),
                  let regions = window.perform(NSSelectorFromString("reservedRegionsOfKind:"), with: kind)?
                    .takeUnretainedValue() as? [NSObject] else {
                return nil
            }
            for region in regions {
                let active = (region.value(forKey: "active") as? Bool) ?? true
                guard active, let frame = (region.value(forKey: "frame") as? NSValue)?.cgRectValue,
                      !frame.isEmpty else { continue }
                return frame
            }
            return nil
        }
    }
}

#if DEBUG
// MARK: - 미리보기 틀 (개발용)

/// 실기기도 펼치는 시뮬레이터도 없을 때, 아이패드 시뮬레이터에서 안쪽 화면을 흉내 낸다.
///
/// `-FoldPreview` 를 붙여 실행하면 앱을 안쪽 화면 크기(669 x 951) 틀에 담고 접힌 선을 그린다.
/// 아이패드를 돌리면 틀도 가로가 된다. 돌릴 수 없는 명령줄 시뮬레이터에서는
/// `-FoldPreviewLandscape` 로 가로 틀을 강제한다(13인치 아이패드 세로 폭 1032pt 에 951pt 가 들어간다).
enum FoldPreview {
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-FoldPreview") }
    static var forcesLandscape: Bool { ProcessInfo.processInfo.arguments.contains("-FoldPreviewLandscape") }
    /// `-FoldPretend`: 폰 시뮬레이터 창을 그대로 펼친 화면으로 본다(틀 없이).
    static var pretends: Bool { ProcessInfo.processInfo.arguments.contains("-FoldPretend") }
}

private struct FoldPreviewFrame<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { outer in
            let landscape = FoldPreview.forcesLandscape || outer.size.width > outer.size.height
            let inner = FoldLayout.innerScreenSize
            let size = landscape ? CGSize(width: inner.height, height: inner.width) : inner
            let outerFrame = outer.frame(in: .global)
            // 틀은 가운데에 선다. 그 왼쪽 위가 틀 안 앱의 "창 원점"이다.
            let origin = CGPoint(x: outerFrame.minX + (outer.size.width - size.width) / 2,
                                 y: outerFrame.minY + (outer.size.height - size.height) / 2)
            let fold = FoldLayout(posture: landscape ? .innerLandscape : .innerPortrait,
                                  windowSize: size, windowOrigin: origin)

            ZStack {
                Color.black
                content()
                    .environment(\.foldLayout, fold)
                    .onChange(of: fold, initial: true) { _, now in
                        FoldState.current = now
                        FoldSheetGuard.install()
                    }
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay { hingeLine(fold: fold, size: size) }
            }
            .frame(width: outer.size.width, height: outer.size.height)
        }
        .ignoresSafeArea()
    }

    private func hingeLine(fold: FoldLayout, size: CGSize) -> some View {
        Path { path in
            if fold.posture == .innerLandscape {
                path.move(to: CGPoint(x: size.width / 2, y: 0))
                path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            } else {
                path.move(to: CGPoint(x: 0, y: size.height / 2))
                path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            }
        }
        .stroke(Color.red.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
        .allowsHitTesting(false)
    }
}
#endif
