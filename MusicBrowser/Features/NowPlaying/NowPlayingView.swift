import SwiftUI
import MusicKit

struct NowPlayingView: View {
    @Environment(PlayerService.self) private var player
    @Environment(\.dismiss) private var dismiss

    @State private var isSeeking = false
    @State private var seekTime: TimeInterval = 0
    @State private var showQueue = false
    @State private var showLyrics = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                artwork
                Spacer().frame(height: 32)
                trackInfo
                Spacer().frame(height: 24)
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
            lyricsSheet
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
                Task { try? await player.skipBackward() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
            }

            Button {
                Task { try? await player.togglePlayPause() }
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
            }

            Button {
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
            Button { player.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.body)
                    .foregroundStyle(player.shuffleIsOn ? .primary : .tertiary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button { player.cycleRepeat() } label: {
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

    // MARK: - Lyrics Sheet

    private var lyricsSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if player.hasLyrics {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Lyrics")
                                .font(.largeTitle.bold())
                                .padding(.horizontal)

                            Text(player.currentTitle ?? "")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            // MusicKit doesn't expose lyrics content via public API
                            // Show availability indicator + prompt to use Apple Music
                            VStack(spacing: 12) {
                                Image(systemName: "text.quote")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.tertiary)

                                Text("Lyrics available in Apple Music")
                                    .font(.headline)

                                Text("Open this song in Apple Music to view synced lyrics.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)

                                if let songID = player.currentSongID {
                                    Link(destination: URL(string: "music://music.apple.com/song/\(songID.rawValue)")!) {
                                        Label("Open in Apple Music", systemImage: "arrow.up.right")
                                    }
                                    .buttonStyle(.bordered)
                                    .padding(.top, 8)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }
                        .padding(.vertical)
                    }
                } else {
                    ContentUnavailableView(
                        "No Lyrics",
                        systemImage: "text.quote",
                        description: Text("Lyrics are not available for this song.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showLyrics = false }
                }
            }
        }
    }
}
