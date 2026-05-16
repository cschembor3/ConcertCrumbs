//
//  ArtistShowsView.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 6/19/22.
//

import SwiftUI

struct ArtistShowsView: View {

    @State private var loaded: Bool = false
    @State private var isLoading: Bool = false
    @State private var loadingMore: Bool = false

    @State private var viewModel: ArtistShowsViewModel

    init(viewModel: ArtistShowsViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {

        ZStack {

            List(viewModel.shows, id: \.id) { show in
                NavigationLink(value: show) {
                    Text("\(show.formattedDate) - \(show.venueName ?? "")")
                        .font(.monospaced(.body)())
                }
                .onAppear {
                    if viewModel.needsToFetchMore(show: show) {
                        self.loadingMore = true
                        Task {
                            _ = await self.viewModel.fetchMore()
                            self.loadingMore = false
                        }
                    }
                }
            }
            .navigationDestination(for: ShowDisplayInfo.self) { setlist in
                SetlistView(viewModel: .init(response: setlist.setlistResponse))
                    .navigationTitle(setlist.venueName ?? "")
            }

            ProgressView()
                .opacity(self.isLoading ? 1 : 0)
        }
        .navigationTitle(self.viewModel.artistName)
        .task {
            guard !self.loaded else { return }
            self.loaded = true
            self.isLoading = true
            _ = await self.viewModel.fetch()
            self.isLoading = false
        }
    }
}

struct IdentifiableSong: Identifiable {
    let id: UUID = UUID()
    let songName: String
    init(songName: String) {
        self.songName = songName
    }
}

#Preview {
    ArtistShowsView(viewModel: ArtistShowsViewModel(artist: (id: "12345", name: "Deftones")))
}
