import SwiftUI

/// DJ Tools section: BPM/key/genre/energy filter stack with live-filtered results,
/// Camelot wheel visualization, and batch analysis.
struct DJToolsView: View {
    @Environment(AnalysisService.self) private var analysisService
    @Environment(DiscoveryService.self) private var discoveryService
    @Environment(AudioAnalysisService.self) private var audioAnalysisService
    @Environment(MusicService.self) private var musicService
    @Environment(PlayerService.self) private var player

    @AppStorage("djtools.bpmMin") private var bpmMin: Double = 60
    @AppStorage("djtools.bpmMax") private var bpmMax: Double = 200
    @State private var selectedKeys: Set<String> = []
    @State private var selectedGenres: Set<String> = []
    @AppStorage("djtools.energyMin") private var energyMin: Double = 0
    @AppStorage("djtools.energyMax") private var energyMax: Double = 1
    @State private var filteredResults: [SongAnalysis] = []

    private let allKeys = ["C Major", "C Minor", "D Major", "D Minor", "E Major", "E Minor",
                           "F Major", "F Minor", "G Major", "G Minor", "A Major", "A Minor",
                           "B Major", "B Minor"]
    private let commonGenres = ["Pop", "Rock", "Electronic", "Hip-Hop", "R&B", "Jazz",
                                "Country", "Metal", "Classical", "Indie", "Folk", "Funk"]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // BPM Range
                bpmFilterSection

                // Key selection
                keyFilterSection

                // Genre chips
                genreFilterSection

                // Energy range
                energyFilterSection

                // Batch analysis button
                batchAnalysisSection

                // Results
                resultsSection
            }
            .padding()
        }
        .onChange(of: bpmMin) { _, _ in applyFilters() }
        .onChange(of: bpmMax) { _, _ in applyFilters() }
        .onChange(of: selectedKeys) { _, _ in applyFilters() }
        .onChange(of: selectedGenres) { _, _ in applyFilters() }
        .onChange(of: energyMin) { _, _ in applyFilters() }
        .onChange(of: energyMax) { _, _ in applyFilters() }
        .task { applyFilters() }
        .onAppear {
            if let keys = UserDefaults.standard.stringArray(forKey: "djtools.selectedKeys") {
                selectedKeys = Set(keys)
            }
            if let genres = UserDefaults.standard.stringArray(forKey: "djtools.selectedGenres") {
                selectedGenres = Set(genres)
            }
        }
        .onChange(of: selectedKeys) { _, newValue in
            UserDefaults.standard.set(Array(newValue), forKey: "djtools.selectedKeys")
        }
        .onChange(of: selectedGenres) { _, newValue in
            UserDefaults.standard.set(Array(newValue), forKey: "djtools.selectedGenres")
        }
    }

    // MARK: - BPM Filter

    private var bpmFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BPM Range")
                    .font(.headline)
                Spacer()
                Text("\(Int(bpmMin)) - \(Int(bpmMax))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Slider(value: $bpmMin, in: 60...200, step: 5)
                Slider(value: $bpmMax, in: 60...200, step: 5)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Key Filter

    private var keyFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Musical Key")
                .font(.headline)

            FlowLayout(spacing: 6) {
                ForEach(allKeys, id: \.self) { key in
                    Button {
                        if selectedKeys.contains(key) {
                            selectedKeys.remove(key)
                        } else {
                            selectedKeys.insert(key)
                        }
                    } label: {
                        Text(key)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(selectedKeys.contains(key) ? Color.accentColor : Color.clear)
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1)
                            )
                            .foregroundStyle(selectedKeys.contains(key) ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Genre Filter

    private var genreFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Genre")
                .font(.headline)

            FlowLayout(spacing: 6) {
                ForEach(commonGenres, id: \.self) { genre in
                    Button {
                        if selectedGenres.contains(genre) {
                            selectedGenres.remove(genre)
                        } else {
                            selectedGenres.insert(genre)
                        }
                    } label: {
                        Text(genre)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(selectedGenres.contains(genre) ? Color.purple : Color.clear)
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.purple.opacity(0.5), lineWidth: 1)
                            )
                            .foregroundStyle(selectedGenres.contains(genre) ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Energy Filter

    private var energyFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Energy")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.0f%% - %.0f%%", energyMin * 100, energyMax * 100))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Slider(value: $energyMin, in: 0...1, step: 0.05)
                Slider(value: $energyMax, in: 0...1, step: 0.05)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Batch Analysis

    private var batchAnalysisSection: some View {
        VStack(spacing: 8) {
            if audioAnalysisService.isAnalyzing {
                ProgressView(value: audioAnalysisService.analysisProgress) {
                    Text("Analyzing \(audioAnalysisService.analyzedCount)/\(audioAnalysisService.totalToAnalyze)")
                        .font(.caption)
                }
            } else {
                Button {
                    Haptic.medium()
                    Task {
                        let songs = try? await musicService.allLibrarySongs()
                        guard let songs else { return }
                        let tuples = songs.map { (id: $0.id.rawValue, title: $0.title, artist: $0.artistName) }
                        await audioAnalysisService.analyzeBatch(songs: tuples)
                        applyFilters()
                    }
                } label: {
                    Label("Analyze Library", systemImage: "waveform.badge.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Results

    @State private var isLoadingPlay = false

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Results (\(filteredResults.count))")
                    .font(.headline)

                Spacer()

                if !filteredResults.isEmpty {
                    Button {
                        Haptic.medium()
                        playFilteredResults(shuffled: false)
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .disabled(isLoadingPlay)

                    Button {
                        Haptic.medium()
                        playFilteredResults(shuffled: true)
                    } label: {
                        Image(systemName: "shuffle")
                    }
                    .disabled(isLoadingPlay)
                }
            }

            if filteredResults.isEmpty {
                Text("Adjust filters or run analysis to see results")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(filteredResults.prefix(20), id: \.songID) { analysis in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(analysis.title)
                                .font(.body)
                                .lineLimit(1)
                            Text(analysis.artistName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if let bpm = analysis.bpm {
                            Text("\(Int(bpm))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.orange)
                        }
                        if let key = analysis.musicalKey {
                            Text(key)
                                .font(.caption2)
                                .foregroundStyle(.purple)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Filter Logic

    private func playFilteredResults(shuffled: Bool) {
        let ids = filteredResults.prefix(50).map { $0.songID }
        isLoadingPlay = true
        Task {
            defer { isLoadingPlay = false }
            guard let songs = try? await musicService.librarySongs(byIDs: ids), !songs.isEmpty else { return }
            if shuffled {
                try? await player.playSongsShuffled(songs)
            } else {
                try? await player.playSongs(songs)
            }
        }
    }

    private func applyFilters() {
        let analyses = analysisService.allCachedAnalyses()
        let criteria = DiscoveryService.FilterCriteria(
            bpmRange: bpmMin...bpmMax,
            keys: selectedKeys.isEmpty ? nil : selectedKeys,
            genres: selectedGenres.isEmpty ? nil : selectedGenres,
            energyRange: energyMin...energyMax
        )
        filteredResults = discoveryService.filterStack(analyses: analyses, criteria: criteria)
    }
}
