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
            powerSource: FakePowerSource(isOnACPower: true)
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
            powerSource: FakePowerSource(isOnACPower: false)
        )

        #expect(!controller.start())
        #expect(!controller.isActive)
        #expect(assertion.startCount == 0)
        #expect(controller.statusMessage.contains("连接电源"))
    }

    @Test
    func automaticallyStopsWhenTimerExpires() {
        let assertion = FakeAssertionManager()
        let controller = WakeController(
            assertionManager: assertion,
            powerSource: FakePowerSource(isOnACPower: true)
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
            powerSource: power
        )

        #expect(controller.start())
        power.isOnACPower = false
        controller.refresh()

        #expect(!controller.isActive)
        #expect(assertion.stopCount == 1)
        #expect(controller.statusMessage.contains("电源已断开"))
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
