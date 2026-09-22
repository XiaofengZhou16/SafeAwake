import Foundation
import IOKit.ps

public protocol PowerSourceProviding {
    var isOnACPower: Bool { get }
}

public struct SystemPowerSourceProvider: PowerSourceProviding {
    public init() {}

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
