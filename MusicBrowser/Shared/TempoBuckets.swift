import Foundation

struct TempoSummary {
    let average: Double
    let analyzedCount: Int
    let totalCount: Int
}

enum TempoBuckets {
    static func label(for bpm: Double?) -> String {
        guard let bpm else { return "Unscanned" }
        switch bpm {
        case ..<90: return "Slow Burn"
        case ..<110: return "Cruise"
        case ..<130: return "Pocket"
        case ..<150: return "Drive"
        default: return "Hyper"
        }
    }

    static func summary(for bpms: [Double?]) -> TempoSummary {
        let analyzed = bpms.compactMap { $0 }
        guard !bpms.isEmpty else {
            return TempoSummary(average: 0, analyzedCount: 0, totalCount: 0)
        }

        let average = analyzed.isEmpty ? 0 : analyzed.reduce(0, +) / Double(analyzed.count)
        return TempoSummary(
            average: average,
            analyzedCount: analyzed.count,
            totalCount: bpms.count
        )
    }
}
