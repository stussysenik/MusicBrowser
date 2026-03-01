import SwiftUI
import MusicKit

struct LibraryPlaylistsView: View {
    @Environment(MusicService.self) private var musicService

    @State private var playlists: [Playlist] = []
    @State private var isLoading = true
    @State private var hasMore = true
    @State private var sortOption: PlaylistSortOption = .name
    @State private var sortDirection: SortDirection = .ascending

    private var displayPlaylists: [Playlist] {
        var result = playlists
        if sortOption == .dateModified {
            result.sort { a, b in
                let dA = a.lastModifiedDate ?? .distantPast
                let dB = b.lastModifiedDate ?? .distantPast
                return sortDirection.isAscending ? dA < dB : dA > dB
            }
        } else if sortOption == .lastPlayed {
            result.sort { a, b in
                let dA = a.lastPlayedDate ?? .distantPast
                let dB = b.lastPlayedDate ?? .distantPast
                return sortDirection.isAscending ? dA < dB : dA > dB
            }
        }
        return result
    }

    var body: some View {
        Group {
            if isLoading && playlists.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if playlists.isEmpty {
                ContentUnavailableView("No Playlists", systemImage: "music.note.list")
            } else {
                List {
                    ForEach(Array(displayPlaylists.enumerated()), id: \.element.id) { idx, playlist in
                        NavigationLink(value: playlist) {
                            HStack(spacing: 12) {
                                ArtworkView(artwork: playlist.artwork, size: 56)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name)
                                        .lineLimit(1)
                                    if let curator = playlist.curatorName {
                                        Text(curator)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .task {
                            if idx == displayPlaylists.count - 5 { await loadMore() }
                        }
                    }

                    if hasMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Section("Sort By") {
                        Picker("Sort", selection: $sortOption) {
                            ForEach(PlaylistSortOption.allCases, id: \.self) { option in
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
                } label: {
                    Label("View Options", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .task { await loadPlaylists() }
        .onChange(of: sortOption) { _, _ in
            if sortOption == .name {
                Task { await reloadPlaylists() }
            }
        }
        .onChange(of: sortDirection) { _, _ in
            if sortOption == .name {
                Task { await reloadPlaylists() }
            }
        }
    }

    private func loadPlaylists() async {
        do {
            let response = try await musicService.libraryPlaylists(sort: sortOption, direction: sortDirection)
            playlists = Array(response.items)
            hasMore = response.items.count == 100
            isLoading = false
        } catch {
            isLoading = false
        }
    }

    private func reloadPlaylists() async {
        playlists = []
        isLoading = true
        hasMore = true
        await loadPlaylists()
    }

    private func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        do {
            let response = try await musicService.libraryPlaylists(
                offset: playlists.count,
                sort: sortOption,
                direction: sortDirection
            )
            playlists.append(contentsOf: response.items)
            hasMore = response.items.count == 100
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}
