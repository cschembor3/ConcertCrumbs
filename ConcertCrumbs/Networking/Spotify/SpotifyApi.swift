//
//  SpotifyApi.swift
//  ConcertCrumbs
//
//  Created by Connor Schembor on 5/11/26.
//

import Foundation

protocol SpotifyApiInterface {
    func fetchAuthToken() async throws -> SpotifyAuthResponse
}

struct SpotifyApi: SpotifyApiInterface {

    private static let authBaseUrl = "https://accounts.spotify.com"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchAuthToken() async throws -> SpotifyAuthResponse {
        guard let url = URL(string: "\(Self.authBaseUrl)/api/token") else {
            throw URLError(.badURL)
        }

        let body = [
            "grant_type": "client_credentials",
            "client_id": Secrets.Spotify.clientId,
            "client_secret": Secrets.Spotify.clientSecret,
        ]

        let request = constructPostRequest(from: url, formBody: body)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(SpotifyAuthResponse.self, from: data)
    }
}

extension SpotifyApi {

    fileprivate func constructPostRequest(from url: URL, formBody: [String: String]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = RequestType.post.description
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody =
            formBody
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        return request
    }
}

struct SpotifyAuthResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}
