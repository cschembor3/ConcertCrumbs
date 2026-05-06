//
//  SetlistApi.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 5/28/22.
//

import Foundation

protocol SetlistApiInterface {
    func getArtistSetlists(id: String, page: Int) async throws -> ArtistSetlistResponse
    func getSetlist(id: String) async throws -> SetlistResponse
    func getConcertsAttended(for username: String) async throws -> ArtistSetlistResponse
    func searchArtists(artistName: String, page: Int) async throws -> ArtistSearchResponse
}

struct SetlistApi: SetlistApiInterface {

    private static let baseUrl = "https://api.setlist.fm/rest/1.0"
    private static let acceptHeader: (header: String, responseType: String) = ("Accept", "application/json")
    private static let apiKeyHeader: (header: String, apiKey: String) = ("x-api-key", Secrets.setlistApiKey)

    func searchArtists(artistName: String, page: Int = 1) async throws -> ArtistSearchResponse {

        let encodedName = artistName.replacing(" ", with: "%20")
        guard let url = URL(string: "\(SetlistApi.baseUrl)/search/artists?p=\(page)&sort=relevance&artistName=\(encodedName)") else {
            throw URLError(.badURL)
        }

        let request = constructGetRequest(from: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ArtistSearchResponse.self, from: data)
    }

    func getArtistSetlists(id: String, page: Int = 1) async throws -> ArtistSetlistResponse {

        let id = id.lowercased()

        guard let url = URL(string: "\(SetlistApi.baseUrl)/artist/\(id)/setlists?p=\(page)") else {
            throw URLError(.badURL)
        }

        let request = constructGetRequest(from: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ArtistSetlistResponse.self, from: data)
    }

    func getSetlist(id: String) async throws -> SetlistResponse {

        guard let url = URL(string: "\(SetlistApi.baseUrl)/setlist/\(id)") else {
            throw URLError(.badURL)
        }

        let request = constructGetRequest(from: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(SetlistResponse.self, from: data)
    }

    func getConcertsAttended(for username: String) async throws -> ArtistSetlistResponse {

        guard let url = URL(string: "\(SetlistApi.baseUrl)/user/\(username)/attended?p=1") else {
            throw URLError(.badURL)
        }

        let request = constructGetRequest(from: url)
        let (data,  _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ArtistSetlistResponse.self, from: data)
    }
}

private extension SetlistApi {

    func constructGetRequest(from url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = RequestType.get.description
        request.addValue(Self.acceptHeader.responseType, forHTTPHeaderField: Self.acceptHeader.header)
        request.addValue(Self.apiKeyHeader.apiKey, forHTTPHeaderField: Self.apiKeyHeader.header)
        return request
    }
}

enum RequestType: CustomStringConvertible {
    case delete
    case get
    case post
    case put

    var description: String {
        switch self {
        case .delete:
            return "DELETE"
        case .get:
            return "GET"
        case .post:
            return "POST"
        case .put:
            return "PUT"
        }
    }
}

struct ArtistSearchResponse: Codable {
    let artist: [ArtistSearch]?
    let total: Int?
    let page: Int?
    let itemsPerPage: Int?
}

struct ArtistSearch: Codable, Equatable, Identifiable {
    let id: UUID
    let ticketMasterId: Int?
    let name: String
    let sortName: String
    let disambiguation: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case id = "mbid"
        case ticketMasterId = "tmid"
        case name
        case sortName
        case disambiguation
        case url
    }
}

struct ArtistSetlistResponse: Codable {
    let type: String?
    let itemsPerPage: Int?
    let page: Int?
    let total: Int?
    let setlist: [SetlistResponse]
}

struct SetlistResponse: Codable, Hashable, Identifiable {
    let id: String
    let versionId: String
    let eventDate: String
    let artist: Artist
    let venue: Venue
    let tour: Tour?
    let sets: Sets
    let url: String
}

struct Artist: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "mbid"
        case name
    }
}

struct Venue: Codable, Hashable {
    let id: String
    let name: String?
    let city: Location
}

struct Location: Codable, Hashable {
    let id: String
    let name: String?
    let state: String?
    let stateCode: String?
    let country: Country?
}

struct Country: Codable, Hashable {
    let code: String?
    let name: String?
}

struct Tour: Codable, Hashable {
    let name: String?
}

struct Sets: Codable, Hashable {
    let set: [SetInfo]
}

struct SetInfo: Codable, Hashable {
    let encore: Int?
    let song: [Song]?
}

struct Song: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        self.init(name: name)
    }

    init(name: String) {
        self.name = name
        self.id = UUID()
    }

    enum CodingKeys: String, CodingKey {
        case name
    }
}

extension Data {
    func prettyPrint() {
        if let json = try? JSONSerialization.jsonObject(with: self, options: .mutableContainers),
           let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            print(String(decoding: jsonData, as: UTF8.self))
        } else {
            print("json data malformed")
        }
    }
}
