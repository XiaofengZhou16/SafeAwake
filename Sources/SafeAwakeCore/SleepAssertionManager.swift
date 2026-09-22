import Foundation

public protocol SleepAssertionManaging: AnyObject {
    var isActive: Bool { get }
    func start()
    func stop()
}

public final class ProcessInfoSleepAssertionManager: SleepAssertionManaging {
    private var activity: NSObjectProtocol?

    public init() {}

    public var isActive: Bool {
        activity != nil
    }

    public func start() {
        guard activity == nil else { return }

        activity = ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled, .userInitiated],
            reason: "SafeAwake is keeping the Mac available for a user-started task."
        )
    }

    public func stop() {
        guard let activity else { return }
        ProcessInfo.processInfo.endActivity(activity)
        self.activity = nil
    }

    deinit {
        stop()
    }
}
