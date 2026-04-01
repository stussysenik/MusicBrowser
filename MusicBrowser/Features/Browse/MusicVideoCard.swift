import SwiftUI
import MusicKit

struct MusicVideoCard: View {
    let video: MusicVideo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                ArtworkView(artwork: video.artwork, size: 180)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .bottomTrailing) {
                        if let duration = video.duration {
                            Text(formatDuration(duration))
                                .font(.caption2.monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(6)
                        }
                    }

                Text(video.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                Text(video.artistName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 180)
        }
        .buttonStyle(.plain)
    }
}
