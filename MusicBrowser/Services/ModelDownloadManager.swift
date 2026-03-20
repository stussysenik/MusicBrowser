import Foundation
import CryptoKit
import CoreML

/// Manages downloading, verifying, and compiling CoreML models for audio analysis.
@Observable
final class ModelDownloadManager {

    var downloadProgress: Double = 0
    var isDownloading = false
    var currentModelVersion: String?

    private let modelsDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = appSupport.appendingPathComponent("MLModels", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        currentModelVersion = loadCurrentVersion()
    }

    // MARK: - Download

    /// Downloads a model from the given manifest.
    func download(manifest: MLModelManifest, progress: ((Double) -> Void)? = nil) async throws -> URL {
        isDownloading = true
        downloadProgress = 0
        defer {
            isDownloading = false
        }

        let destinationURL = modelsDirectory.appendingPathComponent("model-\(manifest.modelVersion).mlmodel")

        // Skip if already downloaded and verified
        if FileManager.default.fileExists(atPath: destinationURL.path),
           verify(fileAt: destinationURL, expectedSHA256: manifest.sha256Checksum) {
            currentModelVersion = manifest.modelVersion
            return destinationURL
        }

        let (tempURL, _) = try await URLSession.shared.download(from: manifest.downloadURL, delegate: nil)

        // Move to final location
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        // Verify checksum
        guard verify(fileAt: destinationURL, expectedSHA256: manifest.sha256Checksum) else {
            try? FileManager.default.removeItem(at: destinationURL)
            throw ModelDownloadError.checksumMismatch
        }

        currentModelVersion = manifest.modelVersion
        saveCurrentVersion(manifest.modelVersion)
        downloadProgress = 1.0
        return destinationURL
    }

    // MARK: - Verification

    /// Verifies a file's SHA-256 checksum.
    func verify(fileAt url: URL, expectedSHA256: String) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        let hash = SHA256.hash(data: data)
        let hexString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return hexString == expectedSHA256.lowercased()
    }

    // MARK: - Compilation

    /// Compiles a .mlmodel file into a .mlmodelc for runtime use.
    func compileModel(at url: URL) throws -> URL {
        let compiledURL = try MLModel.compileModel(at: url)
        // Move compiled model to our managed directory
        let destination = modelsDirectory.appendingPathComponent(compiledURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: compiledURL, to: destination)
        return destination
    }

    // MARK: - Cleanup

    /// Removes old model versions, keeping only the specified number of recent ones.
    func cleanupOldModels(keeping count: Int = 2) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: modelsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let modelFiles = contents
            .filter { $0.pathExtension == "mlmodel" || $0.pathExtension == "mlmodelc" }
            .sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return dateA > dateB
            }

        for file in modelFiles.dropFirst(count) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Private

    private func loadCurrentVersion() -> String? {
        let versionFile = modelsDirectory.appendingPathComponent(".current-version")
        return try? String(contentsOf: versionFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveCurrentVersion(_ version: String) {
        let versionFile = modelsDirectory.appendingPathComponent(".current-version")
        try? version.write(to: versionFile, atomically: true, encoding: .utf8)
    }
}

enum ModelDownloadError: LocalizedError {
    case checksumMismatch
    case compilationFailed

    var errorDescription: String? {
        switch self {
        case .checksumMismatch: return "Downloaded model checksum doesn't match expected value"
        case .compilationFailed: return "Failed to compile CoreML model"
        }
    }
}
