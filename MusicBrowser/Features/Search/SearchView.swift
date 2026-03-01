import SwiftUI
import MusicKit

struct SearchView: View {
    @Environment(MusicService.self) private var musicService
    @Environment(PlayerService.self) private var player

    @State private var searchText = ""
    @State private var results: MusicCatalogSearchResponse?
    @State private var searchTask: Task<Void, Never>?
    @State private var searchError: Error?

    var body: some View {
        List {
            if let searchError, results == nil {
                ContentUnavailableView {
                    Label("Search Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Couldn't search Apple Music. Check your connection and try again.")
                } actions: {
                    Button("Retry") {
                        self.searchError = nil
                        let text = searchText
                        searchTask?.cancel()
                        searchTask = Task {
                            do {
                                results = try await musicService.search(text)
                            } catch {
                                self.searchError = error
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } else if let results {
                songResults(results)
                albumResults(results)
                artistResults(results)
                playlistResults(results)
            } else if searchText.isEmpty {
                ContentUnavailableView(
                    "Search Apple Music",
                    systemImage: "magnifyingglass",
                    description: Text("Find songs, albums, artists, and playlists.")
                )
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Artists, Songs, Albums")
        .navigationTitle("Search")
        .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
        .navigationDestination(for: Artist.self) { ArtistDetailView(artist: $0) }
        .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlist: $0) }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchError = nil
            guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                results = nil
                return
            }
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                do {
                    results = try await musicService.search(newValue)
                    searchError = nil
                } catch {
                    if !Task.isCancelled {
                        searchError = error
                    }
                }
            }
        }
    }

    // MARK: - Result Sections

    @ViewBuilder
    private func songResults(_ res: MusicCatalogSearchResponse) -> some View {
        if !res.songs.isEmpty {
            Section("Songs") {
                ForEach(res.songs.prefix(6)) { song in
                    TrackRow(
                        title: song.title,
                        artistName: song.artistName,
                        artwork: song.artwork,
                        duration: song.duration
                    ) {
                        Task { try? await player.playSong(song) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func albumResults(_ res: MusicCatalogSearchResponse) -> some View {
        if !res.albums.isEmpty {
            Section("Albums") {
                ForEach(res.albums.prefix(6)) { album in
                    NavigationLink(value: album) {
                        HStack(spacing: 12) {
                            ArtworkView(artwork: album.artwork, size: 50)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album.title).lineLimit(1)
                                Text(album.artistName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func artistResults(_ res: MusicCatalogSearchResponse) -> some View {
        if !res.artists.isEmpty {
            Section("Artists") {
                ForEach(res.artists.prefix(4)) { artist in
                    NavigationLink(value: artist) {
                        HStack(spacing: 12) {
                            ArtworkView(artwork: artist.artwork, size: 44)
                                .clipShape(Circle())
                            Text(artist.name)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func playlistResults(_ res: MusicCatalogSearchResponse) -> some View {
        if !res.playlists.isEmpty {
            Section("Playlists") {
                ForEach(res.playlists.prefix(4)) { playlist in
                    NavigationLink(value: playlist) {
                        HStack(spacing: 12) {
                            ArtworkView(artwork: playlist.artwork, size: 50)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name).lineLimit(1)
                                if let curator = playlist.curatorName {
                                    Text(curator)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
