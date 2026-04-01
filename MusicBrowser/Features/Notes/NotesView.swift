import SwiftUI
import SwiftData
import MusicKit

/// Notes tab — lists all annotated songs and albums sorted by most recently updated.
/// Each row shows the item title, artist, first line of notes, star rating,
/// and relative timestamp. Tapping a row resolves the item via MusicKit
/// and navigates to the appropriate detail view.
struct NotesView: View {
    @Environment(MusicService.self) private var musicService
    @Environment(AnnotationService.self) private var annotationService
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SongAnnotation.updatedAt, order: .reverse)
    private var annotations: [SongAnnotation]

    @Query(sort: \AlbumAnnotation.updatedAt, order: .reverse)
    private var albumAnnotations: [AlbumAnnotation]

    @State private var searchText = ""
    @State private var noteFilter: NoteFilter = .all
    #if os(iOS)
    @State private var exportURL: ExportURL?
    #else
    @State private var isExporting = false
    @State private var exportDocument = NotesExportDocument(data: Data("[]".utf8))
    #endif

    // MARK: - Filter Enum

    enum NoteFilter: String, CaseIterable {
        case all = "All"
        case songs = "Songs"
        case albums = "Albums"
    }

    // MARK: - Unified Note Item

    enum NoteItem: Identifiable {
        case song(SongAnnotation)
        case album(AlbumAnnotation)

        var id: String {
            switch self {
            case .song(let a): return "song-\(a.songID)"
            case .album(let a): return "album-\(a.albumID)"
            }
        }
        var title: String {
            switch self { case .song(let a): return a.title; case .album(let a): return a.title }
        }
        var artistName: String {
            switch self { case .song(let a): return a.artistName; case .album(let a): return a.artistName }
        }
        var notes: String {
            switch self { case .song(let a): return a.notes; case .album(let a): return a.notes }
        }
        var rating: Int {
            switch self { case .song(let a): return a.rating; case .album(let a): return a.rating }
        }
        var tags: [String] {
            switch self { case .song(let a): return a.tags; case .album(let a): return a.tags }
        }
        var updatedAt: Date {
            switch self { case .song(let a): return a.updatedAt; case .album(let a): return a.updatedAt }
        }
        var isSong: Bool {
            if case .song = self { return true } else { return false }
        }
        var timestampLabels: [String] {
            NoteHyperData.timestamps(in: notes)
        }
        var timestampCount: Int {
            timestampLabels.count
        }
        var noteCharacterCount: Int {
            NoteHyperData.characterCount(in: notes)
        }
        var previewTags: String? {
            NoteHyperData.previewTags(tags)
        }
    }

    // MARK: - Filtered / Merged List

    private var noteItems: [NoteItem] {
        var items: [NoteItem] = []
        if noteFilter != .albums {
            let filtered = searchText.isEmpty ? Array(annotations) : annotations.filter { annotation in
                SearchMatcher.matches(term: searchText, fields: [
                    annotation.title,
                    annotation.artistName,
                    annotation.notes,
                    annotation.tags.joined(separator: " "),
                    NoteHyperData.timestamps(in: annotation.notes).joined(separator: " ")
                ])
            }
            items += filtered.map { .song($0) }
        }
        if noteFilter != .songs {
            let filtered = searchText.isEmpty ? Array(albumAnnotations) : albumAnnotations.filter { annotation in
                SearchMatcher.matches(term: searchText, fields: [
                    annotation.title,
                    annotation.artistName,
                    annotation.notes,
                    annotation.tags.joined(separator: " "),
                    NoteHyperData.timestamps(in: annotation.notes).joined(separator: " ")
                ])
            }
            items += filtered.map { .album($0) }
        }
        return items.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if noteItems.isEmpty {
                ContentUnavailableView(
                    "No Notes",
                    systemImage: "note.text",
                    description: Text("Annotate songs or albums to see them here.")
                )
            } else {
                List(noteItems) { item in
                    switch item {
                    case .song(let annotation):
                        NavigationLink(value: annotation) {
                            NoteItemRow(item: item)
                        }
                    case .album(let annotation):
                        NavigationLink(value: annotation) {
                            NoteItemRow(item: item)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Notes")
        .searchable(text: $searchText, prompt: "Search notes, tags, timestamps")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Filter", selection: $noteFilter) {
                    ForEach(NoteFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            ToolbarItem(placement: .primaryAction) {
                if !noteItems.isEmpty {
                    Button {
                        exportNotes()
                    } label: {
                        Label("Export Notes", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        #if os(iOS)
        .sheet(item: $exportURL) { export in
            UIKitActivitySheet(activityItems: [export.url])
        }
        #else
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "musicbrowser-notes"
        ) { _ in }
        #endif
        .navigationDestination(for: SongAnnotation.self) { annotation in
            if musicService.runtime.usesDummyData,
               let song = musicService.dummySong(byID: annotation.songID) {
                DemoSongDetailView(song: song)
            } else {
                SongLoader(songID: annotation.songID)
            }
        }
        .navigationDestination(for: AlbumAnnotation.self) { annotation in
            if musicService.runtime.usesDummyData,
               let album = musicService.dummyAlbum(byID: annotation.albumID) {
                DemoAlbumDetailView(album: album)
            } else {
                AlbumLoader(albumID: annotation.albumID)
            }
        }
    }

    private func exportNotes() {
        guard let data = try? annotationService.exportAllNotesJSON(in: modelContext) else { return }
        #if os(iOS)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("musicbrowser-notes-\(UUID().uuidString)")
            .appendingPathExtension("json")
        do {
            try data.write(to: url, options: .atomic)
            exportURL = ExportURL(url: url)
        } catch {
            return
        }
        #else
        exportDocument = NotesExportDocument(data: data)
        isExporting = true
        #endif
    }
}

// MARK: - Note Item Row

private struct NoteItemRow: View {
    let item: NotesView.NoteItem

    private var iconName: String {
        item.isSong ? "music.note" : "square.stack"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .lineLimit(1)
                Text(item.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let firstLine = item.notes.components(separatedBy: .newlines).first,
                   !firstLine.isEmpty {
                    Text(firstLine)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Label(item.isSong ? "Song" : "Album", systemImage: item.isSong ? "music.note" : "square.stack")
                    if item.timestampCount > 0 {
                        Label("\(item.timestampCount) timestamps", systemImage: "waveform")
                    }
                    if let previewTags = item.previewTags {
                        Text(previewTags)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if item.rating > 0 {
                    HStack(spacing: 1) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= item.rating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(star <= item.rating ? Color.yellow : Color.secondary.opacity(0.3))
                        }
                    }
                }
                Text("\(item.noteCharacterCount) chars")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(item.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#if os(iOS)
private struct ExportURL: Identifiable {
    let id = UUID()
    let url: URL
}
#endif

// MARK: - Song Loader

/// Intermediate destination view that resolves a songID to a MusicKit Song
/// asynchronously, then displays SongDetailView once loaded.
private struct SongLoader: View {
    let songID: String
    @Environment(MusicService.self) private var musicService
    @State private var song: Song?
    @State private var failed = false

    var body: some View {
        Group {
            if let song {
                SongDetailView(song: song)
            } else if failed {
                ContentUnavailableView(
                    "Song Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This song may have been removed from your library.")
                )
            } else {
                ProgressView("Loading song...")
            }
        }
        .task {
            do {
                song = try await musicService.librarySong(byID: songID)
                if song == nil { failed = true }
            } catch {
                failed = true
            }
        }
    }
}

// MARK: - Album Loader

/// Intermediate destination view that resolves an albumID to a MusicKit Album
/// asynchronously, then displays AlbumDetailView once loaded.
private struct AlbumLoader: View {
    let albumID: String
    @Environment(MusicService.self) private var musicService
    @State private var album: Album?
    @State private var failed = false

    var body: some View {
        Group {
            if let album {
                AlbumDetailView(album: album)
            } else if failed {
                ContentUnavailableView(
                    "Album Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This album may have been removed from your library.")
                )
            } else {
                ProgressView("Loading album...")
            }
        }
        .task {
            do {
                album = try await musicService.libraryAlbum(byID: albumID)
                if album == nil { failed = true }
            } catch {
                failed = true
            }
        }
    }
}

#Preview("Notes View") {
    PreviewHost {
        NavigationStack {
            NotesView()
        }
    }
}
