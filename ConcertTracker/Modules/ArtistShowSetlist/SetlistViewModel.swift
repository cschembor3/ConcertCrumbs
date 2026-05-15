//
//  SetlistViewModel.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 2/9/23.
//

import Foundation
import Observation

struct SetGroup: Identifiable {
    let id = UUID()
    let title: String
    let songs: [Song]
}

@MainActor
@Observable
final class SetlistViewModel {

    private(set) var songs: [Song] = []
    private(set) var setGroups: [SetGroup] = []

    init(setlist: [Song]) {
        self.songs = setlist
        if !setlist.isEmpty {
            self.setGroups = [SetGroup(title: "Main Set", songs: setlist)]
        }
    }

    private var response: SetlistResponse? = nil
    init(response: SetlistResponse) {
        self.response = response
        
        // Create set groups from response
        var groups: [SetGroup] = []
        
        for (index, setInfo) in response.sets.set.enumerated() {
            guard let setSongs = setInfo.song, !setSongs.isEmpty else { continue }
            
            let title: String
            if let encore = setInfo.encore {
                title = "Encore \(encore)"
            } else if index == 0 {
                title = "Main Set"
            } else {
                title = "Set \(index + 1)"
            }
            
            groups.append(SetGroup(title: title, songs: setSongs))
            self.songs.append(contentsOf: setSongs)
        }
        
        self.setGroups = groups
    }

    func save() {
        guard let response = self.response else { return }
        UserConcertsService.shared.addShowAsAttended(response)
    }
}
