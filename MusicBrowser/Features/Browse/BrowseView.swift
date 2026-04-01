import SwiftUI
import MusicKit

struct BrowseView: View {
    @Environment(MusicService.self) private var musicService
    @Environment(PlayerService.self) private var player

    @State private var songChart: MusicCatalogChart<Song>?
    @State private var albumChart: MusicCatalogChart<Album>?
    @State private var playlistChart: MusicCatalogChart<Playlist>?
    @State private var musicVideos: [MusicVideo] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var error: Error?

    private let cardSize: CGFloat = 160

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else if error != nil {
                ContentUnavailableView {
                    Label("Browse Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Charts require an Apple Music subscription and connectivity. Try the Library tab.")
                } actions: {
                    Button("Retry") {
                        Task { await loadCharts(force: true) }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                LazyVStack(alignment: .leading, spacing: 28) {
                    if let songChart, !songChart.items.isEmpty {
                        topSongsSection(songChart)
                    }
                    if let albumChart, !albumChart.items.isEmpty {
                        horizontalSection("Top Albums") {
                            ForEach(albumChart.items) { album in
                                NavigationLink(value: album) {
                                    AlbumCard(album, size: cardSize)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if let playlistChart, !playlistChart.items.isEmpty {
                        horizontalSection("Top Playlists") {
                            ForEach(playlistChart.items) { playlist in
                                NavigationLink(value: playlist) {
                                    AlbumCard(playlist, size: cardSize)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if !musicVideos.isEmpty {
                        horizontalSection("Music Videos") {
                            ForEach(musicVideos) { video in
                                MusicVideoCard(video: video) {
                                    player.openMusicVideo(video)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Browse")
        .navigationDestination(for: Album.self) { album in
            AlbumDetailView(album: album)
        }
        .navigationDestination(for: Playlist.self) { playlist in
            PlaylistDetailView(playlist: playlist)
        }
        .navigationDestination(for: Artist.self) { artist in
            ArtistDetailView(artist: artist)
        }
        .refreshable { await loadCharts(force: true) }
        .task { await loadCharts() }
    }

    // MARK: - Sections

    @ViewBuilder
    private func topSongsSection(_ chart: MusicCatalogChart<Song>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chart.title)
                .font(.title2.bold())
                .padding(.horizontal)

            LazyVStack(spacing: 0) {
                ForEach(Array(chart.items.prefix(10).enumerated()), id: \.element.id) { idx, song in
                    TrackRow(
                        title: song.title,
                        artistName: song.artistName,
                        artwork: song.artwork,
                        duration: song.duration
                    ) {
                        Task { try? await player.playSong(song) }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)

                    if idx < min(chart.items.count, 10) - 1 {
                        Divider().padding(.leading, 72)
                    }
                }
            }
        }
    }

    private func horizontalSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    content()
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Data Loading

    private func loadCharts(force: Bool = false) async {
        guard !hasLoaded || force else { return }
        isLoading = true
        do {
            let response = try await musicService.fetchCharts(force: force)
            songChart = response.songCharts.first
            albumChart = response.albumCharts.first
            playlistChart = response.playlistCharts.first
            if let videoChart = response.musicVideoCharts.first {
                musicVideos = Array(videoChart.items)
            }
            error = nil
        } catch {
            self.error = error
        }
        isLoading = false
        hasLoaded = true
    }
}

#Preview("Browse") {
    PreviewHost {
        NavigationStack {
            BrowseView()
        }
    }
}
