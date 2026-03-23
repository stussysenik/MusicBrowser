import SwiftUI
import MusicKit

struct LibraryView: View {
    @Environment(PlayerService.self) private var player
    @Environment(MusicService.self) private var musicService
    @State private var selectedTab = 0

    #if DEBUG
    private var isDemoMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo-mode")
    }
    #endif

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
                    #if DEBUG
                    if isDemoMode {
                        DemoLibrarySongsView()
                    } else {
                        LibrarySongsView()
                    }
                    #else
                    LibrarySongsView()
                    #endif
                case 1:
                    LibraryAlbumsView()
                default:
                    LibrarySongsView()
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
            }
        }
        .navigationDestination(for: Song.self) { SongDetailView(song: $0) }
        .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
        .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlist: $0) }
        .navigationDestination(for: Artist.self) { ArtistDetailView(artist: $0) }
    }
}

#Preview("Library") {
    PreviewHost {
        NavigationStack {
            LibraryView()
        }
    }
}
