//
//  FoldPresentationGuard.swift
//  Rereminder
//
//  ⚠️ 클립키보드(`ClipKeyboard/DesignSystem/FoldPresentationGuard.swift`)에서 옮겨 온 것이다.
//     시트의 짝(`foldSheetCompanion`)은 이 앱에 쓸 곳이 없어 가져오지 않았다.
//
//  펼친 아이폰 듀오에서 **시트와 알림창이 접힌 선 위에 서지 않게** 한다.
//
//  화면 안의 판은 `FoldSplitView` 가 선을 비켜 세운다. 하지만 시트와 알림창은 화면이 아니라
//  시스템이 창 위에 띄운다. 시트는 창 바닥에서 창 끝까지 오르고, 알림창은 창 가운데,
//  곧 접힌 선 위에 선다. 그래서 띄우는 길 자체를 여기 한 곳에서 붙잡는다.
//
//  ⚠️ 접혀 있으면(바깥 화면 · 보통 아이폰 · 아이패드) 아무것도 바꾸지 않는다.
//  ⚠️ ObjC 런타임으로 UIKit 메서드를 바꿔 끼운다. 바꿔 끼운 이름(`fold_…`)은 **원래 구현**을 부른다.
//

import SwiftUI
import UIKit

// MARK: - 지금 접힘

/// 지금 창의 접힘. UIKit 쪽(`FoldSheetGuard`)이 읽는다. 루트의 `MeasuredWindow` 가 적는다.
@MainActor
enum FoldState {
    static var current = FoldLayout.single
}

// MARK: - 시트

/// 모든 시트를 **접힌 선의 한쪽**에 가둔다. 앱 어디서 띄운 시트든 이 한 곳을 지난다.
///
/// - 세로로 펴면 아래에서 오르는 시트는 아래 쪽 판 높이까지만 오른다. 높이 손잡이는 숨긴다.
/// - 가로로 펴면 시트를 오른쪽(결과 쪽)에 세운다(iOS 27 `preferredPlacement`).
///
/// ⚠️ 시트마다 수식어를 거는 길은 버렸다. 시트를 띄우는 자리가 여럿이고, 띄우는 쪽의
///    `presentationDetents` 가 시트 안쪽의 것을 이겨서(실측: 새 기능 안내가 창 끝까지 올라옴)
///    한 곳만 빠뜨려도 선을 덮는다. SwiftUI 도 결국 `UISheetPresentationController` 의
///    `detents` 를 쓰므로, 그 쓰기 자체를 여기서 바꿔 끼운다.
/// ⚠️ 접혀 있으면 받은 값을 그대로 넘긴다. 바깥 화면과 보통 아이폰은 아무것도 달라지지 않는다.
@MainActor
enum FoldSheetGuard {
    private static var installed = false

