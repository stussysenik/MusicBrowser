import SwiftUI
import MusicKit

struct LibraryView: View {
    @Environment(PlayerService.self) private var player
    @Environment(MusicService.self) private var musicService
    @State private var selectedTab = 0
    
    private var isDemoMode: Bool {
        musicService.runtime.usesDummyData
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedTab) {
                Text("Songs").tag(0)
                Text("Albums").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 4)

            Group {
                switch selectedTab {
                case 0:
                    if isDemoMode {
                        DemoLibrarySongsView()
                    } else {
                        LibrarySongsView()
                    }
                case 1:
                    if isDemoMode {
                        DemoLibraryAlbumsView()
                    } else {
                        LibraryAlbumsView()
                    }
                default:
                    if isDemoMode {
                        DemoLibrarySongsView()
                    } else {
                        LibrarySongsView()
                    }
                }
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptic.medium()
                    Task { try? await player.playRandomSong(using: musicService) }
                } label: {
                    Label("Play Random", systemImage: "dice")
                }
                .accessibilityIdentifier("library-play-random")
            }
        }
        .navigationDestination(for: Song.self) { SongDetailView(song: $0) }
        .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
        .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlist: $0) }
        .navigationDestination(for: Artist.self) { ArtistDetailView(artist: $0) }
        .navigationDestination(for: DemoSong.self) { DemoSongDetailView(song: $0) }
        .navigationDestination(for: DemoAlbum.self) { DemoAlbumDetailView(album: $0) }
    }
}

#Preview("Library") {
    PreviewHost {
        NavigationStack {
            LibraryView()
        }
    }
}
