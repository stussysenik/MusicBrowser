import SwiftUI
import MusicKit

struct TrackRow: View {
    let title: String
    let artistName: String
    let artwork: Artwork?
    let duration: TimeInterval?
    var number: Int? = nil
    var bpm: Double? = nil
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let number {
                    Text("\(number)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
                } else {
                    ArtworkView(artwork: artwork, size: 44)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .lineLimit(1)
                    Text(artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let bpm {
                    BPMBadgeView(bpm: bpm)
                }

                if let duration {
                    Text(formatDuration(duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Track Row") {
    TrackRow(
        title: "Sample Song",
        artistName: "Sample Artist",
        artwork: nil,
        duration: 198,
        number: 1
    ) {}
    .padding()
}
