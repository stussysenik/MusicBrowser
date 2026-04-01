import Foundation
import SwiftData
import MediaPlayer
import MusicKit

@MainActor
@Observable
final class AnalysisService {
    struct BPMOverview {
        let analyzedCount: Int
        let totalCount: Int
        let average: Double?
    }

    let runtime: AppRuntime
    private var modelContext: ModelContext?
    private let bpmDetector = BPMDetectionService()

    // MARK: - In-Memory Cache (O(1) lookups)

    private var cache: [String: SongAnalysis] = [:]

    init(runtime: AppRuntime = .current) {
        self.runtime = runtime
    }

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        loadAllCached()
        if runtime.usesDummyData {
            primeDemoLibrary()
        }
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

    func bpm(for demoSong: DemoSong) -> Double? {
        cache[demoSong.id]?.bpm ?? demoSong.bpm
    }

    func bpm(for song: Song) -> Double? {
        let id = song.id.rawValue
        if let cached = cache[id] {
            return cached.bpm
        }
        // Not cached — kick off background analysis
        Task(priority: .utility) { [weak self] in
            await self?.analyzeSong(song)
        }
        return nil
    }

    func bpmOverview(for songIDs: [String]) -> BPMOverview {
        let bpms = songIDs.compactMap { cache[$0]?.bpm }.filter { $0 > 0 }
        let average = bpms.isEmpty ? nil : bpms.reduce(0, +) / Double(bpms.count)
        return BPMOverview(
            analyzedCount: bpms.count,
            totalCount: songIDs.count,
            average: average
        )
    }

    func tempoSectionTitle(for bpm: Double?) -> String {
        TempoBuckets.label(for: bpm)
    }

    // MARK: - Batch Analysis (metadata-only for speed)

    func analyzeBatch(_ songs: [Song]) async {
        guard !runtime.usesDummyData else { return }
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

            if cache.count.isMultiple(of: 24) {
                await Task.yield()
            }
        }
        try? ctx.save()
    }

    private func primeDemoLibrary() {
        guard let ctx = modelContext else { return }

        for song in DemoSongLibrary.songs {
            let analysis = cache[song.id] ?? SongAnalysis(songID: song.id, title: song.title, artistName: song.artistName)
            if cache[song.id] == nil {
                ctx.insert(analysis)
            }
            analysis.bpm = song.bpm
            analysis.bpmSource = BPMSource.metadata.rawValue
            analysis.bpmConfidence = 1
            analysis.analysisDate = Date()
            analysis.analysisVersion = 2
            cache[song.id] = analysis
        }

        try? ctx.save()
    }

    // MARK: - On-Demand Analysis (full DSP cascade)

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
