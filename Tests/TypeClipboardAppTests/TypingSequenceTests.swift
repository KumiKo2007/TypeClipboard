import XCTest
@testable import TypeClipboardApp

final class TypingSequenceTests: XCTestCase {
    func testSeparatesNewlinesAndTabsWithoutChangingOtherCharacters() {
        let actions = TypingSequence.actions(for: "a\r\n\tb\rc\nd\n")

        XCTAssertEqual(actions, [
            .text("a"), .newline, .tab, .text("b"), .newline,
            .text("c"), .newline, .text("d"), .newline
        ])
    }

    func testPreservesUnicodeGraphemeAndSpaces() {
        XCTAssertEqual(
            TypingSequence.actions(for: "  中👩‍💻 "),
            [.text(" "), .text(" "), .text("中"), .text("👩‍💻"), .text(" ")]
        )
    }

    func testEmptyInputHasNoActions() {
        XCTAssertTrue(TypingSequence.actions(for: "").isEmpty)
    }
}
