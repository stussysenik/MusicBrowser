import SwiftUI
import MusicKit

struct LibraryPlaylistsView: View {
    let isActive: Bool

    @Environment(MusicService.self) private var musicService
    @Environment(FilterPresetService.self) private var presetService

    @State private var playlists: [Playlist] = []
    @State private var isLoading = true
    @State private var hasMore = true
    @State private var loadError: Error?
    @State private var loadTask: Task<Void, Never>?
    @AppStorage("playlists.sortOption") private var sortOption: PlaylistSortOption = .name
    @AppStorage("playlists.sortDirection") private var sortDirection: SortDirection = .ascending
    @State private var sectionCache: [(String, [Playlist])] = []
    @State private var showCreatePlaylist = false
    @State private var newPlaylistName = ""

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

    private var letters: [String] {
        sectionCache.map(\.0)
    }

    var body: some View {
        Group {
            if isLoading && playlists.isEmpty {
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { _ in
                        SkeletonTrackRow()
                        Divider().padding(.leading, 68)
                    }
                    Spacer()
                }
            } else if let loadError, playlists.isEmpty {
                ContentUnavailableView {
                    Label("Unable to Load Playlists", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError.localizedDescription)
                } actions: {
                    Button("Retry") {
                        loadTask?.cancel()
                        loadTask = Task { await loadPlaylists() }
                    }
                    .buttonStyle(.bordered)
                }
            } else if playlists.isEmpty {
                ContentUnavailableView("No Playlists", systemImage: "music.note.list")
            } else {
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        if presetService.hasPinnedLetters(for: .playlists) {
                            PinnedLetterChipsBar(
                                pinnedLetters: presetService.pinnedLettersSet(for: .playlists),
                                onUnpin: { letter in
                                    withAnimation { presetService.unpinLetter(letter, for: .playlists) }
                                },
                                onClearAll: {
                                    withAnimation { presetService.clearPinnedLetters(for: .playlists) }
                                }
                            )
                        }

                        HStack(spacing: 0) {
                            List {
                                ForEach(sectionCache, id: \.0) { letter, groupedPlaylists in
                                    Section(letter) {
                                        ForEach(groupedPlaylists) { playlist in
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
                                            .id(playlist.id.rawValue)
                                        }
                                    }
                                    .id(letter)
                                }

                                if hasMore {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .listRowSeparator(.hidden)
                                        .symbolEffect(.pulse, options: .repeating)
                                        .task { await loadMore() }
                                }
                            }
                            .listStyle(.plain)

                            SectionIndexRail(
                                availableLetters: Set(letters),
                                pinnedLetters: presetService.pinnedLettersSet(for: .playlists),
                                onScrollTo: { letter in
                                    withAnimation(.snappy(duration: 0.2)) {
                                        proxy.scrollTo(letter, anchor: .top)
                                    }
                                },
                                onDoubleTap: { letter in
                                    withAnimation { presetService.togglePinnedLetter(letter, for: .playlists) }
                                }
                            )
                        }
                    }
                }
            }
        }
        .toolbar {
            if isActive {
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
                        Label("View Options", systemImage: "line.3.horizontal.decrease")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreatePlaylist = true
                    } label: {
                        Label("New Playlist", systemImage: "plus")
                    }
                }
            }
        }
        .alert("New Playlist", isPresented: $showCreatePlaylist) {
            TextField("Playlist Name", text: $newPlaylistName)
            Button("Cancel", role: .cancel) { newPlaylistName = "" }
            Button("Create") {
                let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
                newPlaylistName = ""
                guard !name.isEmpty else { return }
                Task {
                    do {
                        _ = try await musicService.createPlaylist(name: name)
                        Haptic.success()
                        await reloadPlaylists()
                    } catch {
                        loadError = error
                    }
                }
            }
        }
        .task { await loadPlaylists() }
        .onChange(of: sortOption) { _, _ in
            if sortOption == .name {
                loadTask?.cancel()
                loadTask = Task { await reloadPlaylists() }
            } else {
                rebuildSections()
            }
        }
        .onChange(of: sortDirection) { _, _ in
            if sortOption == .name {
                loadTask?.cancel()
                loadTask = Task { await reloadPlaylists() }
            } else {
                rebuildSections()
            }
        }
        .onChange(of: presetService.pinnedLetters) { old, new in
            let oldSet = old[.playlists] ?? []
            let newSet = new[.playlists] ?? []
            if oldSet != newSet { rebuildSections() }
        }
        .animation(.snappy(duration: 0.2), value: sectionCache.count)
    }

    private func rebuildSections() {
        let base = displayPlaylists

        let pinned = presetService.pinnedLettersSet(for: .playlists)
        let filtered: [Playlist]
        if pinned.isEmpty {
            filtered = base
        } else {
            filtered = base.filter { pinned.contains(firstLetter(for: $0.name)) }
        }

        let grouped = Dictionary(grouping: filtered) { firstLetter(for: $0.name) }
        sectionCache = grouped.sorted { a, b in
            if a.key == "#" { return false }
            if b.key == "#" { return true }
            return a.key < b.key
        }
    }

    private func firstLetter(for text: String) -> String {
        let first = text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1).uppercased()
        return first.rangeOfCharacter(from: .letters) != nil ? first : "#"
    }

    private func loadPlaylists() async {
        do {
            let response = try await musicService.libraryPlaylists(sort: sortOption, direction: sortDirection)
            guard !Task.isCancelled else { return }
            playlists = Array(response.items)
            hasMore = response.items.count == 100
            isLoading = false
            loadError = nil
            rebuildSections()
        } catch {
            guard !Task.isCancelled else { return }
            loadError = error
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
            guard !Task.isCancelled else { return }
            playlists.append(contentsOf: response.items)
            hasMore = response.items.count == 100
            isLoading = false
            rebuildSections()
        } catch {
            guard !Task.isCancelled else { return }
            isLoading = false
        }
    }
}

#Preview("Library Playlists") {
    PreviewHost {
        NavigationStack {
            LibraryPlaylistsView(isActive: true)
        }
    }
}
