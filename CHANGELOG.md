# Changelog

## v1.0.3 — 2026-10-03

### Added

- English and Simplified Chinese interface with a persistent language setting.
- Multiline code typing with Enter and Shift+Enter modes, preserved blank lines and Tab key events.
- Xuexitong and General input profiles with separate newline and brace-pairing settings.
- Cancellation during countdown or typing by pressing a physical keyboard key.

### Fixed

- Optional compensation for code editors that immediately insert a matching `}` after `{`, preventing extra closing braces.
- The trailing Return key is now off by default; source text ending in a newline still types that newline.

The app sends keystrokes and cannot confirm the final text stored by a target editor. Check the result before saving or submitting it.
