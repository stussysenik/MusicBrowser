import Foundation

/// Describes a downloadable CoreML model for audio analysis.
/// Codable (not SwiftData) — fetched from a remote manifest endpoint.
struct MLModelManifest: Codable, Sendable {
    let modelVersion: String
    let downloadURL: URL
    let sha256Checksum: String
    let fileSize: Int64
    let minimumAppVersion: String
    let features: [String]
    let releaseNotes: String
}
