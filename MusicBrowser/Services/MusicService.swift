import Foundation
import MusicKit

@Observable
final class MusicService {
    private enum SearchError: Error {
        case catalogUnavailable
    }

    struct SearchResults {
        enum Source {
            case catalog
            case library
        }

        let songs: [Song]
        let albums: [Album]
        let artists: [Artist]
        let playlists: [Playlist]
        let source: Source
    }

    var isAuthorized = false

    // MARK: - Cache

    private var chartsCache: MusicCatalogChartsResponse?
    private var chartsCacheTime: Date?
    private let cacheTTL: TimeInterval = 300
    private var searchCache: [String: (results: SearchResults, timestamp: Date)] = [:]
    private let searchCacheTTL: TimeInterval = 60
    private var genresCache: [Genre] = []
    private var genresCacheTime: Date?
    private let genresCacheTTL: TimeInterval = 600

    // MARK: - Charts

    func fetchCharts(force: Bool = false) async throws -> MusicCatalogChartsResponse {
        if !force,
           let cached = chartsCache,
           let time = chartsCacheTime,
           Date().timeIntervalSince(time) < cacheTTL {
            return cached
        }
        var request = MusicCatalogChartsRequest(
            kinds: [.mostPlayed],
            types: [Album.self, Song.self, Playlist.self]
        )
        request.limit = 25
        let response = try await request.response()
        chartsCache = response
        chartsCacheTime = Date()
        return response
    }

    // MARK: - Search

    func fetchGenres(limit: Int = 300, force: Bool = false) async throws -> [Genre] {
        if !force,
           let time = genresCacheTime,
           !genresCache.isEmpty,
           Date().timeIntervalSince(time) < genresCacheTTL {
            return genresCache
        }

        var request = MusicCatalogResourceRequest<Genre>()
        request.limit = limit
        let response = try await request.response()
        let genres = Array(response.items).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        genresCache = genres
        genresCacheTime = Date()
        return genres
    }

    func search(_ term: String) async throws -> SearchResults {
        let normalizedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheKey = normalizedTerm.lowercased()

        if let cached = searchCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < searchCacheTTL {
            return cached.results
        }

        if let catalogResults = try? await searchCatalog(term: normalizedTerm) {
            searchCache[cacheKey] = (catalogResults, Date())
            return catalogResults
        }

        let libraryResults = try await searchLibrary(term: normalizedTerm)
        searchCache[cacheKey] = (libraryResults, Date())
        return libraryResults
    }

    private func searchCatalog(term: String) async throws -> SearchResults {
        let subscription = try await MusicSubscription.current
        guard subscription.canPlayCatalogContent else {
            throw SearchError.catalogUnavailable
        }

        var request = MusicCatalogSearchRequest(term: term, types: [
            Song.self, Album.self, Artist.self, Playlist.self
        ])
        request.limit = 12
        let response = try await request.response()

        return SearchResults(
            songs: Array(response.songs),
            albums: Array(response.albums),
            artists: Array(response.artists),
            playlists: Array(response.playlists),
            source: .catalog
        )
    }

    private func searchLibrary(term: String) async throws -> SearchResults {
        var request = MusicLibrarySearchRequest(term: term, types: [
            Song.self, Album.self, Artist.self, Playlist.self
        ])
        request.limit = 12
        let response = try await request.response()

        return SearchResults(
            songs: Array(response.songs),
            albums: Array(response.albums),
            artists: Array(response.artists),
            playlists: Array(response.playlists),
            source: .library
        )
    }

    // MARK: - Local Library Search

    private var allLibrarySongsCache: [Song] = []
    private var allSongsCacheTime: Date?
    private let allSongsCacheTTL: TimeInterval = 300

    func searchLibraryLocal(term: String) async throws -> SearchResults {
        let allSongs = try await fetchAllLibrarySongs()
        let lowered = term.lowercased()
        let matched = allSongs.filter {
            $0.title.localizedCaseInsensitiveContains(lowered) ||
            $0.artistName.localizedCaseInsensitiveContains(lowered) ||
            ($0.albumTitle?.localizedCaseInsensitiveContains(lowered) == true) ||
            $0.genreNames.contains { $0.localizedCaseInsensitiveContains(lowered) }
        }
        return SearchResults(
            songs: Array(matched.prefix(50)),
            albums: [],
            artists: [],
            playlists: [],
            source: .library
        )
    }

