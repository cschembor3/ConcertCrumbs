//
//  UserShowsViewModel.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 2/20/23.
//

import AsyncAlgorithms
import Combine
import Foundation
import FirebaseDatabase
import SwiftUI

@MainActor
protocol UserShowsViewModelProtocol: ObservableObject {
    var entries: [ShowSeenEntry] { get }
    func resetNewShowCount()
    func remove(entryId: String, showId: String)
    func sort(_ option: UserShowsViewModel.SortOption)
}

final class UserShowsViewModel: UserShowsViewModelProtocol {

    private static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()


    @Published var entries = [ShowSeenEntry]()

    private var cancellables = [AnyCancellable]()
    private var concertService: any UserConcertsServiceProtocol = UserConcertsService.shared

    init(concertService: any UserConcertsServiceProtocol = UserConcertsService.shared) {
        self.concertService = concertService
        Task {
            await self.populateInitialShowsAttended()
            self.listenForNewShowsAdded()
        }
    }

    func resetNewShowCount() {
        self.concertService.newShowAttendedCount = 0
    }

    func sort(_ option: SortOption) {
        self.entries = self.getSortedEntries(sortOption: option)
    }

    func remove(entryId: String, showId: String) {
        guard var (index, entry) = self.entries.enumerated().first(where: { $0.element.id.uuidString == entryId }),
              let show = entry.children?.firstIndex(where: { $0.setlistFmShowId == showId }) else {
            return
        }

        entry.children?.remove(at: show)
        entries[index] = entry

        self.concertService.removeShowAsAttended(id: showId)
    }

    private func populateInitialShowsAttended() async {
        guard let showsAttended = try? concertService.getShowsAttended() else { return }
        let artistsDict = await Dictionary(grouping: showsAttended, by: { $0.artistName })

        var artistsSeen = [ArtistSeen]()
        artistsDict.forEach { (artistName, artists) in
            let shows = artists.map { ShowSeen(id: $0.id, venueName: $0.venueName ?? "Saint Vitus", city: "Brooklyn", date: $0.showDate) }
            artistsSeen.append(.init(id: artistName, name: artistName, shows: shows))
        }

        self.entries = artistsSeen.map { artist in
            .init(
                setlistFmShowId: "",
                name: artist.name,
                text: artist.name,
                type: .artist,
                children: artist.shows.map { show in
                    .init(
                        setlistFmShowId: show.id,
                        name: show.venueName,
                        text: "\(show.date) - \(show.venueName)",
                        type: .show,
                        children: nil,
                        date: Self.dateFormatter.date(from: show.date)
                    )
                },
                date: nil
            )
        }
    }

    private func listenForNewShowsAdded() {
        concertService.beginListeningForNewShowsAdded()
        concertService.newShowsAttended
            .sink { [weak self] newShow in
                if var artistEntry = self?.entries.first(where: { newShow.artistName == $0.name }) {
                    let newShowEntry = ShowSeenEntry(
                        setlistFmShowId: newShow.id,
                        name: "Saint Vitus",
                        text: newShow.showDate,
                        type: .show,
                        children: nil,
                        date: Self.dateFormatter.date(from: newShow.showDate)
                    )

                    artistEntry.children?.append(newShowEntry)
                } else {
                    self?.entries.append(
                        .init(
                            setlistFmShowId: "",
                            name: newShow.artistName,
                            text: newShow.artistName,
                            type: .artist,
                            children: [
                                .init(
                                    setlistFmShowId: newShow.id,
                                    name: "Saint Vitus",
                                    text: newShow.showDate,
                                    type: .show,
                                    children: nil,
                                    date: Self.dateFormatter.date(from: newShow.showDate)
                                )
                            ],
                            date: nil
                        )
                    )
                }
            }
            .store(in: &cancellables)
    }

    private func getSortedEntries(sortOption: SortOption) -> [ShowSeenEntry] {
        switch sortOption {
        case .alphabetically:
            entries.sorted { artist1, artist2 in
                artist1.name.lowercased() < artist2.name.lowercased()
            }
        case .dateDescending:
            entries.sorted { artist1, artist2 in
                self.getMostRecentDate(from: artist1.children ?? []) ?? Date.distantPast <
                    self.getMostRecentDate(from: artist2.children ?? []) ?? Date.distantPast
            }.reversed()
        }
    }

    enum SortOption {
        case alphabetically
        case dateDescending
    }

    private func getMostRecentDate(from shows: [ShowSeenEntry]) -> Date? {
        let mostRecentShow = shows.reduce(nil as ShowSeenEntry?, { show1, show2 in
            if let date1 = show1?.date {
                if let date2 = show2.date {
                    return date1 > date2 ? show1 : show2
                } else {
                    return show1
                }
            } else if let _ = show2.date {
                return show2
            }

            return show1
        })

        return mostRecentShow?.date
    }
}

struct ArtistSeen: Hashable, Identifiable {
    let id: String
    let name: String
    let shows: [ShowSeen]
}

struct ShowSeen: Hashable, Identifiable {
    let id: String
    let venueName: String
    let city: String
    let date: String
}

struct ShowSeenEntry: Identifiable, Equatable {
    let id = UUID()
    let setlistFmShowId: String
    let name: String
    let text: String
    let type: EntryType
    var children: [ShowSeenEntry]?
    let date: Date?

    enum EntryType {
        case artist
        case show
    }
}
