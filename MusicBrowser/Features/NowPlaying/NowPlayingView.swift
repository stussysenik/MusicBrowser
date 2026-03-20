import SwiftUI
import MusicKit

struct NowPlayingView: View {
    @Environment(PlayerService.self) private var player
    @Environment(MusicService.self) private var musicService
    @Environment(StatsService.self) private var statsService
    @Environment(\.dismiss) private var dismiss

    @State private var isSeeking = false
    @State private var seekTime: TimeInterval = 0
    @State private var showQueue = false
    @State private var showLyrics = false
    @State private var recentSessions: [ListeningSession] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 16)
                    artwork
                    Spacer().frame(height: 32)
                    trackInfo
                    Spacer().frame(height: 24)
                    progressBar
                    Spacer().frame(height: 24)
                    controls
                    Spacer().frame(height: 16)
                    secondaryControls
                    Spacer().frame(height: 32)

                    if !recentSessions.isEmpty {
                        recentlyPlayedSection
                    }

                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 28)
            }
            .onAppear {
                recentSessions = statsService.recentSessions(limit: 20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        if player.hasLyrics {
                            Button { showLyrics = true } label: {
                                Image(systemName: "quote.bubble")
                            }
                        }
                        Button { showQueue = true } label: {
                            Image(systemName: "list.bullet")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
        }
        .sheet(isPresented: $showLyrics) {
            LyricsView()
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 560)
        #endif
    }

    // MARK: - Artwork

    private var artwork: some View {
        Group {
            if let art = player.currentArtwork {
                ArtworkImage(art, width: 280, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .frame(width: 280, height: 280)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 64))
                            .foregroundStyle(.tertiary)
                    }
            }
        }
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

    // MARK: - Recently Played

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recently Played")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(recentSessions, id: \.id) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(session.artistName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(session.startedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
            }
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
