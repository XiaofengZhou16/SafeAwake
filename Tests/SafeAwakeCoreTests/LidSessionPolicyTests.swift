import Foundation
import Testing
@testable import SafeAwakeCore

struct LidSessionPolicyTests {
    private let safe = LidSessionPolicy.Safety()

    private func required<T>(_ value: T?) throws -> T { try #require(value) }

    private func ready() -> LidSessionPolicy {
        var policy = LidSessionPolicy()
        policy.restorationVerified()
        return policy
    }

    private func admitted(minutes: Int = 30) throws -> LidSessionPolicy {
        var policy = ready()
        let challenge = try required(policy.request(minutes: minutes, now: .zero, safety: safe))
        #expect(policy.authenticationSucceeded(id: challenge.id, now: .seconds(1), safety: safe) != nil)
        return policy
    }

    @Test func startupRequiresVerifiedRecovery() {
        var policy = LidSessionPolicy()
        #expect(policy.request(minutes: 30, now: .zero, safety: safe) == nil)
        #expect(policy.state == .recoveryRequired)
    }

    @Test(arguments: [-1, 31, Int.max]) func invalidDurationsAreRejected(minutes: Int) {
        var policy = ready()
        #expect(policy.request(minutes: minutes, now: .zero, safety: safe) == nil)
        #expect(policy.state == .idle)
    }

    @Test(arguments: [1, 7, 30]) func exactDurationBeginsAtAuthentication(minutes: Int) throws {
        var policy = ready()
        let challenge = try required(policy.request(minutes: minutes, now: .zero, safety: safe))
        let lease = try required(policy.authenticationSucceeded(id: challenge.id, now: .seconds(10), safety: safe))
        #expect(lease.deadline == .seconds(10 + minutes * 60))
    }

    @Test func zeroCancelsAndCannotMeanUnlimited() throws {
        var policy = try admitted()
        #expect(policy.request(minutes: 0, now: .seconds(2), safety: safe) == nil)
        #expect(policy.state == .restorationRequired)
    }

    @Test func authenticationIsSingleUseAndCannotExtend() throws {
        var policy = ready()
        let challenge = try required(policy.request(minutes: 30, now: .zero, safety: safe))
        let lease = try required(policy.authenticationSucceeded(id: challenge.id, now: .seconds(1), safety: safe))
        #expect(policy.authenticationSucceeded(id: challenge.id, now: .seconds(2), safety: safe) == nil)
        #expect(policy.request(minutes: 30, now: .seconds(3), safety: safe) == nil)
        #expect(policy.state == .admitted(lease))
        policy.end()
        policy.restorationVerified()
        #expect(policy.authenticationSucceeded(id: challenge.id, now: .seconds(4), safety: safe) == nil)
        let next = try required(policy.request(minutes: 1, now: .seconds(5), safety: safe))
        #expect(next.id != challenge.id)
        #expect(policy.authenticationSucceeded(id: challenge.id, now: .seconds(6), safety: safe) == nil)
    }

    @Test func cancelledAuthenticationCannotActivateLater() throws {
        var policy = ready()
        let challenge = try required(policy.request(minutes: 1, now: .zero, safety: safe))
        policy.authenticationCancelled(id: challenge.id)
        #expect(policy.authenticationSucceeded(id: challenge.id, now: .seconds(1), safety: safe) == nil)
    }

    @Test func staleAuthenticationFailsAtBoundary() throws {
        var policy = ready()
        let challenge = try required(policy.request(minutes: 1, now: .zero, safety: safe))
        #expect(policy.authenticationSucceeded(id: challenge.id, now: .seconds(60), safety: safe) == nil)
        #expect(policy.state == .idle)
    }

    @Test func reopeningConsumesSession() throws {
        var policy = try admitted()
        var closed = safe
        closed.lidClosed = true
        policy.tick(now: .seconds(2), safety: closed)
        policy.tick(now: .seconds(3), safety: safe)
        #expect(policy.state == .restorationRequired)
        policy.tick(now: .seconds(4), safety: closed)
        #expect(policy.state == .restorationRequired)
    }

    @Test func unusedAuthorizationExpiresAfterOneMinute() throws {
        var policy = try admitted()
        policy.tick(now: .seconds(61), safety: safe)
        #expect(policy.state == .restorationRequired)
    }

    @Test func hardDeadlineCannotBeExtendedByClosedLid() throws {
        var policy = try admitted()
        var closed = safe
        closed.lidClosed = true
        policy.tick(now: .seconds(2), safety: closed)
        policy.tick(now: .seconds(1800), safety: closed)
        if case .admitted = policy.state {} else { Issue.record("Ended before deadline") }
        policy.tick(now: .seconds(1801), safety: closed)
        #expect(policy.state == .restorationRequired)
    }

    @Test func clockRollbackFailsClosed() throws {
        var policy = try admitted()
        policy.tick(now: .zero, safety: safe)
        #expect(policy.state == .restorationRequired)
    }

    @Test func restoreFailureBlocksRestart() throws {
        var policy = try admitted()
        policy.end()
        policy.restorationFailed()
        #expect(policy.request(minutes: 1, now: .seconds(2), safety: safe) == nil)
        policy.end()
        #expect(policy.state == .blocked)
        policy.restorationVerified()
        #expect(policy.request(minutes: 1, now: .seconds(3), safety: safe) != nil)
    }

    @Test func unsafeConditionsRejectAndRevoke() throws {
        var cases = [LidSessionPolicy.Safety]()
        var s = safe; s.onACPower = false; cases.append(s)
        s = safe; s.batteryPercent = nil; cases.append(s)
        s = safe; s.batteryPercent = 20; cases.append(s)
        s = safe; s.batteryPercent = 101; cases.append(s)
        s = safe; s.thermalNominal = false; cases.append(s)
        s = safe; s.lowPowerMode = true; cases.append(s)
        s = safe; s.clientConnected = false; cases.append(s)
        s = safe; s.supportedHardware = false; cases.append(s)
        for unsafe in cases {
            var policy = ready()
            #expect(policy.request(minutes: 1, now: .zero, safety: unsafe) == nil)
            let challenge = try required(policy.request(minutes: 1, now: .zero, safety: safe))
            #expect(policy.authenticationSucceeded(id: challenge.id, now: .seconds(1), safety: unsafe) == nil)
            policy = try admitted()
            policy.tick(now: .seconds(2), safety: unsafe)
            #expect(policy.state == .restorationRequired)
        }
    }

    @Test func newProcessNeverRestoresAnActiveLease() throws {
        let active = try admitted()
        if case .admitted = active.state {} else { Issue.record("Expected lease") }
        #expect(LidSessionPolicy().state == .recoveryRequired)
    }
}
