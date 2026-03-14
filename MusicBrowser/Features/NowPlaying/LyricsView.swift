import SwiftUI
import MusicKit

struct LyricsView: View {
    @Environment(PlayerService.self) private var player
    @Environment(LyricsService.self) private var lyricsService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if lyricsService.isLoading {
                    ProgressView("Loading lyrics...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let lines = lyricsService.currentLyrics, !lines.isEmpty {
                    syncedLyricsView(lines)
                } else if lyricsService.loadError != nil {
                    fallbackView
                } else {
                    fallbackView
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationTitle(player.currentTitle ?? "Lyrics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .task {
            if let songID = player.currentSongID {
                await lyricsService.fetchLyrics(for: songID)
            }
        }
    }

    private func syncedLyricsView(_ lines: [LyricsService.LyricLine]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { idx, line in
                        let isCurrent = isCurrentLine(line, lines: lines, index: idx)
                        Text(line.text)
                            .font(isCurrent ? .title3.bold() : .title3)
                            .foregroundStyle(isCurrent ? .primary : .secondary)
                            .opacity(isCurrent ? 1.0 : 0.6)
                            .id(line.id)
                            .animation(.easeInOut(duration: 0.3), value: isCurrent)
                    }
                }
                .padding()
            }
            .onChange(of: currentLineIndex(lines)) { _, newIndex in
                guard let newIndex, newIndex < lines.count else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(lines[newIndex].id, anchor: .center)
                }
            }
        }
    }

    private var fallbackView: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func isCurrentLine(_ line: LyricsService.LyricLine, lines: [LyricsService.LyricLine], index: Int) -> Bool {
        guard let start = line.startTime else { return false }
        let time = player.playbackTime
        let end = line.endTime ?? lines[safe: index + 1]?.startTime ?? (start + 5)
        return time >= start && time < end
    }

    private func currentLineIndex(_ lines: [LyricsService.LyricLine]) -> Int? {
        let time = player.playbackTime
        return lines.lastIndex { line in
            guard let start = line.startTime else { return false }
            return time >= start
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
