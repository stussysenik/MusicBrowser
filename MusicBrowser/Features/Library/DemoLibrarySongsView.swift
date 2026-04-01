import SwiftUI

struct DemoLibrarySongsView: View {
    @Environment(MusicService.self) private var musicService
    @Environment(PlayerService.self) private var player
    @Environment(AnalysisService.self) private var analysisService

    @State private var sortOption: SongSortOption = .title
    @State private var sortDirection: SortDirection = .ascending
    @State private var grouping: SongGrouping = .letter
    @State private var filterGenre = ""
    @State private var addToPlaylistSong: DemoSong?

    private let sectionRailContentInset: CGFloat = 8

    private var filteredSongs: [DemoSong] {
        var result = musicService.demoSongs

        if !filterGenre.isEmpty {
            result = result.filter { $0.genreNames.contains(filterGenre) }
        }

        result.sort { lhs, rhs in
            let comparison: ComparisonResult
            switch sortOption {
            case .title:
                comparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            case .artist:
                comparison = lhs.artistName.localizedCaseInsensitiveCompare(rhs.artistName)
            case .albumTitle:
                comparison = lhs.albumTitle.localizedCaseInsensitiveCompare(rhs.albumTitle)
            case .duration:
                comparison = lhs.duration == rhs.duration ? .orderedSame : (lhs.duration < rhs.duration ? .orderedAscending : .orderedDescending)
            case .playCount:
                comparison = lhs.playCount == rhs.playCount ? .orderedSame : (lhs.playCount < rhs.playCount ? .orderedAscending : .orderedDescending)
            case .releaseDate:
                comparison = lhs.releaseYear == rhs.releaseYear ? .orderedSame : (lhs.releaseYear < rhs.releaseYear ? .orderedAscending : .orderedDescending)
            case .bpm:
                let lhsBPM = analysisService.bpm(for: lhs) ?? lhs.bpm
                let rhsBPM = analysisService.bpm(for: rhs) ?? rhs.bpm
                comparison = lhsBPM == rhsBPM ? .orderedSame : (lhsBPM < rhsBPM ? .orderedAscending : .orderedDescending)
            case .dateAdded, .lastPlayed:
                comparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            }
            return sortDirection.isAscending ? comparison == .orderedAscending : comparison == .orderedDescending
        }

        return result
    }

    private var groupedSongs: [(String, [DemoSong])] {
        let groups: [String: [DemoSong]]
        switch grouping {
        case .letter:
            groups = Dictionary(grouping: filteredSongs) { StringUtils.firstLetter(of: $0.title) }
        case .year:
            groups = Dictionary(grouping: filteredSongs) { "\($0.releaseYear)" }
        case .decade:
            groups = Dictionary(grouping: filteredSongs) { "\(($0.releaseYear / 10) * 10)s" }
        case .tempo:
            groups = Dictionary(grouping: filteredSongs) { analysisService.tempoSectionTitle(for: analysisService.bpm(for: $0) ?? $0.bpm) }
        }
        return groups.sorted { sortDirection.isAscending ? $0.key < $1.key : $0.key > $1.key }
    }

    private var availableLetters: [String] {
        filteredSongs.availableLetters
    }

    private var allGenres: [String] {
        Array(Set(musicService.demoSongs.flatMap(\.genreNames))).sorted()
    }

    private var bpmOverview: AnalysisService.BPMOverview {
        let values = filteredSongs.compactMap { analysisService.bpm(for: $0) ?? $0.bpm }
        let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        return .init(analyzedCount: values.count, totalCount: filteredSongs.count, average: average)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        headerCard
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .id("demo-songs-top")

                        ForEach(groupedSongs, id: \.0) { label, songs in
                            Color.clear
                                .frame(height: 0)
                                .id("section-\(label)")

                            if grouping != .letter {
                                HStack {
                                    Text(label)
                                        .font(.title3.bold())
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top, 18)
                                .padding(.bottom, 8)
                            }

                            ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
                                demoSongRow(song)

                                if !(label == groupedSongs.last?.0 && idx == songs.count - 1) {
                                    Divider().padding(.leading, 68)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.trailing, sectionRailContentInset)

                if grouping == .letter {
                    #if canImport(UIKit)
                    UIKitSectionIndexRail(
                        availableLetters: Set(availableLetters),
                        onScrollTo: { letter in
                            withAnimation(.snappy(duration: 0.2)) {
                                proxy.scrollTo("section-\(letter)", anchor: .top)
                            }
                        }
                    )
                    .padding(.trailing, 4)
                    #else
                    SectionIndexRail(
                        availableLetters: Set(availableLetters),
                        onScrollTo: { letter in
                            withAnimation(.snappy(duration: 0.2)) {
                                proxy.scrollTo("section-\(letter)", anchor: .top)
                            }
                        }
                    )
                    .padding(.trailing, 4)
                    #endif
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
        .task {
            #if os(iOS)
            await musicService.prepareFallbackLibraryIfPossible()
            #endif
        }
        .sheet(item: $addToPlaylistSong) { song in
            DemoAddToPlaylistSheet(songs: [song])
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Section("Sort By") {
                        Picker("Sort", selection: $sortOption) {
                            ForEach(SongSortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    }

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

                    Section("Group By") {
                        Picker("Grouping", selection: $grouping) {
                            ForEach(SongGrouping.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    }

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
                } label: {
                    Label("View Options", systemImage: "line.3.horizontal.decrease")
                }
                .accessibilityIdentifier("demo-library-view-options")
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(filteredSongs.count) songs")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(musicService.usesRealDeviceLibrary ? "Using your device music library" : "Using the sample library")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Application BPM")
                        .font(.headline)
                    Text("\(bpmOverview.analyzedCount) of \(bpmOverview.totalCount) songs analyzed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let average = bpmOverview.average {
                    Text("\(Int(average)) BPM avg")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func demoSongRow(_ song: DemoSong) -> some View {
        NavigationLink(value: song) {
            HStack(spacing: 12) {
                DemoArtworkTile(title: song.title)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

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

                if sortOption == .bpm {
                    Text("\(Int(analysisService.bpm(for: song) ?? song.bpm))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.orange)
                }

                Text(formatDuration(song.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("demo-library-song-\(song.id)")
        .contextMenu {
            Button {
                player.playDemoSong(song)
            } label: {
                Label("Play", systemImage: "play")
            }
            Button {
                player.playDemoNext(song)
            } label: {
                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            Button {
                player.addDemoSongToQueue(song)
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            Divider()
            Button {
                addToPlaylistSong = song
            } label: {
                Label("Add to Playlist", systemImage: "music.note.list")
            }
        }
    }
}
