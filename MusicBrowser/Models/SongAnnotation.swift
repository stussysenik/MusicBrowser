import Foundation
import SwiftData

@Model
final class SongAnnotation {
    @Attribute(.unique) var songID: String
    var title: String
    var artistName: String
    var notes: String
    var tags: [String]
    var rating: Int
    var createdAt: Date
    var updatedAt: Date

    init(songID: String, title: String, artistName: String) {
        self.songID = songID
        self.title = title
        self.artistName = artistName
        self.notes = ""
        self.tags = []
        self.rating = 0
        self.createdAt = .now
        self.updatedAt = .now
    }
}
