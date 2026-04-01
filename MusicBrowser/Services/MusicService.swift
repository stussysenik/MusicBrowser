import Foundation
import MusicKit
#if os(iOS)
import MediaPlayer
#endif

struct DemoPlaylistRecord: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var trackIDs: [String]
    var updatedAt: Date
}

@Observable
final class MusicService: @unchecked Sendable {
    enum DemoLibrarySource {
        case sample
        case deviceMediaLibrary
    }

    let runtime: AppRuntime
    private let demoPlaylistsKey = "dummy-playlists-v1"

    enum SearchError: LocalizedError {
        case catalogUnavailable
        case catalogAuthorizationRequired

        var errorDescription: String? {
            switch self {
            case .catalogUnavailable:
                return "Apple Music subscription required for catalog search."
            case .catalogAuthorizationRequired:
                return "Apple Music access is required before searching the catalog."
            }
        }
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
        let musicVideos: [MusicVideo]
        let source: Source
    }

    var isAuthorized = false
    var demoSongs: [DemoSong]
    var demoAlbums: [DemoAlbum]
    var demoLibrarySource: DemoLibrarySource = .sample

    init(runtime: AppRuntime = .current) {
        self.runtime = runtime
        self.demoSongs = DemoSongLibrary.songs
        self.demoAlbums = DemoSongLibrary.albums
    }

    deinit {
        #if os(iOS)
        if let mediaLibraryObserver {
            NotificationCenter.default.removeObserver(mediaLibraryObserver)
        }
        if isObservingMediaLibraryChanges {
            MPMediaLibrary.default().endGeneratingLibraryChangeNotifications()
        }
        #endif
    }

    // MARK: - Subscription Cache

    private var subscriptionStatus: MusicSubscription?
    private var subscriptionCheckTime: Date?
    private let subscriptionCacheTTL: TimeInterval = 300

    private func cachedSubscription() async throws -> MusicSubscription {
        guard MusicAuthorization.currentStatus == .authorized else {
            throw SearchError.catalogAuthorizationRequired
        }
        if let cached = subscriptionStatus,
           let time = subscriptionCheckTime,
           Date().timeIntervalSince(time) < subscriptionCacheTTL {
            return cached
        }
        let sub = try await MusicSubscription.current
        subscriptionStatus = sub
        subscriptionCheckTime = Date()
        return sub
    }

    func prefetchSubscriptionStatus() async {
        _ = try? await cachedSubscription()
    }

    func requestCatalogAuthorizationIfNeeded() async -> Bool {
        switch MusicAuthorization.currentStatus {
        case .authorized:
            return true
        case .notDetermined:
            return await MusicAuthorization.request() == .authorized
        default:
            return false
        }
    }

    // MARK: - Cache

    private var chartsCache: MusicCatalogChartsResponse?
    private var chartsCacheTime: Date?
    private let cacheTTL: TimeInterval = 300
    private var searchCache: [String: (results: SearchResults, timestamp: Date)] = [:]
    private let searchCacheTTL: TimeInterval = 60
    private var genresCache: [Genre] = []
    private var genresCacheTime: Date?
    private let genresCacheTTL: TimeInterval = 600

    #if os(iOS)
    var deviceLibraryAuthorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    private var lastDeviceLibraryRefresh: Date?
    private let deviceLibraryCacheTTL: TimeInterval = 45
    private var mediaLibraryObserver: NSObjectProtocol?
    private var isObservingMediaLibraryChanges = false
    #endif

    var usesRealDeviceLibrary: Bool {
        demoLibrarySource == .deviceMediaLibrary
    }

