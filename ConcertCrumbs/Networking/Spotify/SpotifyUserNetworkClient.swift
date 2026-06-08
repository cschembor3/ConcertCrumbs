//
//  SpotifyUserNetworkClient.swift
//  ConcertCrumbs
//
//  Created by Connor Schembor on 5/23/26.
//

import Foundation

struct SpotifyUserNetworkClient: SpotifyNetworkClientInterface {

    enum SpotifyUserNetworkError: Error {
        case unauthorized
        case requestFailed(statusCode: Int)
    }

    private let authService: SpotifyUserAuthServiceInterface
    private let session: URLSession

    init(
        authService: SpotifyUserAuthServiceInterface = SpotifyUserAuthService(),
        session: URLSession = .shared
    ) {
        self.authService = authService
        self.session = session
    }

    func perform(_ request: URLRequest) async throws -> Data {
        let token = try await authService.getValidUserToken()
        let (data, response) = try await session.data(for: authorized(request, token: token))

        if let statusCode = (response as? HTTPURLResponse)?.statusCode {
            if statusCode == 401 {
                let newToken = try await authService.refreshUserToken()
                let (retryData, retryResponse) = try await session.data(for: authorized(request, token: newToken))

                if (retryResponse as? HTTPURLResponse)?.statusCode == 401 {
                    throw SpotifyUserNetworkError.unauthorized
                }

                return retryData
            } else if !(200..<300).contains(statusCode) {
                throw SpotifyUserNetworkError.requestFailed(statusCode: statusCode)
            }
        }

        return data
    }
}

private extension SpotifyUserNetworkClient {

    func authorized(_ request: URLRequest, token: String) -> URLRequest {
        var authorized = request
        authorized.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return authorized
    }
}
