import Foundation
import SwiftData
import Observation

/// Tracks listening sessions and computes stats for the Music Intelligence Dashboard.
@Observable
final class StatsService {
    private var modelContext: ModelContext?

    // Active session tracking
    private var activeSessions: [String: ListeningSession] = [:] // songID -> session

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Session Recording

    /// Call when a song starts playing.
    func startSession(
        songID: String,
        title: String,
        artistName: String,
        albumTitle: String?,
        genreNames: [String],
        songDuration: TimeInterval?,
        releaseYear: Int?
    ) {
        guard let ctx = modelContext else { return }
        let session = ListeningSession(
            songID: songID,
            title: title,
            artistName: artistName,
            albumTitle: albumTitle,
            genreNames: genreNames,
            songDuration: songDuration ?? 0,
            releaseYear: releaseYear
        )
        ctx.insert(session)
        activeSessions[songID] = session
    }

    /// Call when a song ends or is skipped.
    func endSession(songID: String, completed: Bool) {
        guard let session = activeSessions.removeValue(forKey: songID) else { return }
        session.endedAt = .now
        session.duration = session.endedAt?.timeIntervalSince(session.startedAt) ?? 0
        session.completedFully = completed || (session.songDuration > 0 && session.duration / session.songDuration > 0.9)
        try? modelContext?.save()
    }

    // MARK: - Listening Behavior

    enum TimePeriod {
        case today, thisWeek, thisMonth, allTime
        case custom(from: Date, to: Date)

        var dateRange: (start: Date, end: Date) {
            let cal = Calendar.current
            let now = Date()
            switch self {
            case .today:
                return (cal.startOfDay(for: now), now)
            case .thisWeek:
                let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                return (start, now)
            case .thisMonth:
                let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
                return (start, now)
            case .allTime:
                return (.distantPast, now)
            case .custom(let from, let to):
                return (from, to)
            }
        }
    }

    func totalListeningTime(period: TimePeriod) -> TimeInterval {
        let sessions = fetchSessions(period: period)
        return sessions.reduce(0) { $0 + $1.duration }
    }

    func listeningStreak() -> Int {
        let cal = Calendar.current
        let allSessions = fetchSessions(period: .allTime)
        let uniqueDays = Set(allSessions.map { cal.startOfDay(for: $0.startedAt) }).sorted(by: >)

        guard let latest = uniqueDays.first else { return 0 }
        // Only count streak if it includes today or yesterday
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        guard latest >= yesterday else { return 0 }

        var streak = 1
        for i in 1..<uniqueDays.count {
            let expected = cal.date(byAdding: .day, value: -i, to: latest)!
            if cal.isDate(uniqueDays[i], inSameDayAs: expected) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    /// Returns play counts per hour (0-23) for heatmap display.
    func hourlyHeatmap(period: TimePeriod = .thisMonth) -> [Int: Int] {
        let sessions = fetchSessions(period: period)
        var heatmap: [Int: Int] = [:]
        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startedAt)
            heatmap[hour, default: 0] += 1
        }
        return heatmap
    }

    func topSongs(limit: Int = 10, period: TimePeriod = .thisMonth) -> [(songID: String, title: String, artistName: String, playCount: Int)] {
        let sessions = fetchSessions(period: period)
        let grouped = Dictionary(grouping: sessions) { $0.songID }
        return grouped
            .map { (songID: $0.key, title: $0.value.first?.title ?? "", artistName: $0.value.first?.artistName ?? "", playCount: $0.value.count) }
            .sorted { $0.playCount > $1.playCount }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Library Intelligence

    func genreDistribution(songs: [(genreNames: [String], Void)]) -> [(genre: String, count: Int)] {
        var counts: [String: Int] = [:]
        for song in songs {
            for genre in song.genreNames {
                counts[genre, default: 0] += 1
            }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }

    func decadeDistribution(releaseYears: [Int?]) -> [(decade: String, count: Int)] {
        var counts: [String: Int] = [:]
        for year in releaseYears.compactMap({ $0 }) {
            let decade = "\((year / 10) * 10)s"
            counts[decade, default: 0] += 1
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.decade < $1.decade }
    }

    func bpmHistogram(analyses: [SongAnalysis]) -> [(range: String, count: Int)] {
        let buckets = stride(from: 60, to: 200, by: 10)
        var histogram: [(String, Int)] = []
        for low in buckets {
            let high = low + 10
            let count = analyses.filter { a in
                guard let bpm = a.bpm else { return false }
                return bpm >= Double(low) && bpm < Double(high)
            }.count
            histogram.append(("\(low)-\(high)", count))
        }
        return histogram
    }

    func forgottenGems(songIDs: Set<String>, dayThreshold: Int = 90) -> [String] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -dayThreshold, to: Date()) ?? Date()
        let recentSessions = fetchSessions(period: .custom(from: cutoff, to: Date()))
        let recentlyPlayed = Set(recentSessions.map(\.songID))
        return songIDs.subtracting(recentlyPlayed).sorted()
    }

    // MARK: - Weekly Recap

