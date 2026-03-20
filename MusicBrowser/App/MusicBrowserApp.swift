import SwiftUI
import SwiftData
import MusicKit

@main
struct MusicBrowserApp: App {
    @State private var musicService = MusicService()
    @State private var playerService = PlayerService()
    @State private var analysisService = AnalysisService()
    @State private var presetService = FilterPresetService()
    @State private var lyricsService = LyricsService()
    @State private var annotationService = AnnotationService()
    @State private var statsService = StatsService()
    @State private var discoveryService = DiscoveryService()
    @State private var audioAnalysisService = AudioAnalysisService()

    let useMockData = ProcessInfo.processInfo.arguments.contains("-useMockData")
    let container: ModelContainer

    init() {
        let schema = Schema([SongAnalysis.self, SongAnnotation.self, ListeningSession.self, WeeklyRecap.self])
        let config = ModelConfiguration(cloudKitDatabase: .automatic)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(musicService)
                .environment(playerService)
                .environment(analysisService)
                .environment(presetService)
                .environment(lyricsService)
                .environment(annotationService)
                .environment(statsService)
                .environment(discoveryService)
                .environment(audioAnalysisService)
                .task {
                    if useMockData {
                        // Bypass MusicKit auth for mock data mode
                        musicService.isAuthorized = true
                    } else {
                        let status = await MusicAuthorization.request()
                        musicService.isAuthorized = (status == .authorized)
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
