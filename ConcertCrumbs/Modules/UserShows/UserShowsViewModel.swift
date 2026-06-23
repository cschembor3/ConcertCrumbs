//
//  UserShowsViewModel.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 2/20/23.
//

import Foundation
import Observation

@MainActor
protocol UserShowsViewModelProtocol: Observable, AnyObject {
    var entries: [ShowSeenEntry] { get }
    func resetNewShowCount()
    func remove(entryId: String, showId: String)
    func sort(_ option: UserShowsViewModel.SortOption)
}

@MainActor
@Observable
final class UserShowsViewModel: UserShowsViewModelProtocol {

    private static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()

    /// Derived from the service's observable `showsAttended`, so additions and
    /// removals propagate to the UI automatically via Observation — no manual
    /// stream consumption or per-instance listeners required.
    var entries: [ShowSeenEntry] {
        let artistEntries = Self.buildEntries(from: concertService.showsAttended)
        return sortedEntries(artistEntries, by: sortOption)
    }

    private var sortOption: SortOption = .alphabetically
    private var concertService: any UserConcertsServiceProtocol

    init(concertService: any UserConcertsServiceProtocol = UserConcertsService.shared) {
        self.concertService = concertService
        Task { [concertService] in
            await concertService.startObservingIfNeeded()
        }
    }

    func resetNewShowCount() {
        self.concertService.newShowAttendedCount = 0
    }

    func sort(_ option: SortOption) {
        self.sortOption = option
    }

    func remove(entryId: String, showId: String) {
        self.concertService.removeShowAsAttended(id: showId)
    }

    private static func buildEntries(from showsAttended: [UserShowDbModel]) -> [ShowSeenEntry] {
        let artistsDict = Dictionary(grouping: showsAttended, by: { $0.artistName })
        return artistsDict.map { (artistName, shows) in
            ShowSeenEntry(
                setlistFmShowId: "",
                name: artistName,
                text: artistName,
                type: .artist,
                children: shows.map { show in
                    let venueName = show.venueName ?? "Saint Vitus"
                    return ShowSeenEntry(
                        setlistFmShowId: show.id,
                        name: venueName,
                        text: "\(show.showDate) - \(venueName)",
                        type: .show,
                        children: nil,
                        date: Self.dateFormatter.date(from: show.showDate)
                    )
                },
                date: nil
            )
        }
    }

    private func sortedEntries(_ entries: [ShowSeenEntry], by sortOption: SortOption) -> [ShowSeenEntry] {
        switch sortOption {
        case .alphabetically:
            entries.sorted { artist1, artist2 in
                artist1.name.lowercased() < artist2.name.lowercased()
            }
        case .dateDescending:
            entries.sorted { artist1, artist2 in
                (self.getMostRecentDate(from: artist1.children ?? []) ?? Date.distantPast) <
                    (self.getMostRecentDate(from: artist2.children ?? []) ?? Date.distantPast)
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
