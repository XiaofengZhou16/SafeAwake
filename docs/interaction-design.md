# v0.3 interaction decisions

## Sources checked on 2026-09-22

GitHub API snapshots (counts change; popularity is not evidence that a particular feature causes adoption):

| Project | Stars at inspection | Relevant pattern |
| --- | ---: | --- |
| [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake) | 6,925 | Small menu-bar surface, finite sessions, explicit lid-open limitation |
| [Stats](https://github.com/exelban/stats) | 42,035 | Important live status visible directly in the menu bar |
| [caffeine](https://github.com/iannuttall/caffeine) | 29 | Coding-agent-oriented automation; emerging reference, not high-star evidence |
| [Pulse](https://github.com/VenkateshDas/pulse) | 1 | Earlier visual reference only; not a high-star project |

[Amphetamine's official listing](https://apps.apple.com/us/app/amphetamine/id937984704) provides additional context for battery safeguards. It is not presented here as an open-source GitHub reference. No third-party source code was copied for this iteration.

## Adapted to SafeAwake's original purpose

- **Fewer steps:** one action starts a guarded session and requests display sleep. The status switch still starts a session without blanking the screen.
- **Know whether it is running:** menu-bar countdown plus active/idle status; do not depend on color alone.
- **Finish later without restarting:** +30 minutes extends the existing deadline. Selecting a duration explicitly restarts its countdown; the UI explains the difference.
- **Easy recovery:** dedicated stop action; reopen the app for a standalone panel when menu-bar space is limited.
- **Keep the primary surface small:** power preferences and detailed guidance are disclosed on demand; feedback reserves space to avoid layout jumps.
- **Battery guardrail:** AC-only by default; optional battery operation still stops at 20% or when battery state cannot be read. Checks run approximately every five seconds, not continuously in hardware.
- **Honest state:** stopping releases only our assertion. Other apps may still prevent sleep. Display sleep is not an explicit lock command.

## Deliberately not added

No lid-sleep bypass, administrator helper, permanent power-setting changes, automatic restart of sessions, or claim of zero hardware wear. No task-finished detection based merely on the presence of a Codex process. Reliable task-aware stopping would require an explicit lifecycle integration and separate testing.

## Verification boundary

14 unit tests and a release build passed locally. Real native UI start, additive extension, expanded layout, and stop were inspected. `pmset -g assertions` confirmed SafeAwake's own request was created and released. Other applications' requests remained untouched. Display sleep ordering and failure paths were checked with an injected test double; physical lid-close and real battery-drain tests were not performed. Distribution is currently ad-hoc signed, not Developer ID notarized.
