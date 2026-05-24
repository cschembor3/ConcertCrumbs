//
//  UserSetlistView.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 3/5/23.
//

import SwiftUI

struct UserSetlistView: View {

    private var viewModel: UserSetlistViewModel

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
                    SongRow(song: song, imageUrl: viewModel.albumImages[song])
                }
            }

            if let encores = viewModel.setlistInfo?.setlist.encores,
               !encores.isEmpty {

                ForEach(encores) { encore in
                    Section("Encore \(encore.number)") {
                        ForEach(encore.songs, id: \.self) { song in
                            SongRow(song: song, imageUrl: viewModel.albumImages[song])
                        }
                    }
                }
            }

            Section("Create Playlist") {
                Button("Spotify") {
                    // TODO: create Spotify playlist from fetched tracks
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .navigationTitle(viewModel.setlistInfo?.artistName ?? "")
        .toolbarRole(.navigationStack)
    }
}


private struct SongRow: View {

    let song: String
    let imageUrl: String?

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: imageUrl.flatMap(URL.init)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(song)
        }
    }
}

struct UserSetlistView_Previews: PreviewProvider {
    static var previews: some View {
        UserSetlistView(viewModel: UserSetlistViewModel(showId: "be1b9e2"))
    }
}
