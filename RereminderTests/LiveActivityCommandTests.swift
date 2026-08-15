//
//  LiveActivityCommandTests.swift
//  RereminderTests
//
//  다이나믹 아일랜드 버튼이 앱에 닿는 경로를 검증한다.
//  버튼 인텐트는 위젯 확장 프로세스에서 돌기 때문에, 앱이 꺼져 있는 동안 눌린 명령은
//  앱 그룹에 남아 있다가 앱이 열릴 때 정확히 **한 번** 적용되어야 한다.
//

import XCTest
@testable import Rereminder

final class LiveActivityCommandTests: XCTestCase {

    override func setUp() {
        super.setUp()
        LiveActivityCommandStore.clear()
    }

    override func tearDown() {
        LiveActivityCommandStore.clear()
        super.tearDown()
    }

    func test_noCommand_returnsNil() {
        XCTAssertNil(LiveActivityCommandStore.take())
    }

    func test_postedCommand_isDelivered() {
        LiveActivityCommandStore.post(.stop)
        XCTAssertEqual(LiveActivityCommandStore.take(), .stop)
    }

    func test_commandIsDeliveredOnlyOnce() {
        LiveActivityCommandStore.post(.pause)

        XCTAssertEqual(LiveActivityCommandStore.take(), .pause)
        XCTAssertNil(LiveActivityCommandStore.take(),
                     "두 번 적용되면 앱을 열 때마다 타이머가 다시 멈춘다")
    }

    func test_latestCommandWins() {
        LiveActivityCommandStore.post(.pause)
        LiveActivityCommandStore.post(.resume)
        XCTAssertEqual(LiveActivityCommandStore.take(), .resume)
    }

    func test_staleCommandIsDiscarded() {
        let longAgo = Date().addingTimeInterval(-LiveActivityCommandStore.expiry - 1)
        LiveActivityCommandStore.post(.stop, at: longAgo)

        XCTAssertNil(LiveActivityCommandStore.take(),
                     "어제 눌러 둔 '정지'가 오늘 시작한 타이머를 끄면 안 된다")
    }

    func test_freshCommandSurvivesWithinExpiry() {
        let recent = Date().addingTimeInterval(-LiveActivityCommandStore.expiry + 60)
        LiveActivityCommandStore.post(.stop, at: recent)
        XCTAssertEqual(LiveActivityCommandStore.take(), .stop)
    }

    func test_expiredCommandIsAlsoCleared() {
        let longAgo = Date().addingTimeInterval(-LiveActivityCommandStore.expiry - 1)
        LiveActivityCommandStore.post(.pause, at: longAgo)

        _ = LiveActivityCommandStore.take()
        // 버려진 명령이 저장소에 남아 있으면 다음 실행에서 다시 판정 대상이 된다
        XCTAssertNil(LiveActivityCommandStore.take())
    }
}
