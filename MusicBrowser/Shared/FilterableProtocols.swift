import Foundation

protocol FilterableByLetter {
    var title: String { get }
}

extension Collection where Element: FilterableByLetter {
    var availableLetters: [String] {
        Set(map { StringUtils.firstLetter(of: $0.title) }).sorted()
    }

    var availableLetterSet: Set<String> {
        Set(map { StringUtils.firstLetter(of: $0.title) })
    }
}
