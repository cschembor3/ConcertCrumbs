//
//  ArtistsView.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 6/6/22.
//

import SwiftUI

struct ArtistsView<ViewModel>: View where ViewModel: ArtistsViewModelProtocol {

    @State private var path = NavigationPath()

    @State private var loadingMore: Bool = false

    private let concertService = UserConcertsService.shared

    @State private var viewModel: ViewModel
    init(viewModel: ViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        TabView {
            NavigationStack(path: $path) {
                ZStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .opacity(viewModel.isLoading ? 1 : 0)

                    List(viewModel.artists, id: \.id) { artist in
                        NavigationLink(
                            value: ArtistData(id: artist.id.uuidString, name: artist.name)
                        ) {
                            Text(artist.name)
                        }
                        .onAppear {
                            if viewModel.needsToFetchMore(artist: artist) {
                                self.loadingMore = true
                                Task {
                                    _ = await self.viewModel.fetchMore()
                                    self.loadingMore = false
                                }
                            }
                        }
                    }
                    .navigationDestination(for: ArtistData.self) { artist in
                        ArtistShowsView(
                            viewModel: ArtistShowsViewModel(
                                artist: (
                                    id: artist.id.lowercased(),
                                    name: artist.name
                                )
                            )
                        )
                    }
                    .searchable(text: $viewModel.searchText)

                    if let errorMessage = viewModel.errorMessage, viewModel.artists.isEmpty {
                        ErrorRetryView(message: errorMessage) {
                            Task { await viewModel.fetch(searchQuery: viewModel.searchText) }
                        }
                        .padding(.horizontal, 40)
                    } else if self.viewModel.searchText.isEmpty {
                        SearchIconView()
                            .padding(.horizontal, 80)
                    }
                }
                .navigationTitle(Constants.Artists.headerText)
            }
            .listStyle(.inset)
            .padding(.bottom)
            .tabItem {
                Label("Add", systemImage: "magnifyingglass")
            }
            UserShowsView(viewModel: UserShowsViewModel())
                .tabItem {
                    Label("Attended", systemImage: "music.note.list")
                }
                .badge(
                    concertService.newShowAttendedCount > 0 ? "\(concertService.newShowAttendedCount)" : nil
                )
            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle.fill")
                }
        }
    }
}

struct SearchIconView: View {

    var body: some View {

        VStack {
            Text("Search for an artist/band")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.bottom)

            Image(systemName: "music.mic.circle")
                .resizable()
                .scaledToFit()
                .padding(.bottom)
                .foregroundStyle(.secondary)
        }
    }
}

struct ErrorRetryView: View {

    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ArtistsView(viewModel: MockArtistsViewModel())
}

@MainActor
@Observable
class MockArtistsViewModel: ArtistsViewModelProtocol {
    var artists: [ArtistSearch] = [
//        .init(id: UUID(), ticketMasterId: 33333, name: "Deftones", sortName: "", disambiguation: "", url: ""),
//        .init(id: UUID(), ticketMasterId: 44444, name: "Fleetwood Mac", sortName: "", disambiguation: "", url: ""),
//        .init(id: UUID(), ticketMasterId: 55555, name: "ZZ Top", sortName: "", disambiguation: "", url: "")
    ]

    var searchText: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil
    func fetch(searchQuery: String) async {}
    func fetchMore() async {}
    func needsToFetchMore(artist: ArtistSearch) -> Bool {
        false
    }
}

struct ArtistData: Hashable {
    let id: String
    let name: String
}
