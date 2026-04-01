import Foundation
import AVFoundation

// MARK: - Audio Samples

/// Raw PCM audio data ready for DSP analysis.
struct AudioSamples {
    let samples: [Float]
    let sampleRate: Float
}

// MARK: - Protocol

/// Provides a chunk of mono float32 audio for BPM analysis.
protocol AudioBufferProvider {
    func readSamples(maxDuration: TimeInterval) async throws -> AudioSamples
}

// MARK: - Errors

enum AudioBufferError: LocalizedError {
    case noAssetURL
    case readerSetupFailed
    case noSamplesRead

    var errorDescription: String? {
        switch self {
        case .noAssetURL:         return "No local audio file found for this track."
        case .readerSetupFailed:  return "Could not set up audio reader."
        case .noSamplesRead:      return "No audio samples were read."
        }
    }
}

// MARK: - Shared Media Query Helper

#if os(iOS)
import MediaPlayer

/// Centralised MPMediaQuery lookup used by both AssetReaderProvider (asset URL)
/// and BPMDetectionService (metadata BPM tag). Avoids duplicating the same
/// title + artist query in two places.
enum MediaQueryHelper {
    static func findMediaItem(title: String, artist: String) -> MPMediaItem? {
        let query = MPMediaQuery.songs()
        query.addFilterPredicate(MPMediaPropertyPredicate(
            value: title, forProperty: MPMediaItemPropertyTitle, comparisonType: .equalTo
        ))
        query.addFilterPredicate(MPMediaPropertyPredicate(
            value: artist, forProperty: MPMediaItemPropertyArtist, comparisonType: .equalTo
        ))
        return query.items?.first
    }

    static func findMediaItem(persistentID: UInt64) -> MPMediaItem? {
        let query = MPMediaQuery.songs()
        query.addFilterPredicate(MPMediaPropertyPredicate(
            value: NSNumber(value: persistentID),
            forProperty: MPMediaItemPropertyPersistentID,
            comparisonType: .equalTo
        ))
        return query.items?.first
    }
}

// MARK: - Asset Reader Provider (reads from local media library file)

/// Reads up to `maxDuration` seconds of mono float32 audio from a local
/// MPMediaItem's asset URL via AVAssetReader. This is the highest-fidelity
/// source — no ambient noise, no microphone needed.
struct AssetReaderProvider: AudioBufferProvider {

    let title: String
    let artist: String

    func readSamples(maxDuration: TimeInterval) async throws -> AudioSamples {
        // Step 1: Find the MPMediaItem matching title + artist
        guard let assetURL = MediaQueryHelper.findMediaItem(title: title, artist: artist)?.assetURL else {
            throw AudioBufferError.noAssetURL
        }

        // Step 2: Set up AVAssetReader for mono float32 output
        let asset = AVURLAsset(url: assetURL)
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw AudioBufferError.readerSetupFailed
        }

        // Load audio tracks
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioBufferError.readerSetupFailed
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        reader.add(output)

        guard reader.startReading() else {
            throw AudioBufferError.readerSetupFailed
        }

        // Step 3: Read samples up to maxDuration
        let sampleRate: Float = 44100
        let maxSamples = Int(sampleRate * Float(maxDuration))
        var allSamples = [Float]()
        allSamples.reserveCapacity(maxSamples)

        while reader.status == .reading, allSamples.count < maxSamples {
            guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

            let length = CMBlockBufferGetDataLength(blockBuffer)
            let floatCount = length / MemoryLayout<Float>.size

            var data = [Float](repeating: 0, count: floatCount)
            CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: &data)

            let remaining = maxSamples - allSamples.count
            let toAppend = min(floatCount, remaining)
            allSamples.append(contentsOf: data.prefix(toAppend))
        }

        reader.cancelReading()

        guard !allSamples.isEmpty else {
            throw AudioBufferError.noSamplesRead
        }

        return AudioSamples(samples: allSamples, sampleRate: sampleRate)
    }

}
#endif
