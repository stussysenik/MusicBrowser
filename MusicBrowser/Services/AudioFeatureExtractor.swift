import Foundation
import Accelerate

/// Pure-function DSP utility using Accelerate/vDSP for audio feature extraction.
/// All methods are stateless and thread-safe.
enum AudioFeatureExtractor {

    // MARK: - BPM Detection (autocorrelation on onset detection)

    /// Detects BPM from raw audio samples using autocorrelation.
    /// - Parameter buffer: Mono audio samples at known sample rate
    /// - Parameter sampleRate: Sample rate of the buffer (e.g. 16000)
    /// - Returns: Estimated BPM, or nil if detection failed
    static func detectBPM(buffer: [Float], sampleRate: Float = 16000) -> Double? {
        guard buffer.count > Int(sampleRate * 2) else { return nil }

        // Compute onset strength envelope via spectral flux
        let hopSize = 512
        let frameSize = 1024
        let onsetEnvelope = computeOnsetEnvelope(buffer: buffer, frameSize: frameSize, hopSize: hopSize)
        guard onsetEnvelope.count > 100 else { return nil }

        // Autocorrelation of onset envelope
        let autocorr = autocorrelation(onsetEnvelope)

        // Search for peaks in the BPM range 60-200
        let framesPerSecond = sampleRate / Float(hopSize)
        let minLag = Int(framesPerSecond * 60.0 / 200.0) // 200 BPM
        let maxLag = Int(framesPerSecond * 60.0 / 60.0)  // 60 BPM

        guard minLag < maxLag, maxLag < autocorr.count else { return nil }

        var bestLag = minLag
        var bestVal: Float = -Float.infinity
        for lag in minLag...min(maxLag, autocorr.count - 1) {
            if autocorr[lag] > bestVal {
                bestVal = autocorr[lag]
                bestLag = lag
            }
        }

        let bpm = Double(framesPerSecond * 60.0 / Float(bestLag))
        return bpm.isFinite ? bpm : nil
    }

    // MARK: - Key Detection (chroma feature + template matching)

    /// Detects musical key from audio samples using chroma features.
    /// - Returns: Tuple of key name (e.g. "C Major") and confidence 0-1
    static func detectKey(buffer: [Float], sampleRate: Float = 16000) -> (key: String, confidence: Double)? {
        guard buffer.count > Int(sampleRate) else { return nil }

        let chroma = computeChromaFeatures(buffer: buffer, sampleRate: sampleRate)
        guard chroma.count == 12 else { return nil }

        // Template matching against major and minor key profiles
        let majorProfile: [Float] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
        let minorProfile: [Float] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

        var bestCorr: Float = -Float.infinity
        var bestKey = ""

        for shift in 0..<12 {
            let shifted = rotateArray(chroma, by: shift)

            let majorCorr = pearsonCorrelation(shifted, majorProfile)
            if majorCorr > bestCorr {
                bestCorr = majorCorr
                bestKey = "\(noteNames[shift]) Major"
            }

            let minorCorr = pearsonCorrelation(shifted, minorProfile)
            if minorCorr > bestCorr {
                bestCorr = minorCorr
                bestKey = "\(noteNames[shift]) Minor"
            }
        }

        let confidence = Double(max(0, min(1, (bestCorr + 1) / 2)))
        return (bestKey, confidence)
    }

    // MARK: - Energy (RMS normalized to 0.0-1.0)

    /// Computes overall energy level of the audio buffer.
    static func computeEnergy(buffer: [Float]) -> Double {
        guard !buffer.isEmpty else { return 0 }
        var rms: Float = 0
        vDSP_rmsqv(buffer, 1, &rms, vDSP_Length(buffer.count))
        // Normalize: typical music RMS is 0.05-0.3
        return Double(min(1.0, rms / 0.25))
    }

    // MARK: - Spectral Features

    /// Computes spectral centroid and rolloff for genre classification.
    /// Returns [centroid, rolloff] normalized to 0-1.
    static func spectralFeatures(buffer: [Float], sampleRate: Float = 16000) -> [Float] {
        guard buffer.count >= 1024 else { return [0, 0] }

        let frameSize = 1024
        let frame = Array(buffer.prefix(frameSize))

        // FFT magnitude spectrum
        let magnitudes = fftMagnitudes(frame)
        guard !magnitudes.isEmpty else { return [0, 0] }

        let totalEnergy = magnitudes.reduce(0, +)
        guard totalEnergy > 0 else { return [0, 0] }

        // Spectral centroid
        var weightedSum: Float = 0
        for (i, mag) in magnitudes.enumerated() {
            weightedSum += Float(i) * mag
        }
        let centroid = weightedSum / totalEnergy
        let normalizedCentroid = centroid / Float(magnitudes.count)

        // Spectral rolloff (frequency below which 85% of energy is contained)
        var cumEnergy: Float = 0
        let threshold = totalEnergy * 0.85
        var rolloffBin = magnitudes.count - 1
        for (i, mag) in magnitudes.enumerated() {
            cumEnergy += mag
            if cumEnergy >= threshold {
                rolloffBin = i
                break
            }
        }
        let normalizedRolloff = Float(rolloffBin) / Float(magnitudes.count)

        return [normalizedCentroid, normalizedRolloff]
    }

