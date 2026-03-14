import SwiftUI
import MusicKit

struct DiscoverView: View {
    @Environment(MusicService.self) private var musicService

    @State private var genres: [Genre] = []
    @State private var libraryGenreCounts: [String: Int] = [:]
    @State private var songsCount = 0
    @State private var albumsCount = 0
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var filteredGenres: [Genre] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return genres }
        return genres.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                counters

                NavigationLink {
                    BrowseView()
                } label: {
                    Label("Open Live Charts", systemImage: "chart.bar.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)

                genreSearchField

                if isLoading && genres.isEmpty {
                    ProgressView("Loading genres...")
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Discover Unavailable", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Retry") {
                            Task { await loadDiscover(force: true) }
                        }
                    }
                } else {
                    genreSection
                }
            }
            .padding()
        }
        .navigationTitle("Discover")
        .refreshable { await loadDiscover(force: true) }
        .task { await loadDiscover() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Genres")
                .font(.title.bold())
            Text("Browse as many genres as possible and see how your library is distributed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var counters: some View {
        HStack(spacing: 10) {
            counterCard(title: "Genres", value: genres.count)
            counterCard(title: "Songs", value: songsCount)
            counterCard(title: "Albums", value: albumsCount)
        }
    }

    private func counterCard(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var genreSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter genres", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var genreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All Genres (\(filteredGenres.count))")
                .font(.headline)

            LazyVStack(spacing: 6) {
                ForEach(filteredGenres, id: \.id) { genre in
                    HStack(spacing: 8) {
                        Text(genre.name)
                            .font(.body)
                            .lineLimit(1)
                        Spacer()
                        Text("\(libraryGenreCounts[genre.name, default: 0])")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1), in: Capsule())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func loadDiscover(force: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            async let genresTask = musicService.fetchGenres(limit: 300, force: force)
            async let statsTask = loadLibraryStats()

            genres = try await genresTask
            let stats = try await statsTask
            songsCount = stats.songsCount
            albumsCount = stats.albumsCount
            libraryGenreCounts = stats.genreCounts
        } catch {
            errorMessage = "Could not load genre data. Check Apple Music authorization and connectivity."
        }

        isLoading = false
    }

    private func loadLibraryStats() async throws -> (songsCount: Int, albumsCount: Int, genreCounts: [String: Int]) {
        let pageSize = 100

        var allSongCount = 0
        var songOffset = 0
        var genreCounts: [String: Int] = [:]

        while true {
            let response = try await musicService.librarySongs(limit: pageSize, offset: songOffset)
            let items = Array(response.items)
            allSongCount += items.count

            for song in items {
                for genre in song.genreNames {
                    genreCounts[genre, default: 0] += 1
                }
            }

            if items.count < pageSize { break }
            songOffset += pageSize
        }

        var allAlbumCount = 0
        var albumOffset = 0

        while true {
            let response = try await musicService.libraryAlbums(limit: pageSize, offset: albumOffset)
            let items = Array(response.items)
            allAlbumCount += items.count

            if items.count < pageSize { break }
            albumOffset += pageSize
        }

        return (allSongCount, allAlbumCount, genreCounts)
    }
}

#Preview("Discover") {
    PreviewHost {
        NavigationStack {
            DiscoverView()
        }
    }
}
