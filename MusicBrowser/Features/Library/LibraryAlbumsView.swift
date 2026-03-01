import SwiftUI
import MusicKit

struct LibraryAlbumsView: View {
    @Environment(MusicService.self) private var musicService

    @State private var albums: [Album] = []
    @State private var isLoading = true
    @State private var hasMore = true
    @State private var sortOption: AlbumSortOption = .title
    @State private var sortDirection: SortDirection = .ascending
    @State private var grouping: AlbumGrouping = .none

    // Pre-computed group cache
    @State private var groupCache: [(String, [Album])] = []

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        Group {
            if isLoading && albums.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if albums.isEmpty {
                ContentUnavailableView("No Albums", systemImage: "square.stack")
            } else if grouping != .none {
                groupedView
            } else {
                flatGridView
            }
        }
        .toolbar {
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
                    Label("View Options", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .task { await loadAlbums() }
        .onChange(of: sortOption) { _, _ in Task { await reloadAlbums() } }
        .onChange(of: sortDirection) { _, _ in Task { await reloadAlbums() } }
        .onChange(of: grouping) { _, _ in rebuildGroups() }
    }

    // MARK: - Views

    private var flatGridView: some View {
        ScrollView {
            HStack {
                Text("\(albums.count) albums")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(Array(albums.enumerated()), id: \.element.id) { idx, album in
                    NavigationLink(value: album) {
                        AlbumCard(album, size: 160)
                    }
                    .buttonStyle(.plain)
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
        let cal = Calendar.current
        switch grouping {
        case .none:
            groupCache = []
        case .year:
            let grouped = Dictionary(grouping: albums) { album -> String in
                guard let date = album.releaseDate else { return "Unknown" }
                return String(cal.component(.year, from: date))
            }
            groupCache = grouped.sorted { a, b in
                sortDirection.isAscending ? a.key < b.key : a.key > b.key
            }
        case .decade:
            let grouped = Dictionary(grouping: albums) { album -> String in
                guard let date = album.releaseDate else { return "Unknown" }
                let year = cal.component(.year, from: date)
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

    // MARK: - Data

    private func loadAlbums() async {
        do {
            let response = try await musicService.libraryAlbums(sort: sortOption, direction: sortDirection)
            albums = Array(response.items)
            hasMore = response.items.count == 100
            isLoading = false
            rebuildGroups()
        } catch {
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
            albums.append(contentsOf: response.items)
            hasMore = response.items.count == 100
            isLoading = false
            rebuildGroups()
        } catch {
            isLoading = false
        }
    }
}

#Preview("Library Albums") {
    PreviewHost {
        NavigationStack {
            LibraryAlbumsView()
        }
    }
}
