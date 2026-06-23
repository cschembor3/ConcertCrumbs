//
//  SpotifyAuthApi.swift
//  ConcertCrumbs
//
//  Created by Connor Schembor on 5/11/26.
//

import Foundation

protocol SpotifyAuthApiInterface {
    func fetchAuthToken() async throws -> SpotifyAuthResponse
    func exchangeAuthCode(_ code: String, codeVerifier: String, redirectUri: String) async throws -> SpotifyUserTokenResponse
    func refreshUserToken(_ refreshToken: String) async throws -> SpotifyUserTokenResponse
}

struct SpotifyAuthApi: SpotifyAuthApiInterface {

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

    func exchangeAuthCode(_ code: String, codeVerifier: String, redirectUri: String) async throws -> SpotifyUserTokenResponse {
        guard let url = URL(string: "\(Self.authBaseUrl)/api/token") else {
            throw URLError(.badURL)
        }

        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectUri,
            "client_id": Secrets.Spotify.clientId,
            "code_verifier": codeVerifier,
        ]

        let request = constructPostRequest(from: url, formBody: body)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(SpotifyUserTokenResponse.self, from: data)
    }

    func refreshUserToken(_ refreshToken: String) async throws -> SpotifyUserTokenResponse {
        guard let url = URL(string: "\(Self.authBaseUrl)/api/token") else {
            throw URLError(.badURL)
        }

        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Secrets.Spotify.clientId,
        ]

        let request = constructPostRequest(from: url, formBody: body)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(SpotifyUserTokenResponse.self, from: data)
    }
}

extension SpotifyAuthApi {

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

struct SpotifyUserTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let scope: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

// MARK: - Music API

protocol SpotifyMusicApiInterface: Sendable {
    func searchTracks(query: String, limit: Int) async throws -> SpotifyTrackSearchResponse
}

struct SpotifyMusicApi: SpotifyMusicApiInterface {

    private static let baseUrl = "https://api.spotify.com/v1"

    private let client: SpotifyNetworkClientInterface

    init(client: SpotifyNetworkClientInterface = SpotifyNetworkClient()) {
        self.client = client
    }

    func searchTracks(query: String, limit: Int = 5) async throws -> SpotifyTrackSearchResponse {
        var components = URLComponents(string: "\(Self.baseUrl)/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components?.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = RequestType.get.description

        let data = try await client.perform(request)
        print(data.prettyPrint())
        return try JSONDecoder().decode(SpotifyTrackSearchResponse.self, from: data)
    }
}

// MARK: - Response Models

struct SpotifyTrackSearchResponse: Codable {
    let tracks: SpotifyPagingObject<SpotifyTrack>
}

struct SpotifyPagingObject<T: Codable>: Codable {
    let href: String
    let limit: Int
    let next: String?
    let offset: Int
    let previous: String?
    let total: Int
    let items: [T]
}

nonisolated struct SpotifyTrack: Codable, Identifiable {
    let id: String
    let name: String
    let uri: String
    let artists: [SpotifySimplifiedArtist]
    let album: SpotifySimplifiedAlbum
    let durationMs: Int
    let explicit: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, uri, artists, album, explicit
        case durationMs = "duration_ms"
    }
}

struct SpotifySimplifiedArtist: Codable, Identifiable {
    let id: String
    let name: String
    let uri: String
}

struct SpotifySimplifiedAlbum: Codable, Identifiable {
    let id: String
    let name: String
    let images: [SpotifyImage]
}

struct SpotifyImage: Codable {
    let url: String
    let height: Int?
    let width: Int?
}
