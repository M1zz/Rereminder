//
//  LiveActivityCommandTests.swift
//  RereminderTests
//
//  다이나믹 아일랜드 버튼이 앱에 닿는 경로를 검증한다.
//  버튼 인텐트는 앱 프로세스에서 돌지만 화면이 아직 없을 수 있으므로, 그때 눌린 명령은
//  앱 그룹에 남아 있다가 앱이 열릴 때 정확히 **한 번** 적용되어야 한다.
//  그리고 그 자리에서 받아 처리한 경우에는 `dispatch()` 가 그 사실을 알려 줘야 한다
//  (인텐트가 표시를 어림값으로 덮어쓰지 않도록).
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

    // MARK: - dispatch 핸드셰이크
    //
    // 인텐트는 "앱이 받았나"를 기록이 지워졌는지로 판정한다. 이게 틀리면 둘 중 하나가 난다:
    //  • 받았는데 안 받았다고 보면 → 진짜 상태를 어림값이 덮는다
    //  • 안 받았는데 받았다고 보면 → 버튼을 눌러도 화면이 그대로다(=고장으로 읽힌다)

    func test_dispatch_withNoListener_reportsUnhandled() {
        XCTAssertFalse(LiveActivityCommand.pause.dispatch(),
                       "받을 사람이 없으면 처리되지 않은 것으로 보고해야 한다")
        XCTAssertEqual(LiveActivityCommandStore.take(), .pause,
                       "처리되지 않았으니 기록은 남아 있어야 한다")
    }

    func test_dispatch_whenListenerClearsStore_reportsHandled() {
        let token = NotificationCenter.default.addObserver(
            forName: LiveActivityCommand.stop.notificationName,
            object: nil, queue: nil
        ) { _ in
            // 앱의 TimerViewModel 이 하는 일과 같다 — 처리했으면 기록을 지운다
            LiveActivityCommandStore.clear()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        XCTAssertTrue(LiveActivityCommand.stop.dispatch(),
                      "옵저버가 그 자리에서 처리했으면 true 여야 한다")
        XCTAssertNil(LiveActivityCommandStore.take(),
                     "처리된 명령이 남아 있으면 앱이 앞으로 나올 때 두 번 적용된다")
    }

    func test_dispatch_whenListenerIgnores_reportsUnhandled() {
        // 상태가 맞지 않아 그냥 지나가는 옵저버(예: 이미 멈춰 있는데 pause 가 온 경우)
        let token = NotificationCenter.default.addObserver(
            forName: LiveActivityCommand.resume.notificationName,
            object: nil, queue: nil
        ) { _ in }
        defer { NotificationCenter.default.removeObserver(token) }

        XCTAssertFalse(LiveActivityCommand.resume.dispatch(),
                       "받고도 처리하지 않았다면 처리된 것으로 보면 안 된다")
        XCTAssertEqual(LiveActivityCommandStore.take(), .resume)
    }

    func test_isPending_tracksStore() {
        XCTAssertFalse(LiveActivityCommandStore.isPending)
        LiveActivityCommandStore.post(.pause)
        XCTAssertTrue(LiveActivityCommandStore.isPending)
        _ = LiveActivityCommandStore.take()
        XCTAssertFalse(LiveActivityCommandStore.isPending)
    }
}
