//
//  UserDefaultsService.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 9/3/22.
//

import Foundation

class UserDefaultsService: UserDefaultsServiceProtocol {

    func getValue<T>(for key: String) -> T? {
        return UserDefaults.standard.value(forKey: key) as? T
    }

    func setValue<T>(_ value: T, for key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

extension UserDefaultsServiceProtocol {
    func valueExists(for key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) != nil
    }
}

protocol UserDefaultsServiceProtocol {
    func getValue<T>(for key: String) -> T?
    func setValue<T>(_ value: T, for key: String)
}

struct UserDefaultsValues {
    static let usernameKey = "username"
}
