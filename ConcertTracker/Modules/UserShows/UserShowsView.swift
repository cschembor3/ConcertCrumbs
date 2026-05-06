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

    @State private var chosenArtist: ShowSeenEntry?
    @State private var groupingMode: GroupingMode = .alphabetical
    @StateObject private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var entriesByLetter: [(String, [ShowSeenEntry])] {
        let grouped = Dictionary(grouping: viewModel.entries) {
            let first = String($0.name.prefix(1)).uppercased()
            return first.isEmpty ? "#" : first
        }
        return grouped.keys.sorted().map { ($0, grouped[$0]!) }
    }

    private var entriesByYear: [(year: String, shows: [(artistName: String, show: ShowSeenEntry)])] {
        let allShows: [(artistName: String, show: ShowSeenEntry)] = viewModel.entries.flatMap { artist in
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

    var body: some View {

        NavigationStack {
            List {
                switch groupingMode {
                case .alphabetical:
                    ForEach(entriesByLetter, id: \.0) { letter, entries in
                        Section(letter) {
                            ForEach(entries, id: \.id) { entry in
                                ShowsAttendedByArtistView(showsSeenEntry: entry) { entryId, showIdToDelete in
                                    self.viewModel.remove(entryId: entryId, showId: showIdToDelete)
                                }
                            }
                        }
                    }
                case .byYear:
                    ForEach(entriesByYear, id: \.year) { section in
                        Section(section.year) {
                            ForEach(section.shows, id: \.show.id) { item in
                                NavigationLink {
                                    UserSetlistView(viewModel: .init(showId: item.show.setlistFmShowId))
                                } label: {
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
            }
            .listSectionIndexVisibility(.visible)
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

    struct ShowsAttendedByArtistView: View {

        private let showsSeenEntry: ShowSeenEntry
        private let onDelete: (String, String) -> Void
        init(showsSeenEntry: ShowSeenEntry, onDelete: @escaping (String, String) -> Void) {
            self.showsSeenEntry = showsSeenEntry
            self.onDelete = onDelete
        }

        var body: some View {
            //            Section(showsSeenEntry.text) {
            DisclosureGroup(
                content: {
                    ForEach(showsSeenEntry.children ?? []) { show in
                        NavigationLink(show.text) {
                            UserSetlistView(viewModel: .init(showId: show.setlistFmShowId))
                        }
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
            //            }
        }
    }
}

struct UserShowsView_Previews: PreviewProvider {
    static var previews: some View {
        UserShowsView(viewModel: MockUserShowsViewModel())
    }
}

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
