//
//  FoldPresentationGuardTests.swift
//  RereminderTests
//
//  펼친 듀오에서 시트 · 알림창이 접힌 선 위에 서지 않는다는 약속(`FoldPresentationGuard`).
//
//   ① 세로로 펴면 시트 높이는 아래 쪽 판 하나뿐이다. 접혀 있으면 받은 높이 그대로다
//   ② 펴면 알림창은 고르는 쪽 판 크기의 창에서 뜬다(그 판 가운데에 선다)
//   ③ 알림창이 내려가면 판 창은 거둬지고, 남아 있더라도 터치를 막지 않는다
//

import XCTest
import UIKit
@testable import Rereminder
@testable import LeeoKit

@MainActor
final class FoldPresentationGuardTests: XCTestCase {

    private let portrait = FoldLayout(posture: .innerPortrait, windowSize: CGSize(width: 669, height: 951))
    private let landscape = FoldLayout(posture: .innerLandscape, windowSize: CGSize(width: 951, height: 669))
    private var window: UIWindow?

    override func setUp() async throws {
        FoldSheetGuard.install()
    }

    override func tearDown() async throws {
        FoldState.current = .single
        window?.isHidden = true
        window = nil
    }

    // ①
    func test_세로로_펴면_시트는_아래_쪽_판_높이_하나뿐이다() {
        let sheet = UISheetPresentationController(presentedViewController: UIViewController(), presenting: nil)

        FoldState.current = .single
        XCTAssertEqual(FoldSheetGuard.detents(for: sheet, requested: [.medium(), .large()]).count, 2,
                       "접혀 있으면 아무것도 바꾸지 않는다")

        FoldState.current = portrait
        let detents = FoldSheetGuard.detents(for: sheet, requested: [.medium(), .large()])
        XCTAssertEqual(detents.map(\.identifier), [FoldSheetGuard.lowerPaneDetentID])
    }

    // ②③
    func test_펴면_알림창은_고르는_쪽_판에서_뜨고_내려가면_판_창이_비켜선다() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let host = UIWindow(windowScene: scene)
        host.frame = CGRect(x: 0, y: 0, width: 951, height: 669)
        host.rootViewController = UIViewController()
        host.makeKeyAndVisible()
        window = host
        FoldState.current = landscape

        let alert = UIAlertController(title: "t", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        host.rootViewController?.present(alert, animated: false)

        XCTAssertNil(host.rootViewController?.presentedViewController, "앱 창에는 띄우지 않는다")
        let paneRoot = try XCTUnwrap(alert.presentingViewController as? FoldPaneRootController)
        let paneWindow = try XCTUnwrap(paneRoot.view.window)
        XCTAssertEqual(paneWindow.frame.maxX, landscape.hingeCenter - FoldLayout.hingeGap / 2, accuracy: 0.5,
                       "판 창은 접힌 선 앞 12pt 에서 끝난다")

        // 단추를 누르면 UIKit 은 띄운 쪽에게 내려 달라고 한다. 같은 길을 탄다.
        let closed = expectation(description: "dismissed")
        paneRoot.dismiss(animated: false) { closed.fulfill() }
        wait(for: [closed], timeout: 2)

        XCTAssertTrue(paneWindow.isHidden, "알림창이 내려가면 판 창도 거둔다")
        XCTAssertNil(paneWindow.hitTest(CGPoint(x: 10, y: 10), with: nil),
                     "띄운 것이 없는 판 창은 터치를 아래로 흘린다")
    }

    func test_접혀_있으면_알림창은_그대로_앱_창에서_뜬다() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let host = UIWindow(windowScene: scene)
        host.rootViewController = UIViewController()
        host.makeKeyAndVisible()
        window = host
        FoldState.current = .single

        let alert = UIAlertController(title: "t", message: nil, preferredStyle: .alert)
        host.rootViewController?.present(alert, animated: false)
        XCTAssertIdentical(host.rootViewController?.presentedViewController, alert)
        host.rootViewController?.dismiss(animated: false)
    }
}