    private func fetchAllLibrarySongs() async throws -> [Song] {
        if let time = allSongsCacheTime, !allLibrarySongsCache.isEmpty,
           Date().timeIntervalSince(time) < allSongsCacheTTL {
            return allLibrarySongsCache
        }
        var all: [Song] = []
        var offset = 0
        while true {
            let response = try await librarySongs(limit: 100, offset: offset)
            all.append(contentsOf: response.items)
            if response.items.count < 100 { break }
            offset += 100
        }
        allLibrarySongsCache = all
        allSongsCacheTime = Date()
        return all
    }

    // MARK: - Public All Songs Access

    func allLibrarySongs() async throws -> [Song] {
        try await fetchAllLibrarySongs()
    }

    // MARK: - All Library Albums (cached)

    private var allLibraryAlbumsCache: [Album] = []
    private var allAlbumsCacheTime: Date?

    func allLibraryAlbums() async throws -> [Album] {
        if let time = allAlbumsCacheTime, !allLibraryAlbumsCache.isEmpty,
           Date().timeIntervalSince(time) < allSongsCacheTTL {
            return allLibraryAlbumsCache
        }
        var all: [Album] = []
        var offset = 0
        while true {
            let response = try await libraryAlbums(offset: offset)
            all.append(contentsOf: response.items)
            if response.items.count < 100 { break }
            offset += 100
        }
        allLibraryAlbumsCache = all
        allAlbumsCacheTime = Date()
        return all
    }

    func librarySongs(byIDs ids: [String]) async throws -> [Song] {
        var request = MusicLibraryRequest<Song>()
        request.filter(matching: \.id, memberOf: ids.map { MusicItemID($0) })
        let response = try await request.response()
        return Array(response.items)
    }

    // MARK: - Library Songs

    func librarySongs(
        limit: Int = 100,
        offset: Int = 0,
        sort: SongSortOption = .title,
        direction: SortDirection = .ascending
    ) async throws -> MusicLibraryResponse<Song> {
        var request = MusicLibraryRequest<Song>()
        request.limit = limit
        request.offset = offset
        switch sort {
        case .title:
            request.sort(by: \.title, ascending: direction.isAscending)
        case .artist:
            request.sort(by: \.artistName, ascending: direction.isAscending)
        case .albumTitle:
            request.sort(by: \.albumTitle, ascending: direction.isAscending)
        case .dateAdded:
            request.sort(by: \.libraryAddedDate, ascending: direction.isAscending)
        case .playCount:
            request.sort(by: \.playCount, ascending: direction.isAscending)
        case .lastPlayed:
            request.sort(by: \.lastPlayedDate, ascending: direction.isAscending)
        case .releaseDate, .duration, .bpm:
            // Not API-sortable — in-memory sort in view
            request.sort(by: \.title, ascending: true)
        }
        return try await request.response()
    }

    // MARK: - Library Albums

    func libraryAlbums(
        limit: Int = 100,
        offset: Int = 0,
        sort: AlbumSortOption = .title,
        direction: SortDirection = .ascending
    ) async throws -> MusicLibraryResponse<Album> {
        var request = MusicLibraryRequest<Album>()
        request.limit = limit
        request.offset = offset
        switch sort {
        case .title:
            request.sort(by: \.title, ascending: direction.isAscending)
        case .artist:
            request.sort(by: \.artistName, ascending: direction.isAscending)
        case .releaseDate:
            request.sort(by: \.releaseDate, ascending: direction.isAscending)
        case .dateAdded:
            request.sort(by: \.libraryAddedDate, ascending: direction.isAscending)
        case .lastPlayed:
            request.sort(by: \.lastPlayedDate, ascending: direction.isAscending)
        }
        return try await request.response()
    }

    // MARK: - Library Playlists

