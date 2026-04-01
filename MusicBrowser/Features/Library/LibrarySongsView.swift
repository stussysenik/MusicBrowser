import SwiftUI
import MusicKit

struct LibrarySongsView: View {
    private struct HydrationRequest: Equatable {
        let sort: SongSortOption
        let direction: SortDirection
    }

    @Environment(MusicService.self) private var musicService
    @Environment(AnalysisService.self) private var analysisService
    @Environment(PlayerService.self) private var player

    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var hasMore = true
    @State private var loadError: Error?
    @State private var loadTask: Task<Void, Never>?
    @State private var fullLibraryTask: Task<Void, Never>?
    @State private var fullLibraryTaskToken: UUID?
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
    @State private var isTimelineHydrating = false
    @State private var isFullLibraryLoaded = false

    private let timelinePageSize = 100
    private let sectionRailContentInset: CGFloat = 8

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
                .accessibilityIdentifier("library-view-options")
            }
        }
        .task { await loadSongs() }
        .onChange(of: sortOption) { _, _ in
            if isFullLibraryLoaded {
                rebuildDisplayCache()
            } else if sortOption.isAPISort {
                loadTask?.cancel()
                loadTask = Task { await reloadSongs() }
            } else {
                rebuildDisplayCache()
                startFullLibraryLoadIfNeeded()
            }
        }
        .onChange(of: sortDirection) { _, _ in
            if isFullLibraryLoaded {
                rebuildDisplayCache()
            } else if sortOption.isAPISort {
                loadTask?.cancel()
                loadTask = Task { await reloadSongs() }
            } else {
                rebuildDisplayCache()
                startFullLibraryLoadIfNeeded()
            }
        }
        .onChange(of: grouping) { _, newValue in
            rebuildGroups()
            if newValue == .letter {
                startFullLibraryLoadIfNeeded()
            }
        }
        .onChange(of: filterArtist) { _, _ in rebuildDisplayCache() }
        .onChange(of: filterGenre) { _, _ in rebuildDisplayCache() }
        .animation(.snappy(duration: 0.2), value: filteredSongsCache.count)
        .sheet(item: $addToPlaylistSong) { song in
            AddToPlaylistSheet(songs: [song])
        }
        .onDisappear {
            loadTask?.cancel()
            stopFullLibraryHydration()
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

    private var tempoSummary: TempoSummary {
        TempoBuckets.summary(for: filteredSongs.map { analysisService.bpm(for: $0.id.rawValue) })
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
            ZStack(alignment: .trailing) {
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

                        if tempoSummary.analyzedCount > 0 {
                            tempoOverviewRow
                        }

                        if grouping == .letter && isTimelineHydrating {
                            timelineStatusRow
                        }

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
                        } else if isTimelineHydrating {
                            ProgressView()
                                .padding()
                                .symbolEffect(.pulse, options: .repeating)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.trailing, sectionRailContentInset)

                #if canImport(UIKit)
                UIKitSectionIndexRail(
                    availableLetters: Set(availableLetters),
                    canSelectUnavailableLetters: isTimelineHydrating || !isFullLibraryLoaded,
                    onScrollTo: { letter in
                        handleLetterSelection(letter, proxy: proxy)
                    }
                )
                .padding(.trailing, 4)
                #else
                SectionIndexRail(
                    availableLetters: Set(availableLetters),
                    canSelectUnavailableLetters: isTimelineHydrating || !isFullLibraryLoaded,
                    onScrollTo: { letter in
                        handleLetterSelection(letter, proxy: proxy)
                    }
                )
                .padding(.trailing, 4)
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
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

                if tempoSummary.analyzedCount > 0 {
                    tempoOverviewRow
                }

                if grouping == .letter && isTimelineHydrating {
                    timelineStatusRow
                }

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

                if hasMore || isTimelineHydrating {
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
                Task { await playSongFromVisibleContext(song) }
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

        result.sort { compareSongs($0, $1) == .orderedAscending }
        if !sortDirection.isAscending {
            result.reverse()
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
        case .tempo:
            let grouped = Dictionary(grouping: displayCache) { song in
                TempoBuckets.label(for: analysisService.bpm(for: song))
            }
            groupCache = grouped.sorted { a, b in
                sortDirection.isAscending ? a.key < b.key : a.key > b.key
            }
        }
    }

    private var filteredSongs: [Song] { filteredSongsCache }
    private var availableLetters: [String] { availableLettersCache }

    private var timelineStatusRow: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text("Building A-Z timeline")
                    .font(.caption.weight(.semibold))
                Text("Indexing more songs in the background. More letters unlock as pages arrive.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var tempoOverviewRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tempo map")
                    .font(.caption.weight(.semibold))
                Text("\(tempoSummary.analyzedCount)/\(tempoSummary.totalCount) analyzed · avg \(Int(tempoSummary.average.rounded())) BPM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "metronome")
                .foregroundStyle(.orange)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func firstLetter(for text: String) -> String {
        StringUtils.firstLetter(of: text)
    }

    private func compareSongs(_ lhs: Song, _ rhs: Song) -> ComparisonResult {
        let primary: ComparisonResult

        switch sortOption {
        case .title:
            primary = compareText(lhs.title, rhs.title)
        case .artist:
            primary = compareText(lhs.artistName, rhs.artistName)
        case .albumTitle:
            primary = compareText(lhs.albumTitle ?? "", rhs.albumTitle ?? "")
        case .dateAdded:
            primary = compareComparable(lhs.libraryAddedDate ?? .distantPast, rhs.libraryAddedDate ?? .distantPast)
        case .releaseDate:
            primary = compareComparable(lhs.releaseDate ?? .distantPast, rhs.releaseDate ?? .distantPast)
        case .playCount:
            primary = compareComparable(lhs.playCount ?? 0, rhs.playCount ?? 0)
        case .lastPlayed:
            primary = compareComparable(lhs.lastPlayedDate ?? .distantPast, rhs.lastPlayedDate ?? .distantPast)
        case .duration:
            primary = compareComparable(lhs.duration ?? 0, rhs.duration ?? 0)
        case .bpm:
            primary = compareComparable(analysisService.bpm(for: lhs) ?? 0, analysisService.bpm(for: rhs) ?? 0)
        }

        if primary != .orderedSame {
            return primary
        }

        let titleTieBreak = compareText(lhs.title, rhs.title)
        if titleTieBreak != .orderedSame {
            return titleTieBreak
        }

        return compareText(lhs.artistName, rhs.artistName)
    }

    private func compareText(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.localizedCaseInsensitiveCompare(rhs)
    }

    private func compareComparable<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }

    private func hydrationRequest(
        sort: SongSortOption? = nil,
        direction: SortDirection? = nil
    ) -> HydrationRequest {
        let resolvedSort = sort ?? sortOption
        let resolvedDirection = direction ?? sortDirection

        if resolvedSort.isAPISort {
            return HydrationRequest(sort: resolvedSort, direction: resolvedDirection)
        } else {
            return HydrationRequest(sort: .title, direction: .ascending)
        }
    }

    private func stopFullLibraryHydration() {
        fullLibraryTask?.cancel()
        fullLibraryTask = nil
        fullLibraryTaskToken = nil
        isTimelineHydrating = false
    }

    private func startFullLibraryLoadIfNeeded(force: Bool = false) {
        guard grouping == .letter else { return }
        guard force || !isFullLibraryLoaded else { return }
        guard force || hasMore else {
            isTimelineHydrating = false
            isFullLibraryLoaded = true
            return
        }
        guard fullLibraryTask == nil else { return }

        let request = hydrationRequest()
        let taskToken = UUID()
        fullLibraryTaskToken = taskToken
        isTimelineHydrating = hasMore
        fullLibraryTask = Task {
            defer {
                Task { @MainActor in
                    guard fullLibraryTaskToken == taskToken else { return }
                    fullLibraryTask = nil
                    fullLibraryTaskToken = nil
                    isTimelineHydrating = false
                }
            }

            if !force {
                try? await Task.sleep(for: .milliseconds(350))
            }

            do {
                while !Task.isCancelled {
                    let snapshot = await MainActor.run {
                        (
                            hasMore: hasMore,
                            isLoading: isLoading,
                            offset: songs.count
                        )
                    }

                    guard snapshot.hasMore else { break }

                    if snapshot.isLoading {
                        try? await Task.sleep(for: .milliseconds(120))
                        continue
                    }

                    let response = try await musicService.librarySongs(
                        limit: timelinePageSize,
                        offset: snapshot.offset,
                        sort: request.sort,
                        direction: request.direction
                    )
                    let newSongs = Array(response.items)
                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        songs.append(contentsOf: newSongs)
                        hasMore = newSongs.count == timelinePageSize
                        isFullLibraryLoaded = !hasMore
                        isTimelineHydrating = hasMore
                        rebuildIndexes()
                        rebuildDisplayCache()
                    }

                    await analysisService.analyzeBatch(Array(newSongs.prefix(20)))
                    await Task.yield()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isTimelineHydrating = false
                }
            }
        }
    }

    private func ensureFullLibraryLoaded() async {
        if isFullLibraryLoaded {
            return
        }

        await MainActor.run {
            startFullLibraryLoadIfNeeded()
        }

        let task = await MainActor.run { fullLibraryTask }
        await task?.value
    }

    private func handleLetterSelection(_ letter: String, proxy: ScrollViewProxy) {
        Task {
            let alreadyAvailable = await MainActor.run { availableLetters.contains(letter) }
            if !alreadyAvailable {
                await ensureFullLibraryLoaded()
            }

            let canScroll = await MainActor.run { availableLetters.contains(letter) }
            guard canScroll else { return }

            await MainActor.run {
                withAnimation(.snappy(duration: 0.2)) {
                    proxy.scrollTo("section-\(letter)", anchor: .top)
                }
            }
        }
    }

    private func playSongFromVisibleContext(_ song: Song) async {
        guard !filteredSongs.isEmpty else {
            try? await player.playSong(song)
            return
        }

        if let index = filteredSongs.firstIndex(where: { $0.id == song.id }) {
            try? await player.playSongs(filteredSongs, startingAt: index)
        } else {
            try? await player.playSong(song)
        }
    }

    // MARK: - Data Loading

    private func loadSongs() async {
        do {
            let request = hydrationRequest(sort: sortOption, direction: sortDirection)
            let response = try await musicService.librarySongs(
                sort: request.sort,
                direction: request.direction
            )
            guard !Task.isCancelled else { return }
            songs = Array(response.items)
            hasMore = response.items.count == timelinePageSize
            isLoading = false
            loadError = nil
            isFullLibraryLoaded = !hasMore
            rebuildIndexes()
            rebuildDisplayCache()
            startFullLibraryLoadIfNeeded()
            await analysisService.analyzeBatch(Array(songs.prefix(20)))
        } catch {
            guard !Task.isCancelled else { return }
            loadError = error
            isLoading = false
        }
    }

    private func reloadSongs() async {
        stopFullLibraryHydration()
        songs = []
        isLoading = true
        hasMore = true
        isFullLibraryLoaded = false
        await loadSongs()
    }

    private func loadMore() async {
        guard hasMore, !isLoading, !isFullLibraryLoaded else { return }
        guard fullLibraryTask == nil else { return }
        isLoading = true
        do {
            let response = try await musicService.librarySongs(
                limit: timelinePageSize,
                offset: songs.count,
                sort: sortOption,
                direction: sortDirection
            )
            guard !Task.isCancelled else { return }
            let newSongs = Array(response.items)
            songs.append(contentsOf: newSongs)
            hasMore = response.items.count == timelinePageSize
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
