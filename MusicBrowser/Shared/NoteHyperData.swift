import Foundation

enum NoteHyperData {
    static func timestamps(in notes: String) -> [String] {
        let pattern = #"\[(\d{1,2}:\d{2}(?::\d{2})?)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(notes.startIndex..., in: notes)
        return regex.matches(in: notes, range: range).compactMap { match in
            guard
                match.numberOfRanges > 1,
                let captureRange = Range(match.range(at: 1), in: notes)
            else {
                return nil
            }
            return String(notes[captureRange])
        }
    }

    static func timestampCount(in notes: String) -> Int {
        timestamps(in: notes).count
    }

    static func characterCount(in notes: String) -> Int {
        notes.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    static func previewTags(_ tags: [String], limit: Int = 2) -> String? {
        let visibleTags = Array(tags.prefix(limit))
        guard !visibleTags.isEmpty else { return nil }
        return visibleTags.joined(separator: " • ")
    }
}
