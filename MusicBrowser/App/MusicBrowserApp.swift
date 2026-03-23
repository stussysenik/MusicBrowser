import SwiftUI
import SwiftData
import MusicKit

@main
struct MusicBrowserApp: App {
    @State private var musicService = MusicService()
    @State private var playerService = PlayerService()
    @State private var analysisService = AnalysisService()
    @State private var annotationService = AnnotationService()

    let container: ModelContainer

    init() {
        let config = ModelConfiguration(cloudKitDatabase: .automatic)
        let storeURL = config.url

        do {
            container = try ModelContainer(
                for: SongAnnotation.self, SongAnalysis.self, AlbumAnnotation.self,
                migrationPlan: MusicBrowserMigrationPlan.self,
                configurations: config
            )
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
                container = try ModelContainer(
                    for: SongAnnotation.self, SongAnalysis.self, AlbumAnnotation.self,
                    migrationPlan: MusicBrowserMigrationPlan.self,
                    configurations: config
                )
            } catch {
                fatalError("Failed to create ModelContainer after store reset: \(error)")
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
                    let status = await MusicAuthorization.request()
                    musicService.isAuthorized = (status == .authorized)
                    if musicService.isAuthorized {
                        Task { await musicService.prefetchSubscriptionStatus() }
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
