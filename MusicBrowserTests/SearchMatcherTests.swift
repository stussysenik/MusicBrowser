import XCTest
@testable import MusicBrowser

final class SearchMatcherTests: XCTestCase {

    func testMatchesAcrossMultipleFields() {
        XCTAssertTrue(
            SearchMatcher.matches(
                term: "radio kid",
                fields: ["Everything in Its Right Place", "Radiohead", "Kid A"]
            )
        )
    }

    func testMatchesIgnoringCaseAndDiacritics() {
        XCTAssertTrue(
            SearchMatcher.matches(
                term: "elan",
                fields: ["Élan", "Demo Artist"]
            )
        )
    }

    func testRequiresAllTokensToMatch() {
        XCTAssertFalse(
            SearchMatcher.matches(
                term: "radio jazz",
                fields: ["Everything in Its Right Place", "Radiohead", "Kid A"]
            )
        )
    }
}
