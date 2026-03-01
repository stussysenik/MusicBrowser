import Foundation
import MusicKit

@Observable
final class MusicService {
    var isAuthorized = false

    // MARK: - Cache

    private var chartsCache: MusicCatalogChartsResponse?
    private var chartsCacheTime: Date?
    private let cacheTTL: TimeInterval = 300

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

    func search(_ term: String) async throws -> MusicCatalogSearchResponse {
        var request = MusicCatalogSearchRequest(term: term, types: [
            Song.self, Album.self, Artist.self, Playlist.self
        ])
        request.limit = 25
        return try await request.response()
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
