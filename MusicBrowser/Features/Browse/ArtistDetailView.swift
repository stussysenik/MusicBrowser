import SwiftUI
import MusicKit

struct ArtistDetailView: View {
    let artist: Artist
    @Environment(MusicService.self) private var musicService
    @Environment(PlayerService.self) private var player

    @State private var detailedArtist: Artist?
    @State private var isLoading = true

    private var display: Artist { detailedArtist ?? artist }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                topSongs
                albums
            }
            .padding()
        }
        .navigationTitle(artist.name)
        .navigationDestination(for: Song.self) { SongDetailView(song: $0) }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadDetail() }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ArtworkView(artwork: display.artwork, size: 180)
                .clipShape(Circle())

            Text(display.name)
                .font(.title.bold())
        }
    }

    @ViewBuilder
    private var topSongs: some View {
        if let songs = display.topSongs, !songs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Top Songs")
                    .font(.title3.bold())

                LazyVStack(spacing: 0) {
                    ForEach(Array(songs.prefix(10).enumerated()), id: \.element.id) { idx, song in
                        HStack(spacing: 0) {
                            NavigationLink(value: song) {
                                HStack(spacing: 12) {
                                    Text("\(idx + 1)")
                                        .font(.callout.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 28, alignment: .trailing)

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

                                    if let duration = song.duration {
                                        Text(formatDuration(duration))
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task { try? await player.playSong(song) }
                            } label: {
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 4)

                        if idx < min(songs.count, 10) - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var albums: some View {
        if let albumList = display.albums, !albumList.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Albums")
                    .font(.title3.bold())

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(albumList) { album in
                            NavigationLink(value: album) {
                                AlbumCard(album, size: 150)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func loadDetail() async {
        do {
            detailedArtist = try await musicService.artistDetail(artist)
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}

#Preview("Artist Detail") {
    PreviewHost {
        PreviewLibraryItemContainer(
            title: "Artist Preview",
            symbol: "person.2",
            load: { await PreviewLibraryLoader.firstArtist() }
        ) { artist in
            NavigationStack {
                ArtistDetailView(artist: artist)
            }
        }
    }
}
