import XCTest
@testable import MusicBrowser

final class NoteHyperDataTests: XCTestCase {

    func testExtractsPlaybackTimestamps() {
        let notes = """
        Opening texture
        [0:42] vocal enters
        [12:03] huge switch
        """

        XCTAssertEqual(NoteHyperData.timestamps(in: notes), ["0:42", "12:03"])
        XCTAssertEqual(NoteHyperData.timestampCount(in: notes), 2)
    }

    func testCharacterCountTrimsWhitespace() {
        XCTAssertEqual(NoteHyperData.characterCount(in: "  hello world  "), 11)
    }

    func testPreviewTagsLimitsOutput() {
        XCTAssertEqual(
            NoteHyperData.previewTags(["favorite", "mix", "late-night"]),
            "favorite • mix"
        )
    }
}
