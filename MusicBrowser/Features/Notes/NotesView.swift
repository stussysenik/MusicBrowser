import SwiftUI
import SwiftData
import MusicKit

/// Notes tab — lists all annotated songs and albums sorted by most recently updated.
/// Each row shows the item title, artist, first line of notes, star rating,
/// and relative timestamp. Tapping a row resolves the item via MusicKit
/// and navigates to the appropriate detail view.
struct NotesView: View {
    @Environment(MusicService.self) private var musicService

    @Query(sort: \SongAnnotation.updatedAt, order: .reverse)
    private var annotations: [SongAnnotation]

    @Query(sort: \AlbumAnnotation.updatedAt, order: .reverse)
    private var albumAnnotations: [AlbumAnnotation]

    @State private var searchText = ""
    @State private var noteFilter: NoteFilter = .all

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
    }

    // MARK: - Filtered / Merged List

    private var noteItems: [NoteItem] {
        var items: [NoteItem] = []
        if noteFilter != .albums {
            let filtered = searchText.isEmpty ? Array(annotations) : annotations.filter { annotation in
                annotation.title.localizedCaseInsensitiveContains(searchText)
                || annotation.artistName.localizedCaseInsensitiveContains(searchText)
                || annotation.notes.localizedCaseInsensitiveContains(searchText)
                || annotation.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
            items += filtered.map { .song($0) }
        }
        if noteFilter != .songs {
            let filtered = searchText.isEmpty ? Array(albumAnnotations) : albumAnnotations.filter { annotation in
                annotation.title.localizedCaseInsensitiveContains(searchText)
                || annotation.artistName.localizedCaseInsensitiveContains(searchText)
                || annotation.notes.localizedCaseInsensitiveContains(searchText)
                || annotation.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
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
        .searchable(text: $searchText, prompt: "Search notes")
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
        }
        .navigationDestination(for: SongAnnotation.self) { annotation in
            SongLoader(songID: annotation.songID)
        }
        .navigationDestination(for: AlbumAnnotation.self) { annotation in
            AlbumLoader(albumID: annotation.albumID)
        }
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
                Text(item.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

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
