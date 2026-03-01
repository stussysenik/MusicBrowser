import SwiftUI
import MusicKit

struct AlbumCard: View {
    let title: String
    let subtitle: String
    let artwork: Artwork?
    let size: CGFloat

    init(_ album: Album, size: CGFloat = 160) {
        self.title = album.title
        self.subtitle = album.artistName
        self.artwork = album.artwork
        self.size = size
    }

    init(_ playlist: Playlist, size: CGFloat = 160) {
        self.title = playlist.name
        self.subtitle = playlist.curatorName ?? ""
        self.artwork = playlist.artwork
        self.size = size
    }

    init(title: String, subtitle: String, artwork: Artwork?, size: CGFloat = 160) {
        self.title = title
        self.subtitle = subtitle
        self.artwork = artwork
        self.size = size
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkView(artwork: artwork, size: size)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: size)
    }
}
