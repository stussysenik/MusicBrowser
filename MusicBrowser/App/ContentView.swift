import SwiftUI
import SwiftData
import MusicKit

struct ContentView: View {
    @Environment(MusicService.self) private var musicService
    @Environment(PlayerService.self) private var player
    @Environment(AnalysisService.self) private var analysisService
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .library
    @State private var showNowPlaying = false

    enum Tab: Hashable {
        case library, search
    }

    var body: some View {
        if musicService.isAuthorized {
            ZStack(alignment: .bottom) {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        LibraryView()
                    }
                    .tabItem { Label("Library", systemImage: "music.note.list") }
                    .tag(Tab.library)

                    NavigationStack {
                        SearchView()
                    }
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(Tab.search)
                }

                if player.currentTitle != nil {
                    MiniPlayerView(showNowPlaying: $showNowPlaying)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        #if os(iOS)
                        .padding(.bottom, 49)
                        #endif
                }
            }
            .animation(.snappy(duration: 0.3), value: player.currentTitle != nil)
            .sheet(isPresented: $showNowPlaying) {
                NowPlayingView()
            }
            .onAppear {
                analysisService.configure(with: modelContext)
            }
        } else {
            AuthorizationView()
        }
    }
}
