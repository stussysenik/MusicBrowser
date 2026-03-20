import Foundation
import Observation

/// Provides music discovery features: harmonic mixing, smart playlists, and multi-filter queries.
@Observable
final class DiscoveryService {

    // MARK: - Camelot Wheel

    /// Maps each Camelot code to harmonically compatible codes.
    /// Compatible keys: same code, +/-1 in same column, inner/outer ring at same number.
    static let camelotWheel: [String: [String]] = {
        // Camelot notation: 1A-12A (minor), 1B-12B (major)
        var wheel: [String: [String]] = [:]
        for num in 1...12 {
            let prev = num == 1 ? 12 : num - 1
            let next = num == 12 ? 1 : num + 1
            // A column (minor keys)
            wheel["\(num)A"] = ["\(num)A", "\(prev)A", "\(next)A", "\(num)B"]
            // B column (major keys)
            wheel["\(num)B"] = ["\(num)B", "\(prev)B", "\(next)B", "\(num)A"]
        }
        return wheel
    }()

    /// Maps standard key names to Camelot codes.
    static let keyToCamelot: [String: String] = [
        "A Minor": "8A",   "A Major": "11B",
        "A# Minor": "3A",  "A# Major": "6B",   "Bb Minor": "3A",  "Bb Major": "6B",
        "B Minor": "10A",  "B Major": "1B",
        "C Minor": "5A",   "C Major": "8B",
        "C# Minor": "12A", "C# Major": "3B",    "Db Minor": "12A", "Db Major": "3B",
        "D Minor": "7A",   "D Major": "10B",
        "D# Minor": "2A",  "D# Major": "5B",    "Eb Minor": "2A",  "Eb Major": "5B",
        "E Minor": "9A",   "E Major": "12B",
        "F Minor": "4A",   "F Major": "7B",
        "F# Minor": "11A", "F# Major": "2B",    "Gb Minor": "11A", "Gb Major": "2B",
        "G Minor": "6A",   "G Major": "9B",
        "G# Minor": "1A",  "G# Major": "4B",    "Ab Minor": "1A",  "Ab Major": "4B",
    ]

    // MARK: - Harmonic Mix Suggestions

    /// Returns songs harmonically compatible with the given song's key.
    func harmonicMixSuggestions(
        forKey key: String,
        from analyses: [SongAnalysis]
    ) -> [SongAnalysis] {
        guard let camelot = Self.keyToCamelot[key],
              let compatibleCodes = Self.camelotWheel[camelot] else { return [] }

        let compatibleKeys = Set(Self.keyToCamelot.filter { compatibleCodes.contains($0.value) }.map(\.key))

        return analyses.filter { analysis in
            guard let songKey = analysis.musicalKey else { return false }
            return compatibleKeys.contains(songKey)
        }
    }

    // MARK: - Filter Stack

    struct FilterCriteria {
        var bpmRange: ClosedRange<Double>?
        var keys: Set<String>?
        var genres: Set<String>?
        var energyRange: ClosedRange<Double>?
        var moods: Set<String>?
    }

    /// Multi-filter query across analyzed songs.
    func filterStack(
        analyses: [SongAnalysis],
        criteria: FilterCriteria
    ) -> [SongAnalysis] {
        analyses.filter { analysis in
            if let bpmRange = criteria.bpmRange {
                guard let bpm = analysis.bpm, bpmRange.contains(bpm) else { return false }
            }
            if let keys = criteria.keys, !keys.isEmpty {
                guard let key = analysis.musicalKey, keys.contains(key) else { return false }
            }
            if let genres = criteria.genres, !genres.isEmpty {
                guard let genre = analysis.genreML, genres.contains(genre) else { return false }
            }
            if let energyRange = criteria.energyRange {
                guard let energy = analysis.energyScore, energyRange.contains(energy) else { return false }
            }
            if let moods = criteria.moods, !moods.isEmpty {
                guard let mood = analysis.moodClassification, moods.contains(mood) else { return false }
            }
            return true
        }
    }

    // MARK: - Smart Playlist Generation

    struct SmartPlaylistCriteria {
        var name: String = "Smart Playlist"
        var maxSongs: Int = 50
        var filter: FilterCriteria = FilterCriteria()
        var sortBy: SortOption = .bpm

        enum SortOption {
            case bpm, energy, random
        }
    }

    func generateSmartPlaylist(
        from analyses: [SongAnalysis],
        criteria: SmartPlaylistCriteria
    ) -> [SongAnalysis] {
        var result = filterStack(analyses: analyses, criteria: criteria.filter)

        switch criteria.sortBy {
        case .bpm:
            result.sort { ($0.bpm ?? 0) < ($1.bpm ?? 0) }
        case .energy:
            result.sort { ($0.energyScore ?? 0) > ($1.energyScore ?? 0) }
        case .random:
            result.shuffle()
        }

        return Array(result.prefix(criteria.maxSongs))
    }
}
