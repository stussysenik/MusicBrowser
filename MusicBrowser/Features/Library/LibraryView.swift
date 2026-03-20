import SwiftUI
import MusicKit

struct LibraryView: View {
    @Environment(PlayerService.self) private var player
    @Environment(MusicService.self) private var musicService
    @AppStorage("librarySection") private var selection: LibrarySection = .songs

    enum LibrarySection: String, CaseIterable {
        case songs = "Songs"
        case albums = "Albums"
        case playlists = "Playlists"
        case artists = "Artists"
        case genres = "Genres"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selection) {
                ForEach(LibrarySection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            ZStack {
                LibrarySongsView(isActive: selection == .songs)
                    .opacity(selection == .songs ? 1 : 0)
                    .allowsHitTesting(selection == .songs)
                LibraryAlbumsView(isActive: selection == .albums)
                    .opacity(selection == .albums ? 1 : 0)
                    .allowsHitTesting(selection == .albums)
                LibraryPlaylistsView(isActive: selection == .playlists)
                    .opacity(selection == .playlists ? 1 : 0)
                    .allowsHitTesting(selection == .playlists)
                LibraryArtistsView(isActive: selection == .artists)
                    .opacity(selection == .artists ? 1 : 0)
                    .allowsHitTesting(selection == .artists)
                GenreBrowserView()
                    .opacity(selection == .genres ? 1 : 0)
                    .allowsHitTesting(selection == .genres)
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                NavigationLink {
                    NotesListView()
                } label: {
                    Label("Notes", systemImage: "note.text")
                }
            }
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
        .navigationDestination(for: GenreGroup.self) { GenreDetailView(genreGroup: $0) }
    }
}

#Preview("Library") {
    PreviewHost {
        NavigationStack {
            LibraryView()
        }
    }
}
