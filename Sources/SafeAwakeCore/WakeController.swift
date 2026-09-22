import Combine
import Foundation

@MainActor
public final class WakeController: NSObject, ObservableObject {
    @Published public private(set) var isActive = false
    @Published public private(set) var expiresAt: Date?
    @Published public private(set) var statusMessage = "已关闭，Mac 可正常休眠"
    @Published public var requiresACPower = true
    @Published public var selectedDurationMinutes = 120

    private let assertionManager: SleepAssertionManaging
    private let powerSource: PowerSourceProviding
    private let displaySleeper: DisplaySleeper
    private var monitorTimer: Timer?

    public init(
        assertionManager: SleepAssertionManaging = ProcessInfoSleepAssertionManager(),
        powerSource: PowerSourceProviding = SystemPowerSourceProvider(),
        displaySleeper: DisplaySleeper = DisplaySleeper()
    ) {
        self.assertionManager = assertionManager
        self.powerSource = powerSource
        self.displaySleeper = displaySleeper
        super.init()
    }

    @discardableResult
    public func start(now: Date = Date()) -> Bool {
        guard !isActive else { return true }

        if requiresACPower && !powerSource.isOnACPower {
            statusMessage = "未启动：请先连接电源"
            return false
        }

        assertionManager.start()
        guard assertionManager.isActive else {
            statusMessage = "启动失败，请重试"
            return false
        }

        isActive = true
        expiresAt = selectedDurationMinutes > 0
            ? now.addingTimeInterval(TimeInterval(selectedDurationMinutes * 60))
            : nil
        statusMessage = activeStatusMessage(now: now)
        startMonitoring()
        return true
    }

    public func stop(reason: String = "已关闭，Mac 可正常休眠") {
        assertionManager.stop()
        isActive = false
        expiresAt = nil
        statusMessage = reason
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    public func toggle() {
        if isActive {
            stop()
        } else {
            _ = start()
        }
    }

    public func refresh(now: Date = Date()) {
        guard isActive else { return }

        if requiresACPower && !powerSource.isOnACPower {
            stop(reason: "电源已断开，已自动恢复正常休眠")
            return
        }

        if let expiresAt, now >= expiresAt {
            stop(reason: "定时结束，Mac 可正常休眠")
            return
        }

        statusMessage = activeStatusMessage(now: now)
    }

    public func sleepDisplayNow() {
        do {
            try displaySleeper.sleepNow()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func startMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(
            timeInterval: 10,
            target: self,
            selector: #selector(monitorTimerFired),
            userInfo: nil,
            repeats: true
        )
        if let monitorTimer {
            RunLoop.main.add(monitorTimer, forMode: .common)
        }
    }

    @objc private func monitorTimerFired() {
        refresh()
    }

    private func activeStatusMessage(now: Date) -> String {
        guard let expiresAt else {
            return "正在保持唤醒，直至手动关闭"
        }

        let remaining = max(0, Int(ceil(expiresAt.timeIntervalSince(now) / 60.0)))
        return "正在保持唤醒，约剩余 \(remaining) 分钟"
    }

}
