import SwiftUI
import MusicKit

struct LibraryAlbumsView: View {
    let isActive: Bool

    @Environment(MusicService.self) private var musicService

    @State private var albums: [Album] = []
    @State private var isLoading = true
    @State private var hasMore = true
    @State private var loadError: Error?
    @State private var loadTask: Task<Void, Never>?
    @State private var sortOption: AlbumSortOption = .title
    @State private var sortDirection: SortDirection = .ascending
    @State private var grouping: AlbumGrouping = .none

    // Pre-computed group cache
    @State private var groupCache: [(String, [Album])] = []

    // Cached derived values
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
        .animation(.snappy(duration: 0.2), value: albums.count)
    }

    // MARK: - Views

    private var flatGridView: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 8) {
                        HStack {
                            Text("\(albums.count) albums")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("albums-top")

                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(Array(albums.enumerated()), id: \.element.id) { idx, album in
                                NavigationLink(value: album) {
                                    AlbumCard(album, size: 160)
                                }
                                .buttonStyle(.plain)
                                .id(album.id.rawValue)
                                .task {
                                    if idx == albums.count - 5 { await loadMore() }
                                }
                            }
                        }
                        .padding()

                        if hasMore {
                            ProgressView().padding()
                        }
                    }
                }

                SectionIndexRail(
                    availableLetters: Set(availableLettersCache),
                    onScrollTo: { letter in
                        if let firstMatch = albums.first(where: { firstLetter(for: $0.title) == letter }) {
                            withAnimation(.snappy(duration: 0.2)) {
                                proxy.scrollTo(firstMatch.id.rawValue, anchor: .top)
                            }
                        }
                    }
                )
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

                if hasMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .task { await loadMore() }
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
            let response = try await musicService.libraryAlbums(sort: sortOption, direction: sortDirection)
            guard !Task.isCancelled else { return }
            albums = Array(response.items)
            hasMore = response.items.count == 100
            isLoading = false
            loadError = nil
            rebuildGroups()
            rebuildAvailableLetters()
        } catch {
            guard !Task.isCancelled else { return }
            loadError = error
            isLoading = false
        }
    }

    private func reloadAlbums() async {
        albums = []
        isLoading = true
        hasMore = true
        await loadAlbums()
    }

    private func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        do {
            let response = try await musicService.libraryAlbums(
                offset: albums.count,
                sort: sortOption,
                direction: sortDirection
            )
            guard !Task.isCancelled else { return }
            albums.append(contentsOf: response.items)
            hasMore = response.items.count == 100
            isLoading = false
            rebuildGroups()
            rebuildAvailableLetters()
        } catch {
            guard !Task.isCancelled else { return }
            isLoading = false
        }
    }
}

#Preview("Library Albums") {
    PreviewHost {
        NavigationStack {
            LibraryAlbumsView(isActive: true)
        }
    }
}
