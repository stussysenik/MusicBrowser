import SwiftUI
import MusicKit

struct ListeningPathView: View {
    let items: [PlaybackQueueItem]
    let currentIndex: Int?
    let isPlaying: Bool

    private var visibleItems: [PlaybackQueueItem] {
        guard !items.isEmpty else { return [] }
        guard let currentIndex else { return Array(items.prefix(4)) }

        let start = max(0, currentIndex - 1)
        let end = min(items.count - 1, currentIndex + 3)
        return Array(items[start...end])
    }

    private var hiddenCount: Int {
        max(0, items.count - visibleItems.count)
    }

    var body: some View {
        if !visibleItems.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stay With The Music")
                            .font(.headline)
                        Text("See what led here and what is already lined up next.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Label("\(items.count)", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(visibleItems.enumerated()), id: \.element.id) { visibleIndex, item in
                            let role = role(for: item, visibleIndex: visibleIndex)
                            ListeningPathNode(entry: item, role: role, isPlaying: isPlaying)

                            if visibleIndex < visibleItems.count - 1 {
                                Capsule()
                                    .fill(role.connector.opacity(0.35))
                                    .frame(width: 28, height: 3)
                            }
                        }

                        if hiddenCount > 0 {
                            Label("+\(hiddenCount)", systemImage: "ellipsis")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(.thinMaterial, in: Capsule())
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
        }
    }

    private func role(for item: PlaybackQueueItem, visibleIndex: Int) -> ListeningPathNode.Role {
        guard let currentIndex else {
            return visibleIndex == 0 ? .nowPlaying : .upNext
        }

        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return .upNext
        }

        if itemIndex < currentIndex {
            return .recent
        }
        if itemIndex == currentIndex {
            return .nowPlaying
        }
        return itemIndex == currentIndex + 1 ? .upNext : .later
    }
}

private struct ListeningPathNode: View {
    enum Role: Equatable {
        case recent
        case nowPlaying
        case upNext
        case later

        var label: String {
            switch self {
            case .recent: return "Played"
            case .nowPlaying: return "Now"
            case .upNext: return "Next"
            case .later: return "Later"
            }
        }

        var tint: Color {
            switch self {
            case .recent: return .secondary
            case .nowPlaying: return .accentColor
            case .upNext: return .blue
            case .later: return .secondary
            }
        }

        var connector: Color { tint }

        var artworkSize: CGFloat {
            self == .nowPlaying ? 76 : 64
        }

        var cardWidth: CGFloat {
            self == .nowPlaying ? 168 : 148
        }
    }

    let entry: PlaybackQueueItem
    let role: Role
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                ArtworkView(artwork: entry.artwork, size: role.artworkSize)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                if role == .nowPlaying {
                    Image(systemName: isPlaying ? "waveform.circle.fill" : "pause.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(role.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(role.tint)

                Text(entry.title)
                    .font(role == .nowPlaying ? .headline : .subheadline.weight(.semibold))
                    .lineLimit(2)

                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: role.cardWidth, alignment: .leading)
        .padding(14)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(borderColor, lineWidth: role == .nowPlaying ? 1.5 : 1)
        }
    }

    private var backgroundStyle: some ShapeStyle {
        role == .nowPlaying ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.ultraThinMaterial)
    }

    private var borderColor: Color {
        role == .nowPlaying ? role.tint.opacity(0.35) : Color.secondary.opacity(0.18)
    }
}
