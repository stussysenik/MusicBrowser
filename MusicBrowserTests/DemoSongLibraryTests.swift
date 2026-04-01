import XCTest
@testable import MusicBrowser

final class DemoSongLibraryTests: XCTestCase {

    func testDemoLibraryCoversWholeAlphabetAndHashBucket() {
        XCTAssertEqual(DemoSongLibrary.songs.availableLetters.count, 27)
        XCTAssertTrue(DemoSongLibrary.songs.availableLetters.contains("#"))
        XCTAssertTrue(DemoSongLibrary.songs.availableLetters.contains("Z"))
    }

    func testGroupedAsDemoAlbumsUsesPersistentAlbumIDWhenAvailable() {
        let first = DemoSong(
            id: "one",
            title: "Track One",
            artistName: "Artist",
            albumTitle: "Shared Title",
            duration: 180,
            genreNames: ["Pop"],
            playCount: 1,
            releaseYear: 2024,
            bpm: 120,
            mediaPersistentID: 101,
            albumPersistentID: 1
        )
        let second = DemoSong(
            id: "two",
            title: "Track Two",
            artistName: "Artist",
            albumTitle: "Shared Title",
            duration: 181,
            genreNames: ["Pop"],
            playCount: 2,
            releaseYear: 2024,
            bpm: 121,
            mediaPersistentID: 102,
            albumPersistentID: 2
        )

        let grouped = [first, second].groupedAsDemoAlbums

        XCTAssertEqual(grouped.count, 2)
        XCTAssertEqual(Set(grouped.map(\.songs.count)), [1])
    }

    func testGroupedAsDemoAlbumsFallsBackToAlbumTitleAndArtist() {
        let first = DemoSong(
            id: "one",
            title: "Track One",
            artistName: "Artist",
            albumTitle: "Shared Title",
            duration: 180,
            genreNames: ["Pop"],
            playCount: 1,
            releaseYear: 2024,
            bpm: 120
        )
        let second = DemoSong(
            id: "two",
            title: "Track Two",
            artistName: "Artist",
            albumTitle: "Shared Title",
            duration: 181,
            genreNames: ["Pop"],
            playCount: 2,
            releaseYear: 2024,
            bpm: 121
        )

        let grouped = [first, second].groupedAsDemoAlbums

        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped.first?.songs.count, 2)
        XCTAssertEqual(grouped.first?.title, "Shared Title")
    }
}
