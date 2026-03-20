import SwiftUI
import MusicKit

struct LibraryAlbumsView: View {
    let isActive: Bool

    @Environment(MusicService.self) private var musicService
    @Environment(FilterPresetService.self) private var presetService

    @State private var albums: [Album] = []
    @State private var isLoading = true
    @State private var hasMore = true
    @State private var loadError: Error?
    @State private var loadTask: Task<Void, Never>?
    @AppStorage("albums.sortOption") private var sortOption: AlbumSortOption = .title
    @AppStorage("albums.sortDirection") private var sortDirection: SortDirection = .ascending
    @AppStorage("albums.grouping") private var grouping: AlbumGrouping = .none

    // Pre-computed group cache
    @State private var groupCache: [(String, [Album])] = []

    // Cached derived values
    @State private var displayAlbumsCache: [Album] = []
    @State private var availableLettersCache: [String] = []

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        Group {
            if isLoading && albums.isEmpty {
                SkeletonAlbumGrid()
            } else if let loadError, albums.isEmpty {
                ContentUnavailableView {
                    Label("Unable to Load Albums", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError.localizedDescription)
                } actions: {
                    Button("Retry") {
                        loadTask?.cancel()
                        loadTask = Task { await loadAlbums() }
                    }
                    .buttonStyle(.bordered)
                }
            } else if albums.isEmpty {
                ContentUnavailableView("No Albums", systemImage: "square.stack")
            } else if grouping != .none {
                groupedView
            } else {
                flatGridView
            }
        }
        .toolbar {
            if isActive {
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Section("Sort By") {
                            Picker("Sort", selection: $sortOption) {
                                ForEach(AlbumSortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        }

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

                        Section("Group By") {
                            Picker("Grouping", selection: $grouping) {
                                ForEach(AlbumGrouping.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        }
                    } label: {
                        Label("View Options", systemImage: "line.3.horizontal.decrease")
                    }
                }
            }
        }
        .task { await loadAlbums() }
        .onChange(of: sortOption) { _, _ in
            loadTask?.cancel()
            loadTask = Task { await reloadAlbums() }
        }
        .onChange(of: sortDirection) { _, _ in
            loadTask?.cancel()
            loadTask = Task { await reloadAlbums() }
        }
        .onChange(of: grouping) { _, _ in rebuildGroups() }
        .onChange(of: presetService.pinnedLetters) { old, new in
            let oldSet = old[.albums] ?? []
            let newSet = new[.albums] ?? []
            if oldSet != newSet { rebuildDisplayCache() }
        }
        .animation(.snappy(duration: 0.2), value: albums.count)
    }

    // MARK: - Views

    private var displayAlbums: [Album] { displayAlbumsCache }

    private func rebuildDisplayCache() {
        let pinned = presetService.pinnedLettersSet(for: .albums)
        if pinned.isEmpty {
            displayAlbumsCache = albums
        } else {
            displayAlbumsCache = albums.filter { pinned.contains(firstLetter(for: $0.title)) }
        }
        rebuildAvailableLetters()
    }

    private var flatGridView: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if presetService.hasPinnedLetters(for: .albums) {
                    PinnedLetterChipsBar(
                        pinnedLetters: presetService.pinnedLettersSet(for: .albums),
                        onUnpin: { letter in
                            withAnimation { presetService.unpinLetter(letter, for: .albums) }
                        },
                        onClearAll: {
                            withAnimation { presetService.clearPinnedLetters(for: .albums) }
                        }
                    )
                }

                ZStack(alignment: .trailing) {
                    ScrollView {
                        VStack(spacing: 8) {
                            HStack {
                                Text("\(displayAlbums.count) albums")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .id("albums-top")

                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(Array(displayAlbums.indices), id: \.self) { idx in
                                    let album = displayAlbums[idx]
                                    // Insert letter anchor before first album of each letter group
                                    if idx == 0 || firstLetter(for: album.title) != firstLetter(for: displayAlbums[idx - 1].title) {
                                        Color.clear
                                            .frame(height: 0)
                                            .id("letter-\(firstLetter(for: album.title))")
                                    }

                                    NavigationLink(value: album) {
                                        AlbumCard(album, size: 160)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                        }
                        .padding(.trailing, 44)
                    }

                    SectionIndexRail(
                        availableLetters: Set(availableLettersCache),
                        pinnedLetters: presetService.pinnedLettersSet(for: .albums),
                        onScrollTo: { letter in
                            withAnimation(.snappy(duration: 0.2)) {
                                proxy.scrollTo("letter-\(letter)", anchor: .top)
                            }
                        },
                        onDoubleTap: { letter in
                            withAnimation { presetService.togglePinnedLetter(letter, for: .albums) }
                        }
                    )
                }
            }
        }
    }

    private var groupedView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(groupCache, id: \.0) { label, groupAlbums in
                    Section {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(groupAlbums) { album in
                                NavigationLink(value: album) {
                                    AlbumCard(album, size: 160)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text(label)
                            .font(.title2.bold())
                            .padding(.horizontal)
                    }
                }

            }
            .padding()
        }
    }

    // MARK: - Group Builder (called once per data/grouping change)

    private func rebuildGroups() {
        switch grouping {
        case .none:
            groupCache = []
        case .year:
            let grouped = Dictionary(grouping: albums) { album -> String in
                guard let year = album.releaseDate?.year else { return "Unknown" }
                return String(year)
            }
            groupCache = grouped.sorted { a, b in
                sortDirection.isAscending ? a.key < b.key : a.key > b.key
            }
        case .decade:
            let grouped = Dictionary(grouping: albums) { album -> String in
                guard let year = album.releaseDate?.year else { return "Unknown" }
                let decade = (year / 10) * 10
                return "\(decade)s"
            }
            groupCache = grouped.sorted { a, b in
                sortDirection.isAscending ? a.key < b.key : a.key > b.key
            }
        case .artist:
            let grouped = Dictionary(grouping: albums) { $0.artistName }
            groupCache = grouped.sorted { a, b in
                sortDirection.isAscending ? a.key < b.key : a.key > b.key
            }
        }
    }

    private func rebuildAvailableLetters() {
        availableLettersCache = albums.availableLetters
    }

    private func firstLetter(for text: String) -> String {
        StringUtils.firstLetter(of: text)
    }

    // MARK: - Data

    private func loadAlbums() async {
        do {
            let allAlbums = try await musicService.allLibraryAlbums()
            guard !Task.isCancelled else { return }
            albums = allAlbums
            hasMore = false
            isLoading = false
            loadError = nil
            rebuildGroups()
            rebuildDisplayCache()
        } catch {
            guard !Task.isCancelled else { return }
            loadError = error
            isLoading = false
        }
    }

    private func reloadAlbums() async {
        albums = []
        isLoading = true
        hasMore = false
        await loadAlbums()
    }
}

#Preview("Library Albums") {
    PreviewHost {
        NavigationStack {
            LibraryAlbumsView(isActive: true)
        }
    }
}
