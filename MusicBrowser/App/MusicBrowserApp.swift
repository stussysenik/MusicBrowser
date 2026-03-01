import SwiftUI
import SwiftData
import MusicKit

@main
struct MusicBrowserApp: App {
    @State private var musicService = MusicService()
    @State private var playerService = PlayerService()
    @State private var analysisService = AnalysisService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(musicService)
                .environment(playerService)
                .environment(analysisService)
                .task {
                    let status = await MusicAuthorization.request()
                    musicService.isAuthorized = (status == .authorized)
                }
        }
        .modelContainer(for: SongAnalysis.self)
        #if os(macOS)
        .defaultSize(width: 1100, height: 750)
        #endif
    }
}
