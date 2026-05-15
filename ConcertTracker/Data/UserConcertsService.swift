//
//  UserConcertsService.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 2/12/23.
//

import FirebaseDatabase

protocol UserConcertsServiceProtocol {
    func getSetlist(concertId: String)
    func getShowsAttended() throws -> AsyncStream<UserShowDbModel>
    func beginListeningForNewShowsAdded()
    func removeShowAsAttended(id: String)
    var newShowsAttended: AsyncStream<UserShowDbModel> { get }
    var showsAttended: [UserShowDbModel] { get }
    var newShowAttendedCount: Int { get set }
}

final class UserConcertsService: UserConcertsServiceProtocol, ObservableObject {

    static let shared = UserConcertsService()

    private(set) var showsAttended: [UserShowDbModel] = []
    let newShowsAttended: AsyncStream<UserShowDbModel>
    private let newShowsAttendedContinuation: AsyncStream<UserShowDbModel>.Continuation
    @Published var newShowAttendedCount: Int = 0

    private let reference = Database.database().reference()

    private lazy var databasePath: DatabaseReference? = {
        guard let userId = AuthenticationService().user?.uid else { return nil }
        return reference.ref.child("users/\(userId)/showsAttended")
    }()

    private var handle: DatabaseHandle!

    private init() {
        let (stream, continuation) = AsyncStream.makeStream(of: UserShowDbModel.self)
        self.newShowsAttended = stream
        self.newShowsAttendedContinuation = continuation
    }

    // make init an async func
    // only observe single event here, to get initial values
    // create separate func to begin listening for new items
    // have the other observe code here

    func getShowsAttended() throws -> AsyncStream<UserShowDbModel> {

        // TODO: use database path error
        guard let databasePath else { throw CocoaError(.coderReadCorrupt) }

        return AsyncStream { continuation in

            Task {
                await withCheckedContinuation { innerContinuation in
                    databasePath.observeSingleEvent(of: .value, with: { data in

                        guard let json = data.value as? [String: Any] else {
                            innerContinuation.resume()
                            return
                        }

                        do {
                            defer { continuation.finish() }
                            let data = try JSONSerialization.data(withJSONObject: json)
                            let showsDecoded = try JSONDecoder().decode([String: UserShowDbModel].self, from: data)
                            let shows = showsDecoded.values.map { $0 }
                            shows.forEach {
                                self.showsAttended.append($0)
                                continuation.yield($0)
                            }
                            innerContinuation.resume()
                        } catch {
                            print(error)
                            innerContinuation.resume()
                        }
                    })
                }
            }
        }
    }

    func beginListeningForNewShowsAdded() {
        guard let databasePath else { return }
        self.handle = databasePath.observe(.childAdded) { [weak self] data in
            guard let self,
                  let json = data.value as? [String: Any] else { return }
            do {
                let data = try JSONSerialization.data(withJSONObject: json)
                let newShowDecoded = try JSONDecoder().decode(UserShowDbModel.self, from: data)
                if !self.showsAttended.contains(newShowDecoded) {
                    self.showsAttended.append(newShowDecoded)
                    self.newShowsAttendedContinuation.yield(newShowDecoded)
                    self.newShowAttendedCount += 1
                }
            } catch {
                print(error)
            }
        }
    }

    deinit {
        self.newShowsAttendedContinuation.finish()
        self.databasePath?.removeObserver(withHandle: handle)
    }

    func getSetlist(concertId: String) {

    }

    func addShowAsAttended(_ show: SetlistResponse) {

        let user = AuthenticationService().user!

        do {
            let userShowData = try JSONEncoder().encode(show.toUserShowDbModel())
            let userShow = try JSONSerialization.jsonObject(with: userShowData)

            self.reference
                .ref
                .child("users")
                .child(user.uid)
                .child("showsAttended")
                .updateChildValues([show.id: userShow])
        } catch {

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
            fatalError("Error serializing song data - \(#function)")
        }
    }

    func removeShowAsAttended(id: String) {
        let user = AuthenticationService().user!
        self.reference
            .ref
            .child("users")
            .child(user.uid)
            .child("showsAttended")
            .child(id)
            .removeValue()

        self.reference
            .ref
            .child("shows")
            .child(id)
            .child("attendedUsers")
            .observeSingleEvent(of: .value) { snapshot in
                if snapshot.exists() && snapshot.childrenCount == 0 {
                    
                }
            }

        // remove userid from show
        // if show has no users attached, delete its id from artist
        // if artist has no shows attached, delete it
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
