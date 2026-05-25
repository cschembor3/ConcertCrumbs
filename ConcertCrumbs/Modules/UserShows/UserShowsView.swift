//
//  UserShowsView.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 2/20/23.
//

import SwiftUI

struct UserShowsView<ViewModel>: View where ViewModel: UserShowsViewModelProtocol {

    private enum GroupingMode {
        case alphabetical
        case byYear
    }

    struct SetlistDestination: Hashable {
        let showId: String
    }

    @State private var chosenArtist: ShowSeenEntry?
    @State private var groupingMode: GroupingMode = .alphabetical
    @State private var path = NavigationPath()
    @State private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {

        NavigationStack(path: $path) {
            List {
                switch groupingMode {
                case .alphabetical:
                    AlphabeticalConcerts(entries: viewModel.entries) { entryId, showIdToDelete in
                        viewModel.remove(entryId: entryId, showId: showIdToDelete)
                    }
                case .byYear:
                    ChronologicalConcerts(entries: viewModel.entries)
                }
            }
            .listSectionIndexVisibility(.visible)
            .navigationDestination(for: SetlistDestination.self) { destination in
                UserSetlistView(viewModel: .init(showId: destination.showId))
            }
            .onAppear {
                self.viewModel.resetNewShowCount()
            }
            .listStyle(.sidebar)
            .navigationTitle("Shows attended")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("A-Z") {
                            self.viewModel.sort(.alphabetically)
                            self.groupingMode = .alphabetical
                        }

                        Button("By Year") {
                            self.groupingMode = .byYear
                        }
                    } label: {
                        Image(systemName: "slider.vertical.3")
                    }
                }
            }
        }
    }

    struct AlphabeticalConcerts: View {
        private let entries: [ShowSeenEntry]
        private let onRemove: (String, String) -> Void

        init(entries: [ShowSeenEntry], onRemove: @escaping (String, String) -> Void) {
            self.entries = entries
            self.onRemove = onRemove
        }

        var body: some View {
            ForEach(entriesByLetter, id: \.0) { letter, shows in
                Section(letter) {
                    ForEach(shows, id: \.id) { entry in
                        ShowsAttendedByArtistView(showsSeenEntry: entry, onDelete: onRemove)
                    }
                }
            }
        }

        private var entriesByLetter: [(String, [ShowSeenEntry])] {
            let grouped = Dictionary(grouping: self.entries) {
                let first = String($0.name.prefix(1)).uppercased()
                return first.isEmpty ? "#" : first
            }
            return grouped.keys.sorted().map { ($0, grouped[$0]!) }
        }
    }

    struct ChronologicalConcerts: View {

        private let entries: [ShowSeenEntry]
        init(entries: [ShowSeenEntry]) {
            self.entries = entries
        }

        var body: some View {

            ForEach(entriesByYear, id: \.year) { section in
                Section(section.year) {
                    ForEach(section.shows, id: \.show.id) { item in
                        NavigationLink(value: SetlistDestination(showId: item.show.setlistFmShowId)) {
                            VStack(alignment: .leading) {
                                Text(item.artistName)
                                Text(item.show.text)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }

        private var entriesByYear: [(year: String, shows: [(artistName: String, show: ShowSeenEntry)])] {
            let allShows: [(artistName: String, show: ShowSeenEntry)] = self.entries.flatMap { artist in
                (artist.children ?? []).map { (artistName: artist.name, show: $0) }
            }

            let grouped = Dictionary(grouping: allShows) { pair in
                if let date = pair.show.date {
                    return String(Calendar.current.component(.year, from: date))
                }
                return "Unknown"
            }

            return grouped.keys.sorted(by: >).map { year in
                let yearShows = grouped[year]!.sorted {
                    ($0.show.date ?? .distantPast) > ($1.show.date ?? .distantPast)
                }
                return (year: year, shows: yearShows)
            }
        }
    }

    struct ShowsAttendedByArtistView: View {

        private let showsSeenEntry: ShowSeenEntry
        private let onDelete: (String, String) -> Void
        init(showsSeenEntry: ShowSeenEntry, onDelete: @escaping (String, String) -> Void) {
            self.showsSeenEntry = showsSeenEntry
            self.onDelete = onDelete
        }

        var body: some View {
            DisclosureGroup(
                content: {
                    ForEach(showsSeenEntry.children ?? []) { show in
                        NavigationLink(
                            show.text,
                            value: SetlistDestination(showId: show.setlistFmShowId)
                        )
                    }
                    .onDelete { indexSet in
                        self.onDelete(
                            showsSeenEntry.id.uuidString,
                            showsSeenEntry.children![indexSet.first!].setlistFmShowId
                        )
                    }
                },
                label: {
                    Text(showsSeenEntry.text)
                        .badge(showsSeenEntry.children?.count ?? 0)
                }
            )
        }
    }
}

#Preview {
    UserShowsView(viewModel: MockUserShowsViewModel())
}

@MainActor
@Observable
class MockUserShowsViewModel: UserShowsViewModelProtocol {
    func remove(entryId: String, showId: String) {}
    func remove(showId: String) {}
    var entries: [ShowSeenEntry] = [
        .init(
            //            id: UUID(),
            setlistFmShowId: "",
            name: "Deftones",
            text: "Deftones",
            type: .artist,
            children: [
                .init(
                    //                    id: UUID(),
                    setlistFmShowId: "",
                    name: "Saint Vitus",
                    text: "12/04/1998 - Saint Vitus",
                    type: .show,
                    children: nil,
                    date: nil
                ),
                .init(
                    //                    id: UUID(),
                    setlistFmShowId: "",
                    name: "Saint Vitus",
                    text: "12/04/1998 - Saint Vitus",
                    type: .show,
                    children: nil,
                    date: nil
                ),
            ],
            date: nil
        ),
        .init(
            //            id: UUID(),
            setlistFmShowId: "",
            name: "Deerhoof",
            text: "Deerhoof",
            type: .artist,
            children: [
                .init(
                    //                    id: UUID(),
                    setlistFmShowId: "",
                    name: "Brooklyn Monarch",
                    text: "Brooklyn Monarch",
                    type: .show,
                    children: nil,
                    date: nil
                )
            ],
            date: nil
        ),
    ]

    func resetNewShowCount() {}
    func sort(_ option: UserShowsViewModel.SortOption) {}
}
