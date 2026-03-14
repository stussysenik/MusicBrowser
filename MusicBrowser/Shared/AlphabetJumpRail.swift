import Foundation

enum AlphabetJumpRail {
    static let preGeneratedLetters: [String] = (65...90).compactMap { UnicodeScalar($0).map(String.init) } + ["#"]
}
