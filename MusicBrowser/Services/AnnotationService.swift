import Foundation
import Observation
import SwiftData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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

    func exportJSON(in context: ModelContext) throws -> Data {
        let annotations = allAnnotations(in: context)
        let payload = annotations.map { ExportEntry(from: $0) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    // MARK: - Markdown Export

    func exportMarkdown(in context: ModelContext) -> String {
        let annotations = allAnnotations(in: context)
        guard !annotations.isEmpty else { return "# MusicBrowser Annotations\n\nNo annotations yet." }

        var md = "# MusicBrowser Annotations\n\n"
        md += "Exported: \(ISO8601DateFormatter().string(from: Date()))\n\n"
        md += "---\n\n"

        for annotation in annotations {
            md += "## \(annotation.title)\n"
            md += "**Artist:** \(annotation.artistName)\n\n"
            if !annotation.notes.isEmpty {
                md += "\(annotation.notes)\n\n"
            }
            if !annotation.tags.isEmpty {
                md += "**Tags:** \(annotation.tags.map { "`\($0)`" }.joined(separator: ", "))\n\n"
            }
            if annotation.rating > 0 {
                md += "**Rating:** \(String(repeating: "★", count: annotation.rating))\(String(repeating: "☆", count: max(0, 5 - annotation.rating)))\n\n"
            }
            md += "---\n\n"
        }
        return md
    }

    // MARK: - CSV Export

    func exportCSV(in context: ModelContext) -> String {
        let annotations = allAnnotations(in: context)
        var csv = "Song ID,Title,Artist,Notes,Tags,Rating,Created,Updated\n"
        let dateFormatter = ISO8601DateFormatter()

        for a in annotations {
            let escapedNotes = a.notes.replacingOccurrences(of: "\"", with: "\"\"")
            let tags = a.tags.joined(separator: "; ")
            csv += "\"\(a.songID)\",\"\(a.title)\",\"\(a.artistName)\",\"\(escapedNotes)\",\"\(tags)\",\(a.rating),\(dateFormatter.string(from: a.createdAt)),\(dateFormatter.string(from: a.updatedAt))\n"
        }
        return csv
    }

    // MARK: - Clipboard

    func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
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
