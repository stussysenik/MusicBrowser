import XCTest
@testable import MusicBrowser

// Mock type conforming to FilterableByLetter for testing
private struct MockSong: FilterableByLetter {
    let title: String
}

final class FilterableProtocolsTests: XCTestCase {

    // MARK: - availableLetters

    func testAvailableLettersBasic() {
        let songs = [
            MockSong(title: "Apple"),
            MockSong(title: "Banana"),
            MockSong(title: "Cherry")
        ]
        let letters = songs.availableLetters
        XCTAssertEqual(letters, ["A", "B", "C"])
    }

    func testAvailableLettersDuplicates() {
        let songs = [
            MockSong(title: "Apple"),
            MockSong(title: "Avocado"),
            MockSong(title: "Banana")
        ]
        let letters = songs.availableLetters
        XCTAssertEqual(letters, ["A", "B"])
    }

    func testAvailableLettersWithNumbers() {
        let songs = [
            MockSong(title: "123 Song"),
            MockSong(title: "Apple")
        ]
        let letters = songs.availableLetters
        XCTAssertEqual(letters, ["#", "A"])
    }

    func testAvailableLettersEmpty() {
        let songs: [MockSong] = []
        XCTAssertEqual(songs.availableLetters, [])
    }

    func testAvailableLettersSorted() {
        let songs = [
            MockSong(title: "Zebra"),
            MockSong(title: "Apple"),
            MockSong(title: "Mango")
        ]
        let letters = songs.availableLetters
        XCTAssertEqual(letters, ["A", "M", "Z"])
    }

    // MARK: - availableLetterSet

    func testAvailableLetterSetContains() {
        let songs = [
            MockSong(title: "Apple"),
            MockSong(title: "Banana")
        ]
        let set = songs.availableLetterSet
        XCTAssertTrue(set.contains("A"))
        XCTAssertTrue(set.contains("B"))
        XCTAssertFalse(set.contains("C"))
    }

    func testAvailableLetterSetWithHash() {
        let songs = [
            MockSong(title: "99 Problems")
        ]
        let set = songs.availableLetterSet
        XCTAssertTrue(set.contains("#"))
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - All 27 letters

    func testAllLettersCovered() {
        var songs: [MockSong] = []
        for char in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" {
            songs.append(MockSong(title: "\(char) Song"))
        }
        songs.append(MockSong(title: "1 Song"))

        let letters = songs.availableLetters
        XCTAssertEqual(letters.count, 27)
        XCTAssertEqual(letters.first, "#")
        XCTAssertEqual(letters.last, "Z")
    }
}
