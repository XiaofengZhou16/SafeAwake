# Changelog

All notable changes to SafeAwake will be documented in this file.

## [0.3.0] - 2026-09-22

### Added

- One-click start-and-display-sleep action with power checks.
- Menu-bar countdown, end time, and additive 30-minute extension.
- Battery safety cutoff at 20%, including unreadable battery state.
- Reopenable control panel and explicit stop action.
- Seven additional session-safety tests (14 total).

### Changed

- Collapsed secondary settings and guidance; stable-height inline feedback.
- Clear distinction between releasing our assertion, system sleep, display sleep, and locking.
- Refresh deadlines after system wake; weak monitoring timer capture.
- Preserve preferences without automatically restoring active sessions.

### Verified

- Local release build and 14 automated tests passed.
- Native UI start, extension, expanded guidance, and stop checked.
- System assertion appeared on start and disappeared on stop.
- Display-sleep sequencing tested with a mock; this iteration did not turn off the user's screen or test physical lid closure.

## [0.2.0] - 2026-09-22

### Added

- Pulse-inspired status HUD with a live remaining-time ring.
- Compact duration chips that can adjust an active session without interruption.
- Inline action feedback and current power-source status.
- Persistent duration and AC-only preferences.

### Changed

- Reorganized the popover into compact, material-backed cards.
- Replaced the large start/stop button with a direct status switch.
- Clarified the display-sleep action and physical lid-close safety boundary.
- Improved hover states, accessibility labels, spacing, and visual hierarchy.

## [0.1.0] - 2026-09-22

### Added

- Native macOS menu-bar interface.
- Reversible idle-sleep assertion using public Apple APIs.
- 30-minute, 1-hour, 2-hour, 4-hour, and manual-stop sessions.
- Safe default that requires AC power.
- Automatic stop when AC power is disconnected.
- One-click display sleep while the Mac remains available.
- Explicit boundary: physical lid-close sleep is never bypassed.
