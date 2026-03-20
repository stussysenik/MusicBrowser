import SwiftUI

/// Discovery section: weekly recap card, personality badge, rediscovery nudges.
struct DiscoveryEngineView: View {
    @Environment(StatsService.self) private var statsService

    @State private var recap: WeeklyRecap?
    @State private var personality: String = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Weekly Recap
                weeklyRecapSection

                // Listening Personality
                personalitySection

                // Rediscovery nudges placeholder
                rediscoverySection
            }
            .padding()
        }
        .task { loadData() }
    }

    // MARK: - Weekly Recap

    private var weeklyRecapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Recap")
                .font(.headline)

            if let recap {
                WeeklyRecapCard(
                    weekID: recap.weekID,
                    totalMinutes: recap.totalMinutes,
                    uniqueSongs: recap.uniqueSongs,
                    uniqueArtists: recap.uniqueArtists,
                    topSongTitle: recap.topSongTitle,
                    topArtistName: recap.topArtistName,
                    topGenre: recap.topGenre,
                    personalityType: recap.personalityType
                )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Keep listening to generate your first weekly recap")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(.quaternary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Personality

    private var personalitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Listening Personality")
                .font(.headline)

            HStack(spacing: 12) {
                Image(systemName: personalityIcon)
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(personality.isEmpty ? "New Listener" : personality)
                        .font(.title3.bold())
                    Text(personalityDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var personalityIcon: String {
        switch personality {
        case "Explorer": return "safari"
        case "Deep Diver": return "waveform"
        case "Genre Loyalist": return "heart.fill"
        case "Power Listener": return "bolt.fill"
        default: return "headphones"
        }
    }

    private var personalityDescription: String {
        switch personality {
        case "Explorer": return "You love discovering new genres and artists"
        case "Deep Diver": return "You listen to full tracks and complete albums"
        case "Genre Loyalist": return "You know what you like and stick with it"
        case "Power Listener": return "Your listening volume is impressive"
        default: return "Start listening to discover your personality"
        }
    }

    // MARK: - Rediscovery

    private var rediscoverySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rediscovery Nudges")
                .font(.headline)

            VStack(spacing: 8) {
                Image(systemName: "arrow.clockwise.heart")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Songs you haven't played in a while will appear here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(.quaternary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Data

    private func loadData() {
        recap = statsService.generateWeeklyRecap()
        personality = statsService.listeningPersonality()
    }
}
