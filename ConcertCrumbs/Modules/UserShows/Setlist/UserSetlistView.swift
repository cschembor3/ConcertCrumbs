//
//  UserSetlistView.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 3/5/23.
//

import SwiftUI

struct UserSetlistView: View {

    @ObservedObject private var viewModel: UserSetlistViewModel

    init(viewModel: UserSetlistViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {

        List {
            if let tour = viewModel.setlistInfo?.tourName {
                Section("Tour") {
                    Text(tour)
                }
            }

            if let venue = viewModel.setlistInfo?.venueName {
                Section("Venue") {
                    Text(venue)
                }
            }

            Section("Setlist") {
                ForEach(viewModel.setlistInfo?.setlist.setSongs ?? [], id: \.self) { song in
                    Text(song)
                }
            }

            if let encores = viewModel.setlistInfo?.setlist.encores,
               !encores.isEmpty {

                ForEach(encores) { encore in
                    Section("Encore \(encore.number)") {
                        ForEach(encore.songs, id: \.self) { song in
                            Text(song)
                        }
                    }
                }
            }

            Section("Create Playlist") {
                Button("Spotify") {
                    print("hi")
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .navigationTitle(viewModel.setlistInfo?.artistName ?? "")
        .toolbarRole(.navigationStack)
    }
}


struct UserSetlistView_Previews: PreviewProvider {
    static var previews: some View {
        UserSetlistView(viewModel: UserSetlistViewModel(showId: "be1b9e2"))
    }
}
