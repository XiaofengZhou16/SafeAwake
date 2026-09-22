# Single-use closed-lid sessions: safety gate (experimental)

Status: policy model and tests only. **Not an operational closed-lid feature.**
No privileged helper, authentication dialog, XPC endpoint, global power write,
installation, or new UI toggle is included in this branch. Existing v0.3 behavior
is unchanged. Do not market these unit tests as hardware-safety verification.

## Product contract

- Duration: integer minutes 1–30; 0 cancels, never means unlimited.
- Fresh OS-mediated password/Touch ID verification for every session. No password
  collection, stored credential, remembered approval, or automatic extension.
- Authentication challenge expires after 60 seconds. The session deadline starts
  at successful verification, not at a later lid closure. Close within 60 seconds
  or the authorization expires. Reopening ends the session.
- First hardware pilot is AC-only, with battery >20%, nominal thermal state,
  Low Power Mode off, and positively identified supported hardware. Missing sensor
  data rejects activation. These are conservative initial product limits, not
  a statement that these thresholds guarantee safe temperatures.
- Never use in a bag, sleeve, enclosed space, or with obstructed ventilation.
- A new app/helper process never resumes an old active session.
- Stop, deadline, disconnect, logout, sleep, unsafe conditions, and backend failure
  all request restoration. Failure to verify restoration blocks new sessions.

The helper's installation approval persists until removal. The permission to
activate one bounded session does not. The UI must explain this distinction.

## What the current code establishes

`LidSessionPolicy` is an internal, deterministic state machine. It has no I/O.
It tests duration limits, correlation/replay rejection, expiry, cancellation,
reopening, invalid clock progression, conservative safety admission, and recovery
gating. Inputs are simulated observations. Challenge UUIDs are NOT credentials.
Calling `authenticationSucceeded` is NOT proof of a real OS authentication.
Calling `restorationVerified` is NOT proof of system restoration.

## Required trusted implementation before enabling

1. **Signing:** Developer ID signed app and helper, hardened runtime, notarization
   for distribution. Exact signing identities/Team ID are build inputs, never
   hard-coded fake values. Reject ad-hoc, unsigned, wrong-team, wrong-identifier,
   and changed peers. No environment-variable or hidden-menu bypass.
2. **IPC:** OS-verified peer identity on both sides, bounded typed messages, one
   session/owner, no shell strings, caller-supplied executable paths or arbitrary
   commands. Read power, lid, thermal, and clock state in the trusted helper,
   not from client claims. Stale/replayed requests must fail.
3. **Authentication:** fresh LAContext, no reuse window, destroy after use, cancel
   pending prompts on cancellation/disconnect. Establish how verified OS evidence
   is bound to the helper-generated nonce, exact duration, caller, and expiry.
   Do NOT expose an `authenticated: true` IPC flag. Validate password and Touch ID
   paths, including unavailable biometrics and cancellation. Apple's general
   device-owner policy can allow other methods on some systems; enforce the
   requested method set explicitly rather than promising it from a generic policy.
4. **Restoration:** before any change, atomically persist a root-owned, symlink-safe
   recovery journal of the exact prior setting and ownership. Abort if journal
   persistence fails. Refuse pre-existing disabled-sleep or ambiguous ownership.
   Do not blindly reset settings owned by other software.
5. **Crash containment:** helper-owned continuous monotonic deadline and a separately
   supervised recovery path. No UI timer as authority. On daemon restart/boot,
   recover journal before accepting any new session; never restore active leases.
   Subprocesses need bounded execution and post-command state readback. Failed
   restoration must remain visible and retryable, not become an idle success UI.
6. **Removal/update:** restore and verify first, unregister helper second. Preserve
   recovery capability if restoration fails. Test forced removal and damaged state.
7. **Boundaries:** disabling system sleep is a global setting, not a scoped idle
   assertion. A stalled kernel, stopped watchdog, or power failure can defeat
   software scheduling; 30 minutes is the intended maximum lease, not an absolute
   real-time guarantee under arbitrary faults. Do not claim zero damage or that
   OS thermal reports measure every component's temperature.

## Release acceptance checklist (all pending)

- [ ] Signed helper/client trust checks, unauthorized client and replay tests.
- [ ] Actual password/Touch ID prompts every time; cancellation never enables.
- [ ] Continuous clock deadline unaffected by wall-clock adjustments or sleep.
- [ ] Durable journal fault injection before/during/after enable and restore.
- [ ] Kill UI, kill helper, disconnect IPC, restart, revoke approval, failed command,
      command hang, malformed journal, disk-full, competing sleep-setting changes.
- [ ] Supervised hardware test, lid closed with no external display, on supported
      macOS/hardware; independent evidence tasks run and sleep policy is restored.
- [ ] AC removal, unknown battery, thermal warning, and lid reopening tests.
- [ ] Independent security review of the privileged boundary and recovery design.
- [ ] Developer ID signed/notarized artifacts; staged opt-in pilot, no auto-enable.

As of 2026-09-22 the local signing identity check returned no valid code-signing
identities. No helper was installed and no global power setting was changed.
Signing and hardware validation remain release gates, not tasks marked complete.

## Primary references

- [Apple: idle assertions do not prevent lid-close sleep](https://developer.apple.com/documentation/iokit/kiopmassertiontypepreventuseridlesystemsleep)
- [Apple: LaunchDaemon registration requires administrator approval](https://developer.apple.com/documentation/servicemanagement/smappservice/register%28%29)
- [Apple: local device-owner authentication](https://developer.apple.com/documentation/LocalAuthentication/LAPolicy/deviceOwnerAuthentication)
- [Apple: thermal state](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum)

These APIs do not themselves certify a closed-lid workaround as hardware-safe.
