//
//  TemplateSaveTests.swift
//  RereminderTests
//
//  템플릿 저장 리그레션 테스트.
//
//  ⚠️ 이 파일이 지키는 한 가지 — **무료 사용자의 템플릿은 사라지지 않는다.**
//     "저장은 Pro"를 "한도 0"으로 구현했더니 `saveIfNeeded` 의 정리 루프가 시드 템플릿까지
//     통째로 지웠고, 타이머를 한 번 시작하는 것만으로(시작이 이 함수를 부른다) 칩이 전부
//     없어졌다. 저장을 막는 것과 갖고 있던 것을 지우는 것은 전혀 다른 일이다.
//

import Security
import SwiftData
import XCTest
@testable import Rereminder

/// SwiftData 를 함께 import 하면 `Timer` 가 Foundation 것과 겹친다 — 모델을 명시해 둔다
private typealias TimerTemplate = Rereminder.Timer

@MainActor
final class TemplateSaveTests: XCTestCase {

    private static let proKey = "rereminder.pro.purchased"
    private static let devPaywallKey = "dev.testPaywall"
    private static let grandfatherKey = "rereminder.grandfather.granted"
    private static let seedKey = "hasSeededTemplates"

    private var container: ModelContainer!
    private var context: ModelContext!
    private var service: TimerConfigService!

    private var savedDevPaywall = false
    private var savedGrandfather = false
    private var savedSeeded = false

