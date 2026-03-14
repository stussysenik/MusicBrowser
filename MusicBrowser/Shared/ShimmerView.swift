import SwiftUI

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: max(0, phase - 0.3)),
                            .init(color: .white.opacity(0.4), location: phase),
                            .init(color: .clear, location: min(1, phase + 0.3))
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blendMode(.screen)
                }
            }
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Track Row

struct SkeletonTrackRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.quaternary)
                    .frame(width: 140, height: 12)

                RoundedRectangle(cornerRadius: 3)
                    .fill(.quaternary)
                    .frame(width: 90, height: 10)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 3)
                .fill(.quaternary)
                .frame(width: 32, height: 10)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .shimmer()
    }
}

// MARK: - Skeleton Album Grid

struct SkeletonAlbumGrid: View {
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.quaternary)
                        .aspectRatio(1, contentMode: .fit)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                        .frame(width: 80, height: 10)
                }
            }
        }
        .padding()
        .shimmer()
    }
}

// MARK: - Skeleton Artist Detail

struct SkeletonArtistDetail: View {
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 180, height: 180)

                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(width: 120, height: 20)
            }

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.quaternary)
                    .frame(width: 100, height: 16)

                ForEach(0..<5, id: \.self) { _ in
                    SkeletonTrackRow()
                }
            }
        }
        .padding()
        .shimmer()
    }
}

#Preview("Skeleton Track Row") {
    VStack(spacing: 0) {
        ForEach(0..<5, id: \.self) { _ in
            SkeletonTrackRow()
            Divider().padding(.leading, 68)
        }
    }
}

#Preview("Skeleton Album Grid") {
    SkeletonAlbumGrid()
}