    // MARK: - Private Helpers

    private static func computeOnsetEnvelope(buffer: [Float], frameSize: Int, hopSize: Int) -> [Float] {
        var envelope: [Float] = []
        var prevMagnitudes: [Float]?

        var offset = 0
        while offset + frameSize <= buffer.count {
            let frame = Array(buffer[offset..<offset + frameSize])
            let magnitudes = fftMagnitudes(frame)

            if let prev = prevMagnitudes {
                // Spectral flux: sum of positive differences
                var flux: Float = 0
                for i in 0..<min(magnitudes.count, prev.count) {
                    let diff = magnitudes[i] - prev[i]
                    if diff > 0 { flux += diff }
                }
                envelope.append(flux)
            }
            prevMagnitudes = magnitudes
            offset += hopSize
        }
        return envelope
    }

    private static func autocorrelation(_ signal: [Float]) -> [Float] {
        let n = signal.count
        var result = [Float](repeating: 0, count: n)
        vDSP_conv(signal, 1, signal, 1, &result, 1, vDSP_Length(n), vDSP_Length(n))
        // Normalize
        if let maxVal = result.first, maxVal > 0 {
            var divisor = maxVal
            vDSP_vsdiv(result, 1, &divisor, &result, 1, vDSP_Length(n))
        }
        return result
    }

    private static func computeChromaFeatures(buffer: [Float], sampleRate: Float) -> [Float] {
        let frameSize = 4096
        guard buffer.count >= frameSize else { return [] }

        var chroma = [Float](repeating: 0, count: 12)
        let magnitudes = fftMagnitudes(Array(buffer.prefix(frameSize)))
        let binHz = sampleRate / Float(frameSize)

        for (bin, mag) in magnitudes.enumerated() where bin > 0 {
            let freq = Float(bin) * binHz
            guard freq > 20 && freq < 5000 else { continue }
            // Map frequency to pitch class
            let midiNote = 69 + 12 * log2(freq / 440.0)
            let pitchClass = Int(round(midiNote)) % 12
            let safeIndex = ((pitchClass % 12) + 12) % 12
            chroma[safeIndex] += mag * mag
        }

        // Normalize chroma
        let maxChroma = chroma.max() ?? 1
        if maxChroma > 0 {
            chroma = chroma.map { $0 / maxChroma }
        }
        return chroma
    }

    private static func fftMagnitudes(_ frame: [Float]) -> [Float] {
        let n = frame.count
        guard n > 0 else { return [] }
        let log2n = vDSP_Length(log2(Float(n)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var realPart = frame
        var imagPart = [Float](repeating: 0, count: n)
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)

        // Apply Hann window
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        vDSP_vmul(realPart, 1, window, 1, &realPart, 1, vDSP_Length(n))

        vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

        // Compute magnitudes: sqrt(real^2 + imag^2) for each bin
        var magnitudes = [Float](repeating: 0, count: n / 2)
        for i in 0..<n/2 {
            let r = realPart[i]
            let im = imagPart[i]
            magnitudes[i] = sqrt(r * r + im * im)
        }

        return magnitudes
    }

    private static func rotateArray(_ array: [Float], by positions: Int) -> [Float] {
        guard !array.isEmpty else { return array }
        let shift = ((positions % array.count) + array.count) % array.count
        return Array(array[shift...]) + Array(array[..<shift])
    }

    private static func pearsonCorrelation(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let n = Float(a.count)
        let meanA = a.reduce(0, +) / n
        let meanB = b.reduce(0, +) / n

        var num: Float = 0
        var denA: Float = 0
        var denB: Float = 0
        for i in 0..<a.count {
            let da = a[i] - meanA
            let db = b[i] - meanB
            num += da * db
            denA += da * da
            denB += db * db
        }
        let den = sqrt(denA * denB)
        return den > 0 ? num / den : 0
    }
}
