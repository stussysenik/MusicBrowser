import Foundation
import Observation

@Observable
final class FilterPresetService {
    enum PresetScope: String, CaseIterable {
        case songs, albums, search
    }

    var activeAlphabetFilter: [PresetScope: String] = [:]

    func activeLetter(for scope: PresetScope) -> String? {
        activeAlphabetFilter[scope]
    }

    func setActiveAlphabetFilter(_ letter: String?, for scope: PresetScope) {
        activeAlphabetFilter[scope] = letter
    }

    func clearAlphabetFilter(for scope: PresetScope) {
        activeAlphabetFilter[scope] = nil
    }
}
