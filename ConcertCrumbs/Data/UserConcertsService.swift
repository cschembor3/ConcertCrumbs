//
//  UserConcertsService.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 2/12/23.
//

import FirebaseDatabase
import Observation

@MainActor
protocol UserConcertsServiceProtocol {
    func getSetlist(concertId: String)
    func loadShowsAttended() async throws -> [UserShowDbModel]
    func beginListeningForNewShowsAdded()
    func removeShowAsAttended(id: String)
    var newShowsAttended: AsyncStream<UserShowDbModel> { get }
    var showsAttended: [UserShowDbModel] { get }
    var newShowAttendedCount: Int { get set }
}

@MainActor
@Observable
final class UserConcertsService: UserConcertsServiceProtocol {

    static let shared = UserConcertsService()

    private(set) var showsAttended: [UserShowDbModel] = []
    var newShowAttendedCount: Int = 0

    @ObservationIgnored let newShowsAttended: AsyncStream<UserShowDbModel>
    private let newShowsAttendedContinuation: AsyncStream<UserShowDbModel>.Continuation

    private let reference = Database.database().reference()

    @ObservationIgnored private var databasePath: DatabaseReference? {
        guard let userId = AuthenticationService.shared.user?.uid else { return nil }
        return reference.child("users/\(userId)/showsAttended")
    }

    private var handle: DatabaseHandle?

    private init() {
        let (stream, continuation) = AsyncStream.makeStream(of: UserShowDbModel.self)
        self.newShowsAttended = stream
        self.newShowsAttendedContinuation = continuation
    }

    func loadShowsAttended() async throws -> [UserShowDbModel] {
        guard let databasePath else { throw CocoaError(.coderReadCorrupt) }

        let snapshot: DataSnapshot = try await withCheckedThrowingContinuation { continuation in
            databasePath.observeSingleEvent(
                of: .value,
                with: { continuation.resume(returning: $0) },
                withCancel: { continuation.resume(throwing: $0) }
            )
        }

        guard let json = snapshot.value as? [String: Any] else { return [] }

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode([String: UserShowDbModel].self, from: data)
        let shows = Array(decoded.values)
        self.showsAttended = shows
        return shows
    }

    func beginListeningForNewShowsAdded() {
        guard let databasePath else { return }
        self.handle = databasePath.observe(.childAdded) { [weak self] data in
            guard let json = data.value as? [String: Any] else { return }
            Task { @MainActor in
                guard let self else { return }
                do {
                    let bytes = try JSONSerialization.data(withJSONObject: json)
                    let newShow = try JSONDecoder().decode(UserShowDbModel.self, from: bytes)
                    guard !self.showsAttended.contains(newShow) else { return }
                    self.showsAttended.append(newShow)
                    self.newShowsAttendedContinuation.yield(newShow)
                    self.newShowAttendedCount += 1
                } catch {
                    print(error)
                }
            }
        }
    }

    isolated deinit {
        newShowsAttendedContinuation.finish()
        if let handle {
            databasePath?.removeObserver(withHandle: handle)
        }
    }

    func getSetlist(concertId: String) {

    }

    func addShowAsAttended(_ show: SetlistResponse) {

        guard let user = AuthenticationService.shared.user else { return }

        do {
            let userShowData = try JSONEncoder().encode(show.toUserShowDbModel())
            let userShow = try JSONSerialization.jsonObject(with: userShowData)

            self.reference
                .ref
                .child("users")
                .child(user.uid)
                .child("showsAttended")
                .updateChildValues([show.id: userShow]) { error, _ in
                    if let error {
                        print("Error writing attended show - \(#function): \(error)")
                    }
                }
        } catch {
            print("Error encoding attended show - \(#function): \(error)")
            return
        }

        self.reference
            .ref
            .child("artists")
            .child(show.artist.id.uuidString)
            .child("name")
            .setValue(show.artist.name)

        self.reference
            .ref
            .child("artists")
            .child(show.artist.id.uuidString)
            .child("shows")
            .updateChildValues([show.id: true])

        let showDbModel = show.toDbModel()
        self.reference
            .ref
            .child("shows")
            .child(showDbModel.id)
            .child("artistId")
            .setValue(showDbModel.artistId)

        self.reference
            .ref
            .child("shows")
            .child(showDbModel.id)
            .child("attendedUsers")
            .updateChildValues([user.uid: true])

        do {
            let songsData = try JSONEncoder().encode(showDbModel.songs)
            let songs = try JSONSerialization.jsonObject(with: songsData)
            self.reference
                .ref
                .child("shows")
                .child(showDbModel.id)
                .child("songs")
                .setValue(songs)
        } catch {
            print("Error serializing song data - \(#function): \(error)")
            return
        }
    }

    func removeShowAsAttended(id: String) {
        guard let user = AuthenticationService.shared.user else { return }

        let database = self.reference

        // Remove the show from the user's attended list.
        database
            .child("users")
            .child(user.uid)
            .child("showsAttended")
            .child(id)
            .removeValue()

        let showRef = database.child("shows").child(id)

        // Remove this user from the show's attendee list.
        showRef.child("attendedUsers").child(user.uid).removeValue()

        // If no attendees remain, delete the orphaned show and detach it from its artist.
        showRef.child("attendedUsers").observeSingleEvent(of: .value) { snapshot in
            guard !snapshot.exists() || snapshot.childrenCount == 0 else { return }

            // Resolve the owning artist before deleting the show node.
            showRef.child("artistId").observeSingleEvent(of: .value) { artistSnapshot in
                showRef.removeValue()

                guard let artistId = artistSnapshot.value as? String else { return }
                let artistRef = database.child("artists").child(artistId)
                artistRef.child("shows").child(id).removeValue()

                // If the artist has no remaining shows, delete the artist node too.
                artistRef.child("shows").observeSingleEvent(of: .value) { showsSnapshot in
                    if !showsSnapshot.exists() || showsSnapshot.childrenCount == 0 {
                        artistRef.removeValue()
                    }
                }
            }
        }
    }
}

struct ShowDbModel: Codable {
    let id: String
    let artistId: String
    let venue: VenueDbModel
    let songs: [SongDbModel]

    struct VenueDbModel: Codable {
        let id: String
        let name: String?
        let city: String?
        let state: String?
    }

    struct SongDbModel: Codable {
        let name: String
    }
}

struct UserShowDbModel: Codable, Equatable {
    let id: String
    let artistName: String
    let showDate: String
    let venueName: String?
}

extension SetlistResponse {

    func toUserShowDbModel() -> UserShowDbModel {
        let fromServerDateFormatter = DateFormatter()
        fromServerDateFormatter.dateFormat = "dd-MM-yyyy"

        let formattedDate: String
        if let date = fromServerDateFormatter.date(from: self.eventDate) {
            let newDateFormatter = DateFormatter()
            newDateFormatter.dateFormat = "MM/dd/yyyy"
            formattedDate = newDateFormatter.string(from: date)
        } else {
            formattedDate = self.eventDate
        }

        return UserShowDbModel(id: self.id, artistName: self.artist.name, showDate: formattedDate, venueName: self.venue.name)
    }

    func toDbModel() -> ShowDbModel {
        let songs = self.sets.set.compactMap { $0.song }.flatMap { $0 }.map { ShowDbModel.SongDbModel(name: $0.name) }
        return ShowDbModel(
            id: self.id,
            artistId: self.artist.id.uuidString,
            venue: .init(id: self.venue.id, name: self.venue.name, city: self.venue.city.name, state: self.venue.city.state),
            songs: songs
        )
    }
}
