import Foundation
import SwiftData
import MediaPlayer
import MusicKit

@Observable
final class AnalysisService {
    private var modelContext: ModelContext?
    private let bpmDetector = BPMDetectionService()

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

    // MARK: - Batch Analysis (metadata-only for speed)

    func analyzeBatch(_ songs: [Song]) async {
        guard let ctx = modelContext else { return }
        let uncached = songs.filter { cache[$0.id.rawValue] == nil }
        guard !uncached.isEmpty else { return }

        // Batch uses metadata-only: instant MPMediaItem.beatsPerMinute lookup.
        // Full DSP analysis runs on-demand when a specific song is viewed/played.
        for song in uncached {
            let songID = song.id.rawValue
            #if os(iOS)
            let item = MediaQueryHelper.findMediaItem(title: song.title, artist: song.artistName)
            let bpm = item?.beatsPerMinute ?? 0
            #else
            let bpm = 0
            #endif

            let analysis: SongAnalysis
            if let existing = cache[songID] {
                analysis = existing
            } else {
                analysis = SongAnalysis(songID: songID, title: song.title, artistName: song.artistName)
                ctx.insert(analysis)
            }

            if bpm > 0 {
                analysis.bpm = Double(bpm)
                analysis.bpmSource = BPMSource.metadata.rawValue
                analysis.bpmConfidence = 0.5
            }
            analysis.analysisDate = Date()
            analysis.analysisVersion = 2
            cache[songID] = analysis
        }
        try? ctx.save()
    }

    // MARK: - On-Demand Analysis (full DSP cascade)

    @MainActor
    private func analyzeSong(_ song: Song) async {
        guard let ctx = modelContext else { return }
        let songID = song.id.rawValue

        // Already analyzed with BPM?
        if let existing = cache[songID], existing.bpm != nil, existing.analysisVersion >= 2 { return }

        let result = await bpmDetector.detectBPM(title: song.title, artist: song.artistName)

        let analysis: SongAnalysis
        if let existing = cache[songID] {
            analysis = existing
        } else {
            analysis = SongAnalysis(songID: songID, title: song.title, artistName: song.artistName)
            ctx.insert(analysis)
        }
        analysis.bpm = result?.bpm
        analysis.bpmSource = result?.source.rawValue
        analysis.bpmConfidence = result?.confidence
        analysis.analysisDate = Date()
        analysis.analysisVersion = 2
        cache[songID] = analysis
        try? ctx.save()
    }
}
