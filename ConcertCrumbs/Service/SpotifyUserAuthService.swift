//
//  SpotifyUserAuthService.swift
//  ConcertCrumbs
//
//  Created by Connor Schembor on 5/23/26.
//

import AuthenticationServices
import Foundation

protocol SpotifyUserAuthServiceInterface {
    func login() async throws
    func getValidUserToken() async throws -> String
    @discardableResult func refreshUserToken() async throws -> String
}

enum SpotifyUserAuthError: Error {
    case notAuthenticated
    case invalidCallback
}

final class SpotifyUserAuthService: NSObject, SpotifyUserAuthServiceInterface {

    private enum Keys {
        static let accessToken = "spotify.user_access_token"
        static let refreshToken = "spotify.user_refresh_token"
        static let tokenExpiry = "spotify.user_token_expiry"
    }

    private static let redirectUri = "concertcrumbs://spotify-callback"
    private static let scopes = "playlist-modify-public playlist-modify-private"
    private static let expiryBuffer: TimeInterval = 60

    private let api: SpotifyAuthApiInterface
    private let keychain: KeychainHelperInterface
    private let userDefaults: UserDefaults

    // Retained for the duration of the auth session
    private var authSession: ASWebAuthenticationSession?

    init(
        api: SpotifyAuthApiInterface = SpotifyAuthApi(),
        keychain: KeychainHelperInterface = KeychainHelper(),
        userDefaults: UserDefaults = .standard
    ) {
        self.api = api
        self.keychain = keychain
        self.userDefaults = userDefaults
    }

    func getValidUserToken() async throws -> String {
        if let token = keychain.read(forKey: Keys.accessToken), !isTokenExpired() {
            return token
        }

        if let refreshToken = keychain.read(forKey: Keys.refreshToken) {
            return try await refresh(using: refreshToken)
        }

        throw SpotifyUserAuthError.notAuthenticated
    }

    @discardableResult
    func refreshUserToken() async throws -> String {
        guard let refreshToken = keychain.read(forKey: Keys.refreshToken) else {
            throw SpotifyUserAuthError.notAuthenticated
        }
        return try await refresh(using: refreshToken)
    }

    func login() async throws {
        let verifier = SpotifyPKCE.generateCodeVerifier()
        let challenge = SpotifyPKCE.codeChallenge(for: verifier)

        let code = try await presentAuthSession(challenge: challenge)
        let tokenResponse = try await api.exchangeAuthCode(
            code,
            codeVerifier: verifier,
            redirectUri: Self.redirectUri
        )

        try storeTokens(from: tokenResponse)
    }
}

// MARK: - Private

private extension SpotifyUserAuthService {

    @MainActor
    func presentAuthSession(challenge: String) async throws -> String {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: Secrets.Spotify.clientId),
            URLQueryItem(name: "redirect_uri", value: Self.redirectUri),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: Self.scopes),
        ]

        guard let url = components?.url else { throw URLError(.badURL) }

        let callbackUrl: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "concertcrumbs"
            ) { callbackUrl, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let callbackUrl {
                    continuation.resume(returning: callbackUrl)
                } else {
                    continuation.resume(throwing: SpotifyUserAuthError.invalidCallback)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.authSession = session
            session.start()
        }

        authSession = nil

        guard let code = URLComponents(url: callbackUrl, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value
        else {
            throw SpotifyUserAuthError.invalidCallback
        }

        return code
    }

    func refresh(using refreshToken: String) async throws -> String {
        let response = try await api.refreshUserToken(refreshToken)
        try storeTokens(from: response)
        return response.accessToken
    }

    func storeTokens(from response: SpotifyUserTokenResponse) throws {
        try keychain.save(response.accessToken, forKey: Keys.accessToken)
        try keychain.save(response.refreshToken, forKey: Keys.refreshToken)

        let expiry = Date().timeIntervalSinceReferenceDate
            + Double(response.expiresIn)
            - Self.expiryBuffer
        userDefaults.set(expiry, forKey: Keys.tokenExpiry)
    }

    func isTokenExpired() -> Bool {
        let expiry = userDefaults.double(forKey: Keys.tokenExpiry)
        guard expiry > 0 else { return true }
        return Date().timeIntervalSinceReferenceDate >= expiry
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SpotifyUserAuthService: ASWebAuthenticationPresentationContextProviding {

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
