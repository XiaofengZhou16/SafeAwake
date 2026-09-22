import Foundation
import Testing
@testable import SafeAwakeCore

@MainActor
struct WakeControllerTests {
    @Test
    func startsAndStopsAssertion() {
        let assertion = FakeAssertionManager()
        let controller = WakeController(
            assertionManager: assertion,
            powerSource: FakePowerSource(isOnACPower: true),
            defaults: makeDefaults()
        )

        #expect(controller.start(now: Date(timeIntervalSince1970: 0)))
        #expect(controller.isActive)
        #expect(assertion.startCount == 1)

        controller.stop()
        #expect(!controller.isActive)
        #expect(assertion.stopCount == 1)
    }

    @Test
    func refusesToStartOnBatteryByDefault() {
        let assertion = FakeAssertionManager()
        let controller = WakeController(
            assertionManager: assertion,
            powerSource: FakePowerSource(isOnACPower: false),
            defaults: makeDefaults()
        )

        #expect(!controller.start())
        #expect(!controller.isActive)
        #expect(assertion.startCount == 0)
        #expect(controller.statusMessage.contains("连接电源"))
        #expect(controller.feedbackTone == .warning)
    }

    @Test
    func automaticallyStopsWhenTimerExpires() {
        let assertion = FakeAssertionManager()
        let controller = WakeController(
            assertionManager: assertion,
            powerSource: FakePowerSource(isOnACPower: true),
            defaults: makeDefaults()
        )
        controller.selectedDurationMinutes = 30
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(controller.start(now: start))
        controller.refresh(now: start.addingTimeInterval(30 * 60 + 1))

        #expect(!controller.isActive)
        #expect(assertion.stopCount == 1)
        #expect(controller.statusMessage.contains("定时结束"))
    }

    @Test
    func automaticallyStopsWhenPowerIsDisconnected() {
        let assertion = FakeAssertionManager()
        let power = MutablePowerSource(isOnACPower: true)
        let controller = WakeController(
            assertionManager: assertion,
            powerSource: power,
            defaults: makeDefaults()
        )

        #expect(controller.start())
        power.isOnACPower = false
        controller.refresh()

        #expect(!controller.isActive)
        #expect(assertion.stopCount == 1)
        #expect(controller.statusMessage.contains("电源已断开"))
    }

    @Test
    func changesDurationWithoutRestartingAssertion() {
        let assertion = FakeAssertionManager()
        let controller = WakeController(
            assertionManager: assertion,
            powerSource: FakePowerSource(isOnACPower: true),
            defaults: makeDefaults()
        )
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(controller.start(now: start))
        controller.setDuration(minutes: 60, now: start.addingTimeInterval(10))

        #expect(controller.isActive)
        #expect(controller.selectedDurationMinutes == 60)
        #expect(controller.expiresAt == start.addingTimeInterval(10 + 3_600))
        #expect(assertion.startCount == 1)
        #expect(assertion.stopCount == 0)
    }

    @Test
    func persistsSafePreferences() {
        let defaults = makeDefaults()
        let first = WakeController(
            assertionManager: FakeAssertionManager(),
            powerSource: FakePowerSource(isOnACPower: true),
            defaults: defaults
        )
        first.setDuration(minutes: 30)
        first.requiresACPower = false

        let restored = WakeController(
            assertionManager: FakeAssertionManager(),
            powerSource: FakePowerSource(isOnACPower: true),
            defaults: defaults
        )

        #expect(restored.selectedDurationMinutes == 30)
        #expect(!restored.requiresACPower)
    }

    @Test
    func formatsRemainingTimeForTheStatusHUD() {
        let controller = WakeController(
            assertionManager: FakeAssertionManager(),
            powerSource: FakePowerSource(isOnACPower: true),
            defaults: makeDefaults()
        )
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(controller.start(now: start))
        #expect(controller.remainingText(now: start) == "2 小时")
        #expect(controller.remainingText(now: start.addingTimeInterval(30 * 60)) == "1 小时 30 分钟")
        #expect(controller.remainingFraction(now: start.addingTimeInterval(60 * 60)) == 0.5)
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "SafeAwakeTests.\(UUID().uuidString)")!
    }
}

private final class FakeAssertionManager: SleepAssertionManaging {
    private(set) var isActive = false
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() {
        startCount += 1
        isActive = true
    }

    func stop() {
        guard isActive else { return }
        stopCount += 1
        isActive = false
    }
}

private struct FakePowerSource: PowerSourceProviding {
    let isOnACPower: Bool
}

private final class MutablePowerSource: PowerSourceProviding {
    var isOnACPower: Bool

    init(isOnACPower: Bool) {
        self.isOnACPower = isOnACPower
    }
}
