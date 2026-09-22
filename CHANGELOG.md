# Changelog

All notable changes to SafeAwake will be documented in this file.

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
