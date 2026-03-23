import SwiftUI
import SwiftData
import MusicKit

struct AlbumDetailView: View {
    let album: Album
    @Environment(MusicService.self) private var musicService
    @Environment(PlayerService.self) private var player
    @Environment(AnnotationService.self) private var annotationService
    @Environment(\.modelContext) private var modelContext

    @State private var detailedAlbum: Album?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var annotation: AlbumAnnotation?
    @State private var newTag = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var showSaveConfirmation = false

    private var displayAlbum: Album { detailedAlbum ?? album }
    private var tracks: MusicItemCollection<Track>? { displayAlbum.tracks }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                controls
                trackList
                annotationSection
            }
            .padding()
        }
        .onAppear { loadOrCreateAnnotation() }
        .navigationTitle(album.title)
        .navigationDestination(for: Song.self) { SongDetailView(song: $0) }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadDetail() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ArtworkView(artwork: displayAlbum.artwork, size: 220)
                .shadow(radius: 12, y: 6)

            Text(displayAlbum.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(displayAlbum.artistName)
                .font(.title3)
                .foregroundStyle(.secondary)

            if let releaseDate = displayAlbum.releaseDate {
                Text(releaseDate, format: .dateTime.year())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                Task { try? await player.playAlbum(displayAlbum) }
            } label: {
                Label("Play", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                Task { try? await player.playAlbumShuffled(displayAlbum) }
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    // MARK: - Track List

    @ViewBuilder
    private var trackList: some View {
        if isLoading {
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonTrackRow()
                    Divider().padding(.leading, 44)
                }
            }
        } else if let loadError {
            ContentUnavailableView {
                Label("Unable to Load Tracks", systemImage: "exclamationmark.triangle")
            } description: {
                Text(loadError.localizedDescription)
            } actions: {
                Button("Retry") { Task { await loadDetail() } }
                    .buttonStyle(.bordered)
            }
        } else if let tracks, !tracks.isEmpty {
            LazyVStack(spacing: 0) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { idx, track in
                    HStack(spacing: 0) {
                        TrackRow(
                            title: track.title,
                            artistName: track.artistName,
                            artwork: nil,
                            duration: track.duration,
                            number: idx + 1
                        ) {
                            Task {
                                try? await player.playTracks(tracks, startingAt: idx)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    if idx < tracks.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        } else {
            Text("No tracks available")
                .foregroundStyle(.secondary)
                .padding(.top, 20)
        }
    }

    private func loadDetail() async {
        isLoading = true
        loadError = nil
        do {
            detailedAlbum = try await musicService.albumWithTracks(album)
            isLoading = false
        } catch {
            loadError = error
            isLoading = false
        }
    }

    // MARK: - Annotations

    private var annotationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Annotations")
                .font(.headline)

            // Rating
            HStack(spacing: 4) {
                Text("Rating")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                ForEach(1...5, id: \.self) { star in
                    Button {
                        let newRating = (annotation?.rating == star) ? 0 : star
                        annotation?.rating = newRating
                        debouncedSave()
                    } label: {
                        Image(systemName: (annotation?.rating ?? 0) >= star ? "star.fill" : "star")
                            .foregroundStyle((annotation?.rating ?? 0) >= star ? .yellow : .secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .animation(.snappy(duration: 0.2), value: annotation?.rating)

            // Tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let tags = annotation?.tags, !tags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.caption)
                                Button {
                                    annotation?.tags.removeAll { $0 == tag }
                                    debouncedSave()
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(minHeight: 34)
                            .background(.quaternary, in: Capsule())
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.snappy(duration: 0.2), value: tags)
                }

                HStack {
                    TextField("Add tag", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onSubmit { addTag() }
                    Button("Add") { addTag() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            // Notes
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: Binding(
                    get: { annotation?.notes ?? "" },
                    set: { newValue in
                        annotation?.notes = newValue
                        debouncedSave()
                    }
                ))
                .frame(minHeight: 80)
                .font(.body)
                .scrollContentBackground(.hidden)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .sensoryFeedback(.success, trigger: showSaveConfirmation)
    }

    private func loadOrCreateAnnotation() {
        if let existing = annotationService.albumAnnotation(for: displayAlbum.id.rawValue, in: modelContext) {
            annotation = existing
        } else {
            let new = AlbumAnnotation(albumID: displayAlbum.id.rawValue, title: displayAlbum.title, artistName: displayAlbum.artistName)
            modelContext.insert(new)
            annotation = new
        }
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty else { return }
        if annotation?.tags.contains(tag) == false {
            annotation?.tags.append(tag)
            debouncedSave()
        }
        newTag = ""
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let annotation else { return }
            annotationService.saveAlbumAnnotation(annotation, in: modelContext)
            showSaveConfirmation.toggle()
        }
    }
}

#Preview("Album Detail") {
    PreviewHost {
        PreviewLibraryItemContainer(
            title: "Album Preview",
            symbol: "square.stack",
            load: { await PreviewLibraryLoader.firstAlbum() }
        ) { album in
            NavigationStack {
                AlbumDetailView(album: album)
            }
        }
    }
}
