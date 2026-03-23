import Foundation
import Accelerate

// MARK: - BPM Result Types

/// The result of a BPM detection pass — includes the tempo, a 0-1 confidence score,
/// and which source produced the reading (file analysis, microphone, or metadata tag).
struct BPMResult {
    let bpm: Double
    let confidence: Double
    let source: BPMSource
}

/// Where the BPM reading originated — used to display provenance in the UI
/// and to decide whether re-analysis is worthwhile.
enum BPMSource: String, Codable {
    case assetReader   // Read directly from the audio file via AVAssetReader
    case microphoneTap // Captured live from the device microphone
    case metadata      // MPMediaItem.beatsPerMinute tag
}

// MARK: - Protocol

/// Stateless DSP engine that takes raw PCM samples and returns a BPM estimate.
/// Conformers can swap algorithms without touching the orchestration layer.
protocol BPMDetectionEngineProtocol {
    func detectBPM(samples: [Float], sampleRate: Float) -> BPMResult?
}

// MARK: - Spectral Flux BPM Engine

/// Pure-Accelerate BPM detector using spectral flux onset detection + autocorrelation.
///
/// **Algorithm overview:**
/// 1. Window the audio into 2048-sample frames with a 512-sample hop (75% overlap).
/// 2. Apply a Hann window via `vDSP_vmul`.
/// 3. Compute real-to-complex FFT (2048-point) via `vDSP_fft_zrip`.
/// 4. Derive magnitude spectrum per frame with `vDSP_zvabs`.
/// 5. Half-wave rectified spectral flux: keep only positive differences between
///    consecutive magnitude spectra, forming an onset detection function.
/// 6. Autocorrelate the onset function over lags corresponding to 60-200 BPM.
/// 7. Pick the lag with maximum correlation; convert to BPM.
///
/// Everything runs on the CPU via vDSP — no Metal, no third-party libs.
struct SpectralFluxBPMEngine: BPMDetectionEngineProtocol {

    // DSP constants
    private let frameSize = 2048
    private let hopSize = 512
    private let minBPM: Double = 60
    private let maxBPM: Double = 200

