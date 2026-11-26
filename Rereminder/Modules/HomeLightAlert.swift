//
//  HomeLightAlert.swift
//  Rereminder
//
//  알림이 울릴 때 집의 조명 색을 바꾼다 (HomeKit). 제보(2026-11-26): "집안의 조명색의 변화로 내가 해야 할 일 인지하기".
//
//  ⚠️ **HomeKit 은 앱이 앞에 떠 있을 때만 기기를 조작하게 해 준다.** 그래서 이건 앱 화면에서 울리는 알림
//     (`TimerEngine.onPreAlert`·`onFinish`)에만 붙는다. 타이머가 도는 동안 화면을 켜 두므로(`isIdleTimerDisabled`)
//     대부분은 그 경우다. 화면이 꺼진 뒤를 맡으려면 홈 허브 자동화(`HMTimerTrigger`)가 필요한데, 1분 단위로만
//     걸리고 최대 1분 늦게 돈다 — 1단계에서 쓰는 사람이 있는지 본 뒤에 정한다.
//  ⚠️ 색은 **이제 시작되는 구간의 색**이다(`SectionPalette` 순서와 같은 표). 링·문장·조명이 같은 색이어야
//     "방이 파래졌다 = 2구간"이 읽힌다. 끝나면 빨강(앱의 정지 색).
//  ⚠️ 기본값은 꺼짐. 권한은 설정에서 켜는 순간 묻는다(AlarmKit 과 같은 규칙) — 타이머를 거는 순간 시스템 창을 띄우지 않는다.
//  ⚠️ 바꾸기 전 값을 떠 두었다가 돌려놓는다. 잠깐 바뀌는 방식은 몇 초 뒤에, 그대로 두는 방식은 타이머를 멈출 때.
//

import SwiftUI
#if canImport(HomeKit) && !os(visionOS)
import HomeKit
#endif

// MARK: - 설정

enum HomeLightMode: String, CaseIterable, Identifiable {
    /// 몇 초 그 색으로 바뀌었다가 원래대로
    case flash
    /// 다음 알림까지 그 색으로 남는다 — 방 색이 곧 지금 구간이다
    case stay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash: String(localized: "Briefly, then back")
        case .stay: String(localized: "Until the next alert")
        }
    }
}

enum HomeLightSettings {
    static let enabledKey = "homeLight.enabled"
    static let lightIDsKey = "homeLight.lightIDs"
    static let modeKey = "homeLight.mode"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    static var mode: HomeLightMode {
        HomeLightMode(rawValue: UserDefaults.standard.string(forKey: modeKey) ?? "") ?? .flash
    }

    static var selectedIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: lightIDsKey) ?? []) }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: lightIDsKey) }
    }

    /// 엔타이틀먼트(`com.apple.developer.homekit`)를 앱에 넣었나.
    /// ⚠️ 포털의 App ID(com.xa.toki)에 HomeKit 을 켜기 전에 엔타이틀먼트를 넣으면 기기·맥 서명이 실패해
    ///    배포가 막힌다(2026-11-26 확인, `-allowProvisioningUpdates` 로도 저절로 켜지지 않는다).
    ///    순서: 포털에서 켜기 → 두 엔타이틀먼트 파일에 키 추가 → 이 값을 true. `docs/OPERATIONS_CHECKLIST.md` 10번.
    static let entitlementReady = true

    /// 설정에 이 기능을 보일까 (visionOS 는 뺀다).
    static var isSupported: Bool {
        #if canImport(HomeKit) && !os(visionOS)
        entitlementReady
        #else
        false
        #endif
    }
}

// MARK: - 색 (순수 계산)

enum HomeLightPlan {
    /// 전구에 보낼 색. 색상(도), 채도(%).
    struct Shade: Equatable {
        let hue: Double
        let saturation: Double
    }

    /// `SectionPalette` 의 순서(파랑·초록·보라·청록·분홍·남색)와 같은 표.
    /// SwiftUI 색은 모드마다 바뀌어 전구 값으로 옮기면 흔들린다 — 전구용은 고정값으로 둔다.
    static let sectionShades: [Shade] = [
        Shade(hue: 211, saturation: 100),   // blue
        Shade(hue: 135, saturation: 85),    // green
        Shade(hue: 285, saturation: 80),    // purple
        Shade(hue: 188, saturation: 90),    // teal
        Shade(hue: 345, saturation: 75),    // pink
        Shade(hue: 241, saturation: 85),    // indigo
    ]