    func libraryPlaylists(
        limit: Int = 100,
        offset: Int = 0,
        sort: PlaylistSortOption = .name,
        direction: SortDirection = .ascending
    ) async throws -> MusicLibraryResponse<Playlist> {
        var request = MusicLibraryRequest<Playlist>()
        request.limit = limit
        request.offset = offset
        switch sort {
        case .name:
            request.sort(by: \.name, ascending: direction.isAscending)
        case .dateModified, .lastPlayed:
            // Not reliably available — fall back to name, in-memory sort in view
            request.sort(by: \.name, ascending: true)
        }
        return try await request.response()
    }

    // MARK: - Library Artists

    func libraryArtists(
        limit: Int = 100,
        offset: Int = 0,
        direction: SortDirection = .ascending
    ) async throws -> MusicLibraryResponse<Artist> {
        var request = MusicLibraryRequest<Artist>()
        request.limit = limit
        request.offset = offset
        request.sort(by: \.name, ascending: direction.isAscending)
        return try await request.response()
    }

    // MARK: - Random Song

    private var estimatedSongCount: Int?
    private var songCountCacheTime: Date?
    private let songCountCacheTTL: TimeInterval = 60

    func randomLibrarySong() async throws -> Song {
        let count = try await estimateLibrarySongCount()
        guard count > 0 else {
            throw RandomError.emptyLibrary
        }
        let randomOffset = Int.random(in: 0..<count)
        var request = MusicLibraryRequest<Song>()
        request.limit = 1
        request.offset = randomOffset
        let response = try await request.response()
        if let song = response.items.first {
            return song
        }
        // Fallback: offset exceeded actual count (library changed), try offset 0
        var fallback = MusicLibraryRequest<Song>()
        fallback.limit = 1
        fallback.offset = 0
        let fallbackResponse = try await fallback.response()
        guard let song = fallbackResponse.items.first else {
            throw RandomError.emptyLibrary
        }
        return song
    }

    private func estimateLibrarySongCount() async throws -> Int {
        if let cached = estimatedSongCount,
           let time = songCountCacheTime,
           Date().timeIntervalSince(time) < songCountCacheTTL {
            return cached
        }

        // Find upper bound by doubling offset
        var high = 100
        let batchSize = 100

        // Phase 1: find upper bound by doubling
        while true {
            var request = MusicLibraryRequest<Song>()
            request.limit = batchSize
            request.offset = high
            let response = try await request.response()
            if response.items.count < batchSize {
                // Total is between high and high + response.items.count
                let total = high + response.items.count
                estimatedSongCount = total
                songCountCacheTime = Date()
                return total
            }
            high *= 2
        }
    }

    private enum RandomError: LocalizedError {
        case emptyLibrary

        var errorDescription: String? {
            switch self {
            case .emptyLibrary: return "Your library has no songs."
            }
        }
    }

    // MARK: - Playlist Management

    func createPlaylist(name: String, description: String? = nil) async throws -> Playlist {
        try await MusicLibrary.shared.createPlaylist(name: name, description: description)
    }

    func addSongToPlaylist(_ song: Song, playlist: Playlist) async throws {
        try await MusicLibrary.shared.add(song, to: playlist)
    }

    func addToLibrary(_ song: Song) async throws {
        try await MusicLibrary.shared.add(song)
    }

    func addToLibrary(_ album: Album) async throws {
        try await MusicLibrary.shared.add(album)
    }

    func fetchUserPlaylists() async throws -> [Playlist] {
        var request = MusicLibraryRequest<Playlist>()
        request.limit = 100
        request.sort(by: \.name, ascending: true)
        let response = try await request.response()
        return Array(response.items)
    }

    // MARK: - Detail Loading

    func albumWithTracks(_ album: Album) async throws -> Album {
        try await album.with([.tracks, .artists])
    }

    func playlistWithTracks(_ playlist: Playlist) async throws -> Playlist {
        try await playlist.with([.tracks])
    }

    func artistDetail(_ artist: Artist) async throws -> Artist {
        try await artist.with([.albums, .topSongs])
    }
}
