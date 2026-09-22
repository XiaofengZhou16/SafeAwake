import Foundation
import Testing
@testable import SafeAwakeCore

@MainActor
struct SessionSafetyTests {
    private func make(_ power: Power, _ display: Display = Display()) -> WakeController {
        WakeController(assertionManager: Assertion(), powerSource: power, displaySleeper: display,
                       defaults: UserDefaults(suiteName: "SafeAwakeTests.\(UUID())")!)
    }

    @Test func lowBatteryStopsEvenWhenACOnlyIsDisabled() {
        let power = Power()
        let c = make(power)
        c.requiresACPower = false
        #expect(c.start())
        power.isOnACPower = false
        power.batteryPercent = 20
        c.refresh()
        #expect(!c.isActive)
        #expect(!c.start())
    }

    @Test func unknownBatteryFailsClosed() {
        let power = Power()
        power.isOnACPower = false
        power.batteryPercent = nil
        let c = make(power)
        c.requiresACPower = false
        #expect(!c.start())
    }

    @Test func extendsDeadlineWithoutResettingIt() {
        let c = make(Power())
        let now = Date()
        #expect(c.start(now: now))
        c.extendSession(now: now.addingTimeInterval(600))
        #expect(c.expiresAt == now.addingTimeInterval(9000))
        #expect(c.selectedDurationMinutes == 120)
        c.stop()
    }

    @Test func cannotExtendAnExpiredSession() {
        let c = make(Power())
        let now = Date()
        #expect(c.start(now: now))
        c.extendSession(now: now.addingTimeInterval(8000))
        #expect(!c.isActive)
        #expect(c.expiresAt == nil)
    }

    @Test func oneClickDisplayStartsOnlyWhenPowerAllowsIt() {
        let power = Power()
        let display = Display()
        let c = make(power, display)
        power.isOnACPower = false
        c.sleepDisplayNow()
        #expect(display.calls == 0)
        power.isOnACPower = true
        c.sleepDisplayNow()
        #expect(c.isActive)
        #expect(display.calls == 1)
        c.stop()
    }

    @Test func failedDisplayRequestPreservesWakeSessionAndShowsError() {
        let display = Display()
        display.fails = true
        let c = make(Power(), display)
        c.sleepDisplayNow()
        #expect(c.isActive)
        #expect(c.feedbackTone == .warning)
        c.stop()
    }

    @Test func relaunchDoesNotResumeSession() {
        let defaults = UserDefaults(suiteName: "SafeAwakeTests.\(UUID())")!
        let first = WakeController(assertionManager: Assertion(), powerSource: Power(), defaults: defaults)
        first.setDuration(minutes: 0)
        #expect(first.start())
        let second = WakeController(assertionManager: Assertion(), powerSource: Power(), defaults: defaults)
        #expect(!second.isActive)
        #expect(second.menuBarText.isEmpty)
        first.stop()
    }
}

private final class Power: PowerSourceProviding {
    var isOnACPower = true
    var batteryPercent: Int? = 80
}
private final class Assertion: SleepAssertionManaging {
    var isActive = false
    func start() { isActive = true }
    func stop() { isActive = false }
}
private final class Display: DisplaySleeping {
    var calls = 0
    var fails = false
    func sleepNow() throws {
        calls += 1
        if fails { throw DisplaySleepError.commandFailed }
    }
}
