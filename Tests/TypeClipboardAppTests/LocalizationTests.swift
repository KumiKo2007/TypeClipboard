import XCTest
@testable import TypeClipboardApp

@MainActor
final class LocalizationTests: XCTestCase {
    func testExplicitLanguageSelectionAndInterpolation() {
        XCTAssertEqual(
            L10n.text("Sent {0} characters. Check the target content.", ["3"], language: .english),
            "Sent 3 characters. Check the target content."
        )
        XCTAssertEqual(
            L10n.text("Sent {0} characters. Check the target content.", ["3"], language: .simplifiedChinese),
            "已发送 3 个字符，请核对目标中的内容。"
        )
    }

    func testStatusCanBeRenderedAfterLanguageChanges() {
        let status = ClipboardViewModel.StatusMessage(
            text: "Typing cancelled.", style: .info
        )

        XCTAssertEqual(status.localizedText(for: .english), "Typing cancelled.")
        XCTAssertEqual(status.localizedText(for: .simplifiedChinese), "已取消输入。")
    }
}
