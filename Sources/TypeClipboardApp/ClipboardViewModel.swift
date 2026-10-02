import AppKit
import Foundation
import SwiftUI

@MainActor
protocol TypingEngineProtocol {
    func type(text: String, characterDelay: Double, appendReturn: Bool, newlineMode: NewlineMode) async throws
}

extension TypingEngine: TypingEngineProtocol {}

@MainActor
protocol AccessibilityPermissionManaging {
    func isTrusted() -> Bool
    func promptForAccess()
}

extension AccessibilityPermissionManager: AccessibilityPermissionManaging {}

@MainActor
protocol AppRelaunching {
    func restart() throws
}

extension AppRelauncher: AppRelaunching {}

@MainActor
protocol ClipboardWatching: AnyObject {
    func start()
    func stop()
    func sync(changeCount: Int)
}

extension ClipboardWatcher: ClipboardWatching {}

protocol KeyCancellationMonitoring: AnyObject {
    func start() throws
    func stop()
}

extension PhysicalKeyCancellationMonitor: KeyCancellationMonitoring {}

protocol PasteboardProviding {
    var changeCount: Int { get }
    func string(forType dataType: NSPasteboard.PasteboardType) -> String?
}

struct SystemPasteboard: PasteboardProviding {
    private let pasteboard: NSPasteboard

    init(_ pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int {
        pasteboard.changeCount
    }

    func string(forType dataType: NSPasteboard.PasteboardType) -> String? {
        pasteboard.string(forType: dataType)
    }
}

@MainActor
final class ClipboardViewModel: ObservableObject {
    enum CaptureOrigin {
        case bootstrapped
        case manual
        case automatic
    }

    struct StatusMessage: Identifiable {
        enum Style {
            case info
            case success
            case warning
            case error
        }

        let id = UUID()
        let key: String
        let arguments: [String]
        let style: Style

        init(text key: String, arguments: [String] = [], style: Style) {
            self.key = key
            self.arguments = arguments
            self.style = style
        }

        var text: String { localizedText(for: .english) }

        func localizedText(for language: AppLanguage) -> String {
            L10n.text(key, arguments, language: language)
        }
    }

    @Published var bufferText: String = ""
    @Published private(set) var previewDescription: String = "Buffer empty"
    @Published private(set) var characterCount: Int = 0
    @Published private(set) var lineCount: Int = 0
    @Published var autoCapture: Bool = false {
        didSet { autoCapture ? startClipboardMonitoring() : stopClipboardMonitoring() }
    }
    @Published var appendReturn: Bool = false
    @Published var countdownSeconds: Int = 2 {
        didSet {
            if countdownSeconds < 0 { countdownSeconds = 0 }
            if countdownSeconds > 10 { countdownSeconds = 10 }
        }
    }
    @Published var perCharacterDelay: Double = 0.035 {
        didSet {
            if perCharacterDelay < 0 { perCharacterDelay = 0 }
            if perCharacterDelay > 0.25 { perCharacterDelay = 0.25 }
        }
    }
    @Published private(set) var isTyping: Bool = false
    @Published var statusMessage: StatusMessage?
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var isAccessibilityTrusted: Bool = false

    let characterDelayRange = 0.0...0.25
    let countdownRange = 0...10

    var typingButtonDisabled: Bool {
        bufferText.isEmpty || isTyping
    }

    var delayDescription: String {
        "\(Int(perCharacterDelay * 1_000)) ms"
    }

    var countdownDescription: String {
        countdownDescription(for: .english)
    }

    func countdownDescription(for language: AppLanguage) -> String {
        countdownSeconds == 1
            ? L10n.text("1 second", language: language)
            : L10n.text("{0} seconds", [String(countdownSeconds)], language: language)
    }

    func previewDescription(for language: AppLanguage) -> String {
        makePreview(from: bufferText, language: language)
    }

    private let typingEngine: any TypingEngineProtocol
    private let accessibilityManager: any AccessibilityPermissionManaging
    private let relauncher: any AppRelaunching
    private let pasteboard: any PasteboardProviding
    private let countdownTickNanoseconds: UInt64
    private let keyMonitorFactory: (@escaping () -> Void, @escaping () -> Void) -> any KeyCancellationMonitoring
    private var clipboardWatcher: (any ClipboardWatching)?
    private var lastCapturedChangeCount: Int
    private var isProgrammaticBufferMutation = false
    private var userHasEditedBuffer = false
    private var typingTask: Task<Void, Never>?
    private var keyMonitor: (any KeyCancellationMonitoring)?
    private var keyMonitorFailed = false

