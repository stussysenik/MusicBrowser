import SwiftUI
import MusicKit

struct DemoSearchView: View {
    private enum SearchScope: String, CaseIterable {
        case library = "Library"
        case catalog = "Apple Music"
    }

    private enum PlaylistTarget: Identifiable {
        case demo(DemoSong)
        case live(Song)

        var id: String {
            switch self {
            case .demo(let song):
                return "demo-\(song.id)"
            case .live(let song):
                return "live-\(song.id.rawValue)"
            }
        }
    }

    @Environment(PlayerService.self) private var player
    @Environment(MusicService.self) private var musicService

    @State private var searchText = ""
    @State private var searchScope: SearchScope = .library
    @State private var playlistTarget: PlaylistTarget?
    @State private var catalogResults: MusicService.SearchResults?
    @State private var catalogError: Error?
    @State private var isSearchingCatalog = false
    @State private var searchTask: Task<Void, Never>?

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var availableScopes: [SearchScope] {
        let catalogEnabled = Bundle.main.object(forInfoDictionaryKey: "MusicKitCatalogEnabled") as? Bool ?? false
        return catalogEnabled ? SearchScope.allCases : [.library]
    }

    private var matchingSongs: [DemoSong] {
        guard !trimmedSearchText.isEmpty else { return [] }
        return musicService.demoSongs.filter { song in
            SearchMatcher.matches(term: trimmedSearchText, fields: [
                song.title,
                song.artistName,
                song.albumTitle,
                song.genreNames.joined(separator: " ")
            ])
        }
    }

    private var matchingAlbums: [DemoAlbum] {
        guard !trimmedSearchText.isEmpty else { return [] }
        return musicService.demoAlbums.filter { album in
            SearchMatcher.matches(term: trimmedSearchText, fields: [
                album.title,
                album.artistName,
                album.genreNames.joined(separator: " ")
            ])
        }
    }

    private var matchingPlaylists: [DemoPlaylistRecord] {
        guard !trimmedSearchText.isEmpty else { return [] }
        let songsByID = Dictionary(uniqueKeysWithValues: musicService.demoSongs.map { ($0.id, $0) })
        return musicService.fetchDemoPlaylists().filter { playlist in
            let fields = playlist.trackIDs.compactMap { songsByID[$0] }.flatMap { song in
                [song.title, song.artistName, song.albumTitle] + song.genreNames
            }
            return SearchMatcher.matches(term: trimmedSearchText, fields: [playlist.name] + fields)
        }
    }

