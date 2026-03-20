import SwiftUI
import MusicKit

struct GenreBrowserView: View {
    @Environment(MusicService.self) private var musicService
    @Environment(PlayerService.self) private var player

    @State private var genres: [GenreGroup] = []
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var viewMode: GenreViewMode = .grid
    @State private var gradientCache: [String: LinearGradient] = [:]

    enum GenreViewMode: String, CaseIterable {
        case grid = "Grid"
        case wall = "Wall"
        case carousel = "Carousel"

        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .wall: return "rectangle.grid.1x2"
            case .carousel: return "rectangle.split.3x1"
            }
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading genres…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError, genres.isEmpty {
                ContentUnavailableView {
                    Label("Unable to Load Genres", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError.localizedDescription)
                } actions: {
                    Button("Retry") { Task { await loadGenres() } }
                        .buttonStyle(.bordered)
                }
            } else if genres.isEmpty {
                ContentUnavailableView("No Genres", systemImage: "guitars")
            } else {
                switch viewMode {
                case .grid: gridView
                case .wall: wallView
                case .carousel: carouselView
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("View Mode", selection: $viewMode) {
                        ForEach(GenreViewMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                        }
                    }
                } label: {
                    Label("View Mode", systemImage: viewMode.icon)
                }
            }
        }
        .task { await loadGenres() }
        .animation(.snappy(duration: 0.2), value: viewMode)
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)], spacing: 16) {
                ForEach(genres) { genre in
                    NavigationLink(value: genre) {
                        genreCard(genre)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private func genreCard(_ genre: GenreGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(genre.genre)
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(.white)

            Text("\(genre.count) songs")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            HStack(spacing: 12) {
                Button {
                    Haptic.medium()
                    Task { try? await player.playSongs(genre.songs) }
                } label: {
                    Image(systemName: "play.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                }

                Button {
                    Haptic.medium()
                    Task { try? await player.playSongsShuffled(genre.songs) }
                } label: {
                    Image(systemName: "shuffle")
                        .font(.body)
                        .foregroundStyle(.white)
                }

                Spacer()
            }
        }
        .padding()
        .frame(minHeight: 120)
        .background(gradientCache[genre.genre] ?? genreGradient(for: genre.genre))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Wall View

    private var wallView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(genres) { genre in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(genre.genre)
                            .font(.title2.bold())
                            .padding(.horizontal)

                        if !genre.albums.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 4)], spacing: 4) {
                                ForEach(genre.wallAlbums, id: \.id) { album in
                                    NavigationLink(value: album) {
                                        ArtworkView(artwork: album.artwork, size: 80)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }

                        HStack(spacing: 12) {
                            Text("\(genre.count) songs")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                Haptic.medium()
                                Task { try? await player.playSongs(genre.songs) }
                            } label: {
                                Label("Play", systemImage: "play.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button {
                                Haptic.medium()
                                Task { try? await player.playSongsShuffled(genre.songs) }
                            } label: {
                                Label("Shuffle", systemImage: "shuffle")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.horizontal)
                    }

                    Divider().padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Carousel View

    private var carouselView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(genres) { genre in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(genre.genre)
                                .font(.headline)
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text("\(genre.count)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                Haptic.medium()
                                Task { try? await player.playSongs(genre.songs) }
                            } label: {
                                Image(systemName: "play.fill")
                            }

                            Button {
                                Haptic.medium()
                                Task { try? await player.playSongsShuffled(genre.songs) }
                            } label: {
                                Image(systemName: "shuffle")
                            }
                        }
                        .padding(.horizontal)

                        if !genre.albums.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(genre.carouselAlbums, id: \.id) { album in
                                        NavigationLink(value: album) {
                                            AlbumCard(album, size: 120)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Genre Detail (Navigation destination)

    // MARK: - Data

    private func loadGenres() async {
        do {
            let allSongs = try await musicService.allLibrarySongs()
            let allAlbums = try await musicService.allLibraryAlbums()
            guard !Task.isCancelled else { return }

            // Group songs by genre
            var genreMap: [String: [Song]] = [:]
            for song in allSongs {
                for genre in song.genreNames {
                    genreMap[genre, default: []].append(song)
                }
            }

            // Build album lookup by genre
            var genreAlbumMap: [String: [Album]] = [:]
            // Map album titles from songs to actual albums
            let albumByTitle = Dictionary(grouping: allAlbums) { $0.title }
            for (genre, songs) in genreMap {
                var seen = Set<String>()
                var albums: [Album] = []
                for song in songs {
                    if let title = song.albumTitle, !seen.contains(title) {
                        seen.insert(title)
                        if let match = albumByTitle[title]?.first {
                            albums.append(match)
                        }
                    }
                }
                genreAlbumMap[genre] = albums
            }

            let builtGenres = genreMap.map { genre, songs in
                let albums = genreAlbumMap[genre] ?? []
                return GenreGroup(
                    id: genre,
                    genre: genre,
                    songs: songs,
                    albums: albums,
                    wallAlbums: Array(albums.prefix(12)),
                    carouselAlbums: Array(albums.prefix(20))
                )
            }
            .sorted { $0.count > $1.count }

            // Pre-compute gradient cache
            var gradients: [String: LinearGradient] = [:]
            for g in builtGenres {
                gradients[g.genre] = genreGradient(for: g.genre)
            }

            genres = builtGenres
            gradientCache = gradients
            isLoading = false
            loadError = nil

            print("[GenreBrowser] Loaded \(allSongs.count) songs, genres found: \(genreMap.keys.count)")
        } catch {
            guard !Task.isCancelled else { return }
            loadError = error
            isLoading = false
        }
    }

    // MARK: - Helpers

    private func genreGradient(for name: String) -> LinearGradient {
        let hash = abs(name.hashValue)
        let hue = Double(hash % 360) / 360.0
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.6, brightness: 0.7),
                Color(hue: (hue + 0.1).truncatingRemainder(dividingBy: 1.0), saturation: 0.5, brightness: 0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Genre Group

struct GenreGroup: Identifiable, Hashable {
    let id: String
    let genre: String
    let songs: [Song]
    let albums: [Album]
    let wallAlbums: [Album]      // Pre-sliced: max 12 for wall view
    let carouselAlbums: [Album]  // Pre-sliced: max 20 for carousel view
    var count: Int { songs.count }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GenreGroup, rhs: GenreGroup) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Genre Detail View

struct GenreDetailView: View {
    let genreGroup: GenreGroup

    @Environment(PlayerService.self) private var player
    @State private var addToPlaylistSong: Song?

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Button {
                        Haptic.medium()
                        Task { try? await player.playSongs(genreGroup.songs) }
                    } label: {
                        Label("Play All", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Haptic.medium()
                        Task { try? await player.playSongsShuffled(genreGroup.songs) }
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .listRowSeparator(.hidden)

            Section("\(genreGroup.count) Songs") {
                ForEach(genreGroup.songs) { song in
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
        .listStyle(.plain)
        .navigationTitle(genreGroup.genre)
        .sheet(item: $addToPlaylistSong) { song in
            AddToPlaylistSheet(song: song)
        }
    }
}

#Preview("Genre Browser") {
    PreviewHost {
        NavigationStack {
            GenreBrowserView()
        }
    }
}
