import SwiftUI
import MusicKit

struct AddToPlaylistSheet: View {
    let songs: [Song]
    @Environment(MusicService.self) private var musicService
    @Environment(\.dismiss) private var dismiss

    @State private var playlists: [Playlist] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var newPlaylistName = ""
    @State private var isCreating = false
    @State private var addedTo: String?

    var body: some View {
        NavigationStack {
            List {
                // Create new playlist section
                Section {
                    HStack {
                        TextField("New Playlist Name", text: $newPlaylistName)
                            .textFieldStyle(.plain)
                            .accessibilityIdentifier("playlist-new-name")
                        Button {
                            Task { await createAndAdd() }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                        .accessibilityIdentifier("playlist-create")
                    }
                } header: {
                    Text("Create New Playlist")
                }

                if let addedTo {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Added \(songs.count) \(songs.count == 1 ? "song" : "songs") to \(addedTo)")
                                .font(.subheadline)
                        }
                    }
                }

                // Existing playlists
                if isLoading {
                    Section {
                        ProgressView("Loading playlists…")
                    }
                } else if let error {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundStyle(.secondary)
                    }
                } else if playlists.isEmpty {
                    Section {
                        Text("No playlists yet. Create one above.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Your Playlists") {
                        ForEach(playlists) { playlist in
                            Button {
                                Task { await addToPlaylist(playlist) }
                            } label: {
                                HStack(spacing: 12) {
                                    ArtworkView(artwork: playlist.artwork, size: 44)
                                    Text(playlist.name)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
            .task { await loadPlaylists() }
        }
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

    private func addToPlaylist(_ playlist: Playlist) async {
        do {
            for song in songs {
                try await musicService.addSongToPlaylist(song, playlist: playlist)
            }
            Haptic.success()
            addedTo = playlist.name
            try? await Task.sleep(for: .milliseconds(800))
            dismiss()
        } catch {
            self.error = error
        }
    }

    private func createAndAdd() async {
        let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isCreating = true
        do {
            let playlist = try await musicService.createPlaylist(name: name)
            for song in songs {
                try await musicService.addSongToPlaylist(song, playlist: playlist)
            }
            Haptic.success()
            addedTo = name
            newPlaylistName = ""
            // Refresh playlist list
            playlists = try await musicService.fetchUserPlaylists()
            isCreating = false
            try? await Task.sleep(for: .milliseconds(800))
            dismiss()
        } catch {
            self.error = error
            isCreating = false
        }
    }
}