    init(
        typingEngine: (any TypingEngineProtocol)? = nil,
        accessibilityManager: (any AccessibilityPermissionManaging)? = nil,
        relauncher: (any AppRelaunching)? = nil,
        pasteboard: any PasteboardProviding = SystemPasteboard(),
        clipboardWatcher: (any ClipboardWatching)? = nil,
        countdownTickNanoseconds: UInt64 = 1_000_000_000,
        keyMonitorFactory: @escaping (@escaping () -> Void, @escaping () -> Void) -> any KeyCancellationMonitoring = {
            PhysicalKeyCancellationMonitor(onCancel: $0, onFailure: $1)
        }
    ) {
        self.typingEngine = typingEngine ?? TypingEngine()
        self.accessibilityManager = accessibilityManager ?? AccessibilityPermissionManager()
        self.relauncher = relauncher ?? AppRelauncher()
        self.pasteboard = pasteboard
        self.countdownTickNanoseconds = countdownTickNanoseconds
        self.keyMonitorFactory = keyMonitorFactory
        lastCapturedChangeCount = pasteboard.changeCount
        self.clipboardWatcher = clipboardWatcher ?? ClipboardWatcher { [weak self] string, changeCount in
            Task { @MainActor in
                self?.handleClipboardUpdate(string, changeCount: changeCount)
            }
        }

        refreshAccessibilityStatus()
    }

    func captureClipboard() {
        captureClipboard(silent: false)
    }

    func clearBuffer() {
        applyBuffer("", origin: .manual)
        statusMessage = StatusMessage(text: "Cleared the buffer.", style: .info)
    }

    func userEditedBuffer() {
        guard !isProgrammaticBufferMutation else { return }
        userHasEditedBuffer = true
        lastUpdatedAt = Date()
        recalculateBufferMetrics()
    }

    func refreshAccessibilityStatus() {
        isAccessibilityTrusted = accessibilityManager.isTrusted()
    }

    func requestAccessibilityAccess() {
        accessibilityManager.promptForAccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            Task { @MainActor in
                self?.refreshAccessibilityStatus()
            }
        }
    }

    func restartApplicationForAccessibility() {
        statusMessage = StatusMessage(
            text: "Restarting TypeClipboard to apply new accessibility permissions…",
            style: .info
        )
        do {
            try relauncher.restart()
        } catch let error as AppRelauncherError {
            statusMessage = StatusMessage(text: error.localizedDescription, style: .error)
        } catch {
            statusMessage = StatusMessage(text: error.localizedDescription, style: .error)
        }
    }

    func typeBuffer(newlineMode: NewlineMode = .enter) {
        refreshAccessibilityStatus()

        guard !bufferText.isEmpty else {
            statusMessage = StatusMessage(text: "The buffer is empty. Capture the clipboard or type something first.", style: .warning)
            return
        }

        guard isAccessibilityTrusted else {
            statusMessage = StatusMessage(text: "Accessibility is disabled. Enable it to let TypeClipboard simulate keystrokes.", style: .error)
            return
        }

        guard !isTyping else { return }

        keyMonitorFailed = false
        let monitor = keyMonitorFactory(
            { [weak self] in
                MainActor.assumeIsolated { self?.cancelTyping() }
            },
            { [weak self] in
                MainActor.assumeIsolated {
                    self?.keyMonitorFailed = true
                    self?.cancelTyping()
                }
            }
        )
        do {
            try monitor.start()
        } catch {
            statusMessage = StatusMessage(
                text: "Keyboard monitoring is unavailable. Enable Input Monitoring for TypeClipboard in System Settings, then try again.",
                style: .error
            )
            return
        }
        keyMonitor = monitor

        let text = bufferText
        let delay = perCharacterDelay
        let appendReturn = self.appendReturn
        let countdown = countdownSeconds

        isTyping = true
        if countdown > 0 {
            statusMessage = StatusMessage(
                text: countdown == 1
                    ? "Switch to the target window. Typing in 1 second…"
                    : "Switch to the target window. Typing in {0} seconds…",
                arguments: [String(countdown)],
                style: .info
            )
        } else {
            statusMessage = StatusMessage(text: "Typing now…", style: .info)
        }

        typingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.keyMonitor?.stop()
                self.keyMonitor = nil
                self.isTyping = false
                self.typingTask = nil
            }

