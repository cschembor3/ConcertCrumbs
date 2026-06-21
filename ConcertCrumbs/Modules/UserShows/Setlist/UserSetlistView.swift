//
//  UserSetlistView.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 3/5/23.
//

import SwiftUI
import UIKit

struct UserSetlistView: View {

    @Environment(\.openURL) private var openURL
    @State var viewModel: UserSetlistViewModel

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
                    SongRow(song: song, imageUrl: viewModel.spotifyTrackInfo[song]?.imageUrl)
                }
            }

            if let encores = viewModel.setlistInfo?.setlist.encores,
               !encores.isEmpty {

                ForEach(encores) { encore in
                    Section("Encore \(encore.number)") {
                        ForEach(encore.songs, id: \.self) { song in
                            SongRow(song: song, imageUrl: viewModel.spotifyTrackInfo[song]?.imageUrl)
                        }
                    }
                }
            }

            Section("Spotify") {
                if viewModel.isCreatingPlaylist {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Creating playlist...")
                            .foregroundStyle(.secondary)
                    }
                } else if let urlString = viewModel.playlistUrl, let url = URL(string: urlString) {
                    Button("Open in Spotify") {
                        openURL(url)
                    }
                } else {
                    Button("Create Playlist") {
                        Task { await viewModel.createPlaylist() }
                    }
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .navigationTitle(viewModel.setlistInfo?.artistName ?? "")
        .toolbarRole(.navigationStack)
        .alert("Couldn't create playlist", isPresented: Binding(
            get: { viewModel.playlistError != nil },
            set: { if !$0 { viewModel.clearPlaylistError() } }
        )) {
            Button("OK", role: .cancel) { viewModel.clearPlaylistError() }
        } message: {
            Text(viewModel.playlistError ?? "")
        }
    }
}

private struct SongRow: View {

    let song: String
    let imageUrl: String?

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: imageUrl.flatMap(URL.init)) { image in
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

// MARK: - Image caching

/// Memory + disk caching image loader, shared across the app.
///
/// Decoded images are kept in an in-memory `NSCache`; the underlying
/// `URLSession` is backed by a sized `URLCache` so raw bytes also persist to
/// disk between launches. Concurrent requests for the same URL are coalesced.
actor ImageCache {

    static let shared = ImageCache()

    private let memory = NSCache<NSURL, UIImage>()
    private let session: URLSession
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: configuration)
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = memory.object(forKey: url as NSURL) {
            return cached
        }

        if let existing = inFlight[url] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            defer { inFlight[url] = nil }
            guard let (data, _) = try? await session.data(from: url),
                  let image = UIImage(data: data) else { return nil }
            memory.setObject(image, forKey: url as NSURL)
            return image
        }

        inFlight[url] = task
        return await task.value
    }
}

/// Drop-in replacement for `AsyncImage` that resolves through `ImageCache`,
/// avoiding re-downloads and the flicker that `AsyncImage` shows when rows are
/// recycled in a `List`.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {

    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let loadedImage {
                content(Image(uiImage: loadedImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else {
                loadedImage = nil
                return
            }
            loadedImage = await ImageCache.shared.image(for: url)
        }
    }
}

struct UserSetlistView_Previews: PreviewProvider {
    static var previews: some View {
        UserSetlistView(viewModel: UserSetlistViewModel(showId: "be1b9e2"))
    }
}
