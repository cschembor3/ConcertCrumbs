//
//  KeychainHelper.swift
//  ConcertCrumbs
//
//  Created by Connor Schembor on 5/19/26.
//

import Foundation
import Security

protocol KeychainHelperInterface {
    func save(_ value: String, forKey key: String) throws
    func read(forKey key: String) -> String?
    func delete(forKey key: String)
}

struct KeychainHelper: KeychainHelperInterface {

    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
    }

    func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else { return }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]

        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            let attributes: [CFString: Any] = [kSecValueData: data]
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        } else {
            var newItem = query
            newItem[kSecValueData] = data
            let status = SecItemAdd(newItem as CFDictionary, nil)
            guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        }
    }

    func read(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }

        return String(data: data, encoding: .utf8)
    }

    func delete(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
