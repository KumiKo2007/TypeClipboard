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
}

enum TypingSequence {
    static func actions(for text: String) -> [TypingAction] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        return normalized.map { character in
            switch character {
            case "\n": return .newline
            case "\t": return .tab
            default: return .text(String(character))
            }
        }
    }
}
