import SwiftUI
import SwiftData
import MusicKit

@main
struct MusicBrowserApp: App {
    private let runtime: AppRuntime
    @State private var musicService: MusicService
    @State private var playerService: PlayerService
    @State private var analysisService: AnalysisService
    @State private var annotationService: AnnotationService

    let container: ModelContainer

    init() {
        StringArrayTransformer.register()
        let runtime = AppRuntime.current
        self.runtime = runtime
        _musicService = State(initialValue: MusicService(runtime: runtime))
        _playerService = State(initialValue: PlayerService(runtime: runtime))
        _analysisService = State(initialValue: AnalysisService(runtime: runtime))
        _annotationService = State(initialValue: AnnotationService())

        let config: ModelConfiguration
        if runtime.usesDummyData, let storeURL = runtime.storeURL {
            try? FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        } else {
            config = ModelConfiguration(cloudKitDatabase: .none)
        }
        let storeURL = config.url

        func makeContainer(using configuration: ModelConfiguration) throws -> ModelContainer {
            return try ModelContainer(
                for: MusicBrowserSchemaV3.SongAnnotation.self,
                MusicBrowserSchemaV3.SongAnalysis.self,
                MusicBrowserSchemaV3.AlbumAnnotation.self,
                configurations: configuration
            )
        }

        do {
            container = try makeContainer(using: config)
        } catch {
            // Destructive fallback — delete corrupt/unmigrateable store and retry
            print("Store failed to load, resetting: \(error)")
            try? FileManager.default.removeItem(at: storeURL)
            for suffix in ["-wal", "-shm"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: storeURL.path + suffix)
                )
            }
            do {
                container = try makeContainer(using: config)
            } catch {
                print("Store retry failed, falling back to in-memory storage: \(error)")
                let inMemoryConfig = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                do {
                    container = try makeContainer(using: inMemoryConfig)
                } catch {
                    fatalError("Failed to create ModelContainer after in-memory fallback: \(error)")
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(musicService)
                .environment(playerService)
                .environment(analysisService)
                .environment(annotationService)
                .task {
                    if runtime.requiresMusicAuthorization {
                        musicService.isAuthorized = MusicAuthorization.currentStatus == .authorized
                    } else {
                        musicService.isAuthorized = true
                        #if os(iOS)
                        await musicService.prepareFallbackLibraryIfPossible(requestAccess: true)
                        #endif
                    }
                }
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1100, height: 750)
        #endif
    }
}

#Preview("App Root") {
    PreviewHost {
        ContentView()
    }
}
