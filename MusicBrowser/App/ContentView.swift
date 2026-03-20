import SwiftUI
import SwiftData
import MusicKit

struct ContentView: View {
    @Environment(MusicService.self) private var musicService
    @Environment(PlayerService.self) private var player
    @Environment(AnalysisService.self) private var analysisService
    @Environment(StatsService.self) private var statsService
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedTab") private var selectedTab: Tab = .library
    @State private var showNowPlaying = false

    enum Tab: String, Hashable {
        case library, stats, search
    }

    var body: some View {
        if musicService.isAuthorized {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    LibraryView()
                }
                .tabItem { Label("Library", systemImage: "music.note.list") }
                .tag(Tab.library)

                NavigationStack {
                    StatsView()
                }
                .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }
                .tag(Tab.stats)

                NavigationStack {
                    SearchView()
                }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)
            }
            .overlay(alignment: .bottom) {
                if player.currentTitle != nil {
                    MiniPlayerView(showNowPlaying: $showNowPlaying)
                        .padding(.bottom, 54)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.25), value: player.currentTitle != nil)
            .sheet(isPresented: $showNowPlaying) {
                NowPlayingView()
            }
            .onAppear {
                analysisService.configure(with: modelContext)
                statsService.configure(with: modelContext)
                wireSessionCallbacks()
            }
        } else {
            AuthorizationView()
        }
    }

    /// Connects PlayerService session hooks to StatsService for listening tracking.
    private func wireSessionCallbacks() {
        player.onSongStarted = { songID, title, artist, album, genres, duration, year in
            statsService.startSession(
                songID: songID.rawValue,
                title: title,
                artistName: artist,
                albumTitle: album,
                genreNames: genres,
                songDuration: duration,
                releaseYear: year
            )
        }
        player.onSongEnded = { songID, completed in
            statsService.endSession(songID: songID.rawValue, completed: completed)
        }
    }
}

#Preview("Content Root") {
    PreviewHost {
        ContentView()
    }
}