    /// 앱이 뜰 때 한 번. 두 번 불러도 한 번만 바꿔 끼운다.
    static func install() {
        guard !installed else { return }
        installed = true
        swap(UISheetPresentationController.self,
             #selector(setter: UISheetPresentationController.detents),
             #selector(UISheetPresentationController.fold_setDetents(_:)))
        swap(UISheetPresentationController.self,
             #selector(UISheetPresentationController.presentationTransitionWillBegin),
             #selector(UISheetPresentationController.fold_presentationTransitionWillBegin))
        swap(UIViewController.self,
             #selector(UIViewController.present(_:animated:completion:)),
             #selector(UIViewController.fold_present(_:animated:completion:)))
    }

    /// 이 클래스가 직접 갖지 않은 메서드면 먼저 더해서, 부모 클래스(모든 표시 방식)는 건드리지 않는다.
    fileprivate static func swap(_ cls: AnyClass, _ original: Selector, _ replacement: Selector) {
        guard let o = class_getInstanceMethod(cls, original),
              let r = class_getInstanceMethod(cls, replacement) else {
            print("❌ [FoldSheetGuard.swap] 메서드를 못 찾음: \(original)")
            return
        }
        if class_addMethod(cls, original, method_getImplementation(r), method_getTypeEncoding(r)) {
            class_replaceMethod(cls, replacement, method_getImplementation(o), method_getTypeEncoding(o))
        } else {
            method_exchangeImplementations(o, r)
        }
    }

    static let lowerPaneDetentID = UISheetPresentationController.Detent.Identifier("fold.lowerPane")

    /// 세로로 폈을 때 쓸 높이. 시트 맨 위가 접힌 선 띠 아래 끝(`trailStart`)에 닿는다.
    /// 시트 높이는 바닥 안전 영역을 뺀 값이라 그만큼 덜어 낸다.
    static func detents(for sheet: UISheetPresentationController,
                        requested: [UISheetPresentationController.Detent]) -> [UISheetPresentationController.Detent] {
        guard FoldState.current.posture == .innerPortrait else { return requested }
        return [.custom(identifier: lowerPaneDetentID) { [weak sheet] context in
            let fold = FoldState.current
            let bottomInset = sheet?.containerView?.window?.safeAreaInsets.bottom ?? 0
            let height = fold.windowSize.height - bottomInset - fold.trailStart
            return max(0, min(context.maximumDetentValue, height))
        }]
    }

    /// 띄우기 직전에 한 번 더 맞춘다. 높이를 따로 주지 않은 시트는 `detents` 를 쓰지 않고 뜨기 때문이다.
    static func prepare(_ sheet: UISheetPresentationController) {
        switch FoldState.current.posture {
        case .innerPortrait:
            sheet.detents = sheet.detents   // 위의 바꿔 끼운 쓰기를 지난다
            sheet.selectedDetentIdentifier = lowerPaneDetentID
            sheet.prefersGrabberVisible = false
        case .innerLandscape:
            if #available(iOS 27.0, *) {
                sheet.preferredPlacement = .trailing
            }
        case .single:
            break
        }
    }
}

extension UISheetPresentationController {
    // 바꿔 끼운 뒤에는 이 이름이 **원래 구현**을 부른다.
    @objc fileprivate func fold_setDetents(_ detents: [UISheetPresentationController.Detent]) {
        let filtered = MainActor.assumeIsolated { FoldSheetGuard.detents(for: self, requested: detents) }
        fold_setDetents(filtered)
    }

    @objc fileprivate func fold_presentationTransitionWillBegin() {
        MainActor.assumeIsolated { FoldSheetGuard.prepare(self) }
        fold_presentationTransitionWillBegin()
    }
}

// MARK: - 알림창

/// 알림창(`UIAlertController`)을 **고르는 쪽 판 크기의 창**에 띄운다.
///
/// 알림창은 자기가 뜬 창의 가운데에 선다. 앱 창은 펼친 화면 전체라 그 가운데가 접힌 선이다.
/// 알림창이 서는 자리를 고를 길이 UIKit 에 없어서(27.0 SDK), 창을 하나 더 만들어
/// 고르는 쪽 판 자리에 맞춰 두고 거기서 띄운다. 그러면 판 가운데에 선다.
/// 아래에서 오르는 선택 목록(`confirmationDialog`)도 같은 길로 판 바닥에 선다.
///
/// ⚠️ 띄운 쪽(SwiftUI)이 보기에는 자기가 띄운 것이 아니다. 단추를 누르면 알림창이 스스로
///    내려가고 SwiftUI 는 그 단추의 동작으로 상태를 되돌리므로 흐름은 그대로다.
@MainActor
enum FoldAlertRouter {
    private static var paneWindow: UIWindow?

    /// 이 표시를 판 창으로 돌릴 것인가.
    static func shouldRoute(_ presented: UIViewController, from presenter: UIViewController) -> Bool {
        guard FoldState.current.isUnfolded, presented is UIAlertController else { return false }
        return !(presenter is FoldPaneRootController)
    }

    static func route(_ alert: UIViewController, from presenter: UIViewController,
                      animated: Bool, completion: (() -> Void)?) {
        guard let host = presenter.view.window, let scene = host.windowScene else {
            presenter.fold_present(alert, animated: animated, completion: completion)
            return
        }
        let window = paneWindow ?? FoldPaneWindow(windowScene: scene)
        let root = (window.rootViewController as? FoldPaneRootController) ?? FoldPaneRootController()
        window.rootViewController = root
        window.windowLevel = .alert
        window.backgroundColor = .clear
        window.frame = paneFrame(in: host)
        window.isHidden = false
        paneWindow = window
        print("🔀 [FoldAlertRouter.route] 알림창을 고르는 쪽 판(\(window.frame))에 띄움")
        root.fold_present(alert, animated: animated, completion: completion)
    }

    /// 알림창이 내려가면 판 창도 거둔다.
    static func close() {
        paneWindow?.isHidden = true
        paneWindow = nil
    }

    /// 고르는 쪽 판. 가로면 왼쪽, 세로면 아래. 화면 좌표.
    private static func paneFrame(in host: UIWindow) -> CGRect {
        let fold = FoldState.current
        // 앱 창 크기. 실기기는 창 그대로, 미리보기 틀이면 틀의 크기다.
        let bounds = CGRect(origin: .zero,
                            size: FoldState.current.windowSize == .zero ? host.bounds.size : FoldState.current.windowSize)
        let local: CGRect
        switch fold.posture {
        case .innerLandscape:
            local = CGRect(x: 0, y: 0, width: fold.leadEnd, height: bounds.height)
        case .innerPortrait:
            let top = fold.trailStart
            local = CGRect(x: 0, y: top, width: bounds.width, height: bounds.height - top)
        case .single:
            local = bounds
        }
        // 미리보기 틀(`-FoldPreview`)이면 창 안에서 틀이 놓인 자리만큼 옮긴다. 실기기는 0 이다.
        return host.convert(local.offsetBy(dx: fold.windowOrigin.x, dy: fold.windowOrigin.y), to: nil)
    }
}

/// 판 창. 띄운 것이 없으면 **터치를 받지 않는다.**
///
/// ⚠️ 알림창이 내려갈 때 창을 거두는 길(`FoldPaneRootController.dismiss`)을 놓치면,
///    보이지 않는 창이 고르는 쪽 판을 덮어 앱이 눌리지 않는 것처럼 된다. 그 경우에도
///    터치가 아래 앱 창으로 빠지게 둔다.
final class FoldPaneWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard rootViewController?.presentedViewController != nil else { return nil }
        return super.hitTest(point, with: event)
    }
}

/// 판 창의 뿌리. 아무것도 그리지 않고, 띄운 것이 내려가면 창을 거둔다.
final class FoldPaneRootController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag) {
            completion?()
            FoldAlertRouter.close()
        }
    }
}

extension UIViewController {
    @objc fileprivate func fold_present(_ presented: UIViewController, animated: Bool, completion: (() -> Void)?) {
        let routes = MainActor.assumeIsolated { FoldAlertRouter.shouldRoute(presented, from: self) }
        if routes {
            MainActor.assumeIsolated {
                FoldAlertRouter.route(presented, from: self, animated: animated, completion: completion)
            }
        } else {
            fold_present(presented, animated: animated, completion: completion)
        }
    }
}