    var demoLibraryLabel: String {
        usesRealDeviceLibrary ? "your library" : "sample library"
    }

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
            types: [Album.self, Song.self, Playlist.self, MusicVideo.self]
        )
        request.limit = 25
        let response = try await request.response()
        chartsCache = response
        chartsCacheTime = Date()
        return response
    }

    func fetchMusicVideoCharts() async throws -> [MusicVideo] {
        let response = try await fetchCharts()
        return Array(response.musicVideoCharts.first?.items ?? [])
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

    /// Direct catalog search that throws on subscription failure instead of falling back.
    /// Use this when the user explicitly selects catalog scope.
    func searchCatalogDirect(_ term: String) async throws -> SearchResults {
        let normalizedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let subscription = try await cachedSubscription()
        guard subscription.canPlayCatalogContent else {
            throw SearchError.catalogUnavailable
        }

        var request = MusicCatalogSearchRequest(term: normalizedTerm, types: [
            Song.self, Album.self, Artist.self, Playlist.self, MusicVideo.self
        ])
        request.limit = 12
        let response = try await request.response()

        return SearchResults(
            songs: Array(response.songs),
            albums: Array(response.albums),
            artists: Array(response.artists),
            playlists: Array(response.playlists),
            musicVideos: Array(response.musicVideos),
            source: .catalog
        )
    }

    /// Whether the cached subscription allows catalog search.
    var canSearchCatalog: Bool {
        subscriptionStatus?.canPlayCatalogContent ?? false
    }

    private func searchCatalog(term: String) async throws -> SearchResults {
        let subscription = try await cachedSubscription()
        guard subscription.canPlayCatalogContent else {
            throw SearchError.catalogUnavailable
        }

        var request = MusicCatalogSearchRequest(term: term, types: [
            Song.self, Album.self, Artist.self, Playlist.self, MusicVideo.self
        ])
        request.limit = 12
        let response = try await request.response()

        return SearchResults(
            songs: Array(response.songs),
            albums: Array(response.albums),
            artists: Array(response.artists),
            playlists: Array(response.playlists),
            musicVideos: Array(response.musicVideos),
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
            musicVideos: [],
            source: .library
        )
    }

    // MARK: - Local Library Search

    private var allLibrarySongsCache: [Song] = []
    private var allSongsCacheTime: Date?
    private let allSongsCacheTTL: TimeInterval = 300
    private var allLibraryAlbumsCache: [Album] = []
    private var allAlbumsCacheTime: Date?
    private let allAlbumsCacheTTL: TimeInterval = 300
    private var allLibraryArtistsCache: [Artist] = []
    private var allArtistsCacheTime: Date?
    private let allArtistsCacheTTL: TimeInterval = 300
    private var allLibraryPlaylistsCache: [Playlist] = []
    private var allPlaylistsCacheTime: Date?
    private let allPlaylistsCacheTTL: TimeInterval = 300

    func searchLibraryLocal(term: String, forceRefresh: Bool = false) async throws -> SearchResults {
        async let songsTask = allLibrarySongs(force: forceRefresh)
        async let albumsTask = allLibraryAlbums(force: forceRefresh)
        async let artistsTask = allLibraryArtists(force: forceRefresh)
        async let playlistsTask = allLibraryPlaylists(force: forceRefresh)

        let matchedSongs = try await songsTask
        let matchedAlbums = try await albumsTask
        let matchedArtists = try await artistsTask
        let matchedPlaylists = try await playlistsTask

        let filteredSongs = matchedSongs.filter { song in
            SearchMatcher.matches(term: term, fields: [
                song.title,
                song.artistName,
                song.albumTitle ?? "",
                song.genreNames.joined(separator: " ")
            ])
        }
        let filteredAlbums = matchedAlbums.filter { album in
            SearchMatcher.matches(term: term, fields: [
                album.title,
                album.artistName,
                album.genreNames.joined(separator: " ")
            ])
        }
        let filteredArtists = matchedArtists.filter { artist in
            SearchMatcher.matches(term: term, fields: [artist.name])
        }
        let filteredPlaylists = matchedPlaylists.filter { playlist in
            SearchMatcher.matches(term: term, fields: [
                playlist.name,
                playlist.curatorName ?? ""
            ])
        }

        return SearchResults(
            songs: Array(filteredSongs.prefix(50)),
            albums: Array(filteredAlbums.prefix(24)),
            artists: Array(filteredArtists.prefix(24)),
            playlists: Array(filteredPlaylists.prefix(24)),
            musicVideos: [],
            source: .library
        )
    }

    func allLibrarySongs(force: Bool = false) async throws -> [Song] {
        if !force,
           let time = allSongsCacheTime,
           !allLibrarySongsCache.isEmpty,
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

    func allLibraryAlbums(force: Bool = false) async throws -> [Album] {
        if !force,
           let time = allAlbumsCacheTime,
           !allLibraryAlbumsCache.isEmpty,
           Date().timeIntervalSince(time) < allAlbumsCacheTTL {
            return allLibraryAlbumsCache
        }

        var all: [Album] = []
        var offset = 0
        while true {
            let response = try await libraryAlbums(limit: 100, offset: offset)
            all.append(contentsOf: response.items)
            if response.items.count < 100 { break }
            offset += 100
        }
        allLibraryAlbumsCache = all
        allAlbumsCacheTime = Date()
        return all
    }

    func allLibraryArtists(force: Bool = false) async throws -> [Artist] {
        if !force,
           let time = allArtistsCacheTime,
           !allLibraryArtistsCache.isEmpty,
           Date().timeIntervalSince(time) < allArtistsCacheTTL {
            return allLibraryArtistsCache
        }

        var all: [Artist] = []
        var offset = 0
        while true {
            let response = try await libraryArtists(limit: 100, offset: offset)
            all.append(contentsOf: response.items)
            if response.items.count < 100 { break }
            offset += 100
        }
        allLibraryArtistsCache = all
        allArtistsCacheTime = Date()
        return all
    }

    func allLibraryPlaylists(force: Bool = false) async throws -> [Playlist] {
        if !force,
           let time = allPlaylistsCacheTime,
           !allLibraryPlaylistsCache.isEmpty,
           Date().timeIntervalSince(time) < allPlaylistsCacheTTL {
            return allLibraryPlaylistsCache
        }

        var all: [Playlist] = []
        var offset = 0
        while true {
            let response = try await libraryPlaylists(limit: 100, offset: offset)
            all.append(contentsOf: response.items)
            if response.items.count < 100 { break }
            offset += 100
        }
        allLibraryPlaylistsCache = all
        allPlaylistsCacheTime = Date()
        return all
    }

    func invalidateLibraryCaches() {
        allLibrarySongsCache = []
        allSongsCacheTime = nil
        allLibraryAlbumsCache = []
        allAlbumsCacheTime = nil
        allLibraryArtistsCache = []
        allArtistsCacheTime = nil
        invalidatePlaylistCache()
    }

    func invalidatePlaylistCache() {
        allLibraryPlaylistsCache = []
        allPlaylistsCacheTime = nil
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

    // MARK: - Single Song Lookup

    func librarySong(byID songID: String) async throws -> Song? {
        var request = MusicLibraryRequest<Song>()
        request.filter(matching: \.id, equalTo: MusicItemID(songID))
        request.limit = 1
        return try await request.response().items.first
    }

    // MARK: - Single Album Lookup

    func libraryAlbum(byID albumID: String) async throws -> Album? {
        var request = MusicLibraryRequest<Album>()
        request.filter(matching: \.id, equalTo: MusicItemID(albumID))
        request.limit = 1
        return try await request.response().items.first
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

    func randomLibrarySong() async throws -> Song {
        let songs = try await allLibrarySongs(force: true)
        guard let song = songs.randomElement() else {
            throw RandomError.emptyLibrary
        }
        return song
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
        #if os(iOS)
        let playlist = try await MusicLibrary.shared.createPlaylist(name: name, description: description)
        invalidatePlaylistCache()
        return playlist
        #else
        throw PlaylistMutationError.unavailableOnThisPlatform
        #endif
    }

    func addSongToPlaylist(_ song: Song, playlist: Playlist) async throws {
        #if os(iOS)
        try await MusicLibrary.shared.add(song, to: playlist)
        invalidatePlaylistCache()
        #else
        throw PlaylistMutationError.unavailableOnThisPlatform
        #endif
    }

    func addSongsToPlaylist(_ songs: [Song], playlist: Playlist) async throws {
        #if os(iOS)
        for song in songs {
            try await MusicLibrary.shared.add(song, to: playlist)
        }
        invalidatePlaylistCache()
        #else
        throw PlaylistMutationError.unavailableOnThisPlatform
        #endif
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

    private enum PlaylistMutationError: LocalizedError {
        case unavailableOnThisPlatform

        var errorDescription: String? {
            switch self {
            case .unavailableOnThisPlatform:
                return "Playlist editing is currently available on iPhone and iPad."
            }
        }
    }

    // MARK: - Dummy Data Helpers

    #if os(iOS)
    @MainActor
    func prepareFallbackLibraryIfPossible(requestAccess: Bool = false) async {
        guard runtime.usesDummyData else { return }
        #if targetEnvironment(simulator)
        return
        #else
        let status = await mediaLibraryAuthorizationStatus(requestAccess: requestAccess)
        guard status == .authorized else { return }
        refreshFallbackLibraryIfAuthorized()
        #endif
    }

    @MainActor
    private func mediaLibraryAuthorizationStatus(requestAccess: Bool) async -> MPMediaLibraryAuthorizationStatus {
        let current = MPMediaLibrary.authorizationStatus()
        deviceLibraryAuthorizationStatus = current
        guard requestAccess, current == .notDetermined else { return current }

        return await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { status in
                Task { @MainActor in
                    self.deviceLibraryAuthorizationStatus = status
                }
                continuation.resume(returning: status)
            }
        }
    }

    @MainActor
    private func startObservingMediaLibraryChangesIfNeeded() {
        guard !isObservingMediaLibraryChanges else { return }

        MPMediaLibrary.default().beginGeneratingLibraryChangeNotifications()
        mediaLibraryObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.MPMediaLibraryDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.lastDeviceLibraryRefresh = nil
                self.refreshFallbackLibraryIfAuthorized()
            }
        }
        isObservingMediaLibraryChanges = true
    }

    @MainActor
    private func refreshFallbackLibraryIfAuthorized() {
        if let lastDeviceLibraryRefresh,
           Date().timeIntervalSince(lastDeviceLibraryRefresh) < deviceLibraryCacheTTL,
           usesRealDeviceLibrary {
            startObservingMediaLibraryChangesIfNeeded()
            return
        }

        let songs = loadDeviceLibrarySongs()
        guard !songs.isEmpty else { return }

        demoSongs = songs
        demoAlbums = songs.groupedAsDemoAlbums
        demoLibrarySource = .deviceMediaLibrary
        lastDeviceLibraryRefresh = Date()
        startObservingMediaLibraryChangesIfNeeded()
    }

    private func loadDeviceLibrarySongs() -> [DemoSong] {
        let query = MPMediaQuery.songs()
        let items = query.items ?? []
        return items
            .compactMap(DemoSong.init(mediaItem:))
            .sorted { lhs, rhs in
                if lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedSame {
                    return lhs.artistName.localizedCaseInsensitiveCompare(rhs.artistName) == .orderedAscending
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }
    #endif

    func dummySong(byID id: String) -> DemoSong? {
        demoSongs.first(where: { $0.id == id })
    }

    func dummyAlbum(byID id: String) -> DemoAlbum? {
        demoAlbums.first(where: { $0.id == id })
    }

    func fetchDemoPlaylists() -> [DemoPlaylistRecord] {
        guard runtime.usesDummyData else { return [] }
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: demoPlaylistsKey),
           let playlists = try? JSONDecoder().decode([DemoPlaylistRecord].self, from: data) {
            return playlists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        let seeded = [
            DemoPlaylistRecord(
                id: "favorites",
                name: "Favorites",
                trackIDs: ["billie-jean-michael-jackson", "lose-yourself-eminem"],
                updatedAt: .now
            )
        ]
        saveDemoPlaylists(seeded)
        return seeded
    }

    func createDemoPlaylist(name: String) -> DemoPlaylistRecord {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let playlist = DemoPlaylistRecord(
            id: UUID().uuidString,
            name: trimmedName,
            trackIDs: [],
            updatedAt: .now
        )
        var playlists = fetchDemoPlaylists()
        playlists.append(playlist)
        saveDemoPlaylists(playlists)
        return playlist
    }

    func addDemoSongsToPlaylist(_ songs: [DemoSong], playlistID: String) {
        var playlists = fetchDemoPlaylists()
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }

        let newIDs = songs.map(\.id)
        playlists[index].trackIDs.append(contentsOf: newIDs.filter { !playlists[index].trackIDs.contains($0) })
        playlists[index].updatedAt = .now
        saveDemoPlaylists(playlists)
    }

    private func saveDemoPlaylists(_ playlists: [DemoPlaylistRecord]) {
        let sorted = playlists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if let data = try? JSONEncoder().encode(sorted) {
            UserDefaults.standard.set(data, forKey: demoPlaylistsKey)
        }
    }
}
