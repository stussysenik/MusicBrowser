import XCTest
@testable import MusicBrowser

final class RandomPlaybackPlannerTests: XCTestCase {

    func testPrefersFreshStartOutsideCurrentAndRecent() {
        let plan = RandomPlaybackPlanner.makePlan(
            ids: ["a", "b", "c", "d"],
            current: "b",
            recent: ["a", "c"],
            shuffledIDs: ["b", "c", "a", "d"]
        )

        XCTAssertEqual(plan?.startingID, "d")
        XCTAssertEqual(plan?.orderedIDs.first, "d")
    }

    func testFallsBackToNonCurrentWhenFreshPoolIsEmpty() {
        let plan = RandomPlaybackPlanner.makePlan(
            ids: ["a", "b", "c"],
            current: "a",
            recent: ["b", "c"],
            shuffledIDs: ["a", "c", "b"]
        )

        XCTAssertEqual(plan?.startingID, "c")
        XCTAssertEqual(plan?.orderedIDs, ["c", "a", "b"])
    }

    func testSingleSongLibraryReturnsThatSong() {
        let plan = RandomPlaybackPlanner.makePlan(
            ids: ["solo"],
            current: "solo",
            recent: ["solo"],
            shuffledIDs: ["solo"]
        )

        XCTAssertEqual(plan?.startingID, "solo")
        XCTAssertEqual(plan?.orderedIDs, ["solo"])
    }
}
