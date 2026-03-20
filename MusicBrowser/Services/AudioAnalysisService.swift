import Foundation
import AVFoundation
import Observation
import SwiftData
#if canImport(MediaPlayer)
import MediaPlayer
#endif

/// CoreML pipeline orchestrator for on-device audio analysis.
/// Handles audio access, DSP feature extraction, and batch processing.
@Observable
final class AudioAnalysisService {
    private var modelContext: ModelContext?
    private let modelManager = ModelDownloadManager()

    // Batch processing state
    var isAnalyzing = false
    var analysisProgress: Double = 0
    var analyzedCount = 0
    var totalToAnalyze = 0

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Single Song Analysis

    /// Analyzes a single song using available audio analysis techniques.
    /// DRM-protected tracks gracefully fall back to metadata-only analysis.
    @MainActor
    func analyzeSong(songID: String, title: String, artistName: String) async -> SongAnalysis? {
        guard let ctx = modelContext else { return nil }

        // Check for existing analysis
        let predicate = #Predicate<SongAnalysis> { $0.songID == songID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        let existing = try? ctx.fetch(descriptor).first

        let analysis = existing ?? SongAnalysis(songID: songID, title: title, artistName: artistName)
        if existing == nil { ctx.insert(analysis) }

        // Try to get audio buffer for DSP analysis
        if let buffer = await loadAudioBuffer(for: songID) {
            // BPM detection
            if analysis.bpm == nil {
                analysis.bpm = AudioFeatureExtractor.detectBPM(buffer: buffer)
            }

            // Key detection
            if analysis.musicalKey == nil {
                if let keyResult = AudioFeatureExtractor.detectKey(buffer: buffer) {
                    analysis.musicalKey = keyResult.key
                    analysis.keyConfidence = keyResult.confidence
                }
            }

            // Energy score
            if analysis.energyScore == nil {
                analysis.energyScore = AudioFeatureExtractor.computeEnergy(buffer: buffer)
            }

            analysis.analysisSource = "combined"
        } else {
            // Fallback: metadata-only analysis
            #if os(iOS)
            if analysis.bpm == nil {
                analysis.bpm = lookupBPMFromMediaPlayer(title: title, artist: artistName)
            }
            #endif
            analysis.analysisSource = "mediaPlayer"
        }

        analysis.analysisDate = Date()
        analysis.analysisVersion = 2
        try? ctx.save()
        return analysis
    }

    // MARK: - Batch Processing

    /// Analyzes multiple songs in the background with progress reporting.
    func analyzeBatch(songs: [(id: String, title: String, artist: String)]) async {
        guard !isAnalyzing else { return }

        await MainActor.run {
            isAnalyzing = true
            totalToAnalyze = songs.count
            analyzedCount = 0
            analysisProgress = 0
        }

        for (idx, song) in songs.enumerated() {
            guard !Task.isCancelled else { break }

            _ = await analyzeSong(songID: song.id, title: song.title, artistName: song.artist)

            await MainActor.run {
                analyzedCount = idx + 1
                analysisProgress = Double(analyzedCount) / Double(totalToAnalyze)
            }

            // Yield periodically to avoid blocking
            if idx % 5 == 0 {
                await Task.yield()
            }
        }

        await MainActor.run {
            isAnalyzing = false
        }
    }

    // MARK: - Audio Loading

    /// Loads audio samples from a song's asset URL.
    /// Returns nil for DRM-protected tracks.
    private func loadAudioBuffer(for songID: String) async -> [Float]? {
        #if os(iOS)
        // Try to get asset URL from MPMediaQuery
        let query = MPMediaQuery.songs()
        let predicate = MPMediaPropertyPredicate(
            value: songID,
            forProperty: MPMediaItemPropertyPersistentID,
            comparisonType: .equalTo
        )
        query.addFilterPredicate(predicate)

        guard let item = query.items?.first,
              let assetURL = item.assetURL else { return nil }

        return await loadSamplesFromURL(assetURL)
        #else
        return nil
        #endif
    }

    private func loadSamplesFromURL(_ url: URL) async -> [Float]? {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

            // Read 30 seconds from 25% into the track
            let totalFrames = file.length
            let sampleRate = file.processingFormat.sampleRate
            let startFrame = AVAudioFramePosition(Double(totalFrames) * 0.25)
            let framesToRead = min(AVAudioFrameCount(30 * sampleRate), AVAudioFrameCount(totalFrames - startFrame))

            file.framePosition = startFrame

            guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: framesToRead) else { return nil }
            try file.read(into: inputBuffer, frameCount: framesToRead)

            // Convert to mono 16kHz
            guard let converter = AVAudioConverter(from: file.processingFormat, to: format) else { return nil }
            let outputFrameCount = AVAudioFrameCount(Double(framesToRead) * 16000 / sampleRate)
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputFrameCount) else { return nil }

            var error: NSError?
            converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return inputBuffer
            }

            guard error == nil, let channelData = outputBuffer.floatChannelData else { return nil }
            return Array(UnsafeBufferPointer(start: channelData[0], count: Int(outputBuffer.frameLength)))
        } catch {
            return nil
        }
    }

    #if os(iOS)
    private func lookupBPMFromMediaPlayer(title: String, artist: String) -> Double? {
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
        return nil
    }
    #endif
}
