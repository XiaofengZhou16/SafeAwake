import Foundation
import LocalAuthentication

// Local app-side verification only. Not an IPC credential or administrator grant.
// Intentionally not connected to the shipping UI or any power-control backend.
@MainActor
protocol SessionAuthenticationContext: AnyObject {
    func prepareForFreshVerification()
    func verify(reason: String) async throws -> Bool
    func invalidate()
}

@MainActor
private final class SystemSessionAuthenticationContext: SessionAuthenticationContext {
    private let context = LAContext()

    func prepareForFreshVerification() {
        context.touchIDAuthenticationAllowableReuseDuration = 0
        context.localizedCancelTitle = "取消"
    }

    func verify(reason: String) async throws -> Bool {
        var error: NSError?
        // macOS SDK: Touch ID or account password; do not select companion policies.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? SessionAuthenticationError.unavailable as NSError
        }
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }

    func invalidate() { context.invalidate() }
}

enum SessionAuthenticationError: Error, Equatable {
    case invalidDuration, busy, unavailable, rejected, cancelled, expired
}

struct LocalSessionVerification: Equatable {
    let requestID: UUID
    let minutes: Int
    let verifiedAt: Duration
}

@MainActor
final class SessionAuthenticator {
    private let makeContext: () -> any SessionAuthenticationContext
    private let now: () -> Duration
    private var pending: (id: UUID, context: any SessionAuthenticationContext)?

    init(makeContext: @escaping () -> any SessionAuthenticationContext = { SystemSessionAuthenticationContext() },
         now: (() -> Duration)? = nil) {
        self.makeContext = makeContext
        let clock = ContinuousClock()
        let origin = clock.now
        self.now = now ?? { origin.duration(to: clock.now) }
    }

    func verify(minutes: Int) async throws -> LocalSessionVerification {
        guard (1...30).contains(minutes) else { throw SessionAuthenticationError.invalidDuration }
        guard pending == nil else { throw SessionAuthenticationError.busy }
        try Task.checkCancellation()
        let id = UUID()
        let started = now()
        guard started >= .zero else { throw SessionAuthenticationError.expired }
        let context = makeContext()
        context.prepareForFreshVerification()
        pending = (id, context)
        // Invalidate the system prompt even if the user never responds.
        let timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(60)) } catch { return }
            self?.cancel(id: id)
        }
        defer {
            timeout.cancel()
            context.invalidate()
            if pending?.id == id { pending = nil }
        }
        return try await withTaskCancellationHandler {
            let accepted = try await context.verify(reason:
                "确认本次合盖会话：\(minutes) 分钟。仅限本次，结束后再次使用需要重新验证。")
            try Task.checkCancellation()
            guard pending?.id == id else { throw SessionAuthenticationError.cancelled }
            let verifiedAt = now()
            guard verifiedAt >= started, verifiedAt < started + .seconds(60) else {
                throw SessionAuthenticationError.expired
            }
            guard accepted else { throw SessionAuthenticationError.rejected }
            return LocalSessionVerification(requestID: id, minutes: minutes, verifiedAt: verifiedAt)
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(id: id) }
        }
    }

    func cancel() {
        if let id = pending?.id { cancel(id: id) }
    }

    private func cancel(id: UUID) {
        guard let current = pending, current.id == id else { return }
        pending = nil
        current.context.invalidate()
    }
}
