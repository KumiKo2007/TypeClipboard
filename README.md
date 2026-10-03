# TypeClipboard

[简体中文说明](README.zh-CN.md)

![TypeClipboard screenshot](./Screenshot.png)

TypeClipboard is a SwiftUI macOS utility that replays an editable text buffer as live keyboard input. It is useful for remote sessions and browser code editors where ordinary paste is unavailable. The app sends keystrokes; it cannot verify what the target editor ultimately stores.

Inspired by [jlaundry/TypeClipboard](https://github.com/jlaundry/TypeClipboard) for Windows.

## Features
- Capture clipboard contents into an editable buffer
- Adjustable countdown so you can focus the target window before typing begins
- Per-character delay, real Enter or Shift+Enter events for source line breaks, and an optional trailing Return (off by default)
- Manually selected Xuexitong and General input profiles that remember newline and brace-pairing settings
- English and Simplified Chinese interface, with a system-language option
- Inline guidance for macOS Accessibility permission (required to synthesize keystrokes)
- Status banners, manual capture, and cancellation by any new physical keyboard key during countdown or typing
- Optional auto-capture of clipboard changes (off by default to avoid surprises)

## Download
- Get the latest prebuilt `.app` from the [Releases page](https://github.com/ArbenP/TypeClipboard/releases).


## First Run / Permissions
TypeClipboard needs macOS Accessibility permission to generate keystrokes:
1. Launch the app and click **Open Settings** in the banner.  
2. In *Privacy & Security ▸ Accessibility*, enable TypeClipboard.  
3. Click **Restart App** to reload with the permission applied.  
If permission is missing, typing will be blocked and you’ll see an error banner.

The physical-key cancellation feature also needs permission to monitor keyboard events. If TypeClipboard reports that keyboard monitoring is unavailable, enable **Input Monitoring** for TypeClipboard in *Privacy & Security*, then retry. The app will not start typing without the cancellation monitor.

## Usage
- **Capture**: Click *Capture Clipboard* (⇧⌘V) to pull the current clipboard into the buffer.  
- **Edit**: Review or edit text in the buffer; metrics update live.  
- **Choose a profile**: Select *Xuexitong* or *General*, then choose *Enter* or *Shift+Enter* as the newline key. Profiles are selected manually and remember their own settings; the app does not read browser URLs.
- **Auto-closing braces**: If the target inserts `}` when you type `{`, enable *Remove editor-inserted closing braces*. Xuexitong starts with this on; General starts with it off. Start in an empty editor. The app sends Forward Delete immediately after each `{` to remove the generated `}`. Turn this off if the editor does not auto-pair braces, especially when text already exists to the right of the cursor.
- **Type**: Click *Type Now* to send the buffer as keystrokes. Source line breaks use the selected newline key; tabs are sent as Tab key events. Use countdown and delay controls to match the target app’s latency.
- **Cancel**: Press any new physical keyboard key, including a modifier, or click *Cancel Typing* during the countdown or typing. The cancelling key is intercepted so it does not enter the target.
- **Automation**: Turn on *Update buffer when the clipboard changes* only if you want automatic capture; it’s off by default to avoid overwriting edits.  
- **Return key**: *Press Return after typing* is off by default. Turn it on only if your workflow needs an extra Enter beyond the source text.
- **Language**: Choose *Auto (System)*, *English*, or *Simplified Chinese*. The selection takes effect immediately and persists across launches.

After typing, check the target content before saving or submitting it. Some web editors auto-indent, treat Tab as navigation, or otherwise modify synthetic keyboard input. A completed send does not prove that the target content matches the buffer.

## Requirements
- macOS 13 or newer
- Accessibility permission enabled for TypeClipboard

## Build From Source
Requires Swift 6.2+.

CLI build/run:
```bash
swift build
swift run TypeClipboardApp
```

Optimized binary:
```bash
swift build -c release
```
Binary is at `.build/release/TypeClipboardApp`.

## Build a `.app`
- Quick script (ad-hoc signed, embeds Swift runtime):
```bash
./scripts/build-app-bundle.sh
```
Output: `dist/TypeClipboard.app`.

- Xcode path: see `GUIDE.md` for step-by-step instructions to build the `.app` from Xcode (no Developer ID required for local use).

## Tests
```bash
swift test
```

## Troubleshooting
- **Nothing types**: Accessibility permission not granted or the target field rejects synthetic input (some secure fields do).  
- **Keyboard monitoring unavailable**: Enable Input Monitoring for TypeClipboard; typing is blocked until the cancellation monitor starts successfully.
- **Newlines or indentation differ**: Try the other newline mode and check the target editor's automatic indentation settings. TypeClipboard does not silently convert tabs to spaces.
- **Extra `}` characters**: Check whether the target auto-inserts `}` after `{`. Enable brace compensation only in that case. If the editor adds a `}` only after Enter, disable its automatic brace completion in the editor settings before typing; this option only handles an immediately inserted pair.
- **Buffer changed while editing**: Leave auto-capture off, or recapture manually.  
- **Too fast/slow**: Adjust the per-character delay slider (0–250 ms) and/or countdown.  
- **Blocked at launch**: Right-click the app → Open to bypass Gatekeeper for ad-hoc builds.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
