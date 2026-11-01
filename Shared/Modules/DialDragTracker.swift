//
//  DialDragTracker.swift
//  Rereminder
//
//  다이얼 노브를 끄는 동안의 **각도 추적** — 메인 앱과 App Clip 이 같은 규칙으로 돌게 하는
//  단일 소스. 흰 핸들과 종 노브, 두 앱, 모두 이 하나를 쓴다.
//
//  왜 따로 뺐나: 이 산술은 네 군데(메인 다이얼·메인 종·클립 다이얼·클립 종)에 같은 모양으로
//  복사돼 있었고, 그 규칙 하나하나가 **실제로 났던 버그의 수리 흔적**이다. 복사본이 흩어져
//  있으면 다음에 한 곳만 고쳐 놓고 고쳤다고 믿게 된다.
//
//  지키는 규칙 셋 (CLAUDE.md "다이얼 드래그 (튐 방지)" 와 같은 내용):
//
//  ① **잡은 순간의 어긋남(grab delta)을 기억한다.** 손가락은 노브 한가운데를 짚지 않는데,
//     히트 영역이 지름 2.8 × 선 두께라 최대 13° ≈ 130초까지 벌어진다. 이걸 빼지 않으면
//     집는 순간 노브가 손끝으로 순간이동한다.
//  ② **각도는 이어 붙인다**(`TimeMapper.unwrappedAngle`). 359° → 1° 를 +2° 로 읽어야
//     한 바퀴를 넘길 때 값이 뒤집히지 않는다.
//  ③ ⚠️ **자르는 건 마지막에 한 번만.** 잘린 값을 다음 계산에 되먹이면, 손가락이 허용 범위를
//     크게 벗어났을 때 최단 방향이 뒤집혀 반대편으로 튄다(종을 총 시간 너머로 계속 끌면 0 으로,
//     흰 핸들을 0 아래로 끌면 30분으로 튀던 문제). 그래서 `fingerAngle` 은 **자르지 않은 값**을
//     들고 있고, 자르기는 `update` 의 반환값에서만 일어난다.
//
//  좌표는 회전에 휘둘리지 않는 **고정 좌표계**에서 읽어 넘길 것 — 부르는 쪽이 그 좌표계의
//  중심(`center`)을 계산해 준다(클립은 히트 여백만큼 원점이 밀려 있어 중심도 다르다).
//

import CoreGraphics

struct DialDragTracker {

    /// 자르지 않은 손가락 각도. ⚠️ 여기에 잘린 값을 넣지 말 것 — 규칙 ③.
    private(set) var fingerAngle: Double = 0

    /// 잡은 순간 노브와 손가락이 어긋나 있던 만큼 — 규칙 ①.
    private(set) var grabDelta: Double = 0

    /// 지금 끌고 있는가. 종 노브처럼 "어느 것을 끄는지"까지 구분해야 하면
    /// 부르는 쪽이 식별자를 따로 들고, 이 값은 흰 핸들처럼 하나뿐인 노브가 쓴다.
    private(set) var isActive = false

    init() {}

    /// 잡는 순간. `knobAngle` 은 **지금 노브가 그려져 있는** 각도다.
    mutating func begin(at startLocation: CGPoint, center: CGPoint, knobAngle: Double) {
        let grabbed = TimeMapper.ringAngle(at: startLocation, center: center)
        fingerAngle = grabbed
        grabDelta = knobAngle - grabbed
        isActive = true
    }

    /// 끄는 동안. 반환값이 곧 **그릴 각도**다 (자르기는 여기서 한 번만 — 규칙 ③).
    mutating func update(to location: CGPoint, center: CGPoint, maxAngle: Double) -> Double {
        let finger = TimeMapper.ringAngle(at: location, center: center)
        fingerAngle = TimeMapper.unwrappedAngle(finger, continuing: fingerAngle)
        return Self.clamped(fingerAngle + grabDelta, maxAngle: maxAngle)
    }

    /// 자르기 전 각도 — 손가락이 허용 범위를 얼마나 넘었는지 볼 때 쓴다.
    var rawAngle: Double { fingerAngle + grabDelta }

    /// 손을 뗐을 때.
    mutating func end() {
        isActive = false
    }

    /// 허용 범위로 자른다. `maxAngle` 이 음수여도(총 시간이 10초 미만) 0 아래로 내려가지 않는다.
    static func clamped(_ angle: Double, maxAngle: Double) -> Double {
        max(0, min(angle, max(0, maxAngle)))
    }

    /// 종이 한계까지 왔는데 손가락이 시계 방향으로 더 간다 + 흰 핸들이 종의 잡는 자리 안에 겹쳐 있다
    /// → 사람이 잡으려던 것은 핸들이다. 짧은 타이머(30초 + 20초 알림)는 둘이 3° 안에 붙어 있어,
    /// 위에 있는 종이 터치를 다 가져가면 시간을 늘릴 길이 없다.
    static func shouldHandOffToDial(rawAngle: Double, maxAlertAngle: Double,
                                    bellAngle: Double, dialAngle: Double, grabSpanDegrees: Double) -> Bool {
        abs(dialAngle - bellAngle) < grabSpanDegrees && rawAngle > maxAlertAngle + handOffSlopDegrees
    }

    private static let handOffSlopDegrees: Double = 1.5

    /// 종 노브가 갈 수 있는 최대 각도 — 알림은 총 시간보다 **10초 앞**이어야 의미가 있다.
    /// 메인 앱과 클립이 같은 여유를 쓰도록 여기 둔다.
    static func maxAlertAngle(totalSeconds: Int) -> Double {
        Double(totalSeconds - 10) / TimeMapper.secondsPerDegree
    }
}
