import ApplicationServices
import Carbon.HIToolbox
import Foundation

enum PhysicalKeyMonitorError: Error {
    case unavailable
}

/// All lifecycle calls and callbacks run on the main run loop.
/// An active event tap is required so the cancelling key does not reach the target editor.
/// Source: https://developer.apple.com/documentation/coregraphics/cgeventtapoptions
final class PhysicalKeyCancellationMonitor: @unchecked Sendable {
    private let onCancel: () -> Void
    private let onFailure: () -> Void
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var callbackContext: UnsafeMutableRawPointer?
    private var cancellingKeyCode: Int64?
    private var cancellingModifier = false
    private var shouldStop = false
    private var previousFlags: CGEventFlags = []

    init(onCancel: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.onCancel = onCancel
        self.onFailure = onFailure
    }

    func start() throws {
        guard CGPreflightListenEventAccess() else {
            _ = CGRequestListenEventAccess()
            throw PhysicalKeyMonitorError.unavailable
        }
        previousFlags = CGEventSource.flagsState(.combinedSessionState)
        let mask = eventMask(.keyDown) | eventMask(.keyUp) | eventMask(.flagsChanged)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<PhysicalKeyCancellationMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }

        let context = Unmanaged.passRetained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: context
        ), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            Unmanaged<PhysicalKeyCancellationMonitor>.fromOpaque(context).release()
            throw PhysicalKeyMonitorError.unavailable
        }

        callbackContext = context
        self.tap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        guard CGEvent.tapIsEnabled(tap: tap) else {
            tearDown()
            throw PhysicalKeyMonitorError.unavailable
        }
    }

    func stop() {
        shouldStop = true
        if cancellingKeyCode == nil { tearDown() }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            onFailure()
            return Unmanaged.passUnretained(event)
        }

        // Events posted by the typing engine must never cancel its own task.
        if event.getIntegerValueField(.eventSourceUserData) == KeyboardEventTag.synthetic {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if let cancellingKeyCode = cancellingKeyCode {
            let released = keyCode == cancellingKeyCode &&
                (type == .keyUp || (cancellingModifier && type == .flagsChanged))
            if released {
                self.cancellingKeyCode = nil
                DispatchQueue.main.async { [weak self] in self?.tearDown() }
            }
            return nil
        }

        if type == .keyDown {
            cancellingKeyCode = keyCode
            onCancel()
            return nil
        }

        if type == .flagsChanged {
            let modifier = modifierFlag(for: keyCode)
            let newlyPressed = keyCode == Int64(kVK_CapsLock) ||
                (!modifier.isEmpty && !previousFlags.contains(modifier) && event.flags.contains(modifier))
            previousFlags = event.flags
            if newlyPressed {
                cancellingKeyCode = keyCode
                cancellingModifier = true
                onCancel()
                return nil
            }
        }

        if shouldStop { tearDown() }
        return Unmanaged.passUnretained(event)
    }

    private func modifierFlag(for keyCode: Int64) -> CGEventFlags {
        switch keyCode {
        case Int64(kVK_Shift), Int64(kVK_RightShift): return .maskShift
        case Int64(kVK_Control), Int64(kVK_RightControl): return .maskControl
        case Int64(kVK_Option), Int64(kVK_RightOption): return .maskAlternate
        case Int64(kVK_Command), Int64(kVK_RightCommand): return .maskCommand
        case Int64(kVK_CapsLock): return .maskAlphaShift
        case Int64(kVK_Function): return .maskSecondaryFn
        default: return []
        }
    }

    private func eventMask(_ type: CGEventType) -> CGEventMask {
        CGEventMask(1) << type.rawValue
    }

    private func tearDown() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap { CFMachPortInvalidate(tap) }
        runLoopSource = nil
        tap = nil
        if let context = callbackContext {
            callbackContext = nil
            Unmanaged<PhysicalKeyCancellationMonitor>.fromOpaque(context).release()
        }
    }
}
