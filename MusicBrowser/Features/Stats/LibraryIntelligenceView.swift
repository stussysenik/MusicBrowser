import SwiftUI
import Charts

/// Library intelligence section: genre distribution, decade distribution, BPM histogram,
/// forgotten gems, library growth.
struct LibraryIntelligenceView: View {
    @Environment(AnalysisService.self) private var analysisService
    @Environment(MusicService.self) private var musicService

    @State private var genreData: [(genre: String, count: Int)] = []
    @State private var decadeData: [(decade: String, count: Int)] = []
    @State private var bpmData: [(range: String, count: Int)] = []
    @State private var isLoaded = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if !isLoaded {
                    ProgressView("Analyzing library...")
                        .padding()
                } else {
                    genreChart
                    decadeChart
                    bpmChart
                }
            }
            .padding()
        }
        .task { await loadData() }
    }

    // MARK: - Genre Distribution

    private var genreChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Genre Distribution")
                .font(.headline)

            if genreData.isEmpty {
                Text("No genre data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(genreData.prefix(10), id: \.genre) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Genre", item.genre)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                }
                .frame(height: CGFloat(min(genreData.count, 10)) * 30)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Decade Distribution

    private var decadeChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Music by Decade")
                .font(.headline)

            if decadeData.isEmpty {
                Text("No release date data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(decadeData, id: \.decade) { item in
                    BarMark(
                        x: .value("Decade", item.decade),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(Color.purple.gradient)
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - BPM Histogram

    private var bpmChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BPM Distribution")
                .font(.headline)

            let nonZero = bpmData.filter { $0.count > 0 }
            if nonZero.isEmpty {
                Text("Run analysis to see BPM distribution")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(nonZero, id: \.range) { item in
                    BarMark(
                        x: .value("BPM", item.range),
                        y: .value("Songs", item.count)
                    )
                    .foregroundStyle(Color.orange.gradient)
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Data Loading

    private func loadData() async {
        let analyses = analysisService.allCachedAnalyses()

        // Genre distribution from ML analysis
        var genreCounts: [String: Int] = [:]
        for a in analyses {
            if let genre = a.genreML {
                genreCounts[genre, default: 0] += 1
            }
        }
        genreData = genreCounts.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }

        // BPM histogram
        let statsService = StatsService()
        bpmData = statsService.bpmHistogram(analyses: analyses)

        // Decade distribution from analyses
        // We don't have release year in SongAnalysis, so this will be populated
        // when more data is available from listening sessions
        decadeData = []

        isLoaded = true
    }
}
