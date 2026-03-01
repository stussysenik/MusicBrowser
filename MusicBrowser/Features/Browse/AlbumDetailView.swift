import SwiftUI
import MusicKit

struct AlbumDetailView: View {
    let album: Album
    @Environment(MusicService.self) private var musicService
    @Environment(PlayerService.self) private var player

    @State private var detailedAlbum: Album?
    @State private var isLoading = true

    private var displayAlbum: Album { detailedAlbum ?? album }
    private var tracks: MusicItemCollection<Track>? { displayAlbum.tracks }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                controls
                trackList
            }
            .padding()
        }
        .navigationTitle(album.title)
        .navigationDestination(for: Song.self) { SongDetailView(song: $0) }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadDetail() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ArtworkView(artwork: displayAlbum.artwork, size: 220)
                .shadow(radius: 12, y: 6)

            Text(displayAlbum.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(displayAlbum.artistName)
                .font(.title3)
                .foregroundStyle(.secondary)

            if let releaseDate = displayAlbum.releaseDate {
                Text(releaseDate, format: .dateTime.year())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                Task { try? await player.playAlbum(displayAlbum) }
            } label: {
                Label("Play", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                Task {
                    player.toggleShuffle()
                    try? await player.playAlbum(displayAlbum)
                }
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    // MARK: - Track List

    @ViewBuilder
    private var trackList: some View {
        if isLoading {
            ProgressView()
                .padding(.top, 20)
        } else if let tracks, !tracks.isEmpty {
            LazyVStack(spacing: 0) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { idx, track in
                    HStack(spacing: 0) {
                        TrackRow(
                            title: track.title,
                            artistName: track.artistName,
                            artwork: nil,
                            duration: track.duration,
                            number: idx + 1
                        ) {
                            Task {
                                try? await player.playTracks(tracks, startingAt: idx)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    if idx < tracks.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        } else {
            Text("No tracks available")
                .foregroundStyle(.secondary)
                .padding(.top, 20)
        }
    }

    private func loadDetail() async {
        do {
            detailedAlbum = try await musicService.albumWithTracks(album)
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}

#Preview("Album Detail") {
    PreviewHost {
        PreviewLibraryItemContainer(
            title: "Album Preview",
            symbol: "square.stack",
            load: { await PreviewLibraryLoader.firstAlbum() }
        ) { album in
            NavigationStack {
                AlbumDetailView(album: album)
            }
        }
    }
}
