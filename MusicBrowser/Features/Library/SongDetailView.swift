import SwiftUI
import MusicKit

struct SongDetailView: View {
    let song: Song
    @Environment(PlayerService.self) private var player
    @Environment(AnalysisService.self) private var analysisService

    @State private var isSeeking = false
    @State private var seekTime: TimeInterval = 0

    private var isCurrentSong: Bool {
        player.currentSongID == song.id
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                artworkSection
                titleSection
                actionButtons
                if isCurrentSong {
                    progressBar
                    playbackControls
                }
                metadataGrid
                lyricsIndicator
            }
            .padding()
        }
        .navigationTitle(song.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Artwork

    private var artworkSection: some View {
        Group {
            if let art = song.artwork {
                ArtworkImage(art, width: 280, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
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

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 4) {
            Text(song.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(song.artistName)
                .font(.title3)
                .foregroundStyle(.secondary)

            if let albumTitle = song.albumTitle {
                Text(albumTitle)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                Task { try? await player.playSong(song) }
            } label: {
                Label(isCurrentSong && player.isPlaying ? "Playing" : "Play", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                Task { try? await player.playNext(song) }
            } label: {
                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                Task { try? await player.addToQueue(song) }
            } label: {
                Label("Queue", systemImage: "text.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    // MARK: - Progress Bar (live when this song is playing)

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
            .tint(.accentColor)

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
        .padding(.horizontal, 4)
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 40) {
            Button {
                Task { try? await player.skipBackward() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }

            Button {
                Task { try? await player.togglePlayPause() }
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 50))
            }

            Button {
                Task { try? await player.skipForward() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    // MARK: - Metadata Grid

    private var metadataGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
        ], spacing: 16) {
            if let duration = song.duration {
                metadataCell("Duration", value: formatDurationLong(duration), icon: "clock")
            }

            if !song.genreNames.isEmpty {
                metadataCell("Genre", value: song.genreNames.joined(separator: ", "), icon: "guitars")
            }

            if let releaseDate = song.releaseDate {
                metadataCell("Released", value: releaseDate.formatted(.dateTime.year().month().day()), icon: "calendar")
            }

            if let playCount = song.playCount {
                metadataCell("Play Count", value: "\(playCount)", icon: "play.circle")
            }

            if let lastPlayed = song.lastPlayedDate {
                metadataCell("Last Played", value: lastPlayed.formatted(.relative(presentation: .named)), icon: "clock.arrow.circlepath")
            }

            if let bpm = analysisService.bpm(for: song) {
                metadataCell("BPM", value: "\(Int(bpm))", icon: "metronome")
            }
        }
        .padding(.top, 8)
    }

    private func metadataCell(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.callout)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Lyrics Indicator

    @ViewBuilder
    private var lyricsIndicator: some View {
        if song.hasLyrics {
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .foregroundStyle(.secondary)
                Text("Lyrics Available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let lyricsURL = URL(string: "music://music.apple.com/song/\(song.id.rawValue)") {
                    Link(destination: lyricsURL) {
                        Label("Open in Apple Music", systemImage: "arrow.up.right")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

#Preview("Song Detail") {
    PreviewHost {
        PreviewLibraryItemContainer(
            title: "Song Preview",
            symbol: "music.note",
            load: { await PreviewLibraryLoader.firstSong() }
        ) { song in
            NavigationStack {
                SongDetailView(song: song)
            }
        }
    }
}
