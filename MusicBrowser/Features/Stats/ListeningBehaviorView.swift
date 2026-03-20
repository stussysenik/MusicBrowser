import SwiftUI

/// Listening behavior section: time cards, streak badge, hourly heatmap, top songs.
struct ListeningBehaviorView: View {
    @Environment(StatsService.self) private var statsService

    @State private var totalTimeToday: TimeInterval = 0
    @State private var totalTimeWeek: TimeInterval = 0
    @State private var totalTimeMonth: TimeInterval = 0
    @State private var streak: Int = 0
    @State private var heatmap: [Int: Int] = [:]
    @State private var topSongs: [(songID: String, title: String, artistName: String, playCount: Int)] = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Time cards
                timeCardsSection

                // Streak badge
                if streak > 0 {
                    streakBadge
                }

                // Hourly heatmap
                heatmapSection

                // Top songs
                topSongsSection
            }
            .padding()
        }
        .task { loadData() }
    }

    // MARK: - Time Cards

    private var timeCardsSection: some View {
        HStack(spacing: 12) {
            timeCard(title: "Today", minutes: totalTimeToday / 60)
            timeCard(title: "This Week", minutes: totalTimeWeek / 60)
            timeCard(title: "This Month", minutes: totalTimeMonth / 60)
        }
    }

    @ViewBuilder
    private func timeCard(title: String, minutes: Double) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(minutes))")
                .font(.title2.bold().monospacedDigit())
            Text("min")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Streak Badge

    private var streakBadge: some View {
        HStack {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text("\(streak)-day streak")
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Hourly Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Listening Activity")
                .font(.headline)

            HStack(spacing: 2) {
                ForEach(0..<24, id: \.self) { hour in
                    let count = heatmap[hour] ?? 0
                    let maxCount = max(1, heatmap.values.max() ?? 1)
                    let intensity = Double(count) / Double(maxCount)

                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(max(0.05, intensity)))
                            .frame(height: 40)

                        if hour % 6 == 0 {
                            Text("\(hour)")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Top Songs

    private var topSongsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Songs")
                .font(.headline)

            if topSongs.isEmpty {
                Text("No listening data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(Array(topSongs.enumerated()), id: \.offset) { idx, song in
                    HStack(spacing: 12) {
                        Text("\(idx + 1)")
                            .font(.callout.monospacedDigit().bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.body)
                                .lineLimit(1)
                            Text(song.artistName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text("\(song.playCount) plays")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    if idx < topSongs.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Data Loading

    private func loadData() {
        totalTimeToday = statsService.totalListeningTime(period: .today)
        totalTimeWeek = statsService.totalListeningTime(period: .thisWeek)
        totalTimeMonth = statsService.totalListeningTime(period: .thisMonth)
        streak = statsService.listeningStreak()
        heatmap = statsService.hourlyHeatmap()
        topSongs = statsService.topSongs(limit: 10)
    }
}
