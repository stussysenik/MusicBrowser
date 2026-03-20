import Foundation
import Observation

/// Provides mock data for wireframe testing without MusicKit dependency.
/// Activated via `-useMockData` launch argument.
@Observable
final class MockDataService {
    var songs: [MockSong] = []
    var albums: [MockAlbum] = []
    var artists: [MockArtist] = []
    var playlists: [MockPlaylist] = []

    init(includeStressTest: Bool = false) {
        let curated = MockDataGenerator.curatedSongs()
        let all = includeStressTest
            ? curated + MockDataGenerator.stressTestSongs()
            : curated

        songs = all
        albums = MockDataGenerator.deriveAlbums(from: all)
        artists = MockDataGenerator.deriveArtists(from: all)
        playlists = MockDataGenerator.derivePlaylists(from: all)
    }

    func searchResults(for query: String) -> [MockSong] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        return songs.filter {
            $0.title.lowercased().contains(lowered) ||
            $0.artistName.lowercased().contains(lowered) ||
            $0.albumTitle.lowercased().contains(lowered)
        }
    }
}
