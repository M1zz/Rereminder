//
//  FoldLayoutTests.swift
//  RereminderTests
//
//  아이폰 듀오 자리 셈(`FoldLayout`)의 약속을 지킨다. 클립키보드의 같은 테스트를 옮겨 왔다.
//
//   ① 접힌 바깥 화면(466 x 678) · 보통 아이폰 · 아이패드는 지금 화면 그대로다
//   ② 펼친 안쪽 화면(669 x 951)은 세로면 높이 가운데, 가로면 폭 가운데에 접힌 선이 있다
//   ③ 두 쪽은 접힌 선 앞뒤 12pt 를 비우고, 판이 창 전체가 아니어도 선은 창 기준으로 맞는다
//   ④ 가로로 편 고르는 쪽은 바깥 화면과 거의 같은 폭이다(펴도 목록 모양이 그대로)
//

import XCTest
@testable import Rereminder

final class FoldLayoutTests: XCTestCase {

    private let outer = CGSize(width: 466, height: 678)
    private let innerPortrait = CGSize(width: 669, height: 951)
    private let innerLandscape = CGSize(width: 951, height: 669)

    // ①
    func test_접힌_바깥_화면과_아이패드는_나누지_않는다() {
        XCTAssertEqual(FoldLayout.resolve(windowSize: outer, isPhone: true).posture, .single)
        XCTAssertEqual(FoldLayout.resolve(windowSize: CGSize(width: 956, height: 440), isPhone: true).posture, .single,
                       "프로 맥스를 가로로 든 것은 넓어도 접힌 화면이 아니다")
        XCTAssertEqual(FoldLayout.resolve(windowSize: innerPortrait, isPhone: false).posture, .single,
                       "아이패드는 접히지 않는다")
    }

    // ②
    func test_펼친_안쪽_화면은_긴_변의_가운데에_선이_있다() {
        let portrait = FoldLayout.resolve(windowSize: innerPortrait, isPhone: true)
        XCTAssertEqual(portrait.posture, .innerPortrait)
        XCTAssertEqual(portrait.hingeCenter, 475.5, accuracy: 0.01)

        let landscape = FoldLayout.resolve(windowSize: innerLandscape, isPhone: true)
        XCTAssertEqual(landscape.posture, .innerLandscape)
        XCTAssertEqual(landscape.hingeCenter, 475.5, accuracy: 0.01)
    }

    // ③
    func test_두_쪽은_접힌_선을_비우고_창_기준으로_맞는다() {
        let fold = FoldLayout.resolve(windowSize: innerPortrait, isPhone: true)
        // 상태 막대 아래(59pt)에서 시작하는 판
        let pane = CGRect(x: 0, y: 59, width: 669, height: 951 - 59)
        let sizes = fold.split(of: pane)
        XCTAssertEqual(pane.minY + sizes.lead, fold.hingeCenter - FoldLayout.hingeGap / 2, accuracy: 0.01,
                       "결과 쪽(위)은 접힌 선 12pt 위에서 끝난다")
        XCTAssertEqual(sizes.lead + FoldLayout.hingeGap + sizes.trail, pane.height, accuracy: 0.01)
    }

    // ④
    func test_가로로_편_고르는_쪽은_바깥_화면_폭과_같다() {
        let fold = FoldLayout.resolve(windowSize: innerLandscape, isPhone: true)
        let sizes = fold.split(of: CGRect(origin: .zero, size: innerLandscape))
        XCTAssertEqual(sizes.lead, outer.width, accuracy: 10,
                       "펴도 왼쪽 목록이 접혔을 때와 같은 폭이어야 카드 자리가 안 바뀐다")
    }

    func test_접혀_있으면_판_전체가_고르는_쪽이다() {
        let sizes = FoldLayout.single.split(of: CGRect(x: 0, y: 0, width: 402, height: 874))
        XCTAssertEqual(sizes.lead, 402)
        XCTAssertEqual(sizes.trail, 0)
    }

    // ⑤ 시스템이 알려 준 띠가 있으면 그것이 정답이다
    func test_시스템이_알려_준_띠를_따른다() {
        // 세로로 편 화면: 가로로 긴 띠, 높이 480 근처, 두께 30
        let portrait = FoldLayout.resolve(windowSize: innerPortrait, isPhone: true,
                                          division: CGRect(x: 0, y: 465, width: 669, height: 30))
        XCTAssertEqual(portrait.posture, .innerPortrait)
        XCTAssertEqual(portrait.hingeCenter, 480, accuracy: 0.01)
        XCTAssertEqual(portrait.band, 30, accuracy: 0.01, "띠가 24pt 보다 두꺼우면 그 두께를 비운다")
        XCTAssertEqual(portrait.leadEnd, 465, accuracy: 0.01)
        XCTAssertEqual(portrait.trailStart, 495, accuracy: 0.01)

        // 가로로 편 화면: 세로로 긴 띠. 띠가 얇아도 24pt 는 비운다
        let landscape = FoldLayout.resolve(windowSize: innerLandscape, isPhone: true,
                                           division: CGRect(x: 470, y: 0, width: 10, height: 669))
        XCTAssertEqual(landscape.posture, .innerLandscape)
        XCTAssertEqual(landscape.hingeCenter, 475, accuracy: 0.01)
        XCTAssertEqual(landscape.band, FoldLayout.hingeGap, accuracy: 0.01)

        let sizes = landscape.split(of: CGRect(origin: .zero, size: innerLandscape))
        XCTAssertEqual(sizes.lead + landscape.band + sizes.trail, innerLandscape.width, accuracy: 0.01)
    }
}

/// 듀오 계획 판이 미리 보여 주는 문구는 **실제로 나가는 문구**와 같아야 한다.
final class FoldPlanMessageTests: XCTestCase {
    func test_계획_판의_문구는_템플릿_알림과_같은_함수를_쓴다() {
        let template = Rereminder.Timer(name: "t", mainSeconds: 600, prealertOffsetsSec: [300],
                                        prealertMessages: [300: "정리하세요"])
        for offset in [30, 60, 300, 600] {
            XCTAssertEqual(Rereminder.Timer.prealertMessage(for: offset, custom: template.prealertMessages),
                           template.getPrealertMessage(for: offset))
        }
        XCTAssertEqual(Rereminder.Timer.prealertMessage(for: 300, custom: [300: "정리하세요"]), "정리하세요")
        XCTAssertEqual(Rereminder.Timer.finishMessage(custom: ""), Rereminder.Timer.finishMessage(custom: nil),
                       "빈 문구는 기본 종료 문구로 물러선다")
    }
}
