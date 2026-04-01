import XCTest
@testable import MusicBrowser

final class AppRuntimeTests: XCTestCase {
    func testUsesDummyForTests() {
        let runtime = AppRuntime.resolve(
            arguments: [],
            environment: [:],
            isRunningTests: true,
            prefersDummyData: false
        )

        XCTAssertEqual(runtime, .dummy)
    }

    func testUsesDummyForUITestEnvironment() {
        let runtime = AppRuntime.resolve(
            arguments: [],
            environment: ["UI_TEST_MODE": "1"],
            isRunningTests: false,
            prefersDummyData: false
        )

        XCTAssertEqual(runtime, .dummy)
    }

    func testUsesDummyWhenPlatformPrefersDummyData() {
        let runtime = AppRuntime.resolve(
            arguments: [],
            environment: [:],
            isRunningTests: false,
            prefersDummyData: true
        )

        XCTAssertEqual(runtime, .dummy)
    }

    func testUsesLiveWhenPlatformDoesNotPreferDummyData() {
        let runtime = AppRuntime.resolve(
            arguments: [],
            environment: [:],
            isRunningTests: false,
            prefersDummyData: false
        )

        XCTAssertEqual(runtime, .live)
    }

    func testLiveModeOverrideForcesLive() {
        let runtime = AppRuntime.resolve(
            arguments: ["-live-mode"],
            environment: [:],
            isRunningTests: false,
            prefersDummyData: true
        )

        XCTAssertEqual(runtime, .live)
    }
}
