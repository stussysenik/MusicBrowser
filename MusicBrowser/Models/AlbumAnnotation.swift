import Foundation
import SwiftData

@Model
final class AlbumAnnotation {
    @Attribute(.unique) var albumID: String
    var title: String
    var artistName: String
    var notes: String
    var tagsRaw: String
    var rating: Int
    var createdAt: Date
    var updatedAt: Date

    var tags: [String] {
        get { tagsRaw.isEmpty ? [] : tagsRaw.components(separatedBy: ",") }
        set { tagsRaw = newValue.joined(separator: ",") }
    }

    init(albumID: String, title: String, artistName: String) {
        self.albumID = albumID
        self.title = title
        self.artistName = artistName
        self.notes = ""
        self.tagsRaw = ""
        self.rating = 0
        self.createdAt = .now
        self.updatedAt = .now
    }
}
