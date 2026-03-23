import Foundation
import AVFoundation

// MARK: - BPM Detection Service

/// Orchestrates BPM detection through a cascade of sources:
///   1. **Metadata** — MPMediaItem.beatsPerMinute tag (instant but often missing)
///   2. **Asset reader** — reads the local audio file (highest accuracy, ~30s)
///
/// Results are cached permanently in SwiftData via SongAnalysis.
/// No microphone or live detection — one-shot detect and cache.
final class BPMDetectionService {

    private let engine: BPMDetectionEngineProtocol = SpectralFluxBPMEngine()

    /// Attempt BPM detection: metadata first (instant), then asset reader (DSP).
    /// Returns the first successful result, or nil if all sources fail.
    func detectBPM(title: String, artist: String) async -> BPMResult? {
        // Source 1: Metadata (instant)
        #if os(iOS)
        if let result = detectFromMetadata(title: title, artist: artist) {
            return result
        }
        #endif

        // Source 2: Read from local audio file (30s sample, best accuracy)
        #if os(iOS)
        if let result = await detectFromAssetReader(title: title, artist: artist) {
            return result
        }
        #endif

        return nil
    }

    // MARK: - Private: Individual Sources

    #if os(iOS)
    /// Read the song's local audio file and analyze it.
    private func detectFromAssetReader(title: String, artist: String) async -> BPMResult? {
        let provider = AssetReaderProvider(title: title, artist: artist)
        do {
            let audio = try await provider.readSamples(maxDuration: 30)
            return engine.detectBPM(samples: audio.samples, sampleRate: audio.sampleRate)
        } catch {
            return nil
        }
    }

    /// Look up BPM from MPMediaItem metadata tags.
    private func detectFromMetadata(title: String, artist: String) -> BPMResult? {
        guard let item = MediaQueryHelper.findMediaItem(title: title, artist: artist) else { return nil }
        let bpm = item.beatsPerMinute
        guard bpm > 0 else { return nil }

        return BPMResult(
            bpm: Double(bpm),
            confidence: 0.5, // Tag data is reliable but we can't verify accuracy
            source: .metadata
        )
    }
    #endif
}