            do {
                if countdown > 0 {
                    for remaining in stride(from: countdown, to: 0, by: -1) {
                        try Task.checkCancellation()
                        self.statusMessage = StatusMessage(
                            text: remaining == 1 ? "Typing in 1 second…" : "Typing in {0} seconds…",
                            arguments: [String(remaining)],
                            style: .info
                        )
                        try await Task.sleep(nanoseconds: self.countdownTickNanoseconds)
                    }
                }

                try Task.checkCancellation()
                try await self.typingEngine.type(text: text, characterDelay: delay, appendReturn: appendReturn, newlineMode: newlineMode)
                let appended = appendReturn ? 1 : 0
                self.statusMessage = StatusMessage(
                    text: "Sent {0} characters. Check the target content.",
                    arguments: [String(text.count + appended)],
                    style: .success
                )
            } catch is CancellationError {
                self.statusMessage = StatusMessage(
                    text: self.keyMonitorFailed
                        ? "Keyboard monitoring stopped unexpectedly. Typing was cancelled."
                        : "Typing cancelled.",
                    style: self.keyMonitorFailed ? .error : .info
                )
            } catch let error as TypingEngineError {
                self.statusMessage = StatusMessage(text: error.errorDescription ?? "Unexpected error: {0}", style: .error)
            } catch {
                self.statusMessage = StatusMessage(
                    text: "Unexpected error: {0}", arguments: [error.localizedDescription], style: .error
                )
            }
        }
    }

    func cancelTyping() {
        guard isTyping else { return }
        typingTask?.cancel()
    }

    private func captureClipboard(silent: Bool) {
        guard let string = pasteboard.string(forType: .string), !string.isEmpty else {
            if !silent {
                statusMessage = StatusMessage(text: "The clipboard does not contain plain text.", style: .warning)
            }
            return
        }

        lastCapturedChangeCount = pasteboard.changeCount
        clipboardWatcher?.sync(changeCount: lastCapturedChangeCount)
        applyBuffer(string, origin: silent ? .bootstrapped : .manual)

        if !silent {
            statusMessage = StatusMessage(
                text: "Captured {0} characters from the clipboard.", arguments: [String(string.count)], style: .success
            )
        }
    }

    func handleClipboardUpdate(_ string: String, changeCount: Int) {
        lastCapturedChangeCount = changeCount
        clipboardWatcher?.sync(changeCount: changeCount)

        guard autoCapture else {
            statusMessage = StatusMessage(
                text: "Clipboard changed ({0} characters). Auto-capture is off.",
                arguments: [String(string.count)],
                style: .info
            )
            return
        }

        if userHasEditedBuffer {
            statusMessage = StatusMessage(
                text: "Ignored clipboard change to avoid overwriting your edits. Capture manually when ready.",
                style: .warning
            )
            return
        }

        applyBuffer(string, origin: .automatic)
        statusMessage = StatusMessage(
            text: "Clipboard captured automatically ({0} characters).",
            arguments: [String(string.count)],
            style: .info
        )
    }

    private func applyBuffer(_ text: String, origin: CaptureOrigin) {
        isProgrammaticBufferMutation = true
        bufferText = text
        isProgrammaticBufferMutation = false
        userHasEditedBuffer = false
        lastUpdatedAt = Date()
        recalculateBufferMetrics()
    }

    private func recalculateBufferMetrics() {
        characterCount = bufferText.count
        let normalized = bufferText.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        lineCount = bufferText.isEmpty ? 0 : normalized.components(separatedBy: "\n").count
        previewDescription = makePreview(from: bufferText, language: .english)
    }

    private func startClipboardMonitoring() {
        clipboardWatcher?.start()
    }

    private func stopClipboardMonitoring() {
        clipboardWatcher?.stop()
    }

    private func makePreview(from text: String, language: AppLanguage) -> String {
        guard !text.isEmpty else { return L10n.text("Buffer empty", language: language) }

        let sanitized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "⏎")
            .replacingOccurrences(of: "\t", with: "⇥")

        let snippet: String
        if sanitized.count <= 32 {
            snippet = sanitized
        } else {
            let start = sanitized.prefix(14)
            let end = sanitized.suffix(14)
            snippet = "\(start)…\(end)"
        }

        let key = characterCount == 1 ? "{0} ({1} character)" : "{0} ({1} characters)"
        return L10n.text(key, [snippet, String(characterCount)], language: language)
    }
}
