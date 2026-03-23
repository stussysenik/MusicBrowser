import Foundation

// MARK: - Song Sort

enum SongSortOption: String, CaseIterable {
    case title = "Title"
    case artist = "Artist"
    case albumTitle = "Album"
    case dateAdded = "Date Added"
    case releaseDate = "Release Date"
    case playCount = "Play Count"
    case lastPlayed = "Last Played"
    case duration = "Duration"
    case bpm = "BPM"

    /// Whether MusicLibraryRequest supports this sort natively
    var isAPISort: Bool {
        switch self {
        case .title, .artist, .albumTitle, .dateAdded, .releaseDate, .playCount, .lastPlayed:
            return true
        case .duration, .bpm:
            return false
        }
    }
}

// MARK: - Album Sort

enum AlbumSortOption: String, CaseIterable {
    case title = "Title"
    case artist = "Artist"
    case releaseDate = "Release Date"
    case dateAdded = "Date Added"
    case lastPlayed = "Last Played"

    var isAPISort: Bool { true }
}

// MARK: - Album Grouping

enum AlbumGrouping: String, CaseIterable {
    case none = "None"
    case year = "Year"
    case decade = "Decade"
    case artist = "Artist"
}

// MARK: - Song Grouping

enum SongGrouping: String, CaseIterable {
    case letter = "Letter"
    case year = "Year"
    case decade = "Decade"
}

// MARK: - Playlist Sort

enum PlaylistSortOption: String, CaseIterable {
    case name = "Name"
    case dateModified = "Date Modified"
    case lastPlayed = "Last Played"
}

// MARK: - Direction

enum SortDirection: String, CaseIterable {
    case ascending = "Ascending"
    case descending = "Descending"

    var isAscending: Bool { self == .ascending }

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }

    var systemImage: String {
        self == .ascending ? "chevron.up" : "chevron.down"
    }
}