    /// 끝 — 앱의 정지 색(빨강).
    static let finish = Shade(hue: 0, saturation: 100)

    /// 잠깐 바뀌는 방식에서 그 색을 몇 초 두나.
    static let flashHold: TimeInterval = 4

    static func shade(forSection index: Int) -> Shade {
        sectionShades[abs(index) % sectionShades.count]
    }

    /// 이 종이 울리면 시작되는 구간 — 종이 끝내는 구간(`bellSectionIndex`)의 다음.
    static func sectionStarting(afterBell seconds: Int, among offsets: [Int]) -> Int {
        TimerSections.bellSectionIndex(of: seconds, among: Set(offsets)) + 1
    }
}

// MARK: - 조명 제어

@MainActor
final class HomeLightController: NSObject, ObservableObject {
    static let shared = HomeLightController()

    struct Light: Identifiable, Equatable {
        let id: String
        let name: String
        let room: String?
        /// 색을 바꿀 수 있나. 아니면 깜빡이기만 한다.
        let supportsColor: Bool
    }

    enum Status: Equatable {
        case idle          // 아직 HomeKit 을 열지 않았다
        case loading
        case denied
        case ready
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lights: [Light] = []

    #if canImport(HomeKit) && !os(visionOS)
    private var manager: HMHomeManager?
    /// 이번 실행에서 바꾸기 전 값. 서비스 id → (특성 종류 → 값)
    private var saved: [String: [String: Any]] = [:]
    private var restoreTask: Task<Void, Never>?
    #endif

    /// HomeKit 을 연다. 처음이면 시스템이 권한을 묻는다 — 설정에서 켤 때만 부를 것.
    func activate() {
        #if canImport(HomeKit) && !os(visionOS)
        guard HomeLightSettings.isSupported else { return }
        guard manager == nil else { refresh(); return }
        status = .loading
        let m = HMHomeManager()
        m.delegate = self
        manager = m
        #endif
    }

    /// 앱이 뜰 때 이미 켜 둔 사람이면 미리 연다(권한은 이미 받았다).
    func activateIfEnabled() {
        if HomeLightSettings.isEnabled { activate() }
    }

    // MARK: 알림에서 부르는 자리

    /// 예비 알림 — 이제 시작되는 구간의 색으로.
    func bellRang(seconds: Int, offsets: [Int]) {
        guard HomeLightSettings.isSupported, HomeLightSettings.isEnabled else { return }
        let section = HomeLightPlan.sectionStarting(afterBell: seconds, among: offsets)
        show(HomeLightPlan.shade(forSection: section), mode: HomeLightSettings.mode)
    }

    /// 반복의 새 회 — 첫 구간의 색으로.
    func roundBegan() {
        guard HomeLightSettings.isSupported, HomeLightSettings.isEnabled else { return }
        show(HomeLightPlan.shade(forSection: 0), mode: HomeLightSettings.mode)
    }

    /// 끝 — 빨강. 그대로 두는 방식이면 타이머를 멈출 때까지 빨강이다.
    func finished() {
        guard HomeLightSettings.isSupported, HomeLightSettings.isEnabled else { return }
        show(HomeLightPlan.finish, mode: HomeLightSettings.mode)
    }

    /// 설정의 시험 버튼 — 방식과 무관하게 잠깐 바꿨다가 돌려놓는다.
    func test() {
        show(HomeLightPlan.shade(forSection: 1), mode: .flash)
    }

    /// 타이머를 멈췄다 — 바꾼 조명을 원래대로.
    func timerStopped() {
        #if canImport(HomeKit) && !os(visionOS)
        guard !saved.isEmpty else { return }
        restoreTask?.cancel()
        restoreTask = nil
        Task { await restore() }
        #endif
    }

    // MARK: 내부

