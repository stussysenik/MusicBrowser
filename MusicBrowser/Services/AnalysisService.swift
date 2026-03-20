import Foundation
import SwiftData
import MediaPlayer
import MusicKit

@Observable
final class AnalysisService {
    private var modelContext: ModelContext?

    // MARK: - In-Memory Cache (O(1) lookups)

    private var cache: [String: SongAnalysis] = [:]

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        loadAllCached()
    }

    /// Preload all existing analyses from SwiftData into memory — one query, O(1) thereafter
    private func loadAllCached() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<SongAnalysis>()
        guard let all = try? ctx.fetch(descriptor) else { return }
        for analysis in all {
            cache[analysis.songID] = analysis
        }
    }

    // MARK: - O(1) Lookups

    func cachedAnalysis(for song: Song) -> SongAnalysis? {
        cache[song.id.rawValue]
    }

    func bpm(for songID: String) -> Double? {
        cache[songID]?.bpm
    }

    func bpm(for song: Song) -> Double? {
        let id = song.id.rawValue
        if let cached = cache[id] {
            return cached.bpm
        }
        // Not cached — kick off background analysis
        Task.detached(priority: .utility) { [weak self] in
            await self?.analyzeSong(song)
        }
        return nil
    }

    /// Refreshes the in-memory cache for a specific song after ML analysis writes new fields.
    func refreshCache(for songID: String) {
        guard let ctx = modelContext else { return }
        let predicate = #Predicate<SongAnalysis> { $0.songID == songID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        if let updated = try? ctx.fetch(descriptor).first {
            cache[songID] = updated
        }
    }

    /// Returns all cached analyses for bulk operations.
    func allCachedAnalyses() -> [SongAnalysis] {
        Array(cache.values)
    }

    // MARK: - Batch Analysis

    func analyzeBatch(_ songs: [Song]) async {
        // Skip songs already in cache
        let uncached = songs.filter { cache[$0.id.rawValue] == nil }
        guard !uncached.isEmpty else { return }
        for song in uncached {
            await analyzeSong(song)
        }
    }

    // MARK: - Private

    @MainActor
    private func analyzeSong(_ song: Song) async {
        guard let ctx = modelContext else { return }
        let songID = song.id.rawValue

        // Already analyzed with BPM?
        if let existing = cache[songID], existing.bpm != nil { return }

        // Try to get BPM from MPMediaItem
        let bpmValue = lookupBPMFromMediaPlayer(title: song.title, artist: song.artistName)

        let analysis: SongAnalysis
        if let existing = cache[songID] {
            analysis = existing
        } else {
            analysis = SongAnalysis(
                songID: songID,
                title: song.title,
                artistName: song.artistName
            )
            ctx.insert(analysis)
        }
        analysis.bpm = bpmValue
        analysis.analysisDate = Date()
        cache[songID] = analysis
        try? ctx.save()
    }

    private func lookupBPMFromMediaPlayer(title: String, artist: String) -> Double? {
        #if os(iOS)
        let query = MPMediaQuery.songs()
        let titlePredicate = MPMediaPropertyPredicate(
            value: title,
            forProperty: MPMediaItemPropertyTitle,
            comparisonType: .equalTo
        )
        let artistPredicate = MPMediaPropertyPredicate(
            value: artist,
            forProperty: MPMediaItemPropertyArtist,
            comparisonType: .equalTo
        )
        query.addFilterPredicate(titlePredicate)
        query.addFilterPredicate(artistPredicate)

        if let item = query.items?.first {
            let bpm = item.beatsPerMinute
            return bpm > 0 ? Double(bpm) : nil
        }
        #endif
        return nil
    }
}
