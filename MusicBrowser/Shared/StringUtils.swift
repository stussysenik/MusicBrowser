import Foundation

/// String utility functions for consistent text processing across the app
enum StringUtils {
    /// Extracts the first letter of a string for alphabetical indexing
    /// - Parameter text: The input string
    /// - Returns: The first uppercase letter, or "#" for non-alphabetic characters
    static func firstLetter(of text: String) -> String {
        let first = text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1).uppercased()
        return first.rangeOfCharacter(from: .letters) != nil ? first : "#"
    }
}
