//
//  SetlistView.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 2/8/23.
//

import SwiftUI

struct SetlistView: View {

    @State private var viewModel: SetlistViewModel

    init(viewModel: SetlistViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {

        List {
            ForEach(Array(viewModel.setGroups.enumerated()), id: \.element.id) { index, setGroup in
                Section(setGroup.title) {
                    ForEach(setGroup.songs) { song in
                        Text(song.name)
                    }
                }
            }
        }
        .navigationTitle("Setlist")
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.save()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .tint(.green)
                .buttonStyle(.glassProminent)
            }
        }
    }
}

#Preview {
    SetlistView(
        viewModel: SetlistViewModel(
            response: .init(
                id: UUID().uuidString,
                versionId: UUID().uuidString,
                eventDate: Date().formatted(),
                artist: Artist(id: UUID(), name: "Deftones"),
                venue: Venue(
                    id: UUID().uuidString,
                    name: "Stone Pony",
                    city: Location(
                        id: UUID().uuidString,
                        name: "Asbury Park",
                        state: "New Jersey",
                        stateCode: "07712",
                        country: Country(code: "", name: "US")
                    )
                ),
                tour: Tour(name: "private music"),
                sets: Sets(
                    set: [
                        .init(encore: nil, song: [.init(name: "my mind is a mountain"), .init(name: "souvenir")]),
                        .init(encore: 1, song: [Song(name: "Diamond Eyes")])]
                ),
                url: ""
            )
        )
    )
}
