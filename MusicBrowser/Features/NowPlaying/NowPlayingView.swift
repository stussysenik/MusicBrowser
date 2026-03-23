import SwiftUI
import MusicKit

struct NowPlayingView: View {
    @Environment(PlayerService.self) private var player
    @Environment(MusicService.self) private var musicService
    @Environment(AnalysisService.self) private var analysis
    @Environment(\.dismiss) private var dismiss

    @State private var isSeeking = false
    @State private var seekTime: TimeInterval = 0
    @State private var showQueue = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                artwork
                Spacer().frame(height: 32)
                trackInfo
                Spacer().frame(height: 16)
                LiveBPMView(bpm: analysis.bpm(for: player.currentSongID?.rawValue ?? ""))
                Spacer().frame(height: 16)
                progressBar
                Spacer().frame(height: 24)
                controls
                Spacer().frame(height: 16)
                secondaryControls
                Spacer()
            }
            .padding(.horizontal, 28)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showQueue = true } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 560)
        #endif
    }

    // MARK: - Artwork

    private var artwork: some View {
        ArtworkView(artwork: player.currentArtwork, size: 280)
            .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
    }

    // MARK: - Track Info

    private var trackInfo: some View {
        VStack(spacing: 4) {
            Text(player.currentTitle ?? "Not Playing")
                .font(.title3.bold())
                .lineLimit(1)

            Text(player.currentArtist ?? "")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress

    private var progressBar: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { isSeeking ? seekTime : player.playbackTime },
                    set: { newVal in
                        isSeeking = true
                        seekTime = newVal
                    }
                ),
                in: 0...max(player.currentDuration, 1),
                onEditingChanged: { editing in
                    if !editing {
                        player.seek(to: seekTime)
                        isSeeking = false
                    }
                }
            )
            .tint(.primary)

            HStack {
                Text(formatDurationLong(isSeeking ? seekTime : player.playbackTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("-" + formatDurationLong(max(0, player.currentDuration - (isSeeking ? seekTime : player.playbackTime))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 40) {
            Button {
                Haptic.light()
                Task { try? await player.skipBackward() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
            }

            Button {
                Haptic.light()
                Task { try? await player.togglePlayPause() }
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
            }

            Button {
                Haptic.light()
                Task { try? await player.skipForward() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    // MARK: - Secondary Controls

    private var secondaryControls: some View {
        HStack(spacing: 32) {
            Button {
                Haptic.selection()
                player.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.body)
                    .foregroundStyle(player.shuffleIsOn ? .primary : .tertiary)
            }
            .buttonStyle(.plain)

            Button {
                Haptic.medium()
                Task { try? await player.playRandomSong(using: musicService) }
            } label: {
                Image(systemName: "dice")
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                Haptic.selection()
                player.cycleRepeat()
            } label: {
                Image(systemName: repeatIcon)
                    .font(.body)
                    .foregroundStyle(player.repeatMode != MusicKit.MusicPlayer.RepeatMode.none ? .primary : .tertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private var repeatIcon: String {
        switch player.repeatMode {
        case .one: return "repeat.1"
        case .all: return "repeat"
        default: return "repeat"
        }
    }
}

#Preview("Now Playing") {
    PreviewHost {
        NowPlayingView()
    }
}