    var body: some View {
        List {
            if searchScope == .library {
                libraryResults
            } else {
                catalogResultsContent
            }
        }
        .listStyle(.plain)
        .navigationTitle("Search")
        .searchable(text: $searchText, prompt: "Songs, Albums, Artists")
        .searchScopes($searchScope) {
            ForEach(availableScopes, id: \.self) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .task {
            #if os(iOS)
            await musicService.prepareFallbackLibraryIfPossible()
            #endif
        }
        .onChange(of: searchText) { _, newValue in
            guard searchScope == .catalog else { return }
            runCatalogSearch(for: newValue)
        }
        .onChange(of: searchScope) { _, newValue in
            searchTask?.cancel()
            catalogError = nil
            if newValue == .catalog, !trimmedSearchText.isEmpty {
                runCatalogSearch(for: trimmedSearchText, debounce: false)
            } else {
                catalogResults = nil
                isSearchingCatalog = false
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .searchSuggestions {
            if searchScope == .library {
                ForEach(matchingSongs.prefix(5)) { song in
                    Text(song.title)
                        .searchCompletion(song.title)
                }
                ForEach(matchingAlbums.prefix(3)) { album in
                    Text(album.title)
                        .searchCompletion(album.title)
                }
            }
        }
        .navigationDestination(for: DemoSong.self) { song in
            DemoSongDetailView(song: song)
        }
        .navigationDestination(for: DemoAlbum.self) { album in
            DemoAlbumDetailView(album: album)
        }
        .navigationDestination(for: Album.self) { album in
            AlbumDetailView(album: album)
        }
        .navigationDestination(for: Artist.self) { artist in
            ArtistDetailView(artist: artist)
        }
        .navigationDestination(for: Playlist.self) { playlist in
            PlaylistDetailView(playlist: playlist)
        }
        .sheet(item: $playlistTarget) { target in
            switch target {
            case .demo(let song):
                DemoAddToPlaylistSheet(songs: [song])
            case .live(let song):
                AddToPlaylistSheet(songs: [song])
            }
        }
    }

    @ViewBuilder
    private var libraryResults: some View {
        if trimmedSearchText.isEmpty {
            ContentUnavailableView(
                "Search \(musicService.demoLibraryLabel)",
                systemImage: "magnifyingglass",
                description: Text("Search every song, album, and playlist in the current snapshot.")
            )
            .listRowSeparator(.hidden)
        } else {
            if !matchingSongs.isEmpty {
                Section("Songs") {
                    ForEach(matchingSongs.prefix(25)) { song in
                        NavigationLink(value: song) {
                            HStack(spacing: 12) {
                                DemoArtworkTile(title: song.title)
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .lineLimit(1)
                                    Text(song.artistName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text("\(Int(song.bpm))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.orange)
                            }
                        }
                        .contextMenu {
                            Button {
                                player.playDemoSong(song)
                            } label: {
                                Label("Play", systemImage: "play")
                            }
                            Button {
                                player.playDemoNext(song)
                            } label: {
                                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                            }
                            Button {
                                player.addDemoSongToQueue(song)
                            } label: {
                                Label("Add to Queue", systemImage: "text.badge.plus")
                            }
                            Divider()
                            Button {
                                playlistTarget = .demo(song)
                            } label: {
                                Label("Add to Playlist", systemImage: "music.note.list")
                            }
                        }
                    }
                }
            }

            if !matchingAlbums.isEmpty {
                Section("Albums") {
                    ForEach(matchingAlbums.prefix(16)) { album in
                        NavigationLink(value: album) {
                            HStack(spacing: 12) {
                                DemoArtworkTile(title: album.title)
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(album.title)
                                        .lineLimit(1)
                                    Text(album.artistName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text("\(album.songs.count) tracks")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            if !matchingPlaylists.isEmpty {
                Section("Playlists") {
                    ForEach(matchingPlaylists.prefix(12)) { playlist in
                        LabeledContent(playlist.name, value: "\(playlist.trackIDs.count) tracks")
                    }
                }
            }

            if matchingSongs.isEmpty && matchingAlbums.isEmpty && matchingPlaylists.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different title, artist, album, or tag.")
                )
                .listRowSeparator(.hidden)
            }
        }
    }

    @ViewBuilder
    private var catalogResultsContent: some View {
        if trimmedSearchText.isEmpty {
            ContentUnavailableView(
                "Search Apple Music",
                systemImage: "music.note.house",
                description: Text("Search the Apple Music catalog from the same screen.")
            )
            .listRowSeparator(.hidden)
        } else if isSearchingCatalog, catalogResults == nil {
            HStack {
                Spacer()
                ProgressView("Searching Apple Music")
                Spacer()
            }
            .listRowSeparator(.hidden)
        } else if let catalogError, catalogResults == nil {
            ContentUnavailableView {
                Label("Apple Music Unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(catalogError.localizedDescription)
            } actions: {
                Button("Retry") {
                    runCatalogSearch(for: trimmedSearchText, debounce: false)
                }
                .buttonStyle(.bordered)
            }
            .listRowSeparator(.hidden)
        } else if let catalogResults {
            if !catalogResults.songs.isEmpty {
                Section("Songs") {
                    ForEach(catalogResults.songs.prefix(12)) { song in
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
                                playlistTarget = .live(song)
                            } label: {
                                Label("Add to Playlist", systemImage: "music.note.list")
                            }
                        }
                    }
                }
            }

            if !catalogResults.albums.isEmpty {
                Section("Albums") {
                    ForEach(catalogResults.albums.prefix(8)) { album in
                        NavigationLink(value: album) {
                            HStack(spacing: 12) {
                                ArtworkView(artwork: album.artwork, size: 50)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(album.title)
                                        .lineLimit(1)
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

            if !catalogResults.artists.isEmpty {
                Section("Artists") {
                    ForEach(catalogResults.artists.prefix(8)) { artist in
                        NavigationLink(value: artist) {
                            Text(artist.name)
                        }
                    }
                }
            }

            if !catalogResults.playlists.isEmpty {
                Section("Playlists") {
                    ForEach(catalogResults.playlists.prefix(8)) { playlist in
                        NavigationLink(value: playlist) {
                            HStack(spacing: 12) {
                                ArtworkView(artwork: playlist.artwork, size: 46)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name)
                                        .lineLimit(1)
                                    if let curatorName = playlist.curatorName {
                                        Text(curatorName)
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

            if catalogResults.songs.isEmpty,
               catalogResults.albums.isEmpty,
               catalogResults.artists.isEmpty,
               catalogResults.playlists.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different keyword or artist name.")
                )
                .listRowSeparator(.hidden)
            }
        }
    }

    private func runCatalogSearch(for rawTerm: String, debounce: Bool = true) {
        searchTask?.cancel()
        catalogError = nil

        let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            isSearchingCatalog = false
            catalogResults = nil
            return
        }

        isSearchingCatalog = true
        searchTask = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard !Task.isCancelled else { return }

            let isAuthorized = await musicService.requestCatalogAuthorizationIfNeeded()
            guard !Task.isCancelled else { return }

            guard isAuthorized else {
                catalogResults = nil
                catalogError = MusicService.SearchError.catalogAuthorizationRequired
                isSearchingCatalog = false
                return
            }

            do {
                let results = try await musicService.searchCatalogDirect(term)
                guard !Task.isCancelled else { return }
                catalogResults = results
                catalogError = nil
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                catalogResults = nil
                catalogError = error
            }

            if !Task.isCancelled {
                isSearchingCatalog = false
            }
        }
    }
}

#Preview("Demo Search") {
    PreviewHost {
        NavigationStack {
            DemoSearchView()
        }
    }
}
