import SwiftUI

struct QueueView: View {
    @Environment(PlayerService.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if player.playbackQueueItems.isEmpty {
                    ContentUnavailableView(
                        "Queue Empty",
                        systemImage: "list.bullet",
                        description: Text("Play something to see it here.")
                    )
                } else {
                    List {
                        if let current = player.currentPlaybackItem {
                            Section("Now Playing") {
                                queueRow(current, isCurrent: true)
                            }
                        }

                        let upcoming = player.upcomingPlaybackItems
                        if !upcoming.isEmpty {
                            Section("Up Next") {
                                ForEach(upcoming) { entry in
                                    queueRow(entry, isCurrent: false)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Queue")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func queueRow(_ entry: PlaybackQueueItem, isCurrent: Bool) -> some View {
        HStack(spacing: 12) {
            ArtworkView(artwork: entry.artwork, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(isCurrent ? .body.bold() : .body)
                    .lineLimit(1)
                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isCurrent && player.isPlaying {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .symbolEffect(.variableColor.iterative)
            }
        }
    }
}

#Preview("Queue") {
    PreviewHost {
        QueueView()
    }
}
