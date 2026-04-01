import XCTest
@testable import MusicBrowser

final class SortOptionsTests: XCTestCase {

    // MARK: - SongSortOption.isAPISort

    func testAPISortableOptions() {
        let apiSortable: [SongSortOption] = [.title, .artist, .albumTitle, .dateAdded, .releaseDate, .playCount, .lastPlayed]
        for option in apiSortable {
            XCTAssertTrue(option.isAPISort, "\(option.rawValue) should be API sortable")
        }
    }

    func testNonAPISortableOptions() {
        let nonApiSortable: [SongSortOption] = [.duration, .bpm]
        for option in nonApiSortable {
            XCTAssertFalse(option.isAPISort, "\(option.rawValue) should NOT be API sortable")
        }
    }

    func testAllSongSortOptionsCovered() {
        // Ensure we haven't missed any new cases
        XCTAssertEqual(SongSortOption.allCases.count, 9, "Expected 9 sort options")
    }

    // MARK: - AlbumSortOption.isAPISort

    func testAlbumSortOptionsAllAPISortable() {
        for option in AlbumSortOption.allCases {
            XCTAssertTrue(option.isAPISort, "\(option.rawValue) should be API sortable")
        }
    }

    // MARK: - SortDirection

    func testSortDirectionToggle() {
        var direction = SortDirection.ascending
        XCTAssertTrue(direction.isAscending)

        direction.toggle()
        XCTAssertFalse(direction.isAscending)
        XCTAssertEqual(direction, .descending)

        direction.toggle()
        XCTAssertTrue(direction.isAscending)
        XCTAssertEqual(direction, .ascending)
    }

    func testSortDirectionSystemImage() {
        XCTAssertEqual(SortDirection.ascending.systemImage, "chevron.up")
        XCTAssertEqual(SortDirection.descending.systemImage, "chevron.down")
    }

    func testSortDirectionIsAscending() {
        XCTAssertTrue(SortDirection.ascending.isAscending)
        XCTAssertFalse(SortDirection.descending.isAscending)
    }

    // MARK: - SongGrouping

    func testSongGroupingCases() {
        XCTAssertEqual(SongGrouping.allCases.count, 4)
        XCTAssertEqual(SongGrouping.letter.rawValue, "Letter")
        XCTAssertEqual(SongGrouping.year.rawValue, "Year")
        XCTAssertEqual(SongGrouping.decade.rawValue, "Decade")
        XCTAssertEqual(SongGrouping.tempo.rawValue, "Tempo")
    }

    // MARK: - AlbumGrouping

    func testAlbumGroupingCases() {
        XCTAssertEqual(AlbumGrouping.allCases.count, 4)
        XCTAssertEqual(AlbumGrouping.none.rawValue, "None")
        XCTAssertEqual(AlbumGrouping.artist.rawValue, "Artist")
    }

    // MARK: - PlaylistSortOption

    func testPlaylistSortOptionCases() {
        XCTAssertEqual(PlaylistSortOption.allCases.count, 3)
        XCTAssertEqual(PlaylistSortOption.name.rawValue, "Name")
    }
}
