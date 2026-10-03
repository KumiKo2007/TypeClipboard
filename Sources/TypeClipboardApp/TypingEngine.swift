import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

enum TypingEngineError: LocalizedError {
    case emptyBuffer
    case accessibilityDenied
    case eventCreationFailed

    var errorDescription: String? {
        switch self {
        case .emptyBuffer:
            return "There is nothing to type. Capture the clipboard or paste text into the buffer."
        case .accessibilityDenied:
            return "TypeClipboard needs accessibility access to simulate keystrokes. Enable it in System Settings ▸ Privacy & Security ▸ Accessibility."
        case .eventCreationFailed:
            return "macOS refused to create keyboard events. Try again or restart the app."
        }
    }
}

@MainActor
final class TypingEngine {
    private let keyPressDuration: UInt64 = 15_000_000 // 15 ms between key down and key up

    func type(text: String, characterDelay: Double, appendReturn: Bool, newlineMode: NewlineMode, compensateAutoClosingBraces: Bool = false) async throws {
        guard !text.isEmpty else { throw TypingEngineError.emptyBuffer }
        guard EventPostingPermission.isGranted() else { throw TypingEngineError.accessibilityDenied }

        let sanitizedDelay = max(characterDelay, 0)
        let eventSource = CGEventSource(stateID: .hidSystemState)

        for action in TypingSequence.actions(for: text, compensateAutoClosingBraces: compensateAutoClosingBraces) {
            switch action {
            case .text(let value):
                try await send(text: value, using: eventSource, interCharacterDelay: sanitizedDelay)
            case .newline:
                // Target frameworks may ignore a Unicode string on a keyboard event.
                // Source: https://developer.apple.com/documentation/coregraphics/cgevent/keyboardsetunicodestring(stringlength:unicodestring:)
                let flags: CGEventFlags = newlineMode == .shiftEnter ? .maskShift : []
                try await send(keyCode: CGKeyCode(kVK_Return), flags: flags, using: eventSource, interCharacterDelay: sanitizedDelay)
            case .tab:
                try await send(keyCode: CGKeyCode(kVK_Tab), flags: [], using: eventSource, interCharacterDelay: sanitizedDelay)
            case .deleteForward:
                try await send(keyCode: CGKeyCode(kVK_ForwardDelete), flags: [], using: eventSource, interCharacterDelay: sanitizedDelay)
            }
        }

        if appendReturn {
            try await send(keyCode: CGKeyCode(kVK_Return), flags: [], using: eventSource, interCharacterDelay: sanitizedDelay)
        }
    }

    private func send(text: String, using source: CGEventSource?, interCharacterDelay delay: Double) async throws {
        try Task.checkCancellation()
        var utf16Units = Array(text.utf16)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            throw TypingEngineError.eventCreationFailed
        }

        keyDown.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)
        keyUp.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)
        markSynthetic(keyDown, keyUp)

        try await postPair(down: keyDown, up: keyUp, delay: delay)
    }

    private func send(keyCode: CGKeyCode, flags: CGEventFlags, using source: CGEventSource?, interCharacterDelay delay: Double) async throws {
        try Task.checkCancellation()
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            throw TypingEngineError.eventCreationFailed
        }
        down.flags = flags
        up.flags = flags
        markSynthetic(down, up)

        try await postPair(down: down, up: up, delay: delay)
    }

    private func markSynthetic(_ down: CGEvent, _ up: CGEvent) {
        down.setIntegerValueField(.eventSourceUserData, value: KeyboardEventTag.synthetic)
        up.setIntegerValueField(.eventSourceUserData, value: KeyboardEventTag.synthetic)
    }

    private func postPair(down: CGEvent, up: CGEvent, delay: Double) async throws {
        down.post(tap: .cghidEventTap)
        // The key-up must be sent even if the task is cancelled during the key hold.
        try? await Task.sleep(nanoseconds: keyPressDuration)
        up.post(tap: .cghidEventTap)
        try Task.checkCancellation()
        try await Task.sleep(nanoseconds: nanoseconds(for: delay))
    }

    private func nanoseconds(for delay: Double) -> UInt64 {
        guard delay > 0 else { return 0 }
        return UInt64(delay * 1_000_000_000)
    }
}