    override func setUpWithError() throws {
        try super.setUpWithError()

        // DEBUG 빌드의 개발자 자동 Pro·그랜드파더링을 꺼서 "무료 사용자" 전제를 만든다
        let defaults = UserDefaults.standard
        savedDevPaywall = defaults.bool(forKey: Self.devPaywallKey)
        savedGrandfather = defaults.bool(forKey: Self.grandfatherKey)
        defaults.set(true, forKey: Self.devPaywallKey)
        defaults.removeObject(forKey: Self.grandfatherKey)
        // 시드는 앱 전체에서 한 번만 심어진다 — 호스트 앱이 이미 심어 둔 흔적을 지운다
        savedSeeded = defaults.bool(forKey: Self.seedKey)
        defaults.removeObject(forKey: Self.seedKey)
        clearProState()

        // ⚠️ `cloudKitDatabase: .none` 을 반드시 준다. 호스트 앱의 iCloud 엔타이틀먼트 때문에
        //    기본값(.automatic)이면 메모리 스토어조차 CloudKit 규칙 검사에 걸려 로드에 실패한다
        //    (앱 본체가 겪던 바로 그 문제 — `RereminderApp.sharedModelContainer`).
        let schema = Schema([TimerTemplate.self, TimerRecord.self])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema,
                                               isStoredInMemoryOnly: true,
                                               cloudKitDatabase: .none)
        )
        context = ModelContext(container)
        service = TimerConfigService()
        service.attachContext(context)
    }

    override func tearDownWithError() throws {
        service = nil
        context = nil
        container = nil

        clearProState()
        let defaults = UserDefaults.standard
        defaults.set(savedDevPaywall, forKey: Self.devPaywallKey)
        if savedGrandfather {
            defaults.set(true, forKey: Self.grandfatherKey)
        }
        defaults.set(savedSeeded, forKey: Self.seedKey)
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func clearProState() {
        UserDefaults.standard.removeObject(forKey: Self.proKey)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.proKey,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.Ysoup.Rereminder",
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func setProUser(_ pro: Bool) {
        clearProState()
        if pro {
            UserDefaults.standard.set(true, forKey: Self.proKey)
        }
    }

    @discardableResult
    private func insert(mainSeconds: Int, offsets: [Int], name: String = "T") -> TimerTemplate {
        let t = TimerTemplate(name: name, mainSeconds: mainSeconds, prealertOffsetsSec: offsets)
        context.insert(t)
        try? context.save()
        return t
    }

    private func save(mainSec: Int, offsets: [Int]) -> Bool {
        service.saveIfNeeded(
            mainSec: mainSec,
            offsets: offsets,
            prealertMessages: [:],
            finishMessage: nil
        )
    }

    // MARK: - 무료 사용자

    /// 제보의 정체 — 무료 사용자가 타이머를 시작하면 갖고 있던 템플릿이 전부 사라졌다
    func test_freeUser_keepsExistingTemplates() {
        insert(mainSeconds: 1800, offsets: [600, 300], name: "Presentation 30 min")
        insert(mainSeconds: 1500, offsets: [300, 60], name: "Study 25 min")

        let saved = save(mainSec: 900, offsets: [60])

        XCTAssertFalse(saved, "무료는 저장하지 않는다")
        XCTAssertEqual(service.fetchRecents().count, 2, "갖고 있던 템플릿은 그대로 남아야 한다")
    }

    /// 시작을 여러 번 해도 마찬가지다 (`applyCurrentSettings` 는 시작마다 불린다)
    func test_freeUser_repeatedStarts_doNotWipeSeeds() {
        service.seedIfNeeded()
        let seeded = service.fetchRecents().count
        XCTAssertGreaterThan(seeded, 0, "시드가 심어져야 이후 검증이 의미가 있다")

        for minutes in [10, 20, 30] {
            _ = save(mainSec: minutes * 60, offsets: [60])
        }

        XCTAssertEqual(service.fetchRecents().count, seeded)
    }

    // MARK: - Pro 사용자

    func test_proUser_savesNewTemplate() {
        setProUser(true)

        let saved = save(mainSec: 900, offsets: [300, 60])

        XCTAssertTrue(saved)
        let recents = service.fetchRecents()
        XCTAssertEqual(recents.count, 1)
        XCTAssertEqual(recents.first?.mainSeconds, 900)
        XCTAssertEqual(recents.first?.prealertOffsetsSec, [60, 300], "저장은 오름차순으로 정규화된다")
    }

    // MARK: - 앱이 실제로 쓰는 저장소

    /// **저장이 아예 안 되던 진짜 원인을 막는 테스트.**
    ///
    /// iCloud(CloudKit) 엔타이틀먼트가 붙자 SwiftData 가 이 로컬 스토어에도 CloudKit 스키마
    /// 규칙(모든 속성 optional/기본값·관계 optional·unique 금지)을 적용했고, `Timer` 가 셋 다
    /// 어겨 **스토어가 통째로 로드에 실패**했다. 화면에는 아무 오류도 없이 그저 저장이 안 됐다.
    func test_appModelContainer_loadsRealStoreAndPersists() throws {
        let container = RereminderApp.sharedModelContainer

        // 메모리 폴백으로 떨어지면 아래 save 는 통과해 버린다 — 진짜 스토어인지 먼저 본다
        let configuration = try XCTUnwrap(container.configurations.first)
        XCTAssertFalse(configuration.isStoredInMemoryOnly, "실제 파일 스토어가 열려야 한다")
        XCTAssertNil(configuration.cloudKitContainerIdentifier,
                     "CloudKit 동기화가 켜지면 이 모델은 스토어를 열 수 없다")

        let context = ModelContext(container)
        let probe = TimerTemplate(name: "probe", mainSeconds: 123, prealertOffsetsSec: [60])
        let probeID = probe.id
        context.insert(probe)
        try context.save()   // 스토어가 안 열렸으면 여기서 끝난다

        let found = try context.fetch(
            FetchDescriptor<TimerTemplate>(predicate: #Predicate { $0.id == probeID })
        )
        XCTAssertEqual(found.count, 1, "저장한 것이 다시 읽혀야 한다")

        context.delete(probe)
        try context.save()
    }

    /// 중복은 맨 앞 하나가 아니라 **전체**와 견준다 — A·B 를 번갈아 쓰면 복사본이 쌓였다
    func test_proUser_duplicateDeeperInList_isNotSavedAgain() {
        setProUser(true)
        insert(mainSeconds: 900, offsets: [300, 60], name: "A")
        insert(mainSeconds: 1200, offsets: [60], name: "B")   // 이쪽이 맨 앞

        let saved = save(mainSec: 900, offsets: [300, 60])    // A 와 같은 설정

        XCTAssertTrue(saved, "이미 템플릿으로 남아 있으므로 저장된 것과 같다")
        XCTAssertEqual(service.fetchRecents().count, 2, "복사본이 생기면 안 된다")
    }
}
