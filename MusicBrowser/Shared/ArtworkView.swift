import SwiftUI
import MusicKit

struct ArtworkView: View {
    let artwork: Artwork?
    let size: CGFloat

    var body: some View {
        if let artwork {
            ArtworkImage(artwork, width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size > 80 ? 10 : 6))
        } else {
            RoundedRectangle(cornerRadius: size > 80 ? 10 : 6)
                .fill(.quaternary)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.3))
                        .foregroundStyle(.tertiary)
                }
        }
    }
}
