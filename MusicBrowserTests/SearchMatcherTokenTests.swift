import XCTest
@testable import MusicBrowser

final class SearchMatcherTokenTests: XCTestCase {

    func testTokenizeDropsPunctuationAndNormalizesCase() {
        XCTAssertEqual(
            SearchMatcher.tokenize("  Björk, Post-Human!  "),
            ["bjork", "post", "human"]
        )
    }

    func testEmptySearchStillMatches() {
        XCTAssertTrue(SearchMatcher.matches(term: "   ", fields: ["Anything"]))
    }
}
