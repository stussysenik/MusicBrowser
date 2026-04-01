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
        case library, notes, search
    }

    private var miniPlayerReservationHeight: CGFloat {
        player.currentTitle != nil ? 84 : 0
    }

    private var miniPlayerBottomPadding: CGFloat {
        #if os(iOS)
        58
        #else
        12
        #endif
    }

    var body: some View {
        if musicService.isAuthorized {
            ZStack(alignment: .bottom) {
                TabView(selection: $selectedTab) {
                    tabRoot {
                        LibraryView()
                    }
                    .tabItem { Label("Library", systemImage: "music.note.list") }
                    .tag(Tab.library)

                    tabRoot {
                        NotesView()
                    }
                    .tabItem { Label("Notes", systemImage: "note.text") }
                    .tag(Tab.notes)

                    tabRoot {
                        SearchView()
                    }
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(Tab.search)
                }
                if player.currentTitle != nil {
                    MiniPlayerView(showNowPlaying: $showNowPlaying)
                        .padding(.bottom, miniPlayerBottomPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.25), value: player.currentTitle != nil)
            .sheet(isPresented: $showNowPlaying) {
                NowPlayingView()
            }
            .onAppear {
                if AppRuntime.current.usesDummyData {
                    selectedTab = .library
                }
                analysisService.configure(with: modelContext)
            }
        } else {
            AuthorizationView()
        }
    }

    @ViewBuilder
    private func tabRoot<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .safeAreaInset(edge: .bottom) {
                    if player.currentTitle != nil {
                        Color.clear.frame(height: miniPlayerReservationHeight)
                    }
                }
        }
    }
}

#Preview("Content Root") {
    PreviewHost {
        ContentView()
    }
}
