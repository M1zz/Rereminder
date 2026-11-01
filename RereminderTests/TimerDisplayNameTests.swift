//
//  TimerDisplayNameTests.swift
//  RereminderTests
//
//  저장된 자동 이름이 말이 섞인 채 화면에 나가지 않게 한다("메인10분 / 예비 1 3 5분" 제보).
//

import XCTest
@testable import Rereminder

final class TimerDisplayNameTests: XCTestCase {

    private func expected(_ main: Int, _ offsets: [Int]) -> String {
        Timer.displayName(stored: Timer.generatedName(mainSec: main, offsets: offsets),
                          mainSeconds: main, offsets: offsets)
    }

    func test_옛_한국어_이름도_앱이_만든_이름으로_본다() {
        for name in ["메인 10분", "메인10분", "메인 10분 / 예비 1·3·5분", "메인10분 / 예비 1 3 5분",
                     "메인 알림 10분", "메인 10분 30초, 예비: 1분"] {
            XCTAssertTrue(Timer.isGeneratedName(name), name)
        }
    }

    func test_영어_이름은_값이_달라도_앱이_만든_이름으로_본다() {
        XCTAssertTrue(Timer.isGeneratedName("Main 25 min / Pre-alert 5·1 min"))
        XCTAssertEqual(Timer.displayName(stored: "Main 25 min / Pre-alert 9 min", mainSeconds: 600, offsets: [60]),
                       expected(600, [60]), "템플릿을 고쳐 이름만 옛 값으로 남아도 실제 값을 말한다")
    }

    func test_사용자가_붙인_이름은_그대로다() {
        for name in ["메인 발표", "Main talk", "10분 스트레칭", "메인 10분 리허설"] {
            XCTAssertFalse(Timer.isGeneratedName(name), name)
            XCTAssertEqual(Timer.displayName(stored: name, mainSeconds: 600, offsets: [60]), name)
        }
    }

    func test_옛_이름은_화면에_저장값_그대로_나가지_않는다() {
        let shown = Timer.displayName(stored: "메인10분 / 예비 1 3 5분", mainSeconds: 600, offsets: [60, 180, 300])
        XCTAssertEqual(shown, expected(600, [60, 180, 300]))
        XCTAssertFalse(shown.contains("메인"))
    }
}
