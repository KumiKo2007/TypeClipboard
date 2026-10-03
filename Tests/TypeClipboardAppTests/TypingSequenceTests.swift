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

    func testCompensatesForEditorInsertedClosingBraces() {
        let source = "struct Stack {\n\tint top;\n};\n\nint main() {\n\tif (true) {\n\t\treturn 0;\n\t}\n}"
        var editor = AutoPairingEditor()

        for action in TypingSequence.actions(for: source, compensateAutoClosingBraces: true) {
            editor.apply(action)
        }

        XCTAssertEqual(editor.text, source)
    }

    func testDefaultDoesNotDeleteExistingContentAfterOpeningBrace() {
        XCTAssertEqual(TypingSequence.actions(for: "{}"), [.text("{"), .text("}")])
    }
}

private struct AutoPairingEditor {
    private var characters: [Character] = []
    private var cursor = 0

    var text: String { String(characters) }

    mutating func apply(_ action: TypingAction) {
        switch action {
        case .text("{"):
            characters.insert(contentsOf: ["{", "}"], at: cursor)
            cursor += 1
        case .text(let value):
            characters.insert(contentsOf: Array(value), at: cursor)
            cursor += value.count
        case .newline:
            characters.insert("\n", at: cursor)
            cursor += 1
        case .tab:
            characters.insert("\t", at: cursor)
            cursor += 1
        case .deleteForward:
            if cursor < characters.count { characters.remove(at: cursor) }
        }
    }
}
