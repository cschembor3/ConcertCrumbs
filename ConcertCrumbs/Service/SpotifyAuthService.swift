//
//  SpotifyAuthService.swift
//  ConcertCrumbs
//
//  Created by Connor Schembor on 5/19/26.
//

import Foundation

protocol SpotifyAuthServiceInterface {
    func getValidToken() async throws -> String
    @discardableResult func refreshToken() async throws -> String
}

final class SpotifyAuthService: SpotifyAuthServiceInterface {

    private enum Keys {
        static let accessToken = "spotify.access_token"
        static let tokenExpiry = "spotify.token_expiry"
    }

    private static let expiryBuffer: TimeInterval = 60

    private let api: SpotifyApiInterface
    private let keychain: KeychainHelperInterface
    private let userDefaults: UserDefaults

    init(
        api: SpotifyApiInterface = SpotifyApi(),
        keychain: KeychainHelperInterface = KeychainHelper(),
        userDefaults: UserDefaults = .standard
    ) {
        self.api = api
        self.keychain = keychain
        self.userDefaults = userDefaults
    }

    func getValidToken() async throws -> String {
        if let token = keychain.read(forKey: Keys.accessToken), !isTokenExpired() {
            return token
        }
        return try await refreshToken()
    }

    @discardableResult
    func refreshToken() async throws -> String {
        let response = try await api.fetchAuthToken()

        try keychain.save(response.accessToken, forKey: Keys.accessToken)

        let expiry =
            Date().timeIntervalSinceReferenceDate
            + Double(response.expiresIn)
            - Self.expiryBuffer
        userDefaults.set(expiry, forKey: Keys.tokenExpiry)

        return response.accessToken
    }
}

extension SpotifyAuthService {

    fileprivate func isTokenExpired() -> Bool {
        let expiry = userDefaults.double(forKey: Keys.tokenExpiry)
        guard expiry > 0 else { return true }
        return Date().timeIntervalSinceReferenceDate >= expiry
    }
}
