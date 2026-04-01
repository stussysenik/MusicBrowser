import XCTest
@testable import MusicBrowser

final class TempoBucketsTests: XCTestCase {

    func testLabelBoundaries() {
        XCTAssertEqual(TempoBuckets.label(for: nil), "Unscanned")
        XCTAssertEqual(TempoBuckets.label(for: 89), "Slow Burn")
        XCTAssertEqual(TempoBuckets.label(for: 90), "Cruise")
        XCTAssertEqual(TempoBuckets.label(for: 110), "Pocket")
        XCTAssertEqual(TempoBuckets.label(for: 130), "Drive")
        XCTAssertEqual(TempoBuckets.label(for: 150), "Hyper")
    }

    func testSummaryTracksAnalyzedAndAverage() {
        let summary = TempoBuckets.summary(for: [80, nil, 120, 160])

        XCTAssertEqual(summary.totalCount, 4)
        XCTAssertEqual(summary.analyzedCount, 3)
        XCTAssertEqual(summary.average, 120, accuracy: 0.001)
    }

    func testSummaryForEmptyInputIsZeroed() {
        let summary = TempoBuckets.summary(for: [])

        XCTAssertEqual(summary.totalCount, 0)
        XCTAssertEqual(summary.analyzedCount, 0)
        XCTAssertEqual(summary.average, 0)
    }
}