    func generateWeeklyRecap() -> WeeklyRecap? {
        guard let ctx = modelContext else { return nil }
        let cal = Calendar.current
        let now = Date()
        let weekOfYear = cal.component(.weekOfYear, from: now)
        let year = cal.component(.yearForWeekOfYear, from: now)
        let weekID = String(format: "%d-W%02d", year, weekOfYear)

        // Check if already generated
        let predicate = #Predicate<WeeklyRecap> { $0.weekID == weekID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        if let existing = try? ctx.fetch(descriptor).first { return existing }

        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let sessions = fetchSessions(period: .custom(from: weekStart, to: now))
        guard !sessions.isEmpty else { return nil }

        let totalMinutes = sessions.reduce(0.0) { $0 + $1.duration } / 60.0
        let uniqueSongs = Set(sessions.map(\.songID)).count
        let uniqueArtists = Set(sessions.map(\.artistName)).count

        let songCounts = Dictionary(grouping: sessions) { $0.songID }
        let topSong = songCounts.max { $0.value.count < $1.value.count }
        let artistCounts = Dictionary(grouping: sessions) { $0.artistName }
        let topArtist = artistCounts.max { $0.value.count < $1.value.count }
        let genreCounts = sessions.flatMap(\.genreNames).reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let topGenre = genreCounts.max { $0.value < $1.value }?.key

        let personality = listeningPersonality(sessions: sessions)

        let recap = WeeklyRecap(
            weekID: weekID,
            totalMinutes: totalMinutes,
            uniqueSongs: uniqueSongs,
            uniqueArtists: uniqueArtists,
            topSongID: topSong?.key,
            topSongTitle: topSong?.value.first?.title,
            topArtistName: topArtist?.key,
            topGenre: topGenre,
            personalityType: personality
        )
        ctx.insert(recap)
        try? ctx.save()
        return recap
    }

    func listeningPersonality(sessions: [ListeningSession]? = nil) -> String {
        let data = sessions ?? fetchSessions(period: .thisMonth)
        guard !data.isEmpty else { return "New Listener" }

        let uniqueArtists = Set(data.map(\.artistName)).count
        let uniqueGenres = Set(data.flatMap(\.genreNames)).count
        let completionRate = data.isEmpty ? 0 : Double(data.filter(\.completedFully).count) / Double(data.count)

        if uniqueGenres > 8 { return "Explorer" }
        if completionRate > 0.85 { return "Deep Diver" }
        if uniqueArtists < 5 { return "Genre Loyalist" }
        if data.count > 100 { return "Power Listener" }
        return "Casual Listener"
    }

    // MARK: - Dummy Data (for testing)

    static func withDummyData(context: ModelContext) -> StatsService {
        let service = StatsService()
        service.configure(with: context)

        let cal = Calendar.current
        let artists = ["The Resonators", "Luna Park", "Jade Compass", "Polar Echo", "Skyline"]
        let genres = [["Rock", "Indie"], ["Pop", "Electronic"], ["Jazz"], ["Hip-Hop", "R&B"], ["Folk"]]
        let songs = ["Midnight Dreams", "Golden Highway", "Electric Symphony", "Broken Echoes", "Crystal Light",
                     "Silver Rain", "Neon Storm", "Shadow Dance", "Cosmic Fire", "Velvet Wave"]

        for dayOffset in 0..<30 {
            let sessionsPerDay = Int.random(in: 3...12)
            for _ in 0..<sessionsPerDay {
                let hour = Int.random(in: 6...23)
                let date = cal.date(byAdding: .day, value: -dayOffset, to: Date())!
                let startDate = cal.date(bySettingHour: hour, minute: Int.random(in: 0...59), second: 0, of: date)!
                let songIdx = Int.random(in: 0..<songs.count)
                let artistIdx = Int.random(in: 0..<artists.count)
                let songDuration = TimeInterval.random(in: 150...400)
                let actualDuration = TimeInterval.random(in: 30...songDuration)

                let session = ListeningSession(
                    songID: "dummy-\(songIdx)",
                    title: songs[songIdx],
                    artistName: artists[artistIdx],
                    albumTitle: "Album \(songIdx / 3 + 1)",
                    genreNames: genres[artistIdx],
                    duration: actualDuration,
                    songDuration: songDuration,
                    startedAt: startDate,
                    endedAt: startDate.addingTimeInterval(actualDuration),
                    completedFully: actualDuration / songDuration > 0.9,
                    releaseYear: Int.random(in: 1970...2025)
                )
                context.insert(session)
            }
        }
        try? context.save()
        return service
    }

    // MARK: - Recent Sessions

    func recentSessions(limit: Int = 30) -> [ListeningSession] {
        guard let ctx = modelContext else { return [] }
        var descriptor = FetchDescriptor<ListeningSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? ctx.fetch(descriptor)) ?? []
    }

    // MARK: - Private

    private func fetchSessions(period: TimePeriod) -> [ListeningSession] {
        guard let ctx = modelContext else { return [] }
        let range = period.dateRange
        let start = range.start
        let end = range.end
        let predicate = #Predicate<ListeningSession> { $0.startedAt >= start && $0.startedAt <= end }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return (try? ctx.fetch(descriptor)) ?? []
    }
}
