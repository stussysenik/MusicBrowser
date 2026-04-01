import SwiftUI

struct DemoAddToPlaylistSheet: View {
    let songs: [DemoSong]

    @Environment(MusicService.self) private var musicService
    @Environment(\.dismiss) private var dismiss

    @State private var playlists: [DemoPlaylistRecord] = []
    @State private var newPlaylistName = ""
    @State private var addedTo: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Create New Playlist") {
                    HStack {
                        TextField("New Playlist Name", text: $newPlaylistName)
                            .textFieldStyle(.plain)
                            .accessibilityIdentifier("demo-playlist-new-name")

                        Button {
                            createAndAdd()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("demo-playlist-create")
                    }
                }

                if let addedTo {
                    Section {
                        Label(
                            "Added \(songs.count) \(songs.count == 1 ? "song" : "songs") to \(addedTo)",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.green)
                    }
                }

                if playlists.isEmpty {
                    Section {
                        Text("No playlists yet. Create one above.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Your Playlists") {
                        ForEach(playlists) { playlist in
                            Button {
                                addToPlaylist(playlist)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playlist.name)
                                        Text("\(playlist.trackIDs.count) tracks")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
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
            .onAppear {
                playlists = musicService.fetchDemoPlaylists()
            }
        }
    }

    private func createAndAdd() {
        let trimmedName = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let playlist = musicService.createDemoPlaylist(name: trimmedName)
        musicService.addDemoSongsToPlaylist(songs, playlistID: playlist.id)
        playlists = musicService.fetchDemoPlaylists()
        newPlaylistName = ""
        Haptic.success()
        addedTo = playlist.name
        dismissSoon()
    }

    private func addToPlaylist(_ playlist: DemoPlaylistRecord) {
        musicService.addDemoSongsToPlaylist(songs, playlistID: playlist.id)
        playlists = musicService.fetchDemoPlaylists()
        Haptic.success()
        addedTo = playlist.name
        dismissSoon()
    }

    private func dismissSoon() {
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            dismiss()
        }
    }
}
