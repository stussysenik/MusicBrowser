import SwiftUI
import MusicKit

struct MiniPlayerView: View {
    @Environment(PlayerService.self) private var player
    @Binding var showNowPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Left side: tappable to open NowPlaying
            Button {
                showNowPlaying = true
            } label: {
                HStack(spacing: 12) {
                    if let demoSong = player.currentDemoSong, player.currentArtwork == nil {
                        DemoArtworkTile(title: demoSong.title)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        ArtworkView(artwork: player.currentArtwork, size: 44)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.currentTitle ?? "Not Playing")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(player.currentArtist ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mini-player-open")

            Spacer()

            // Transport controls — independent siblings, not nested inside the expand button
            Button {
                Task { try? await player.skipBackward() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.callout)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mini-player-skip-backward")

            Button {
                Task { try? await player.togglePlayPause() }
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mini-player-play-pause")

            Button {
                Task { try? await player.skipForward() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.callout)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mini-player-skip-forward")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .padding(.horizontal, 8)
    }
}

#Preview("Mini Player") {
    PreviewHost {
        MiniPlayerView(showNowPlaying: .constant(false))
            .padding()
    }
}
