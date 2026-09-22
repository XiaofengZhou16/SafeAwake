import Foundation
import IOKit.ps

public protocol PowerSourceProviding {
    var isOnACPower: Bool { get }
    var batteryPercent: Int? { get }
}

public extension PowerSourceProviding {
    var batteryPercent: Int? { nil }
}

public struct SystemPowerSourceProvider: PowerSourceProviding {
    public init() {}

    public var batteryPercent: Int? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = d[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = d[kIOPSMaxCapacityKey] as? Int, maximum > 0
            else { continue }
            return min(100, max(0, current * 100 / maximum))
        }
        return nil
    }

    public var isOnACPower: Bool {
        guard
            let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let source = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue()
        else {
            // Fail closed: an unknown power state must not start a keep-awake session.
            return false
        }

        return (source as String) == kIOPSACPowerValue
    }
}
