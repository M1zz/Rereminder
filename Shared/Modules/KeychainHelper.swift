//
//  KeychainHelper.swift
//  Rereminder
//
//  구매 상태를 Keychain에 저장 (앱 삭제 후 재설치에도 유지)
//

import Foundation
import Security

enum KeychainHelper {

    /// Bool 값을 Keychain에 저장. 실패 시 false 반환.
    @discardableResult
    static func save(key: String, value: Bool) -> Bool {
        let data = Data([value ? 1 : 0])

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.Ysoup.Rereminder",
        ]

        // 기존 항목 삭제
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecSuccess {
            return true
        }

        // 실패 시 1회 재시도 (삭제 후 다시 저장)
        SecItemDelete(query as CFDictionary)
        let retryStatus = SecItemAdd(addQuery as CFDictionary, nil)
        return retryStatus == errSecSuccess
    }

    /// Keychain에서 Bool 값 로드
    static func load(key: String) -> Bool? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.Ysoup.Rereminder",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data, !data.isEmpty else {
            return nil
        }

        return data[0] == 1
    }

    /// Keychain 항목 삭제
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.Ysoup.Rereminder",
        ]
        SecItemDelete(query as CFDictionary)
    }
}
