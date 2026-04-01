import XCTest
@testable import MusicBrowser

final class StringUtilsTests: XCTestCase {

    // MARK: - firstLetter(of:)

    func testFirstLetterNormalString() {
        XCTAssertEqual(StringUtils.firstLetter(of: "Hello"), "H")
    }

    func testFirstLetterLowercaseReturnsUppercased() {
        XCTAssertEqual(StringUtils.firstLetter(of: "world"), "W")
    }

    func testFirstLetterNumberReturnsHash() {
        XCTAssertEqual(StringUtils.firstLetter(of: "123 Song"), "#")
    }

    func testFirstLetterSpecialCharReturnsHash() {
        XCTAssertEqual(StringUtils.firstLetter(of: "!@#$"), "#")
    }

    func testFirstLetterEmptyStringReturnsHash() {
        XCTAssertEqual(StringUtils.firstLetter(of: ""), "#")
    }

    func testFirstLetterWhitespaceOnlyReturnsHash() {
        XCTAssertEqual(StringUtils.firstLetter(of: "   "), "#")
    }

    func testFirstLetterWithLeadingWhitespace() {
        XCTAssertEqual(StringUtils.firstLetter(of: "  Apple"), "A")
    }

    func testFirstLetterUnicodeLetter() {
        XCTAssertEqual(StringUtils.firstLetter(of: "Über"), "Ü")
    }

    func testFirstLetterAccentedLetter() {
        XCTAssertEqual(StringUtils.firstLetter(of: "élan"), "É")
    }

    func testFirstLetterSingleChar() {
        XCTAssertEqual(StringUtils.firstLetter(of: "Z"), "Z")
    }

    func testFirstLetterEmojiReturnsHash() {
        XCTAssertEqual(StringUtils.firstLetter(of: "🎵 Music"), "#")
    }
}
