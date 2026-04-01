import SwiftUI
import SwiftData

struct DemoSongDetailView: View {
    let song: DemoSong

    @Environment(PlayerService.self) private var player
    @Environment(AnalysisService.self) private var analysisService
    @Environment(AnnotationService.self) private var annotationService
    @Environment(\.modelContext) private var modelContext

    @State private var annotation: SongAnnotation?
    @State private var newTag = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var showSaveConfirmation = false
    @State private var showPlaylistSheet = false

    private var isCurrentSong: Bool {
        player.currentTrackID == song.id
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                DemoArtworkTile(title: song.title)
                titleSection
                controls
                if isCurrentSong {
                    progressBar
                    listeningActions
                }
                metadataGrid
                annotationSection
            }
            .padding()
        }
        .navigationTitle(song.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showPlaylistSheet) {
            DemoAddToPlaylistSheet(songs: [song])
        }
        .onAppear {
            loadOrCreateAnnotation()
        }
    }

    private var titleSection: some View {
        VStack(spacing: 6) {
            Text(song.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(song.artistName)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(song.albumTitle)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    player.playDemoSong(song)
                } label: {
                    Label(isCurrentSong && player.isPlaying ? "Playing" : "Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("demo-song-play")

                Button {
                    player.playDemoNext(song)
                } label: {
                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("demo-song-play-next")
            }

            HStack(spacing: 12) {
                Button {
                    player.addDemoSongToQueue(song)
                } label: {
                    Label("Queue", systemImage: "text.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("demo-song-queue")

                Button {
                    showPlaylistSheet = true
                } label: {
                    Label("Playlist", systemImage: "music.note.list")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("demo-song-playlist")
            }
        }
        .controlSize(.large)
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { player.playbackTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.currentDuration, 1)
            )

            HStack {
                Text(formatDurationLong(player.playbackTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("-" + formatDurationLong(max(0, player.currentDuration - player.playbackTime)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
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
            .accessibilityIdentifier("demo-song-capture-timestamp")
        }
        .controlSize(.large)
    }

    private var metadataGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            metadataCell("Duration", value: formatDurationLong(song.duration), icon: "clock")
            metadataCell("Year", value: "\(song.releaseYear)", icon: "calendar")
            metadataCell("Genre", value: song.genreNames.joined(separator: ", "), icon: "guitars")
            metadataCell("BPM", value: "\(Int(analysisService.bpm(for: song) ?? song.bpm))", icon: "metronome")
        }
    }

    private func metadataCell(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.secondary)
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
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    private var annotationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Annotations")
                .font(.headline)

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
                    }
                    .buttonStyle(.plain)
                }
            }

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
                            .background(.quaternary, in: Capsule())
                        }
                    }
                }

                HStack {
                    TextField("Add tag", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onSubmit { addTag() }
                    Button("Add") { addTag() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
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
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
        .sensoryFeedback(.success, trigger: showSaveConfirmation)
    }

    private func loadOrCreateAnnotation() {
        if let existing = annotationService.annotation(for: song.id, in: modelContext) {
            annotation = existing
        } else {
            let new = SongAnnotation(songID: song.id, title: song.title, artistName: song.artistName)
            modelContext.insert(new)
            annotation = new
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if annotation?.tags.contains(trimmed) == false {
            annotation?.tags.append(trimmed)
            debouncedSave()
        }
        newTag = ""
    }

    private func captureTimestamp() {
        let stamp = "[\(formatDurationLong(player.playbackTime))]"
        let existing = annotation?.notes ?? ""
        annotation?.notes = existing.isEmpty ? "\(stamp) " : "\(existing)\n\(stamp) "
        debouncedSave()
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
}

struct DemoArtworkTile: View {
    let title: String

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: Double(abs(title.hashValue % 360)) / 360.0, saturation: 0.45, brightness: 0.92),
                        Color.black.opacity(0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 240, height: 240)
            .overlay {
                Text(String(title.prefix(1)))
                    .font(.system(size: 70, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}
