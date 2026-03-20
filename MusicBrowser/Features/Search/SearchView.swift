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
    @State private var searchScope: SearchScope = .catalog
    @State private var addToPlaylistSong: Song?
    @State private var addedToLibrary: Set<MusicItemID> = []

    private enum SearchScope: String, CaseIterable {
        case catalog = "Catalog"
        case library = "Library"
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
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
            runSearch(for: newValue)
        }
        .onChange(of: searchScope) { _, _ in
            if !trimmedSearchText.isEmpty {
                runSearch(for: trimmedSearchText, debounce: false)
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .animation(.snappy(duration: 0.2), value: isSearching)
        .animation(.snappy(duration: 0.2), value: searchScope)
        .sheet(item: $addToPlaylistSong) { song in
            AddToPlaylistSheet(song: song)
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
                    response = try await musicService.search(term)
                case .library:
                    response = try await musicService.searchLibraryLocal(term: term)
                }
                guard !Task.isCancelled else { return }
                results = response
                searchError = nil
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
        res.songs.isEmpty && res.albums.isEmpty && res.artists.isEmpty && res.playlists.isEmpty
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
                        if searchScope == .catalog {
                            Divider()
                            Button {
                                Task {
                                    try? await musicService.addToLibrary(song)
                                    addedToLibrary.insert(song.id)
                                    Haptic.success()
                                }
                            } label: {
                                Label(
                                    addedToLibrary.contains(song.id) ? "Added to Library" : "Add to Library",
                                    systemImage: addedToLibrary.contains(song.id) ? "checkmark" : "plus"
                                )
                            }
                            .disabled(addedToLibrary.contains(song.id))
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
                    .contextMenu {
                        if searchScope == .catalog {
                            Button {
                                Task {
                                    try? await musicService.addToLibrary(album)
                                    addedToLibrary.insert(album.id)
                                    Haptic.success()
                                }
                            } label: {
                                Label(
                                    addedToLibrary.contains(album.id) ? "Added to Library" : "Add to Library",
                                    systemImage: addedToLibrary.contains(album.id) ? "checkmark" : "plus"
                                )
                            }
                            .disabled(addedToLibrary.contains(album.id))
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
}

#Preview("Search") {
    PreviewHost {
        NavigationStack {
            SearchView()
        }
    }
}
