import SwiftUI
import MusicKit

struct LibrarySongsView: View {
    @Environment(MusicService.self) private var musicService
    @Environment(PlayerService.self) private var player
    @Environment(AnalysisService.self) private var analysisService

    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var hasMore = true
    @State private var sortOption: SongSortOption = .title
    @State private var sortDirection: SortDirection = .ascending
    @State private var filterArtist: String = ""
    @State private var filterGenre: String = ""
    @State private var bpmMin: Double = 0
    @State private var bpmMax: Double = 300

    // MARK: - Pre-computed indexes (O(1) lookup)

    @State private var artistIndex: [String] = []
    @State private var genreIndex: [String] = []
    @State private var displayCache: [Song] = []

    var body: some View {
        Group {
            if isLoading && songs.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if songs.isEmpty {
                ContentUnavailableView("No Songs", systemImage: "music.note")
            } else {
                songList
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    sortSection
                    directionSection
                    filterSection
                } label: {
                    Label("View Options", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .task { await loadSongs() }
        .onChange(of: sortOption) { _, _ in
            if sortOption.isAPISort {
                Task { await reloadSongs() }
            } else {
                rebuildDisplayCache()
            }
        }
        .onChange(of: sortDirection) { _, _ in
            if sortOption.isAPISort {
                Task { await reloadSongs() }
            } else {
                rebuildDisplayCache()
            }
        }
        .onChange(of: filterArtist) { _, _ in rebuildDisplayCache() }
        .onChange(of: filterGenre) { _, _ in rebuildDisplayCache() }
    }

    // MARK: - Song List

    private var songList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                HStack {
                    Text("\(displayCache.count) songs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if sortOption == .playCount || sortOption == .lastPlayed {
                        Text(sortOption.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)

                ForEach(Array(displayCache.enumerated()), id: \.element.id) { idx, song in
                    songRow(song, at: idx)
                        .task {
                            if idx == displayCache.count - 5 { await loadMore() }
                        }

                    if idx < displayCache.count - 1 {
                        Divider().padding(.leading, 68)
                    }
                }

                if hasMore {
                    ProgressView()
                        .padding()
                }
            }
        }
    }

    // MARK: - Song Row

    @ViewBuilder
    private func songRow(_ song: Song, at idx: Int) -> some View {
        NavigationLink(value: song) {
            HStack(spacing: 0) {
                HStack(spacing: 12) {
                    ArtworkView(artwork: song.artwork, size: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.body)
                            .lineLimit(1)
                        Text(song.artistName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if let duration = song.duration {
                        Text(formatDuration(duration))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }

                if sortOption == .playCount, let count = song.playCount {
                    Text("\(count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 4)
                }
                if sortOption == .bpm, let bpm = analysisService.bpm(for: song) {
                    Text("\(Int(bpm))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.orange)
                        .padding(.trailing, 4)
                }

                Button {
                    Task { try? await player.playSongs(displayCache, startingAt: idx) }
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Menu Sections

    @ViewBuilder
    private var sortSection: some View {
        Section("Sort By") {
            Picker("Sort", selection: $sortOption) {
                ForEach(SongSortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        }
    }

    @ViewBuilder
    private var directionSection: some View {
        Section {
            Button {
                sortDirection.toggle()
            } label: {
                Label(
                    sortDirection.isAscending ? "Ascending" : "Descending",
                    systemImage: sortDirection.systemImage
                )
            }
        }
    }

    @ViewBuilder
    private var filterSection: some View {
        if !genreIndex.isEmpty {
            Section("Genre") {
                Button("All Genres") { filterGenre = "" }
                ForEach(genreIndex.prefix(15), id: \.self) { genre in
                    Button {
                        filterGenre = genre
                    } label: {
                        HStack {
                            Text(genre)
                            if filterGenre == genre {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
        if !artistIndex.isEmpty {
            Section("Artist") {
                Button("All Artists") { filterArtist = "" }
                ForEach(artistIndex.prefix(20), id: \.self) { artist in
                    Button {
                        filterArtist = artist
                    } label: {
                        HStack {
                            Text(artist)
                            if filterArtist == artist {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Index Builders (called once per data load)

    private func rebuildIndexes() {
        var artists = Set<String>()
        var genres = Set<String>()
        for song in songs {
            artists.insert(song.artistName)
            for g in song.genreNames { genres.insert(g) }
        }
        artistIndex = artists.sorted()
        genreIndex = genres.sorted()
    }

    private func rebuildDisplayCache() {
        var result = songs

        if !filterArtist.isEmpty {
            result = result.filter { $0.artistName == filterArtist }
        }
        if !filterGenre.isEmpty {
            result = result.filter { $0.genreNames.contains(filterGenre) }
        }

        switch sortOption {
        case .duration:
            result.sort { ($0.duration ?? 0) < ($1.duration ?? 0) }
            if !sortDirection.isAscending { result.reverse() }
        case .releaseDate:
            result.sort { ($0.releaseDate ?? .distantPast) < ($1.releaseDate ?? .distantPast) }
            if !sortDirection.isAscending { result.reverse() }
        case .bpm:
            result.sort {
                (analysisService.bpm(for: $0) ?? 0) < (analysisService.bpm(for: $1) ?? 0)
            }
            if !sortDirection.isAscending { result.reverse() }
        default:
            break
        }

        if bpmMin > 0 || bpmMax < 300 {
            result = result.filter { song in
                guard let bpm = analysisService.bpm(for: song) else { return bpmMin == 0 }
                return bpm >= bpmMin && bpm <= bpmMax
            }
        }

        displayCache = result
    }

    // MARK: - Data Loading

    private func loadSongs() async {
        do {
            let response = try await musicService.librarySongs(sort: sortOption, direction: sortDirection)
            songs = Array(response.items)
            hasMore = response.items.count == 100
            isLoading = false
            rebuildIndexes()
            rebuildDisplayCache()
            await analysisService.analyzeBatch(Array(songs.prefix(50)))
        } catch {
            isLoading = false
        }
    }

    private func reloadSongs() async {
        songs = []
        isLoading = true
        hasMore = true
        await loadSongs()
    }

    private func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        do {
            let response = try await musicService.librarySongs(
                offset: songs.count,
                sort: sortOption,
                direction: sortDirection
            )
            let newSongs = Array(response.items)
            songs.append(contentsOf: newSongs)
            hasMore = response.items.count == 100
            isLoading = false
            rebuildIndexes()
            rebuildDisplayCache()
            await analysisService.analyzeBatch(newSongs)
        } catch {
            isLoading = false
        }
    }
}
