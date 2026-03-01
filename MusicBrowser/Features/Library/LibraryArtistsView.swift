import SwiftUI
import MusicKit

struct LibraryArtistsView: View {
    @Environment(MusicService.self) private var musicService

    @State private var artists: [Artist] = []
    @State private var isLoading = true
    @State private var hasMore = true
    @State private var sortDirection: SortDirection = .ascending

    // Pre-computed section cache
    @State private var sectionCache: [(String, [Artist])] = []
    @State private var letterCache: [String] = []

    private func rebuildSections() {
        let grouped = Dictionary(grouping: artists) { artist -> String in
            let first = artist.name.prefix(1).uppercased()
            return first.rangeOfCharacter(from: .letters) != nil ? first : "#"
        }
        sectionCache = grouped.sorted { a, b in
            if a.key == "#" { return !sortDirection.isAscending }
            if b.key == "#" { return sortDirection.isAscending }
            return sortDirection.isAscending ? a.key < b.key : a.key > b.key
        }
        letterCache = sectionCache.map(\.0)
    }

    var body: some View {
        Group {
            if isLoading && artists.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if artists.isEmpty {
                ContentUnavailableView("No Artists", systemImage: "person.2")
            } else {
                artistListContent
            }
        }
        .toolbar {
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
        .task { await loadArtists() }
    }

    private var artistListContent: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                artistList
                alphabeticIndex(proxy: proxy)
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

    @ViewBuilder
    private func alphabeticIndex(proxy: ScrollViewProxy) -> some View {
        if letterCache.count > 3 {
            VStack(spacing: 2) {
                ForEach(letterCache, id: \.self) { letter in
                    Button {
                        withAnimation { proxy.scrollTo(letter, anchor: .top) }
                    } label: {
                        Text(letter)
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.trailing, 4)
            .foregroundStyle(.tint)
        }
    }

    private func loadArtists() async {
        do {
            let response = try await musicService.libraryArtists(direction: sortDirection)
            artists = Array(response.items)
            hasMore = response.items.count == 100
            isLoading = false
            rebuildSections()
        } catch {
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
            artists.append(contentsOf: response.items)
            hasMore = response.items.count == 100
            isLoading = false
            rebuildSections()
        } catch {
            isLoading = false
        }
    }
}

#Preview("Library Artists") {
    PreviewHost {
        NavigationStack {
            LibraryArtistsView()
        }
    }
}