    func detectBPM(samples: [Float], sampleRate: Float) -> BPMResult? {
        guard samples.count >= frameSize else { return nil }

        // --- Step 1: Build Hann window ---
        let window = hannWindow(size: frameSize)

        // --- Step 2: Prepare FFT ---
        let log2n = vDSP_Length(log2(Double(frameSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return nil
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        let halfN = frameSize / 2

        // --- Step 3: Compute magnitude spectra for each frame ---
        var magnitudeFrames: [[Float]] = []
        var frameStart = 0

        while frameStart + frameSize <= samples.count {
            // Extract and window the frame
            var windowed = [Float](repeating: 0, count: frameSize)
            vDSP_vmul(
                Array(samples[frameStart..<frameStart + frameSize]), 1,
                window, 1,
                &windowed, 1,
                vDSP_Length(frameSize)
            )

            // Pack into split complex for real FFT
            var realPart = [Float](repeating: 0, count: halfN)
            var imagPart = [Float](repeating: 0, count: halfN)

            // Interleave even/odd samples into real/imag for vDSP's packed format
            for i in 0..<halfN {
                realPart[i] = windowed[2 * i]
                imagPart[i] = windowed[2 * i + 1]
            }

            // Use withUnsafeMutableBufferPointer to keep pointers alive for the
            // entire FFT + magnitude computation scope.
            var magnitude = [Float](repeating: 0, count: halfN)
            realPart.withUnsafeMutableBufferPointer { realBuf in
                imagPart.withUnsafeMutableBufferPointer { imagBuf in
                    var splitComplex = DSPSplitComplex(
                        realp: realBuf.baseAddress!,
                        imagp: imagBuf.baseAddress!
                    )

                    // Forward FFT (in-place)
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

                    // Magnitude spectrum: sqrt(re^2 + im^2)
                    vDSP_zvabs(&splitComplex, 1, &magnitude, 1, vDSP_Length(halfN))
                }
            }

            magnitudeFrames.append(magnitude)
            frameStart += hopSize
        }

        guard magnitudeFrames.count > 1 else { return nil }

        // --- Step 4: Spectral flux (half-wave rectified) ---
        // For each consecutive pair of magnitude frames, sum the positive differences.
        // This gives us an onset strength signal — peaks where new notes/beats begin.
        var onsetFunction = [Float](repeating: 0, count: magnitudeFrames.count - 1)

        for i in 1..<magnitudeFrames.count {
            var diff = [Float](repeating: 0, count: halfN)
            // diff = current - previous
            vDSP_vsub(magnitudeFrames[i - 1], 1, magnitudeFrames[i], 1, &diff, 1, vDSP_Length(halfN))

            // Half-wave rectify: clamp negatives to zero
            var zero: Float = 0
            vDSP_vthres(diff, 1, &zero, &diff, 1, vDSP_Length(halfN))

            // Sum the rectified differences
            var sum: Float = 0
            vDSP_sve(diff, 1, &sum, vDSP_Length(halfN))
            onsetFunction[i - 1] = sum
        }

        guard !onsetFunction.isEmpty else { return nil }

        // --- Step 5: Autocorrelation over BPM-range lags ---
        // Each onset frame corresponds to hopSize/sampleRate seconds.
        // A BPM of B means a beat period of 60/B seconds = (60/B) * (sampleRate/hopSize) frames.
        let framesPerSecond = Double(sampleRate) / Double(hopSize)
        let minLag = Int(framesPerSecond * 60.0 / maxBPM)  // Fastest tempo = shortest lag
        let maxLag = Int(framesPerSecond * 60.0 / minBPM)  // Slowest tempo = longest lag

        guard minLag > 0, maxLag > minLag, maxLag < onsetFunction.count else { return nil }

        var bestLag = minLag
        var bestCorrelation: Float = -.greatestFiniteMagnitude
        var totalCorrelation: Float = 0

        let onsetCount = onsetFunction.count
        let lagCount = maxLag - minLag + 1

        // Single pass: compute autocorrelation per lag, track best and accumulate total.
        // Uses withUnsafeBufferPointer to avoid allocating a new Array on each iteration.
        onsetFunction.withUnsafeBufferPointer { onsetBuf in
            for lag in minLag...maxLag {
                let overlapLength = onsetCount - lag
                guard overlapLength > 0 else { continue }

                // Dot product of onset[0..<overlapLength] with onset[lag..<lag+overlapLength]
                var correlation: Float = 0
                vDSP_dotpr(
                    onsetBuf.baseAddress!, 1,
                    onsetBuf.baseAddress! + lag, 1,
                    &correlation,
                    vDSP_Length(overlapLength)
                )

                totalCorrelation += correlation
                if correlation > bestCorrelation {
                    bestCorrelation = correlation
                    bestLag = lag
                }
            }
        }

        // --- Step 6: Convert lag to BPM ---
        let detectedBPM = 60.0 * framesPerSecond / Double(bestLag)

        // Confidence: ratio of best correlation to mean correlation across all lags
        let meanCorrelation = totalCorrelation / Float(lagCount)
        let confidence = meanCorrelation > 0
            ? Double(min(bestCorrelation / (meanCorrelation * 2.0), 1.0))
            : 0.0

        return BPMResult(
            bpm: detectedBPM.rounded(),
            confidence: max(0, min(confidence, 1.0)),
            source: .assetReader
        )
    }

    // MARK: - Helpers

    /// Generate a Hann window of the given size using vDSP.
    /// The Hann window tapers samples at frame edges to reduce spectral leakage.
    private func hannWindow(size: Int) -> [Float] {
        var window = [Float](repeating: 0, count: size)
        vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))
        return window
    }
}
