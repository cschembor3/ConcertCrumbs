//
//  UserSetlistViewModel.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 3/19/23.
//

import Foundation

@MainActor
final class UserSetlistViewModel: ObservableObject {

    @Published private(set) var setlistInfo: UserSetlistDisplayInfo?

    private let setlistService: SetlistServiceInterface
    init(showId: String, setlistService: SetlistServiceInterface = SetlistService()) {
        self.setlistService = setlistService
        Task {
            await self.populateSetlist(for: showId)
        }
    }
    
    private func populateSetlist(for showId: String) async {
        guard let setlistResponse = try? await self.setlistService.getSetlist(for: showId) else {
            return
        }

        self.setlistInfo = .init(from: setlistResponse)
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

            let setlist = SetDisplayInfo(
                setSongs: mainSetSongs,
                encores: encores
            )

            self.setlist = setlist
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
