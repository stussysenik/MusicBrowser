import Foundation
import SwiftData
import CoreData

@objc(StringArrayTransformer)
final class StringArrayTransformer: NSSecureUnarchiveFromDataTransformer {
    override class var allowedTopLevelClasses: [AnyClass] {
        [NSArray.self, NSString.self]
    }

    static func register() {
        let name = NSValueTransformerName(rawValue: String(describing: StringArrayTransformer.self))
        guard ValueTransformer(forName: name) == nil else { return }
        ValueTransformer.setValueTransformer(StringArrayTransformer(), forName: name)
    }
}

private enum TagCodec {
    static func decode(_ raw: String) -> [String] {
        raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func encode(_ tags: [String]) -> String {
        tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ",")
    }
}

// MARK: - Schema V1 (original schema with tags as [String])

enum MusicBrowserSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [SongAnnotationV1.self, SongAnalysisV1.self]
    }

    @Model
    final class SongAnnotationV1 {
        @Attribute(.unique) var songID: String
        var title: String
        var artistName: String
        var notes: String
        @Attribute(.transformable(by: StringArrayTransformer.self))
        var tags: [String]
        var rating: Int
        var createdAt: Date
        var updatedAt: Date

        init(songID: String, title: String, artistName: String) {
            self.songID = songID
            self.title = title
            self.artistName = artistName
            self.notes = ""
            self.tags = []
            self.rating = 0
            self.createdAt = .now
            self.updatedAt = .now
        }
    }

    @Model
    final class SongAnalysisV1 {
        @Attribute(.unique) var songID: String
        var title: String
        var artistName: String
        var bpm: Double?
        var musicalKey: String?
        var keyConfidence: Double?
        var analysisDate: Date?
        var analysisVersion: Int

        init(songID: String, title: String, artistName: String) {
            self.songID = songID
            self.title = title
            self.artistName = artistName
            self.analysisVersion = 1
        }
    }
}

// MARK: - Schema V2 (current schema — tagsRaw: String, added bpmSource/bpmConfidence)

enum MusicBrowserSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [SongAnnotation.self, SongAnalysis.self]
    }

    @Model
    final class SongAnnotation {
        @Attribute(.unique) var songID: String
        var title: String
        var artistName: String
        var notes: String
        var tagsRaw: String
        var rating: Int
        var createdAt: Date
        var updatedAt: Date

        var tags: [String] {
            get { TagCodec.decode(tagsRaw) }
            set { tagsRaw = TagCodec.encode(newValue) }
        }

        init(songID: String, title: String, artistName: String) {
            self.songID = songID
            self.title = title
            self.artistName = artistName
            self.notes = ""
            self.tagsRaw = ""
            self.rating = 0
            self.createdAt = .now
            self.updatedAt = .now
        }
    }

    @Model
    final class SongAnalysis {
        @Attribute(.unique) var songID: String
        var title: String
        var artistName: String
        var bpm: Double?
        var bpmSource: String?
        var bpmConfidence: Double?
        var musicalKey: String?
        var keyConfidence: Double?
        var analysisDate: Date?
        var analysisVersion: Int

        init(songID: String, title: String, artistName: String) {
            self.songID = songID
            self.title = title
            self.artistName = artistName
            self.analysisVersion = 2
        }
    }
}

// MARK: - Schema V3 (adds AlbumAnnotation)

enum MusicBrowserSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [SongAnnotation.self, SongAnalysis.self, AlbumAnnotation.self]
    }

    @Model
    final class SongAnnotation {
        @Attribute(.unique) var songID: String
        var title: String
        var artistName: String
        var notes: String
        var tagsRaw: String
        var rating: Int
        var createdAt: Date
        var updatedAt: Date

        var tags: [String] {
            get { TagCodec.decode(tagsRaw) }
            set { tagsRaw = TagCodec.encode(newValue) }
        }

        init(songID: String, title: String, artistName: String) {
            self.songID = songID
            self.title = title
            self.artistName = artistName
            self.notes = ""
            self.tagsRaw = ""
            self.rating = 0
            self.createdAt = .now
            self.updatedAt = .now
        }
    }

    @Model
    final class SongAnalysis {
        @Attribute(.unique) var songID: String
        var title: String
        var artistName: String
        var bpm: Double?
        var bpmSource: String?
        var bpmConfidence: Double?
        var musicalKey: String?
        var keyConfidence: Double?
        var analysisDate: Date?
        var analysisVersion: Int

        init(songID: String, title: String, artistName: String) {
            self.songID = songID
            self.title = title
            self.artistName = artistName
            self.analysisVersion = 2
        }
    }

    @Model
    final class AlbumAnnotation {
        @Attribute(.unique) var albumID: String
        var title: String
        var artistName: String
        var notes: String
        var tagsRaw: String
        var rating: Int
        var createdAt: Date
        var updatedAt: Date

        var tags: [String] {
            get { TagCodec.decode(tagsRaw) }
            set { tagsRaw = TagCodec.encode(newValue) }
        }

        init(albumID: String, title: String, artistName: String) {
            self.albumID = albumID
            self.title = title
            self.artistName = artistName
            self.notes = ""
            self.tagsRaw = ""
            self.rating = 0
            self.createdAt = .now
            self.updatedAt = .now
        }
    }
}

// MARK: - Migration Plan

enum MusicBrowserMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MusicBrowserSchemaV1.self, MusicBrowserSchemaV2.self, MusicBrowserSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: MusicBrowserSchemaV2.self,
        toVersion: MusicBrowserSchemaV3.self
    )

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: MusicBrowserSchemaV1.self,
        toVersion: MusicBrowserSchemaV2.self,
        willMigrate: { context in
            // Stash tags data before schema change drops the column
            let annotations = try context.fetch(
                FetchDescriptor<MusicBrowserSchemaV1.SongAnnotationV1>()
            )
            var tagMapping: [String: String] = [:]
            for annotation in annotations {
                let joined = annotation.tags.joined(separator: ",")
                if !joined.isEmpty {
                    tagMapping[annotation.songID] = joined
                }
            }
            if !tagMapping.isEmpty {
                UserDefaults.standard.set(tagMapping, forKey: "_migrationTagsV1toV2")
            }
            try context.save()
        },
        didMigrate: { context in
            // Populate tagsRaw from stashed data
            guard let tagMapping = UserDefaults.standard.dictionary(
                forKey: "_migrationTagsV1toV2"
            ) as? [String: String] else { return }

            let annotations = try context.fetch(
                FetchDescriptor<MusicBrowserSchemaV2.SongAnnotation>()
            )
            for annotation in annotations {
                if let raw = tagMapping[annotation.songID] {
                    annotation.tagsRaw = raw
                }
            }
            try context.save()
            UserDefaults.standard.removeObject(forKey: "_migrationTagsV1toV2")
        }
    )
}
