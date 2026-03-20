import SwiftUI
import MusicKit

struct LibraryArtistsView: View {
    let isActive: Bool

    @Environment(MusicService.self) private var musicService
    @Environment(FilterPresetService.self) private var presetService

    @State private var artists: [Artist] = []
    @State private var isLoading = true
    @State private var hasMore = true
    @State private var loadError: Error?
    @State private var loadTask: Task<Void, Never>?
    @AppStorage("artists.sortDirection") private var sortDirection: SortDirection = .ascending

    // Pre-computed section cache
    @State private var sectionCache: [(String, [Artist])] = []
    @State private var letterCache: [String] = []

    private func rebuildSections() {
        let source: [Artist]
        let pinned = presetService.pinnedLettersSet(for: .artists)
        if pinned.isEmpty {
            source = artists
        } else {
            source = artists.filter { artist in
                let first = artist.name.prefix(1).uppercased()
                let letter = first.rangeOfCharacter(from: .letters) != nil ? first : "#"
                return pinned.contains(letter)
            }
        }

        let grouped = Dictionary(grouping: source) { artist -> String in
            let first = artist.name.prefix(1).uppercased()
            return first.rangeOfCharacter(from: .letters) != nil ? first : "#"
        }
        sectionCache = grouped.sorted { a, b in
            if a.key == "#" { return !sortDirection.isAscending }
            if b.key == "#" { return sortDirection.isAscending }
            return sortDirection.isAscending ? a.key < b.key : a.key > b.key
        }
        letterCache = Dictionary(grouping: artists) { artist -> String in
            let first = artist.name.prefix(1).uppercased()
            return first.rangeOfCharacter(from: .letters) != nil ? first : "#"
        }.keys.sorted()
    }

    var body: some View {
        Group {
            if isLoading && artists.isEmpty {
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { _ in
                        SkeletonTrackRow()
                        Divider().padding(.leading, 68)
                    }
                    Spacer()
                }
            } else if let loadError, artists.isEmpty {
                ContentUnavailableView {
                    Label("Unable to Load Artists", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError.localizedDescription)
                } actions: {
                    Button("Retry") {
                        loadTask?.cancel()
                        loadTask = Task { await loadArtists() }
                    }
                    .buttonStyle(.bordered)
                }
            } else if artists.isEmpty {
                ContentUnavailableView("No Artists", systemImage: "person.2")
            } else {
                artistListContent
            }
        }
        .toolbar {
            if isActive {
                ToolbarItem(placement: .automatic) {
                    Button {
                        sortDirection.toggle()
                        Task { await reloadArtists() }
                    } label: {
                        Label(
                            sortDirection.isAscending ? "A → Z" : "Z → A",
                            systemImage: sortDirection.systemImage
                        )
                    }
                }
            }
        }
        .task { await loadArtists() }
        .onChange(of: presetService.pinnedLetters) { old, new in
            let oldSet = old[.artists] ?? []
            let newSet = new[.artists] ?? []
            if oldSet != newSet { rebuildSections() }
        }
    }

    private var artistListContent: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if presetService.hasPinnedLetters(for: .artists) {
                    PinnedLetterChipsBar(
                        pinnedLetters: presetService.pinnedLettersSet(for: .artists),
                        onUnpin: { letter in
                            withAnimation { presetService.unpinLetter(letter, for: .artists) }
                        },
                        onClearAll: {
                            withAnimation { presetService.clearPinnedLetters(for: .artists) }
                        }
                    )
                }

                HStack(spacing: 0) {
                    artistList

                    SectionIndexRail(
                        availableLetters: Set(letterCache),
                        pinnedLetters: presetService.pinnedLettersSet(for: .artists),
                        onScrollTo: { letter in
                            withAnimation(.snappy(duration: 0.2)) {
                                proxy.scrollTo(letter, anchor: .top)
                            }
                        },
                        onDoubleTap: { letter in
                            withAnimation { presetService.togglePinnedLetter(letter, for: .artists) }
                        }
                    )
                }
            }
        }
    }

    private var artistList: some View {
        List {
            ForEach(sectionCache, id: \.0) { letter, sectionArtists in
                Section(header: Text(letter)) {
                    ForEach(sectionArtists) { artist in
                        artistRow(artist)
                    }
                }
                .id(letter)
            }

            if hasMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .task { await loadMore() }
            }
        }
        .listStyle(.plain)
    }

    private func artistRow(_ artist: Artist) -> some View {
        NavigationLink(value: artist) {
            HStack(spacing: 12) {
                ArtworkView(artwork: artist.artwork, size: 44)
                    .clipShape(Circle())
                Text(artist.name)
            }
        }
    }

    private func loadArtists() async {
        do {
            let response = try await musicService.libraryArtists(direction: sortDirection)
            guard !Task.isCancelled else { return }
            artists = Array(response.items)
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

    private func reloadArtists() async {
        artists = []
        isLoading = true
        hasMore = true
        await loadArtists()
    }

    private func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        do {
            let response = try await musicService.libraryArtists(
                offset: artists.count,
                direction: sortDirection
            )
            guard !Task.isCancelled else { return }
            artists.append(contentsOf: response.items)
            hasMore = response.items.count == 100
            isLoading = false
            rebuildSections()
        } catch {
            guard !Task.isCancelled else { return }
            isLoading = false
        }
    }
}

#Preview("Library Artists") {
    PreviewHost {
        NavigationStack {
            LibraryArtistsView(isActive: true)
        }
    }
}
