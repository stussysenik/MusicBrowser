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

    // ML analysis results
    var energyScore: Double?          // 0.0-1.0
    var moodClassification: String?   // "Energetic", "Melancholic", "Chill", "Aggressive"
    var moodConfidence: Double?
    var genreML: String?              // ML-detected genre
    var genreMLConfidence: Double?
    var instrumentTags: [String]?
    var mlModelVersion: String?       // e.g. "musicbrowser-audio-v1.2"
    var analysisSource: String?       // "mediaPlayer", "soundAnalysis", "coreML", "combined"

    init(songID: String, title: String, artistName: String) {
        self.songID = songID
        self.title = title
        self.artistName = artistName
        self.analysisVersion = 1
    }
}
