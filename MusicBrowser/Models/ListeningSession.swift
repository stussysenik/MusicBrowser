import Foundation
import SwiftData

/// Records individual play sessions for computing listening stats at any time window.
/// ~100 bytes/session = ~1.8MB/year at 50 plays/day.
@Model
final class ListeningSession {
    var id: UUID
    var songID: String
    var title: String
    var artistName: String
    var albumTitle: String?
    var genreNames: [String]
    var duration: TimeInterval         // actual listening duration
    var songDuration: TimeInterval     // full track length
    var startedAt: Date
    var endedAt: Date?
    var completedFully: Bool           // >90% listened
    var releaseYear: Int?

    init(
        songID: String,
        title: String,
        artistName: String,
        albumTitle: String? = nil,
        genreNames: [String] = [],
        duration: TimeInterval = 0,
        songDuration: TimeInterval = 0,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        completedFully: Bool = false,
        releaseYear: Int? = nil
    ) {
        self.id = UUID()
        self.songID = songID
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.genreNames = genreNames
        self.duration = duration
        self.songDuration = songDuration
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.completedFully = completedFully
        self.releaseYear = releaseYear
    }
}
