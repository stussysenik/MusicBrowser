import SwiftUI
import MusicKit

struct AddToPlaylistSheet: View {
    let song: Song

    @Environment(MusicService.self) private var musicService
    @Environment(\.dismiss) private var dismiss

    @State private var playlists: [Playlist] = []
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading Playlists")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    ContentUnavailableView {
                        Label("Unable to Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    }
                } else if playlists.isEmpty {
                    ContentUnavailableView("No Playlists", systemImage: "music.note.list")
                } else {
                    List(playlists) { playlist in
                        Button {
                            addSong(to: playlist)
                        } label: {
                            HStack(spacing: 12) {
                                ArtworkView(artwork: playlist.artwork, size: 44)
                                Text(playlist.name)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add to Playlist")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await loadPlaylists() }
    }

    private func loadPlaylists() async {
        do {
            playlists = try await musicService.fetchUserPlaylists()
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    private func addSong(to playlist: Playlist) {
        Task {
            do {
                try await musicService.addSongToPlaylist(song, playlist: playlist)
                Haptic.success()
                dismiss()
            } catch {
                self.error = error
            }
        }
    }
}
