//
//  RereminderFlags.swift
//  Rereminder
//
//  원격 킬스위치 플래그 — LeeoKit(LeeoRemoteFlags)이 CloudKit RemoteFlags 레코드에서 읽는다.
//
//  ⚠️ rawValue = CloudKit 필드명 계약이다 — 다르면 아무리 꺼도 켜진 채로 도는 조용한 실패. 변경 금지.
//  ⚠️ 조회 실패 = 켬(가용성 우선), 갱신은 6시간 쓰로틀 → 즉시 전파되지 않는다.
//
//  CloudKit Dashboard 설정(1회): 레코드 타입 RemoteFlags, recordName "flags_com.xa.toki",
//  각 플래그를 Int64(1=켬/0=끔) 필드로 만들고 Production 배포. 필드가 없으면 켬으로 동작.
//

import Foundation
import LeeoKit

enum RereminderFlag: String, LeeoRemoteFlag, CaseIterable {
    /// 익명 사용 통계 전송(스냅샷·이벤트). 끄면 수집 즉시 중단.
    case usageReportingEnabled
    /// MetricKit 크래시/행 수집(LeeoDiagnostics). 끄면 다음 실행부터 업로드 중단.
    case diagnosticsEnabled
    /// iCloud KVS 타이머 동기화(iPhone ↔ Mac). 끄면 다음 실행부터 초기화 생략.
    case cloudSyncEnabled
}
