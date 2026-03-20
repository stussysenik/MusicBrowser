#if DEBUG
import SwiftUI
import SwiftData
import MusicKit

/// Shared preview wrapper that injects app services and an in-memory SwiftData store.
struct PreviewHost<Content: View>: View {
    private let musicService: MusicService
    private let playerService: PlayerService
    private let analysisService: AnalysisService
    private let presetService: FilterPresetService
    private let lyricsService: LyricsService
    private let annotationService: AnnotationService
    private let statsService: StatsService
    private let discoveryService: DiscoveryService
    private let audioAnalysisService: AudioAnalysisService
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        let musicService = MusicService()
        musicService.isAuthorized = true
        self.musicService = musicService
        self.playerService = PlayerService()
        self.analysisService = AnalysisService()
        self.presetService = FilterPresetService()
        self.lyricsService = LyricsService()
        self.annotationService = AnnotationService()
        self.statsService = StatsService()
        self.discoveryService = DiscoveryService()
        self.audioAnalysisService = AudioAnalysisService()
        self.content = content()
    }

    var body: some View {
        content
            .environment(musicService)
            .environment(playerService)
            .environment(analysisService)
            .environment(presetService)
            .environment(lyricsService)
            .environment(annotationService)
            .environment(statsService)
            .environment(discoveryService)
            .environment(audioAnalysisService)
            .modelContainer(for: [SongAnalysis.self, SongAnnotation.self, ListeningSession.self, WeeklyRecap.self], inMemory: true)
    }
}

enum PreviewLibraryLoader {
    static func firstSong() async -> Song? {
        var request = MusicLibraryRequest<Song>()
        request.limit = 1
        return try? await request.response().items.first
    }

    static func firstAlbum() async -> Album? {
        var request = MusicLibraryRequest<Album>()
        request.limit = 1
        return try? await request.response().items.first
    }

    static func firstArtist() async -> Artist? {
        var request = MusicLibraryRequest<Artist>()
        request.limit = 1
        return try? await request.response().items.first
    }

    static func firstPlaylist() async -> Playlist? {
        var request = MusicLibraryRequest<Playlist>()
        request.limit = 1
        return try? await request.response().items.first
    }
}

struct PreviewLibraryItemContainer<Item, Content: View>: View {
    let title: String
    let symbol: String
    let load: () async -> Item?
    let content: (Item) -> Content
    @State private var item: Item?

    var body: some View {
        Group {
            if let item {
                content(item)
            } else {
                ContentUnavailableView(title, systemImage: symbol)
            }
        }
        .task {
            if item == nil {
                item = await load()
            }
        }
    }
}
#endif
