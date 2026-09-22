import Combine
import Foundation

public struct WakeDuration: Hashable, Identifiable, Sendable {
    public let minutes: Int
    public let label: String
    public let compactLabel: String

    public var id: Int { minutes }

    public static let options: [WakeDuration] = [
        WakeDuration(minutes: 30, label: "30 分钟", compactLabel: "30m"),
        WakeDuration(minutes: 60, label: "1 小时", compactLabel: "1h"),
        WakeDuration(minutes: 120, label: "2 小时", compactLabel: "2h"),
        WakeDuration(minutes: 240, label: "4 小时", compactLabel: "4h"),
        WakeDuration(minutes: 0, label: "直到手动关闭", compactLabel: "不限时")
    ]

    public static func option(for minutes: Int) -> WakeDuration {
        options.first(where: { $0.minutes == minutes })
            ?? options.first(where: { $0.minutes == 120 })!
    }
}

public enum FeedbackTone: Sendable {
    case success
    case warning
}

@MainActor
public final class WakeController: NSObject, ObservableObject {
    @Published public private(set) var isActive = false
    @Published public private(set) var expiresAt: Date?
    @Published public private(set) var statusMessage = "已关闭，Mac 可正常休眠"
    @Published public private(set) var feedbackMessage: String?
    @Published public private(set) var feedbackTone: FeedbackTone = .success
    @Published public private(set) var isOnACPower = false
    @Published public var requiresACPower: Bool {
        didSet { defaults.set(requiresACPower, forKey: Self.requiresACPowerKey) }
    }
    @Published public var selectedDurationMinutes: Int {
        didSet { defaults.set(selectedDurationMinutes, forKey: Self.durationKey) }
    }

    private let assertionManager: SleepAssertionManaging
    private let powerSource: PowerSourceProviding
    private let displaySleeper: DisplaySleeper
    private let defaults: UserDefaults
    private var monitorTimer: Timer?
    private var feedbackTimer: Timer?
    private var sessionDurationMinutes: Int?

    private static let durationKey = "SafeAwake.selectedDurationMinutes"
    private static let requiresACPowerKey = "SafeAwake.requiresACPower"

    public init(
        assertionManager: SleepAssertionManaging = ProcessInfoSleepAssertionManager(),
        powerSource: PowerSourceProviding = SystemPowerSourceProvider(),
        displaySleeper: DisplaySleeper = DisplaySleeper(),
        defaults: UserDefaults = .standard
    ) {
        self.assertionManager = assertionManager
        self.powerSource = powerSource
        self.displaySleeper = displaySleeper
        self.defaults = defaults

        let storedDuration = defaults.object(forKey: Self.durationKey) as? Int ?? 120
        self.selectedDurationMinutes = WakeDuration.option(for: storedDuration).minutes
        self.requiresACPower = defaults.object(forKey: Self.requiresACPowerKey) == nil
            ? true
            : defaults.bool(forKey: Self.requiresACPowerKey)
        super.init()
        self.isOnACPower = powerSource.isOnACPower
    }

    @discardableResult
    public func start(now: Date = Date()) -> Bool {
        guard !isActive else { return true }

        if requiresACPower && !powerSource.isOnACPower {
            statusMessage = "未启动：请先连接电源"
            showFeedback("请先连接电源，再开启保持唤醒", tone: .warning)
            return false
        }

        assertionManager.start()
        guard assertionManager.isActive else {
            statusMessage = "启动失败，请重试"
            showFeedback("无法创建系统防休眠请求", tone: .warning)
            return false
        }

        isActive = true
        sessionDurationMinutes = selectedDurationMinutes > 0 ? selectedDurationMinutes : nil
        expiresAt = selectedDurationMinutes > 0
            ? now.addingTimeInterval(TimeInterval(selectedDurationMinutes * 60))
            : nil
        statusMessage = activeStatusMessage(now: now)
        showFeedback("保持唤醒已开启")
        startMonitoring()
        return true
    }

    public func stop(
        reason: String = "已关闭，Mac 可正常休眠",
        feedback: String? = "已恢复正常休眠"
    ) {
        assertionManager.stop()
        isActive = false
        expiresAt = nil
        sessionDurationMinutes = nil
        statusMessage = reason
        monitorTimer?.invalidate()
        monitorTimer = nil
        if let feedback { showFeedback(feedback) }
    }

    public func toggle() {
        if isActive {
            stop()
        } else {
            _ = start()
        }
    }

    public func refresh(now: Date = Date()) {
        isOnACPower = powerSource.isOnACPower
        guard isActive else { return }

        if requiresACPower && !isOnACPower {
            stop(
                reason: "电源已断开，已自动恢复正常休眠",
                feedback: "电源断开，保持唤醒已安全关闭"
            )
            return
        }

        if let expiresAt, now >= expiresAt {
            stop(reason: "定时结束，Mac 可正常休眠", feedback: "定时结束，已恢复正常休眠")
            return
        }

        statusMessage = activeStatusMessage(now: now)
    }

    public func setDuration(minutes: Int, now: Date = Date()) {
        let option = WakeDuration.option(for: minutes)
        selectedDurationMinutes = option.minutes
        guard isActive else { return }

        sessionDurationMinutes = option.minutes > 0 ? option.minutes : nil
        expiresAt = option.minutes > 0
            ? now.addingTimeInterval(TimeInterval(option.minutes * 60))
            : nil
        statusMessage = activeStatusMessage(now: now)
        showFeedback("持续时间已调整为\(option.label)")
    }

    public func refreshPowerState() {
        isOnACPower = powerSource.isOnACPower
    }

    public func remainingText(now: Date = Date()) -> String? {
        guard let expiresAt else { return nil }
        let remainingSeconds = max(0, Int(expiresAt.timeIntervalSince(now)))
        if remainingSeconds < 60 { return "不到 1 分钟" }

        let totalMinutes = Int(ceil(Double(remainingSeconds) / 60.0))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 { return "\(hours) 小时 \(minutes) 分钟" }
        if hours > 0 { return "\(hours) 小时" }
        return "\(minutes) 分钟"
    }

    public func remainingFraction(now: Date = Date()) -> Double {
        guard
            isActive,
            let expiresAt,
            let durationMinutes = sessionDurationMinutes,
            durationMinutes > 0
        else {
            return isActive ? 1 : 0
        }

        let total = TimeInterval(durationMinutes * 60)
        return min(1, max(0, expiresAt.timeIntervalSince(now) / total))
    }

    public func sleepDisplayNow() {
        do {
            try displaySleeper.sleepNow()
            showFeedback("显示器已关闭，任务继续运行")
        } catch {
            statusMessage = error.localizedDescription
            showFeedback(error.localizedDescription, tone: .warning)
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
        guard expiresAt != nil else {
            return "持续保持唤醒，直至手动关闭"
        }

        return "将在 \(remainingText(now: now) ?? "不到 1 分钟")后恢复正常休眠"
    }

    private func showFeedback(_ message: String, tone: FeedbackTone = .success) {
        feedbackTimer?.invalidate()
        feedbackMessage = message
        feedbackTone = tone
        let timer = Timer(timeInterval: 3.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.feedbackMessage = nil
                self?.feedbackTimer = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        feedbackTimer = timer
    }

}
