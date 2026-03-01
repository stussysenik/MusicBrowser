import SwiftUI
import MusicKit

struct PlaylistDetailView: View {
    let playlist: Playlist
    @Environment(MusicService.self) private var musicService
    @Environment(PlayerService.self) private var player

    @State private var detailedPlaylist: Playlist?
    @State private var isLoading = true

    private var display: Playlist { detailedPlaylist ?? playlist }
    private var tracks: MusicItemCollection<Track>? { display.tracks }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                controls
                trackList
            }
            .padding()
        }
        .navigationTitle(playlist.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadDetail() }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ArtworkView(artwork: display.artwork, size: 200)
                .shadow(radius: 10, y: 4)

            Text(display.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            if let curator = display.curatorName {
                Text(curator)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let description = display.standardDescription {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                Task { try? await player.playPlaylist(display) }
            } label: {
                Label("Play", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                Task {
                    player.toggleShuffle()
                    try? await player.playPlaylist(display)
                }
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private var trackList: some View {
        if isLoading {
            ProgressView().padding(.top, 20)
        } else if let tracks, !tracks.isEmpty {
            LazyVStack(spacing: 0) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { idx, track in
                    TrackRow(
                        title: track.title,
                        artistName: track.artistName,
                        artwork: track.artwork,
                        duration: track.duration
                    ) {
                        Task {
                            try? await player.playTracks(tracks, startingAt: idx)
                        }
                    }
                    .padding(.vertical, 4)

                    if idx < tracks.count - 1 {
                        Divider().padding(.leading, 64)
                    }
                }
            }
        }
    }

    private func loadDetail() async {
        do {
            detailedPlaylist = try await musicService.playlistWithTracks(playlist)
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}
