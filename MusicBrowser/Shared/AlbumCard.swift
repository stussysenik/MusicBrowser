import SwiftUI
import MusicKit

struct AlbumCard: View {
    let title: String
    let subtitle: String
    let metadata: String?
    let artwork: Artwork?
    let demoArtworkTitle: String?
    let size: CGFloat

    init(_ album: Album, size: CGFloat = 160) {
        self.title = album.title
        self.subtitle = album.artistName
        self.metadata = AlbumMetadata.gridLine(
            primary: album.releaseDate.map { String($0.year) },
            secondary: album.genreNames.first
        )
        self.artwork = album.artwork
        self.demoArtworkTitle = nil
        self.size = size
    }

    init(_ playlist: Playlist, size: CGFloat = 160) {
        self.title = playlist.name
        self.subtitle = playlist.curatorName ?? ""
        self.metadata = "Playlist"
        self.artwork = playlist.artwork
        self.demoArtworkTitle = nil
        self.size = size
    }

    init(_ album: DemoAlbum, size: CGFloat = 160) {
        self.title = album.title
        self.subtitle = album.artistName
        self.metadata = "\(album.songs.count) tracks • \(Int(album.averageBPM)) BPM"
        self.artwork = nil
        self.demoArtworkTitle = album.title
        self.size = size
    }

    init(
        title: String,
        subtitle: String,
        metadata: String? = nil,
        artwork: Artwork?,
        demoArtworkTitle: String? = nil,
        size: CGFloat = 160
    ) {
        self.title = title
        self.subtitle = subtitle
        self.metadata = metadata
        self.artwork = artwork
        self.demoArtworkTitle = demoArtworkTitle
        self.size = size
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            artworkView

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let metadata {
                    Text(metadata)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: size, alignment: .leading)
    }

    @ViewBuilder
    private var artworkView: some View {
        if let demoArtworkTitle {
            DemoArtworkTile(title: demoArtworkTitle)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            ArtworkView(artwork: artwork, size: size)
        }
    }
}

struct AlbumRowContent: View {
    let title: String
    let subtitle: String
    let supporting: String?
    let trailing: String?
    let artwork: Artwork?
    let demoArtworkTitle: String?

    init(_ album: Album) {
        self.title = album.title
        self.subtitle = album.artistName
        self.supporting = AlbumMetadata.gridLine(
            primary: album.genreNames.first,
            secondary: nil
        )
        self.trailing = album.releaseDate.map { String($0.year) }
        self.artwork = album.artwork
        self.demoArtworkTitle = nil
    }

    init(_ album: DemoAlbum) {
        self.title = album.title
        self.subtitle = album.artistName
        self.supporting = "\(album.songs.count) tracks • \(Int(album.averageBPM)) BPM"
        self.trailing = String(album.releaseYear)
        self.artwork = nil
        self.demoArtworkTitle = album.title
    }

    var body: some View {
        HStack(spacing: 12) {
            artworkView

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let supporting {
                    Text(supporting)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: Capsule())
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var artworkView: some View {
        if let demoArtworkTitle {
            DemoArtworkTile(title: demoArtworkTitle)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            ArtworkView(artwork: artwork, size: 60)
        }
    }
}

private enum AlbumMetadata {
    static func gridLine(primary: String?, secondary: String?) -> String? {
        let values: [String] = [primary, secondary]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }

        guard !values.isEmpty else { return nil }
        return values.joined(separator: " • ")
    }
}

#Preview("Album Card") {
    AlbumCard(
        title: "Sample Album",
        subtitle: "Sample Artist",
        metadata: "2024 • Alternative",
        artwork: nil,
        size: 160
    )
    .padding()
}
