import SwiftUI
import MusicKit

struct SearchView: View {
    @Environment(MusicService.self) private var musicService
    @Environment(PlayerService.self) private var player

    @State private var searchText = ""
    @State private var results: MusicService.SearchResults?
    @State private var searchTask: Task<Void, Never>?
    @State private var searchError: Error?
    @State private var isSearching = false
    @State private var searchScope: SearchScope = .library
    @State private var addToPlaylistSong: Song?
    @State private var catalogUnavailable = false
    @State private var shouldRefreshLibrarySnapshot = true

    private enum SearchScope: String, CaseIterable {
        case library = "Library"
        case catalog = "Apple Music"
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    var body: some View {
        if musicService.runtime.usesDummyData {
            DemoSearchView()
        } else {
            liveSearch
        }
    }

    private var liveSearch: some View {
        List {
            if catalogUnavailable && searchScope == .catalog {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Apple Music search needs access to the Apple Music catalog. Showing library results.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.orange.opacity(0.1))
                }
            }

            if searchError != nil, results == nil, !isSearching {
                ContentUnavailableView {
                    Label("Search Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Couldn't search. Check your connection and try again.")
                } actions: {
                    Button("Retry") {
                        runSearch(for: trimmedSearchText, debounce: false)
                    }
                    .buttonStyle(.bordered)
                }
            } else if isSearching, results == nil {
                HStack {
                    Spacer()
                    ProgressView("Searching")
                        .symbolEffect(.pulse, options: .repeating)
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if let results {
                songResults(results)
                albumResults(results)
                artistResults(results)
                playlistResults(results)
                musicVideoResults(results)

                if hasNoResults(results) {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different keyword or artist name.")
                    )
                    .listRowSeparator(.hidden)
                }
            } else if trimmedSearchText.isEmpty {
                ContentUnavailableView(
                    "Search \(searchScope == .catalog ? "Apple Music" : "Your Library")",
                    systemImage: "magnifyingglass",
                    description: Text("Find songs, albums, artists, and playlists.")
                )
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Artists, Songs, Albums")
        .searchScopes($searchScope) {
            ForEach(SearchScope.allCases, id: \.self) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .navigationTitle("Search")
        .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
        .navigationDestination(for: Artist.self) { ArtistDetailView(artist: $0) }
        .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlist: $0) }
        .onChange(of: searchText) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                shouldRefreshLibrarySnapshot = true
            }
            runSearch(for: newValue)
        }
        .onChange(of: searchScope) { _, _ in
            catalogUnavailable = false
            shouldRefreshLibrarySnapshot = true
            if !trimmedSearchText.isEmpty {
                runSearch(for: trimmedSearchText, debounce: false)
            }
        }
        .onDisappear {
            searchTask?.cancel()
            shouldRefreshLibrarySnapshot = true
        }
        .animation(.snappy(duration: 0.2), value: isSearching)
        .animation(.snappy(duration: 0.2), value: searchScope)
        .sheet(item: $addToPlaylistSong) { song in
            AddToPlaylistSheet(songs: [song])
        }
    }

    // MARK: - Search

    private func runSearch(for rawTerm: String, debounce: Bool = true) {
        searchTask?.cancel()
        searchError = nil

        let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            isSearching = false
            results = nil
            return
        }

        isSearching = true
        searchTask = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard !Task.isCancelled else { return }

            do {
                let response: MusicService.SearchResults
                switch searchScope {
                case .catalog:
                    response = try await musicService.searchCatalogDirect(term)
                case .library:
                    let forceRefresh = shouldRefreshLibrarySnapshot
                    response = try await musicService.searchLibraryLocal(term: term, forceRefresh: forceRefresh)
                    shouldRefreshLibrarySnapshot = false
                }
                guard !Task.isCancelled else { return }
                catalogUnavailable = false
                results = response
                searchError = nil
            } catch let error as MusicService.SearchError
                where error == .catalogUnavailable || error == .catalogAuthorizationRequired {
                guard !Task.isCancelled else { return }
                catalogUnavailable = true
                // Fall back to library search automatically
                if let libraryResults = try? await musicService.searchLibraryLocal(
                    term: term,
                    forceRefresh: shouldRefreshLibrarySnapshot
                ) {
                    results = libraryResults
                    shouldRefreshLibrarySnapshot = false
                }
                isSearching = false
                return
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                results = nil
                searchError = error
            }

            if !Task.isCancelled {
                isSearching = false
            }
        }
    }

    private func hasNoResults(_ res: MusicService.SearchResults) -> Bool {
        res.songs.isEmpty && res.albums.isEmpty && res.artists.isEmpty && res.playlists.isEmpty && res.musicVideos.isEmpty
    }

    // MARK: - Result Sections

    @ViewBuilder
    private func songResults(_ res: MusicService.SearchResults) -> some View {
        if !res.songs.isEmpty {
            Section("Songs") {
                ForEach(res.songs.prefix(10)) { song in
                    TrackRow(
                        title: song.title,
                        artistName: song.artistName,
                        artwork: song.artwork,
                        duration: song.duration
                    ) {
                        Task { try? await player.playSong(song) }
                    }
                    .contextMenu {
                        Button {
                            Task { try? await player.playSong(song) }
                        } label: {
                            Label("Play", systemImage: "play")
                        }
                        Button {
                            Task { try? await player.playNext(song) }
                        } label: {
                            Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                        }
                        Button {
                            Task { try? await player.addToQueue(song) }
                        } label: {
                            Label("Add to Queue", systemImage: "text.badge.plus")
                        }
                        Divider()
                        Button {
                            addToPlaylistSong = song
                        } label: {
                            Label("Add to Playlist", systemImage: "music.note.list")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func albumResults(_ res: MusicService.SearchResults) -> some View {
        if !res.albums.isEmpty {
            Section("Albums") {
                ForEach(res.albums.prefix(6)) { album in
                    NavigationLink(value: album) {
                        HStack(spacing: 12) {
                            ArtworkView(artwork: album.artwork, size: 50)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album.title).lineLimit(1)
                                Text(album.artistName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func artistResults(_ res: MusicService.SearchResults) -> some View {
        if !res.artists.isEmpty {
            Section("Artists") {
                ForEach(res.artists.prefix(4)) { artist in
                    NavigationLink(value: artist) {
                        HStack(spacing: 12) {
                            ArtworkView(artwork: artist.artwork, size: 44)
                                .clipShape(Circle())
                            Text(artist.name)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func playlistResults(_ res: MusicService.SearchResults) -> some View {
        if !res.playlists.isEmpty {
            Section("Playlists") {
                ForEach(res.playlists.prefix(4)) { playlist in
                    NavigationLink(value: playlist) {
                        HStack(spacing: 12) {
                            ArtworkView(artwork: playlist.artwork, size: 50)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name).lineLimit(1)
                                if let curator = playlist.curatorName {
                                    Text(curator)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func musicVideoResults(_ res: MusicService.SearchResults) -> some View {
        if !res.musicVideos.isEmpty {
            Section("Music Videos") {
                ForEach(res.musicVideos.prefix(6)) { video in
                    HStack(spacing: 12) {
                        ArtworkView(artwork: video.artwork, size: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(video.title).lineLimit(1)
                            Text(video.artistName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            player.openMusicVideo(video)
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

#Preview("Search") {
    PreviewHost {
        NavigationStack {
            SearchView()
        }
    }
}
