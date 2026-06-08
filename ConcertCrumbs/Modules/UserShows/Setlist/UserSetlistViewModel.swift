//
//  UserSetlistViewModel.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 3/19/23.
//

import Foundation

@MainActor
@Observable
final class UserSetlistViewModel {

    private(set) var setlistInfo: UserSetlistDisplayInfo?
    private(set) var spotifyTrackInfo: [String: SpotifyTrackInfo] = [:]
    private(set) var isCreatingPlaylist = false
    private(set) var playlistUrl: String?
    private(set) var playlistError: String?

    private let setlistService: SetlistServiceInterface
    private let musicApi: SpotifyMusicApiInterface
    private let playlistApi: SpotifyPlaylistApiInterface
    private let userAuthService: SpotifyUserAuthServiceInterface

    init(
        showId: String,
        setlistService: SetlistServiceInterface = SetlistService(),
        musicApi: SpotifyMusicApiInterface = SpotifyMusicApi(),
        playlistApi: SpotifyPlaylistApiInterface = SpotifyPlaylistApi(),
        userAuthService: SpotifyUserAuthServiceInterface = SpotifyUserAuthService()
    ) {
        self.setlistService = setlistService
        self.musicApi = musicApi
        self.playlistApi = playlistApi
        self.userAuthService = userAuthService
        Task {
            await self.populateSetlist(for: showId)
        }
    }

    func createPlaylist() async {
        isCreatingPlaylist = true
        defer { isCreatingPlaylist = false }

        do {
            do {
                _ = try await userAuthService.getValidUserToken()
            } catch SpotifyUserAuthError.notAuthenticated {
                try await userAuthService.login()
            }

            let user = try await playlistApi.getCurrentUser()

            let name: String = {
                let artist = setlistInfo?.artistName ?? "Setlist"
                guard let venue = setlistInfo?.venueName else { return artist }
                return "\(artist) at \(venue)"
            }()

            let playlist = try await playlistApi.createPlaylist(userId: user.id, name: name)

            let allSongs = (setlistInfo?.setlist.setSongs ?? []) +
                (setlistInfo?.setlist.encores?.flatMap(\.songs) ?? [])
            let uris = allSongs.compactMap { spotifyTrackInfo[$0]?.uri }

            if !uris.isEmpty {
                try await playlistApi.addTracks(uris, to: playlist.id)
            }

            playlistUrl = playlist.externalUrls.spotify
        } catch {
            playlistError = error.localizedDescription
        }
    }

    func clearPlaylistError() {
        playlistError = nil
    }
}

// MARK: - Private

private extension UserSetlistViewModel {

    func populateSetlist(for showId: String) async {
        guard let setlistResponse = try? await self.setlistService.getSetlist(for: showId) else {
            return
        }

        self.setlistInfo = .init(from: setlistResponse)
        await fetchSpotifyTrackInfo(artistName: setlistResponse.artist.name)
    }

    func fetchSpotifyTrackInfo(artistName: String) async {
        let allSongs = (setlistInfo?.setlist.setSongs ?? []) +
            (setlistInfo?.setlist.encores?.flatMap(\.songs) ?? [])

        await withTaskGroup(of: (String, SpotifyTrackInfo?).self) { group in
            for song in allSongs {
                group.addTask {
                    let track = try? await self.musicApi.searchTracks(
                        query: "\(artistName) \(song)",
                        limit: 1
                    ).tracks.items.first
                    guard let track else { return (song, nil) }
                    return (song, SpotifyTrackInfo(
                        imageUrl: track.album.images.last?.url ?? "",
                        uri: track.uri
                    ))
                }
            }

            for await (song, info) in group {
                if let info { self.spotifyTrackInfo[song] = info }
            }
        }
    }
}

// MARK: - Display Models

extension UserSetlistViewModel {

    struct SpotifyTrackInfo {
        let imageUrl: String
        let uri: String
    }

    struct UserSetlistDisplayInfo: Identifiable {
        let id: String
        let artistName: String
        let venueName: String?
        let tourName: String?
        let setlist: SetDisplayInfo

        init(from serverResponse: SetlistResponse) {
            self.id = serverResponse.id
            self.artistName = serverResponse.artist.name
            self.venueName = serverResponse.venue.name
            self.tourName = serverResponse.tour?.name

            let sets = serverResponse.sets.set
            let mainSetSongs = sets
                .filter { $0.encore == nil }
                .flatMap { $0.song ?? [] }
                .map { $0.name }

            let encores = sets
                .filter { $0.encore != nil }
                .sorted { $0.encore! < $1.encore! }
                .map { encoreSet in
                    Encore(
                        number: encoreSet.encore!,
                        songs: (encoreSet.song ?? []).map { $0.name }
                    )
                }

            self.setlist = SetDisplayInfo(setSongs: mainSetSongs, encores: encores)
        }
    }

    struct SetDisplayInfo: Identifiable {
        let id = UUID()
        let setSongs: [String]
        let encores: [Encore]?
    }

    struct Encore: Identifiable {
        let id = UUID()
        let number: Int
        let songs: [String]
    }
}