    #if canImport(HomeKit) && !os(visionOS)
    private func refresh() {
        guard let manager else { return }
        if !manager.authorizationStatus.contains(.authorized),
           manager.authorizationStatus.contains(.determined) {
            status = .denied
            lights = []
            return
        }
        lights = manager.homes.flatMap { home in
            home.accessories.flatMap { accessory in
                accessory.services
                    .filter { $0.serviceType == HMServiceTypeLightbulb }
                    .map { service in
                        let types = Set(service.characteristics.map(\.characteristicType))
                        return Light(
                            id: service.uniqueIdentifier.uuidString,
                            name: service.name.isEmpty ? accessory.name : service.name,
                            room: accessory.room?.name,
                            supportsColor: types.contains(HMCharacteristicTypeHue)
                                && types.contains(HMCharacteristicTypeSaturation)
                        )
                    }
            }
        }
        .sorted { ($0.room ?? "", $0.name) < ($1.room ?? "", $1.name) }
        status = .ready
    }

    private var selectedServices: [HMService] {
        guard let manager else { return [] }
        let ids = HomeLightSettings.selectedIDs
        return manager.homes
            .flatMap(\.accessories)
            .flatMap(\.services)
            .filter { ids.contains($0.uniqueIdentifier.uuidString) }
    }

    private func characteristic(_ type: String, in service: HMService) -> HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == type }
    }

    private func show(_ shade: HomeLightPlan.Shade, mode: HomeLightMode) {
        guard HomeLightSettings.isSupported else { return }
        if manager == nil { activate() }
        let services = selectedServices
        guard !services.isEmpty else { return }
        restoreTask?.cancel()
        restoreTask = Task { [weak self] in
            guard let self else { return }
            for service in services {
                await self.apply(shade, to: service)
            }
            guard mode == .flash else { return }
            try? await Task.sleep(for: .seconds(HomeLightPlan.flashHold))
            guard !Task.isCancelled else { return }
            await self.restore()
        }
    }

    private func apply(_ shade: HomeLightPlan.Shade, to service: HMService) async {
        let id = service.uniqueIdentifier.uuidString
        let power = characteristic(HMCharacteristicTypePowerState, in: service)
        let brightness = characteristic(HMCharacteristicTypeBrightness, in: service)
        let hue = characteristic(HMCharacteristicTypeHue, in: service)
        let saturation = characteristic(HMCharacteristicTypeSaturation, in: service)

        // 바꾸기 전 값을 한 번만 떠 둔다 — 두 번째 알림에서 뜨면 첫 알림의 색이 "원래 색"이 된다.
        if saved[id] == nil {
            var snapshot: [String: Any] = [:]
            for c in [power, brightness, hue, saturation].compactMap({ $0 }) {
                try? await c.readValue()
                if let v = c.value { snapshot[c.characteristicType] = v }
            }
            saved[id] = snapshot
        }

        if let hue, let saturation {
            try? await power?.writeValue(true)
            try? await hue.writeValue(shade.hue)
            try? await saturation.writeValue(shade.saturation)
            try? await brightness?.writeValue(100)
        } else if let power {
            // 색이 없는 전구는 두 번 깜빡인다
            let wasOn = (saved[id]?[HMCharacteristicTypePowerState] as? Bool) ?? true
            for _ in 0..<2 {
                try? await power.writeValue(!wasOn)
                try? await Task.sleep(for: .milliseconds(600))
                try? await power.writeValue(wasOn)
                try? await Task.sleep(for: .milliseconds(600))
            }
        }
    }

    private func restore() async {
        let snapshot = saved
        saved = [:]
        guard let manager else { return }
        let services = manager.homes.flatMap(\.accessories).flatMap(\.services)
        for (id, values) in snapshot {
            guard let service = services.first(where: { $0.uniqueIdentifier.uuidString == id }) else { continue }
            // 색부터 돌려놓고 전원은 마지막에 — 꺼져 있던 전구가 색이 바뀐 채로 한 번 켜졌다 꺼지지 않게.
            for type in [HMCharacteristicTypeHue, HMCharacteristicTypeSaturation,
                         HMCharacteristicTypeBrightness, HMCharacteristicTypePowerState] {
                guard let value = values[type], let c = characteristic(type, in: service) else { continue }
                try? await c.writeValue(value)
            }
        }
    }
    #else
    private func show(_ shade: HomeLightPlan.Shade, mode: HomeLightMode) {}
    #endif
}

#if canImport(HomeKit) && !os(visionOS)
extension HomeLightController: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in self.refresh() }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        Task { @MainActor in self.refresh() }
    }
}
#endif
