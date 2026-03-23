import SwiftUI
import MusicKit

struct LibrarySongsView: View {
    @Environment(MusicService.self) private var musicService
    @Environment(AnalysisService.self) private var analysisService
    @Environment(PlayerService.self) private var player

    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var hasMore = true
    @State private var loadError: Error?
    @State private var loadTask: Task<Void, Never>?
    @State private var sortOption: SongSortOption = .title
    @State private var sortDirection: SortDirection = .ascending
    @State private var grouping: SongGrouping = .letter
    @State private var groupCache: [(String, [Song])] = []
    @State private var filterArtist: String = ""
    @State private var filterGenre: String = ""
    @State private var bpmMin: Double = 0
    @State private var bpmMax: Double = 300
    @State private var addToPlaylistSong: Song?

    // MARK: - Pre-computed indexes (O(1) lookup)

    @State private var artistIndex: [String] = []
    @State private var genreIndex: [String] = []
    @State private var displayCache: [Song] = []

    // Cached derived values (rebuilt explicitly instead of per-render)
    @State private var filteredSongsCache: [Song] = []
    @State private var availableLettersCache: [String] = []

    var body: some View {
        Group {
            if isLoading && songs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { _ in
                        SkeletonTrackRow()
                        Divider().padding(.leading, 68)
                    }
                    Spacer()
                }
            } else if let loadError, songs.isEmpty {
                ContentUnavailableView {
                    Label("Unable to Load Songs", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError.localizedDescription)
                } actions: {
                    Button("Retry") {
                        loadTask?.cancel()
                        loadTask = Task { await loadSongs() }
                    }
                    .buttonStyle(.bordered)
                }
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
                    Section("Group By") {
                        Picker("Grouping", selection: $grouping) {
                            ForEach(SongGrouping.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    }
                } label: {
                    Label("View Options", systemImage: "line.3.horizontal.decrease")
                }
            }
        }
        .task { await loadSongs() }
        .onChange(of: sortOption) { _, _ in
            if sortOption.isAPISort {
                loadTask?.cancel()
                loadTask = Task { await reloadSongs() }
            } else {
                rebuildDisplayCache()
            }
        }
        .onChange(of: sortDirection) { _, _ in
            if sortOption.isAPISort {
                loadTask?.cancel()
                loadTask = Task { await reloadSongs() }
            } else {
                rebuildDisplayCache()
            }
        }
        .onChange(of: grouping) { _, _ in rebuildGroups() }
        .onChange(of: filterArtist) { _, _ in rebuildDisplayCache() }
        .onChange(of: filterGenre) { _, _ in rebuildDisplayCache() }
        .animation(.snappy(duration: 0.2), value: filteredSongsCache.count)
        .sheet(item: $addToPlaylistSong) { song in
            AddToPlaylistSheet(song: song)
        }
    }

    // MARK: - Song List

    /// Songs grouped by first letter for section-based scrolling.
    /// Section anchors are always present in the view hierarchy so
    /// `ScrollViewReader.scrollTo` works even for off-screen letters.
    private var groupedByLetter: [(key: String, value: [Song])] {
        Dictionary(grouping: filteredSongs) { firstLetter(for: $0.title) }
            .sorted { $0.key < $1.key }
    }

    private var songList: some View {
        Group {
            if grouping == .letter {
                letterGroupedList
            } else {
                yearGroupedList
            }
        }
    }

    private var letterGroupedList: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        HStack {
                            Text("\(filteredSongs.count) songs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .id("songs-top")

                        ForEach(groupedByLetter, id: \.key) { letter, songs in
                            // Invisible anchor that is always in the view tree
                            Color.clear
                                .frame(height: 0)
                                .id("section-\(letter)")

                            ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
                                songRow(song)
                                    .task {
                                        // Trigger pagination when near the end of ALL songs
                                        if song.id == filteredSongs.last?.id ||
                                           filteredSongs.suffix(5).contains(where: { $0.id == song.id }) {
                                            await loadMore()
                                        }
                                    }

                                if !(letter == groupedByLetter.last?.key && idx == songs.count - 1) {
                                    Divider().padding(.leading, 68)
                                }
                            }
                        }

                        if hasMore {
                            ProgressView()
                                .padding()
                                .symbolEffect(.pulse, options: .repeating)
                        }
                    }
                }

                SectionIndexRail(
                    availableLetters: Set(availableLetters),
                    onScrollTo: { letter in
                        withAnimation(.snappy(duration: 0.2)) {
                            proxy.scrollTo("section-\(letter)", anchor: .top)
                        }
                    }
                )
            }
        }
    }

    private var yearGroupedList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("\(filteredSongs.count) songs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                ForEach(groupCache, id: \.0) { label, songs in
                    Section {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
                            songRow(song)
                                .task {
                                    if song.id == filteredSongs.last?.id ||
                                       filteredSongs.suffix(5).contains(where: { $0.id == song.id }) {
                                        await loadMore()
                                    }
                                }

                            if idx < songs.count - 1 {
                                Divider().padding(.leading, 68)
                            }
                        }
                    } header: {
                        Text(label)
                            .font(.title3.bold())
                            .padding(.horizontal)
                            .padding(.top, 16)
                            .padding(.bottom, 4)
                    }
                }

                if hasMore {
                    ProgressView()
                        .padding()
                        .symbolEffect(.pulse, options: .repeating)
                }
            }
        }
    }

    // MARK: - Song Row

    @ViewBuilder
    private func songRow(_ song: Song) -> some View {
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
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.vertical, 4)
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
                ForEach(genreIndex, id: \.self) { genre in
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
        rebuildFilteredCache()
        rebuildGroups()
    }

    private func rebuildFilteredCache() {
        availableLettersCache = displayCache.availableLetters
        filteredSongsCache = displayCache
    }

    private func rebuildGroups() {
        switch grouping {
        case .letter:
            groupCache = []
        case .year:
            let grouped = Dictionary(grouping: displayCache) { song -> String in
                guard let year = song.releaseDate?.year else { return "Unknown" }
                return String(year)
            }
            groupCache = grouped.sorted { a, b in
                sortDirection.isAscending ? a.key < b.key : a.key > b.key
            }
        case .decade:
            let grouped = Dictionary(grouping: displayCache) { song -> String in
                guard let year = song.releaseDate?.year else { return "Unknown" }
                let decade = (year / 10) * 10
                return "\(decade)s"
            }
            groupCache = grouped.sorted { a, b in
                sortDirection.isAscending ? a.key < b.key : a.key > b.key
            }
        }
    }

    private var filteredSongs: [Song] { filteredSongsCache }
    private var availableLetters: [String] { availableLettersCache }

    private func firstLetter(for text: String) -> String {
        StringUtils.firstLetter(of: text)
    }

    // MARK: - Data Loading

    private func loadSongs() async {
        do {
            let response = try await musicService.librarySongs(sort: sortOption, direction: sortDirection)
            guard !Task.isCancelled else { return }
            songs = Array(response.items)
            hasMore = response.items.count == 100
            isLoading = false
            loadError = nil
            rebuildIndexes()
            rebuildDisplayCache()
            await analysisService.analyzeBatch(Array(songs.prefix(20)))
        } catch {
            guard !Task.isCancelled else { return }
            loadError = error
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
            guard !Task.isCancelled else { return }
            let newSongs = Array(response.items)
            songs.append(contentsOf: newSongs)
            hasMore = response.items.count == 100
            isLoading = false
            rebuildIndexes()
            rebuildDisplayCache()
            await analysisService.analyzeBatch(newSongs)
        } catch {
            guard !Task.isCancelled else { return }
            isLoading = false
        }
    }
}

#Preview("Library Songs") {
    PreviewHost {
        NavigationStack {
            LibrarySongsView()
        }
    }
}
