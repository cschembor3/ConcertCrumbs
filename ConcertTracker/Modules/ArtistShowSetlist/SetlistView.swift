//
//  SetlistView.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 2/8/23.
//

import SwiftUI

struct SetlistView: View {

    @ObservedObject private var viewModel: SetlistViewModel

    init(viewModel: SetlistViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(viewModel.setGroups.indices, id: \.self) { index in
                    let setGroup = viewModel.setGroups[index]
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(setGroup.title)
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(setGroup.songs) { song in
                            HStack {
                                Text(song.name)
                                    .padding(.horizontal)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    if index < viewModel.setGroups.count - 1 {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Setlist")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("I was here") {
                    viewModel.save()
                }
            }
        }
    }
}

struct SetlistView_Previews: PreviewProvider {
    static var previews: some View {
        SetlistView(viewModel: SetlistViewModel(setlist: []))
    }
}
