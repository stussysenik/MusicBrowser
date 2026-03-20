import Foundation
import Observation

@Observable
final class FilterPresetService {
    enum PresetScope: String, CaseIterable {
        case songs, albums, artists, playlists, search
    }

    // Legacy single-letter filter (backward compat)
    var activeAlphabetFilter: [PresetScope: String] = [:]

    // Multi-letter pinning
    var pinnedLetters: [PresetScope: Set<String>] = [:]

    private let pinnedLettersKey = "FilterPresetService.pinnedLetters"

    init() {
        if let data = UserDefaults.standard.dictionary(forKey: pinnedLettersKey) as? [String: [String]] {
            for (key, letters) in data {
                if let scope = PresetScope(rawValue: key) {
                    pinnedLetters[scope] = Set(letters)
                }
            }
        }
    }

    // MARK: - Legacy API (backward compat)

    func activeLetter(for scope: PresetScope) -> String? {
        // Returns first pinned letter or legacy single filter
        if let pinned = pinnedLetters[scope], !pinned.isEmpty {
            return pinned.sorted().first
        }
        return activeAlphabetFilter[scope]
    }

    func setActiveAlphabetFilter(_ letter: String?, for scope: PresetScope) {
        activeAlphabetFilter[scope] = letter
    }

    func clearAlphabetFilter(for scope: PresetScope) {
        activeAlphabetFilter[scope] = nil
    }

    // MARK: - Multi-Letter Pinning API

    func togglePinnedLetter(_ letter: String, for scope: PresetScope) {
        var current = pinnedLetters[scope] ?? []
        if current.contains(letter) {
            current.remove(letter)
        } else {
            current.insert(letter)
        }
        pinnedLetters[scope] = current.isEmpty ? nil : current
        persistPinnedLetters()
    }

    func pinnedLettersSet(for scope: PresetScope) -> Set<String> {
        pinnedLetters[scope] ?? []
    }

    func clearPinnedLetters(for scope: PresetScope) {
        pinnedLetters[scope] = nil
        persistPinnedLetters()
    }

    func unpinLetter(_ letter: String, for scope: PresetScope) {
        pinnedLetters[scope]?.remove(letter)
        if pinnedLetters[scope]?.isEmpty == true {
            pinnedLetters[scope] = nil
        }
        persistPinnedLetters()
    }

    func hasPinnedLetters(for scope: PresetScope) -> Bool {
        guard let set = pinnedLetters[scope] else { return false }
        return !set.isEmpty
    }

    // MARK: - Persistence

    private func persistPinnedLetters() {
        let dict = pinnedLetters.reduce(into: [String: [String]]()) { result, pair in
            result[pair.key.rawValue] = Array(pair.value)
        }
        UserDefaults.standard.set(dict, forKey: pinnedLettersKey)
    }
}
