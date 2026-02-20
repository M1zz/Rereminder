//
//  AppName.swift
//  Rereminder
//
//  앱 이름 중앙 관리
//  영어: Rereminder / 한국어: 두번알림
//  노티, Paywall, UI 전체에서 이 값을 사용
//

import Foundation

enum AppName {
    /// 로컬라이즈된 앱 이름 (영어: Rereminder, 한국어: 두번알림)
    static let display = String(localized: "app_name", defaultValue: "Rereminder")

    /// 노티피케이션 제목용
    static let notification = String(localized: "app_name_notification", defaultValue: "Rereminder Timer")

    /// Pro 이름
    static let pro = String(localized: "app_name_pro", defaultValue: "Rereminder Pro")
}
