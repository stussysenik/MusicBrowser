import SwiftUI
import MusicKit

struct LibraryView: View {
    @State private var selection: LibrarySection = .songs

    enum LibrarySection: String, CaseIterable {
        case songs = "Songs"
        case albums = "Albums"
        case playlists = "Playlists"
        case artists = "Artists"
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

            Group {
                switch selection {
                case .songs: LibrarySongsView()
                case .albums: LibraryAlbumsView()
                case .playlists: LibraryPlaylistsView()
                case .artists: LibraryArtistsView()
                }
            }
        }
        .navigationTitle("Library")
        .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
        .navigationDestination(for: Playlist.self) { PlaylistDetailView(playlist: $0) }
        .navigationDestination(for: Artist.self) { ArtistDetailView(artist: $0) }
    }
}
