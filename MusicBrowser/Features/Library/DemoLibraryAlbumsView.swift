import SwiftUI

struct DemoLibraryAlbumsView: View {
    @Environment(MusicService.self) private var musicService
    @State private var sortDirection: SortDirection = .ascending
    @State private var grouping: AlbumGrouping = .none

    private let columns = [GridItem(.adaptive(minimum: 168, maximum: 220), spacing: 18, alignment: .top)]

    private var albums: [DemoAlbum] {
        let base = musicService.demoAlbums
        return sortDirection.isAscending ? base : base.reversed()
    }

    private var groupedAlbums: [(String, [DemoAlbum])] {
        switch grouping {
        case .none:
            return []
        case .year:
            return Dictionary(grouping: albums) { "\($0.releaseYear)" }
                .sorted { sortDirection.isAscending ? $0.key < $1.key : $0.key > $1.key }
        case .decade:
            return Dictionary(grouping: albums) { "\(($0.releaseYear / 10) * 10)s" }
                .sorted { sortDirection.isAscending ? $0.key < $1.key : $0.key > $1.key }
        case .artist:
            return Dictionary(grouping: albums) { $0.artistName }
                .sorted { sortDirection.isAscending ? $0.key < $1.key : $0.key > $1.key }
        }
    }

    var body: some View {
        Group {
            if grouping == .none {
                ScrollView {
                    VStack(spacing: 18) {
                        summaryHeader
                            .padding(.horizontal)
                            .padding(.top, 8)

                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(albums) { album in
                                NavigationLink(value: album) {
                                    AlbumCard(album, size: 176)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            } else {
                List {
                    Section {
                        summaryHeader
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                    }

                    ForEach(groupedAlbums, id: \.0) { label, albums in
                        Section(label) {
                            ForEach(albums) { album in
                                NavigationLink(value: album) {
                                    AlbumRowContent(album)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                #if os(macOS)
                .listStyle(.automatic)
                #else
                .listStyle(.insetGrouped)
                #endif
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
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
                            ForEach(AlbumGrouping.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    }
                } label: {
                    Label("View Options", systemImage: "line.3.horizontal.decrease")
                }
                .accessibilityLabel("Album View Options")
                .accessibilityIdentifier("demo-library-albums-view-options")
            }
        }
        .task {
            #if os(iOS)
            await musicService.prepareFallbackLibraryIfPossible()
            #endif
        }
    }

    private var summaryHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Albums")
                    .font(.title3.weight(.semibold))
                Text("\(albums.count) in \(musicService.demoLibraryLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(sortDirection.isAscending ? "Ascending" : "Descending")
                    .font(.caption.weight(.semibold))
                Text(grouping == .none ? "Grid" : grouping.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
