//
//  SpotifyNetworkClient.swift
//  ConcertCrumbs
//
//  Created by Connor Schembor on 5/19/26.
//

import Foundation

protocol SpotifyNetworkClientInterface {
    func perform(_ request: URLRequest) async throws -> Data
}

struct SpotifyNetworkClient: SpotifyNetworkClientInterface {

    enum SpotifyNetworkError: Error {
        case unauthorized
        case requestFailed(statusCode: Int)
    }

    private let authService: SpotifyAuthServiceInterface
    private let session: URLSession

    init(
        authService: SpotifyAuthServiceInterface = SpotifyAuthService(),
        session: URLSession = .shared
    ) {
        self.authService = authService
        self.session = session
    }

    func perform(_ request: URLRequest) async throws -> Data {
        let token = try await authService.getValidToken()
        let (data, response) = try await session.data(for: authorized(request, token: token))

        if let statusCode = (response as? HTTPURLResponse)?.statusCode {
            if statusCode == 401 {
                let newToken = try await authService.refreshToken()
                let (retryData, retryResponse) = try await session.data(for: authorized(request, token: newToken))

                let retryStatus = (retryResponse as? HTTPURLResponse)?.statusCode ?? 0
                if retryStatus == 401 {
                    throw SpotifyNetworkError.unauthorized
                } else if !(200..<300).contains(retryStatus) {
                    throw SpotifyNetworkError.requestFailed(statusCode: retryStatus)
                }

                return retryData
            } else if !(200..<300).contains(statusCode) {
                throw SpotifyNetworkError.requestFailed(statusCode: statusCode)
            }
        }

        return data
    }
}

private extension SpotifyNetworkClient {

    func authorized(_ request: URLRequest, token: String) -> URLRequest {
        var authorized = request
        authorized.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return authorized
    }
}
