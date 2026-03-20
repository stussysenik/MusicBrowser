import Foundation
import SwiftData

/// Pre-computed weekly summary for quick dashboard rendering.
@Model
final class WeeklyRecap {
    @Attribute(.unique) var weekID: String   // e.g. "2026-W12"
    var totalMinutes: Double
    var uniqueSongs: Int
    var uniqueArtists: Int
    var topSongID: String?
    var topSongTitle: String?
    var topArtistName: String?
    var topGenre: String?
    var personalityType: String?             // e.g. "Explorer", "Deep Diver", "Genre Loyalist"
    var generatedAt: Date

    init(
        weekID: String,
        totalMinutes: Double = 0,
        uniqueSongs: Int = 0,
        uniqueArtists: Int = 0,
        topSongID: String? = nil,
        topSongTitle: String? = nil,
        topArtistName: String? = nil,
        topGenre: String? = nil,
        personalityType: String? = nil
    ) {
        self.weekID = weekID
        self.totalMinutes = totalMinutes
        self.uniqueSongs = uniqueSongs
        self.uniqueArtists = uniqueArtists
        self.topSongID = topSongID
        self.topSongTitle = topSongTitle
        self.topArtistName = topArtistName
        self.topGenre = topGenre
        self.personalityType = personalityType
        self.generatedAt = .now
    }
}
