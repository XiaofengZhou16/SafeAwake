import Foundation

// EXPERIMENTAL, INTERNAL POLICY MODEL ONLY.
// Not connected to the UI, LocalAuthentication, XPC, a daemon, or power settings.
// A challenge ID is correlation data, NOT proof of authentication. Only a future
// trusted verification boundary may deliver authenticationSucceeded.
// Every time input must come from one continuous monotonic clock, never Date.
struct LidSessionPolicy {
    struct Safety: Equatable {
        var onACPower = true
        var batteryPercent: Int? = 100
        var thermalNominal = true
        var lowPowerMode = false
        var lidClosed = false
        var clientConnected = true
        var supportedHardware = true

        var permitsOperation: Bool {
            onACPower && batteryPercent.map { (21...100).contains($0) } == true
                && thermalNominal && !lowPowerMode && clientConnected && supportedHardware
        }
    }

    struct Challenge: Equatable {
        let id: UUID
        let minutes: Int
        let deadline: Duration
    }

    struct Lease: Equatable {
        let id: UUID
        let deadline: Duration
        let closeBy: Duration
        var sawClosedLid = false
    }

    enum State: Equatable {
        case recoveryRequired
        case idle
        case awaitingAuthentication(Challenge)
        // An admitted lease in the model, NOT an assertion that the OS is awake.
        case admitted(Lease)
        case restorationRequired
        case blocked
    }

    private(set) var state: State = .recoveryRequired
    private var lastTime: Duration = .zero

    // Called only after a future backend has independently read back restoration.
    // Never call merely because a restore command was dispatched or exited zero.
    mutating func restorationVerified() {
        switch state {
        case .recoveryRequired, .restorationRequired, .blocked: state = .idle
        default: break
        }
    }

    mutating func restorationFailed() { state = .blocked }

    mutating func request(minutes: Int, now: Duration, safety: Safety) -> Challenge? {
        guard observe(now) else { return nil }
        if minutes == 0 { end(); return nil }
        guard case .idle = state,
              (1...30).contains(minutes), safety.permitsOperation, !safety.lidClosed
        else { return nil }
        let challenge = Challenge(id: UUID(), minutes: minutes, deadline: now + .seconds(60))
        state = .awaitingAuthentication(challenge)
        return challenge
    }

    // Deliberately internal; this is a transition for simulation/tests, not an IPC API.
    mutating func authenticationSucceeded(id: UUID, now: Duration, safety: Safety) -> Lease? {
        guard observe(now), case let .awaitingAuthentication(challenge) = state else { return nil }
        guard challenge.id == id else { return nil }
        // Consume this challenge on success OR rejection. Never save or reuse it.
        state = .idle
        guard now < challenge.deadline, safety.permitsOperation, !safety.lidClosed else { return nil }
        let lease = Lease(id: id, deadline: now + .seconds(challenge.minutes * 60),
                          closeBy: now + .seconds(60))
        state = .admitted(lease)
        return lease
    }

    mutating func authenticationCancelled(id: UUID) {
        if case let .awaitingAuthentication(challenge) = state, challenge.id == id { state = .idle }
    }

    mutating func tick(now: Duration, safety: Safety) {
        guard observe(now) else { return }
        switch state {
        case let .awaitingAuthentication(challenge):
            if now >= challenge.deadline || !safety.permitsOperation || safety.lidClosed { state = .idle }
        case var .admitted(lease):
            if now >= lease.deadline || !safety.permitsOperation {
                state = .restorationRequired
                return
            }
            if lease.sawClosedLid && !safety.lidClosed {
                state = .restorationRequired
                return
            }
            // Do not let a long-unused authorization arm a later lid closure.
            if !lease.sawClosedLid && now >= lease.closeBy {
                state = .restorationRequired
                return
            }
            if safety.lidClosed { lease.sawClosedLid = true }
            state = .admitted(lease)
        default: break
        }
    }

    // Cancel, app exit, IPC loss, logout, OS sleep, or backend enable failure.
    mutating func end() {
        switch state {
        case .awaitingAuthentication: state = .idle
        case .admitted: state = .restorationRequired
        default: break
        }
    }

    private mutating func observe(_ now: Duration) -> Bool {
        guard now >= .zero, now >= lastTime else {
            // A clock fault must never prolong a lease or unblock recovery.
            switch state {
            case .admitted: state = .restorationRequired
            case .idle, .awaitingAuthentication: state = .blocked
            default: break
            }
            return false
        }
        lastTime = now
        return true
    }
}
