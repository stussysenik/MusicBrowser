import Foundation

// MARK: - Mock Data Types for Wireframe Testing

/// Mock song for UI testing without MusicKit dependency.
struct MockSong: Identifiable, Hashable {
    let id: String
    let title: String
    let artistName: String
    let albumTitle: String
    let duration: TimeInterval
    let genreNames: [String]
    let playCount: Int
    let releaseDate: Date?
    let releaseYear: Int?
    let bpm: Double?
    let artworkPlaceholder: String  // SF Symbol name

    init(
        id: String = UUID().uuidString,
        title: String,
        artistName: String,
        albumTitle: String = "",
        duration: TimeInterval = 240,
        genreNames: [String] = [],
        playCount: Int = 0,
        releaseDate: Date? = nil,
        releaseYear: Int? = nil,
        bpm: Double? = nil,
        artworkPlaceholder: String = "music.note"
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.duration = duration
        self.genreNames = genreNames
        self.playCount = playCount
        self.releaseDate = releaseDate
        self.releaseYear = releaseYear
        self.bpm = bpm
        self.artworkPlaceholder = artworkPlaceholder
    }
}

extension MockSong: FilterableByLetter {
    // FilterableByLetter requires `title` which we already have
}

/// Mock album for UI testing.
struct MockAlbum: Identifiable, Hashable {
    let id: String
    let title: String
    let artistName: String
    let trackCount: Int
    let releaseYear: Int?
    let genreNames: [String]
    let artworkPlaceholder: String

    init(
        id: String = UUID().uuidString,
        title: String,
        artistName: String,
        trackCount: Int = 12,
        releaseYear: Int? = nil,
        genreNames: [String] = [],
        artworkPlaceholder: String = "square.stack"
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.trackCount = trackCount
        self.releaseYear = releaseYear
        self.genreNames = genreNames
        self.artworkPlaceholder = artworkPlaceholder
    }
}

extension MockAlbum: FilterableByLetter {}

/// Mock artist for UI testing.
struct MockArtist: Identifiable, Hashable {
    let id: String
    let name: String
    let songCount: Int
    let artworkPlaceholder: String

    var title: String { name }  // FilterableByLetter conformance

    init(
        id: String = UUID().uuidString,
        name: String,
        songCount: Int = 20,
        artworkPlaceholder: String = "person.circle"
    ) {
        self.id = id
        self.name = name
        self.songCount = songCount
        self.artworkPlaceholder = artworkPlaceholder
    }
}

extension MockArtist: FilterableByLetter {}

/// Mock playlist for UI testing.
struct MockPlaylist: Identifiable, Hashable {
    let id: String
    let name: String
    let curatorName: String?
    let trackCount: Int
    let artworkPlaceholder: String

    var title: String { name }  // FilterableByLetter conformance

    init(
        id: String = UUID().uuidString,
        name: String,
        curatorName: String? = nil,
        trackCount: Int = 25,
        artworkPlaceholder: String = "music.note.list"
    ) {
        self.id = id
        self.name = name
        self.curatorName = curatorName
        self.trackCount = trackCount
        self.artworkPlaceholder = artworkPlaceholder
    }
}

extension MockPlaylist: FilterableByLetter {}
