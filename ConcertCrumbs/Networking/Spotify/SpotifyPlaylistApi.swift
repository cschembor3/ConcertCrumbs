//
//  SpotifyPlaylistApi.swift
//  ConcertCrumbs
//
//  Created by Connor Schembor on 5/23/26.
//

import Foundation

protocol SpotifyPlaylistApiInterface {
    func getCurrentUser() async throws -> SpotifyUser
    func createPlaylist(userId: String, name: String) async throws -> SpotifyPlaylist
    func addTracks(_ uris: [String], to playlistId: String) async throws
}

struct SpotifyPlaylistApi: SpotifyPlaylistApiInterface {

    private static let baseUrl = "https://api.spotify.com/v1"
    private static let maxTracksPerRequest = 100

    private let client: SpotifyNetworkClientInterface

    init(client: SpotifyNetworkClientInterface = SpotifyUserNetworkClient()) {
        self.client = client
    }

    func getCurrentUser() async throws -> SpotifyUser {
        guard let url = URL(string: "\(Self.baseUrl)/me") else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = RequestType.get.description

        let data = try await client.perform(request)
        return try JSONDecoder().decode(SpotifyUser.self, from: data)
    }

    func createPlaylist(userId: String, name: String) async throws -> SpotifyPlaylist {
        guard let url = URL(string: "\(Self.baseUrl)/users/\(userId)/playlists") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = RequestType.post.description
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CreatePlaylistBody(name: name))

        let data = try await client.perform(request)
        return try JSONDecoder().decode(SpotifyPlaylist.self, from: data)
    }

    func addTracks(_ uris: [String], to playlistId: String) async throws {
        guard let url = URL(string: "\(Self.baseUrl)/playlists/\(playlistId)/tracks") else {
            throw URLError(.badURL)
        }

        for batch in uris.batched(by: Self.maxTracksPerRequest) {
            var request = URLRequest(url: url)
            request.httpMethod = RequestType.post.description
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AddTracksBody(uris: batch))
            _ = try await client.perform(request)
        }
    }
}

// MARK: - Request Bodies

private struct CreatePlaylistBody: Encodable {
    let name: String
    let isPublic: Bool = false

    enum CodingKeys: String, CodingKey {
        case name
        case isPublic = "public"
    }
}

private struct AddTracksBody: Encodable {
    let uris: [String]
}

// MARK: - Response Models

struct SpotifyUser: Codable {
    let id: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

struct SpotifyPlaylist: Codable, Identifiable {
    let id: String
    let name: String
    let externalUrls: ExternalUrls

    struct ExternalUrls: Codable {
        let spotify: String
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case externalUrls = "external_urls"
    }
}

// MARK: - Helpers

private extension Array {
    func batched(by size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
