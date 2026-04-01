import Foundation
import Observation
import SwiftData

@Observable
final class AnnotationService {
    func annotation(for songID: String, in context: ModelContext) -> SongAnnotation? {
        let predicate = #Predicate<SongAnnotation> { $0.songID == songID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func saveAnnotation(_ annotation: SongAnnotation, in context: ModelContext) {
        annotation.updatedAt = .now
        context.insert(annotation)
        try? context.save()
    }

    func allAnnotations(in context: ModelContext) -> [SongAnnotation] {
        let descriptor = FetchDescriptor<SongAnnotation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Album Annotations

    func albumAnnotation(for albumID: String, in context: ModelContext) -> AlbumAnnotation? {
        let predicate = #Predicate<AlbumAnnotation> { $0.albumID == albumID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func saveAlbumAnnotation(_ annotation: AlbumAnnotation, in context: ModelContext) {
        annotation.updatedAt = .now
        context.insert(annotation)
        try? context.save()
    }

    func allAlbumAnnotations(in context: ModelContext) -> [AlbumAnnotation] {
        let descriptor = FetchDescriptor<AlbumAnnotation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func exportJSON(in context: ModelContext) throws -> Data {
        let annotations = allAnnotations(in: context)
        let payload = annotations.map { ExportEntry(from: $0) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    func exportAllNotesJSON(in context: ModelContext) throws -> Data {
        let songAnnotations = allAnnotations(in: context).map(ExportNoteEntry.song)
        let albumAnnotations = allAlbumAnnotations(in: context).map(ExportNoteEntry.album)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode((songAnnotations + albumAnnotations).sorted { $0.updatedAt > $1.updatedAt })
    }
}

private struct ExportEntry: Codable {
    let songID: String
    let title: String
    let artistName: String
    let notes: String
    let tags: [String]
    let rating: Int
    let createdAt: Date
    let updatedAt: Date

    init(from annotation: SongAnnotation) {
        songID = annotation.songID
        title = annotation.title
        artistName = annotation.artistName
        notes = annotation.notes
        tags = annotation.tags
        rating = annotation.rating
        createdAt = annotation.createdAt
        updatedAt = annotation.updatedAt
    }
}

private struct ExportNoteEntry: Codable {
    let kind: String
    let itemID: String
    let title: String
    let artistName: String
    let notes: String
    let tags: [String]
    let rating: Int
    let noteCharacterCount: Int
    let timestampCount: Int
    let timestamps: [String]
    let createdAt: Date
    let updatedAt: Date

    static func song(_ annotation: SongAnnotation) -> ExportNoteEntry {
        ExportNoteEntry(
            kind: "song",
            itemID: annotation.songID,
            title: annotation.title,
            artistName: annotation.artistName,
            notes: annotation.notes,
            tags: annotation.tags,
            rating: annotation.rating,
            noteCharacterCount: NoteHyperData.characterCount(in: annotation.notes),
            timestampCount: NoteHyperData.timestampCount(in: annotation.notes),
            timestamps: NoteHyperData.timestamps(in: annotation.notes),
            createdAt: annotation.createdAt,
            updatedAt: annotation.updatedAt
        )
    }

    static func album(_ annotation: AlbumAnnotation) -> ExportNoteEntry {
        ExportNoteEntry(
            kind: "album",
            itemID: annotation.albumID,
            title: annotation.title,
            artistName: annotation.artistName,
            notes: annotation.notes,
            tags: annotation.tags,
            rating: annotation.rating,
            noteCharacterCount: NoteHyperData.characterCount(in: annotation.notes),
            timestampCount: NoteHyperData.timestampCount(in: annotation.notes),
            timestamps: NoteHyperData.timestamps(in: annotation.notes),
            createdAt: annotation.createdAt,
            updatedAt: annotation.updatedAt
        )
    }
}
