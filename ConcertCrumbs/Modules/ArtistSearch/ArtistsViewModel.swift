//
//  ArtistsViewModel.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 6/8/22.
//

import AsyncAlgorithms
import Foundation
import Observation

@MainActor protocol ArtistsViewModelProtocol: Observable, AnyObject {
    var artists: [ArtistSearch] { get }
    var searchText: String { get set }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    func fetch(searchQuery: String) async
    func fetchMore() async
    func needsToFetchMore(artist: ArtistSearch) -> Bool
}

@MainActor
@Observable
final class ArtistsViewModel: ArtistsViewModelProtocol {

    private(set) var artists: [ArtistSearch] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String? = nil
    var searchText: String = "" {
        didSet { searchTextContinuation.yield(searchText) }
    }

    private let setlistService: SetlistServiceInterface
    private var page: Int = 1
    private var searchQuery: String = ""
    private var searchTask: Task<Void, Never>?
    private let searchTextContinuation: AsyncStream<String>.Continuation

    init(setlistService: SetlistServiceInterface = SetlistService()) {
        self.setlistService = setlistService

        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        self.searchTextContinuation = continuation

        self.searchTask = Task { [weak self] in
            let queries = stream
                .debounce(for: .milliseconds(200))
                .removeDuplicates()
            for await query in queries {
                guard let self else { return }
                self.searchQuery = query
                await self.fetch(searchQuery: query)
            }
        }
    }

    isolated deinit {
        searchTextContinuation.finish()
        searchTask?.cancel()
    }

    func fetch(searchQuery: String) async {
        guard !searchQuery.isEmpty else {
            self.artists = []
            self.page = 1
            self.errorMessage = nil
            return
        }

        self.page = 1
        self.errorMessage = nil
        self.isLoading = true
        defer { self.isLoading = false }

        do {
            let response = try await setlistService.search(artistName: searchQuery, page: page)
            guard let artists = response.artist else { return }
            self.artists = artists
        } catch {
            self.errorMessage = error.localizedDescription
            print(error)
        }
    }

    func fetchMore() async {
        self.page += 1
        do {
            let response = try await setlistService.search(artistName: self.searchQuery, page: page)
            guard let artists = response.artist else { return }
            self.artists.append(contentsOf: artists)
        } catch {
            self.page -= 1
            print(error)
        }
    }

    func needsToFetchMore(artist: ArtistSearch) -> Bool {
        guard let indexOfCurrArtist = self.artists.firstIndex(of: artist) else { return false }
        return self.artists.count - indexOfCurrArtist < 3
    }
}
