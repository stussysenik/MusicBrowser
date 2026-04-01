import XCTest
@testable import MusicBrowser

final class FormatTests: XCTestCase {

    // MARK: - formatDuration

    func testFormatDurationZero() {
        XCTAssertEqual(formatDuration(0), "0:00")
    }

    func testFormatDurationUnderMinute() {
        XCTAssertEqual(formatDuration(45), "0:45")
    }

    func testFormatDurationExactMinute() {
        XCTAssertEqual(formatDuration(60), "1:00")
    }

    func testFormatDurationMinutesAndSeconds() {
        XCTAssertEqual(formatDuration(185), "3:05")
    }

    func testFormatDurationSingleDigitSeconds() {
        XCTAssertEqual(formatDuration(61), "1:01")
    }

    func testFormatDurationLargeValue() {
        XCTAssertEqual(formatDuration(599), "9:59")
    }

    // MARK: - formatDurationLong

    func testFormatDurationLongZero() {
        XCTAssertEqual(formatDurationLong(0), "0:00")
    }

    func testFormatDurationLongUnderHour() {
        XCTAssertEqual(formatDurationLong(185), "3:05")
    }

    func testFormatDurationLongExactHour() {
        XCTAssertEqual(formatDurationLong(3600), "1:00:00")
    }

    func testFormatDurationLongHoursMinutesSeconds() {
        XCTAssertEqual(formatDurationLong(3661), "1:01:01")
    }

    func testFormatDurationLongJustUnderHour() {
        XCTAssertEqual(formatDurationLong(3599), "59:59")
    }

    func testFormatDurationLongMultipleHours() {
        XCTAssertEqual(formatDurationLong(7384), "2:03:04")
    }

    // MARK: - Date.year

    func testDateYear() {
        let components = DateComponents(year: 2024, month: 6, day: 15)
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(date.year, 2024)
    }

    func testDateYearCurrent() {
        let year = Date().year
        // Should be a reasonable year
        XCTAssertGreaterThanOrEqual(year, 2024)
        XCTAssertLessThanOrEqual(year, 2030)
    }
}
