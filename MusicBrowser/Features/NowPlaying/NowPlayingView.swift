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
    @State private var skipFeedback: SkipDirection?
    @State private var addToPlaylistSong: Song?
    @State private var addToPlaylistDemoSong: DemoSong?

    private enum SkipDirection {
        case backward, forward
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    artwork
                    trackInfo
                    LiveBPMView(bpm: analysis.bpm(for: player.currentTrackID ?? ""))
                    progressBar
                    controls
                    secondaryControls

                    if !player.playbackQueueItems.isEmpty {
                        ListeningPathView(
                            items: player.playbackQueueItems,
                            currentIndex: player.currentPlaybackIndex,
                            isPlaying: player.isPlaying
                        )
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
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
        .sheet(item: $addToPlaylistSong) { song in
            AddToPlaylistSheet(songs: [song])
        }
        .sheet(item: $addToPlaylistDemoSong) { song in
            DemoAddToPlaylistSheet(songs: [song])
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 560)
        #endif
    }

    // MARK: - Artwork

    private var artwork: some View {
        ZStack {
            if let demoSong = player.currentDemoSong, player.currentArtwork == nil {
                DemoArtworkTile(title: demoSong.title)
            } else {
                ArtworkView(artwork: player.currentArtwork, size: 280)
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
            }

            HStack(spacing: 0) {
                skipZone(.backward)
                skipZone(.forward)
            }

            if let feedback = skipFeedback {
                Image(systemName: feedback == .forward ? "forward.fill" : "backward.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: feedback == .forward ? .trailing : .leading)
                    .padding(.horizontal, 40)
                    .transition(.opacity)
                    .accessibilityLabel(feedback == .forward ? "Skipping forward" : "Skipping backward")
            }
        }
        .frame(maxWidth: 320)
        .aspectRatio(1, contentMode: .fit)
        .animation(.easeInOut(duration: 0.15), value: skipFeedback != nil)
    }

    private func skipZone(_ direction: SkipDirection) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                Haptic.light()
                skipFeedback = direction
                Task {
                    switch direction {
                    case .backward: try? await player.skipBackward()
                    case .forward: try? await player.skipForward()
                    }
                    try? await Task.sleep(for: .milliseconds(600))
                    skipFeedback = nil
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
            .accessibilityIdentifier("now-playing-skip-backward")

            Button {
                Haptic.light()
                Task { try? await player.togglePlayPause() }
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
            }
            .accessibilityIdentifier("now-playing-play-pause")

            Button {
                Haptic.light()
                Task { try? await player.skipForward() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
            }
            .accessibilityIdentifier("now-playing-skip-forward")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    // MARK: - Secondary Controls

    private var secondaryControls: some View {
        HStack(spacing: 16) {
            secondaryControlButton(
                title: "Playlist",
                systemImage: "music.note.list",
                isActive: player.currentSong != nil || player.currentDemoSong != nil,
                isDisabled: player.currentSong == nil && player.currentDemoSong == nil
            ) {
                Haptic.medium()
                if let song = player.currentSong {
                    addToPlaylistSong = song
                } else {
                    addToPlaylistDemoSong = player.currentDemoSong
                }
            }

            secondaryControlButton(
                title: "Shuffle",
                systemImage: "shuffle",
                isActive: player.shuffleIsOn
            ) {
                Haptic.selection()
                player.toggleShuffle()
            }

            secondaryControlButton(
                title: "Fresh Mix",
                systemImage: "dice",
                isActive: true
            ) {
                Haptic.medium()
                Task { try? await player.playRandomSong(using: musicService) }
            }

            secondaryControlButton(
                title: "Repeat",
                systemImage: repeatIcon,
                isActive: player.repeatMode != MusicKit.MusicPlayer.RepeatMode.none
            ) {
                Haptic.selection()
                player.cycleRepeat()
            }
        }
    }

    @ViewBuilder
    private func secondaryControlButton(
        title: String,
        systemImage: String,
        isActive: Bool,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.body)
                    .foregroundStyle(isActive ? .primary : .tertiary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityIdentifier("now-playing-action-\(title.replacingOccurrences(of: " ", with: "-").lowercased())")
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
