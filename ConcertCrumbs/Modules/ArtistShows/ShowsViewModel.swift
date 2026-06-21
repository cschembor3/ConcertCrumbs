//
//  ArtistShowsViewModel.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 2/4/23.
//

import Foundation
import Observation

@MainActor
@Observable
final class ArtistShowsViewModel {

    var shows = [ShowDisplayInfo]()
    private(set) var errorMessage: String? = nil
    private var page: Int = 1

    private let artist: (id: String, name: String)
    private let setlistApi: SetlistApiInterface
    init(
        artist: (id: String, name: String),
        setlistApi: SetlistApiInterface = SetlistApi()
    ) {
        self.artist = artist
        self.setlistApi = setlistApi
    }

    func fetch() async -> [ShowDisplayInfo] {
        self.page = 1
        self.errorMessage = nil
        do {
            let a = try await self.setlistApi.getArtistSetlists(id: self.artist.id, page: 1).setlist
            let shows = a.map { ShowDisplayInfo(setlistResponse: $0) }
            self.shows = shows
        } catch {
            print("🚨 Error at \(#function): \(error)")
            self.shows = []
            self.errorMessage = error.localizedDescription
        }

        return self.shows
    }

    func fetchMore() async -> [ShowDisplayInfo] {
        self.page += 1
        do {
            let response = try await self.setlistApi.getArtistSetlists(id: self.artist.id, page: self.page)
            self.shows.append(contentsOf: response.setlist.map { ShowDisplayInfo(setlistResponse: $0) })
        } catch {
            self.page -= 1
            print("🚨 Error at \(#function): \(error)")
        }

        return self.shows
    }

    func needsToFetchMore(show: ShowDisplayInfo) -> Bool {
        guard let indexOfCurrShow = self.shows.firstIndex(of: show) else { return false }
        return self.shows.count - indexOfCurrShow < 3
    }

    var artistName: String {
        self.artist.name
    }
}

struct ShowDisplayInfo: Identifiable, Hashable {

    private static var inputDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter
    }()

    private static var outputDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()

    let id: String
    let formattedDate: String
    let venueName: String?
    let setlist: [Song]
    let setlistResponse: SetlistResponse

    init(setlistResponse: SetlistResponse) {
        self.setlistResponse = setlistResponse
        
        self.id = setlistResponse.id
        self.venueName = setlistResponse.venue.name
        self.setlist = setlistResponse.sets.set.flatMap { $0.song ?? [] }

        if let date = Self.inputDateFormatter.date(from: setlistResponse.eventDate) {
            self.formattedDate = Self.outputDateFormatter.string(from: date)
        } else {
            self.formattedDate = ""
        }
    }
}
