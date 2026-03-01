import Foundation
import SwiftData

@Model
final class SongAnalysis {
    @Attribute(.unique) var songID: String
    var title: String
    var artistName: String

    // Analysis results
    var bpm: Double?
    var musicalKey: String?
    var keyConfidence: Double?
    var analysisDate: Date?
    var analysisVersion: Int

    init(songID: String, title: String, artistName: String) {
        self.songID = songID
        self.title = title
        self.artistName = artistName
        self.analysisVersion = 1
    }
}
