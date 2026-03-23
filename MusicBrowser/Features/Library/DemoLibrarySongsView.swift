#if DEBUG
import SwiftUI

/// Demo version of LibrarySongsView using hardcoded songs instead of MusicKit.
/// Activated via `-demo-mode` launch argument for simulator testing and Maestro E2E.
struct DemoLibrarySongsView: View {

    @State private var sortOption: SongSortOption = .title
    @State private var sortDirection: SortDirection = .ascending
    @State private var filterGenre: String = ""

    private var sortedSongs: [DemoSong] {
        var result = DemoSongLibrary.songs

        if !filterGenre.isEmpty {
            result = result.filter { $0.genreNames.contains(filterGenre) }
        }

        switch sortOption {
        case .title:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            result.sort { $0.artistName.localizedCaseInsensitiveCompare($1.artistName) == .orderedAscending }
        case .albumTitle:
            result.sort { $0.albumTitle.localizedCaseInsensitiveCompare($1.albumTitle) == .orderedAscending }
        case .duration:
            result.sort { $0.duration < $1.duration }
        case .playCount:
            result.sort { $0.playCount < $1.playCount }
        default:
            break
        }

        if !sortDirection.isAscending { result.reverse() }
        return result
    }

    private var availableLetters: [String] {
        sortedSongs.availableLetters
    }

    private var allGenres: [String] {
        Set(DemoSongLibrary.songs.flatMap(\.genreNames)).sorted()
    }

    private var groupedByLetter: [(key: String, value: [DemoSong])] {
        Dictionary(grouping: sortedSongs) { StringUtils.firstLetter(of: $0.title) }
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        HStack {
                            Text("\(sortedSongs.count) songs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .id("demo-songs-top")

                        ForEach(groupedByLetter, id: \.key) { letter, songs in
                            Color.clear
                                .frame(height: 0)
                                .id("section-\(letter)")

                            ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
                                demoSongRow(song)

                                if !(letter == groupedByLetter.last?.key && idx == songs.count - 1) {
                                    Divider().padding(.leading, 68)
                                }
                            }
                        }
                    }
                }

                SectionIndexRail(
                    availableLetters: Set(availableLetters),
                    onScrollTo: { letter in
                        withAnimation(.snappy(duration: 0.2)) {
                            proxy.scrollTo("section-\(letter)", anchor: .top)
                        }
                    }
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    sortSection
                    directionSection
                    filterSection
                } label: {
                    Label("View Options", systemImage: "line.3.horizontal.decrease")
                }
            }
        }
    }

    // MARK: - Song Row

    @ViewBuilder
    private func demoSongRow(_ song: DemoSong) -> some View {
        HStack(spacing: 12) {
            // Placeholder artwork
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hue: Double(song.title.hashValue % 360) / 360.0, saturation: 0.3, brightness: 0.9))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(String(song.title.prefix(1)))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }

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

            Text(formatDuration(song.duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)

            if sortOption == .playCount {
                Text("\(song.playCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Menu Sections

    @ViewBuilder
    private var sortSection: some View {
        Section("Sort By") {
            Picker("Sort", selection: $sortOption) {
                ForEach(SongSortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        }
    }

    @ViewBuilder
    private var directionSection: some View {
        Section {
            Button {
                sortDirection.toggle()
            } label: {
                Label(
                    sortDirection.isAscending ? "Ascending" : "Descending",
                    systemImage: sortDirection.systemImage
                )
            }
        }
    }

    @ViewBuilder
    private var filterSection: some View {
        Section("Genre") {
            Button("All Genres") { filterGenre = "" }
            ForEach(allGenres, id: \.self) { genre in
                Button {
                    filterGenre = genre
                } label: {
                    HStack {
                        Text(genre)
                        if filterGenre == genre {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }
}

#Preview("Demo Library Songs") {
    NavigationStack {
        DemoLibrarySongsView()
            .navigationTitle("Library")
    }
}
#endif
