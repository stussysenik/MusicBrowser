import SwiftUI
import SwiftData
import MusicKit

struct SongDetailView: View {
    let song: Song
    @Environment(PlayerService.self) private var player
    @Environment(AnalysisService.self) private var analysisService
    @Environment(AnnotationService.self) private var annotationService
    @Environment(\.modelContext) private var modelContext

    @State private var isSeeking = false
    @State private var seekTime: TimeInterval = 0
    @State private var annotation: SongAnnotation?
    @State private var newTag = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var showSaveConfirmation = false

    private var isCurrentSong: Bool {
        player.currentSongID == song.id
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                artworkSection
                titleSection
                actionButtons
                if isCurrentSong {
                    progressBar
                    listeningActions
                    playbackControls
                }
                metadataGrid
                if annotation != nil {
                    annotationSection
                }
            }
            .padding()
        }
        .navigationTitle(song.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            loadOrCreateAnnotation()
        }
        .onDisappear {
            saveTask?.cancel()
            if annotation != nil { try? modelContext.save() }
        }
    }

    // MARK: - Artwork

    private var artworkSection: some View {
        ArtworkView(artwork: song.artwork, size: 280)
            .frame(maxWidth: 320)
            .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 4) {
            Text(song.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(song.artistName)
                .font(.title3)
                .foregroundStyle(.secondary)

            if let albumTitle = song.albumTitle {
                Text(albumTitle)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                Task { try? await player.playSong(song) }
            } label: {
                Label(isCurrentSong && player.isPlaying ? "Playing" : "Play", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                Task { try? await player.playNext(song) }
            } label: {
                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                Task { try? await player.addToQueue(song) }
            } label: {
                Label("Queue", systemImage: "text.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    // MARK: - Progress Bar (live when this song is playing)

    private var progressBar: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { isSeeking ? seekTime : player.playbackTime },
                    set: { newVal in
                        isSeeking = true
                        seekTime = newVal
                    }
                ),
                in: 0...max(player.currentDuration, 1),
                onEditingChanged: { editing in
                    if !editing {
                        player.seek(to: seekTime)
                        isSeeking = false
                    }
                }
            )
            .tint(.accentColor)

            HStack {
                Text(formatDurationLong(isSeeking ? seekTime : player.playbackTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("-" + formatDurationLong(max(0, player.currentDuration - (isSeeking ? seekTime : player.playbackTime))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 40) {
            Button {
                Task { try? await player.skipBackward() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }

            Button {
                Task { try? await player.togglePlayPause() }
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 50))
            }

            Button {
                Task { try? await player.skipForward() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var listeningActions: some View {
        HStack {
            Button {
                captureTimestamp()
            } label: {
                Label("Capture Timestamp", systemImage: "waveform.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Metadata Grid

    private var metadataGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
        ], spacing: 16) {
            if let duration = song.duration {
                metadataCell("Duration", value: formatDurationLong(duration), icon: "clock")
            }

            if !song.genreNames.isEmpty {
                metadataCell("Genre", value: song.genreNames.joined(separator: ", "), icon: "guitars")
            }

            if let releaseDate = song.releaseDate {
                metadataCell("Released", value: releaseDate.formatted(.dateTime.year().month().day()), icon: "calendar")
            }

            if let playCount = song.playCount {
                metadataCell("Play Count", value: "\(playCount)", icon: "play.circle")
            }

            if let lastPlayed = song.lastPlayedDate {
                metadataCell("Last Played", value: lastPlayed.formatted(.relative(presentation: .named)), icon: "clock.arrow.circlepath")
            }

            if let bpm = analysisService.bpm(for: song) {
                metadataCell("BPM", value: "\(Int(bpm))", icon: "metronome")
            }
        }
        .padding(.top, 8)
    }

    private func metadataCell(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.callout)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
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
                HStack {
                    Text("Notes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isCurrentSong {
                        Button("Capture Timestamp") {
                            captureTimestamp()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
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
        if let existing = annotationService.annotation(for: song.id.rawValue, in: modelContext) {
            annotation = existing
        } else {
            let new = SongAnnotation(songID: song.id.rawValue, title: song.title, artistName: song.artistName)
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
            annotationService.saveAnnotation(annotation, in: modelContext)
            showSaveConfirmation.toggle()
        }
    }

    private func captureTimestamp() {
        let token = "[\(formatDurationLong(player.playbackTime))] "
        if annotation?.notes.isEmpty == false {
            annotation?.notes += "\n\(token)"
        } else {
            annotation?.notes = token
        }
        debouncedSave()
    }

}

#Preview("Song Detail") {
    PreviewHost {
        PreviewLibraryItemContainer(
            title: "Song Preview",
            symbol: "music.note",
            load: { await PreviewLibraryLoader.firstSong() }
        ) { song in
            NavigationStack {
                SongDetailView(song: song)
            }
        }
    }
}
