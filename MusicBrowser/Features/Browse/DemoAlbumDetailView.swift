import SwiftUI
import SwiftData

struct DemoAlbumDetailView: View {
    let album: DemoAlbum

    @Environment(PlayerService.self) private var player
    @Environment(AnnotationService.self) private var annotationService
    @Environment(\.modelContext) private var modelContext

    @State private var annotation: AlbumAnnotation?
    @State private var newTag = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var showSaveConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                DemoArtworkTile(title: album.title)
                VStack(spacing: 6) {
                    Text(album.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(album.artistName)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("\(album.releaseYear) • \(Int(album.averageBPM)) BPM avg")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 16) {
                    Button {
                        player.playDemoAlbum(album)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        player.playDemoAlbumShuffled(album)
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)

                LazyVStack(spacing: 0) {
                    ForEach(Array(album.songs.enumerated()), id: \.element.id) { idx, song in
                        NavigationLink(value: song) {
                            HStack(spacing: 12) {
                                Text("\(idx + 1)")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .trailing)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .font(.body)
                                        .lineLimit(1)
                                    Text(song.artistName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                BPMBadgeView(bpm: song.bpm)

                                Text(formatDuration(song.duration))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)

                        if idx < album.songs.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }

                annotationSection
            }
            .padding()
        }
        .navigationTitle(album.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            loadOrCreateAnnotation()
        }
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
        if let existing = annotationService.albumAnnotation(for: album.id, in: modelContext) {
            annotation = existing
        } else {
            let new = AlbumAnnotation(albumID: album.id, title: album.title, artistName: album.artistName)
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
