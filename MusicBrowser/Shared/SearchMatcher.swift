import Foundation

enum SearchMatcher {
    static func matches(term: String, fields: [String]) -> Bool {
        let tokens = tokenize(term)
        guard !tokens.isEmpty else { return true }

        let haystack = normalize(fields.joined(separator: " "))
        return tokens.allSatisfy { haystack.contains($0) }
    }

    static func tokenize(_ term: String) -> [String] {
        normalize(term)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(
                of: #"[^\p{L}\p{N}\s]+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
