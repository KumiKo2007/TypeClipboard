import Foundation

enum KeyboardEventTag {
    static let synthetic: Int64 = 0x5459434C4950
}

enum NewlineMode: String, CaseIterable, Identifiable {
    case enter
    case shiftEnter

    var id: String { rawValue }
}

enum TypingAction: Equatable {
    case text(String)
    case newline
    case tab
    case deleteForward
}

enum TypingSequence {
    static func actions(for text: String, compensateAutoClosingBraces: Bool = false) -> [TypingAction] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        return normalized.flatMap { character -> [TypingAction] in
            switch character {
            case "\n": return [.newline]
            case "\t": return [.tab]
            case "{" where compensateAutoClosingBraces:
                // In editors that insert a matching } immediately, remove the generated
                // character before typing the rest of the source verbatim.
                return [.text("{"), .deleteForward]
            default: return [.text(String(character))]
            }
        }
    }
}
