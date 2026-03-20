import SwiftUI

/// Reusable gradient card displaying a weekly listening recap.
struct WeeklyRecapCard: View {
    let weekID: String
    let totalMinutes: Double
    let uniqueSongs: Int
    let uniqueArtists: Int
    let topSongTitle: String?
    let topArtistName: String?
    let topGenre: String?
    let personalityType: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(weekID)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                if let personality = personalityType {
                    Text(personality)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }

            Text("\(Int(totalMinutes)) min")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                statPill(value: "\(uniqueSongs)", label: "Songs")
                statPill(value: "\(uniqueArtists)", label: "Artists")
            }

            if let topSong = topSongTitle {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Top Song")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(topSong)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 12) {
                if let artist = topArtistName {
                    miniStat(label: "Top Artist", value: artist)
                }
                if let genre = topGenre {
                    miniStat(label: "Top Genre", value: genre)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.purple, .blue, .indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    @ViewBuilder
    private func miniStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}
