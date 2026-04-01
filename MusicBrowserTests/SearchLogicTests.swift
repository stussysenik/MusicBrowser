import XCTest
@testable import MusicBrowser

final class SearchLogicTests: XCTestCase {

    // MARK: - SearchResults emptiness

    func testEmptySearchResults() {
        let results = MusicService.SearchResults(
            songs: [],
            albums: [],
            artists: [],
            playlists: [],
            musicVideos: [],
            source: .library
        )
        XCTAssertTrue(results.songs.isEmpty)
        XCTAssertTrue(results.albums.isEmpty)
        XCTAssertTrue(results.artists.isEmpty)
        XCTAssertTrue(results.playlists.isEmpty)
        XCTAssertTrue(results.musicVideos.isEmpty)
    }

    func testSearchResultsSource() {
        let catalog = MusicService.SearchResults(
            songs: [], albums: [], artists: [], playlists: [], musicVideos: [],
            source: .catalog
        )
        let library = MusicService.SearchResults(
            songs: [], albums: [], artists: [], playlists: [], musicVideos: [],
            source: .library
        )

        switch catalog.source {
        case .catalog: break // expected
        case .library: XCTFail("Expected catalog source")
        }

        switch library.source {
        case .library: break // expected
        case .catalog: XCTFail("Expected library source")
        }
    }

    // MARK: - SearchError

    func testSearchErrorCatalogUnavailable() {
        let error = MusicService.SearchError.catalogUnavailable
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("subscription"),
                      "Error should mention subscription")
    }

    // MARK: - Term normalization

    func testSearchTermTrimming() {
        let term = "  hello world  "
        let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(normalized, "hello world")
    }

    func testSearchTermEmpty() {
        let term = "   "
        let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(normalized.isEmpty)
    }

    func testSearchTermCaseInsensitiveContains() {
        let title = "Bohemian Rhapsody"
        XCTAssertTrue(title.localizedCaseInsensitiveContains("bohemian"))
        XCTAssertTrue(title.localizedCaseInsensitiveContains("RHAPSODY"))
        XCTAssertFalse(title.localizedCaseInsensitiveContains("stairway"))
    }
}
