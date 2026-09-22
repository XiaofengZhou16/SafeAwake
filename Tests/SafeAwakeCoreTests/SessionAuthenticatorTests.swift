import Foundation
import Testing
@testable import SafeAwakeCore

@MainActor
struct SessionAuthenticatorTests {
    @Test func eachRequestUsesNewContextAndID() async throws {
        var contexts = [MockAuthenticationContext]()
        let auth = SessionAuthenticator(makeContext: {
            let context = MockAuthenticationContext()
            contexts.append(context)
            return context
        })
        let first = try await auth.verify(minutes: 1)
        let second = try await auth.verify(minutes: 30)
        #expect(first.requestID != second.requestID)
        #expect(first.minutes == 1 && second.minutes == 30)
        #expect(contexts.count == 2)
        #expect(contexts.allSatisfy { $0.prepared && $0.invalidations > 0 })
        #expect(contexts[1].reason.contains("30"))
    }

    @Test func invalidDurationNeverOpensPrompt() async {
        var count = 0
        let auth = SessionAuthenticator(makeContext: { count += 1; return MockAuthenticationContext() })
        for minutes in [-1, 0, 31, Int.max] {
            do { _ = try await auth.verify(minutes: minutes); Issue.record("Accepted invalid duration") }
            catch { #expect(error as? SessionAuthenticationError == .invalidDuration) }
        }
        #expect(count == 0)
    }

    @Test func deniedVerificationIsNotApproval() async {
        let context = MockAuthenticationContext()
        context.accepted = false
        let auth = SessionAuthenticator(makeContext: { context })
        do { _ = try await auth.verify(minutes: 1); Issue.record("Accepted denial") }
        catch { #expect(error as? SessionAuthenticationError == .rejected) }
        #expect(context.invalidations > 0)
    }

    @Test func systemErrorCleansUp() async {
        let context = MockAuthenticationContext()
        context.error = SessionAuthenticationError.unavailable
        let auth = SessionAuthenticator(makeContext: { context })
        do { _ = try await auth.verify(minutes: 1); Issue.record("Accepted error") }
        catch { #expect(error as? SessionAuthenticationError == .unavailable) }
        #expect(context.invalidations > 0)
    }

    @Test func cancellationRejectsEvenLateSuccess() async {
        let context = MockAuthenticationContext()
        let auth = SessionAuthenticator(makeContext: { context })
        context.beforeReturn = { auth.cancel() }
        do { _ = try await auth.verify(minutes: 1); Issue.record("Accepted cancelled request") }
        catch { #expect(error as? SessionAuthenticationError == .cancelled) }
    }

    @Test(arguments: [-1, 60, 61]) func staleOrInvalidClockRejectsSuccess(seconds: Int) async {
        var time = Duration.zero
        let context = MockAuthenticationContext()
        let auth = SessionAuthenticator(makeContext: { context }, now: { time })
        context.beforeReturn = { time = .seconds(seconds) }
        do { _ = try await auth.verify(minutes: 30); Issue.record("Accepted stale verification") }
        catch { #expect(error as? SessionAuthenticationError == .expired) }
        #expect(context.invalidations > 0)
    }
}

@MainActor
private final class MockAuthenticationContext: SessionAuthenticationContext {
    var prepared = false
    var accepted = true
    var invalidations = 0
    var reason = ""
    var error: Error?
    var beforeReturn: (() -> Void)?
    func prepareForFreshVerification() { prepared = true }
    func invalidate() { invalidations += 1 }
    func verify(reason: String) async throws -> Bool {
        self.reason = reason
        beforeReturn?()
        if let error { throw error }
        return accepted
    }
}
