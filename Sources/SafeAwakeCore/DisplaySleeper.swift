import Foundation

public enum DisplaySleepError: LocalizedError {
    case commandFailed

    public var errorDescription: String? {
        switch self {
        case .commandFailed:
            return "无法关闭显示器，请稍后重试。"
        }
    }
}

public struct DisplaySleeper {
    public init() {}

    public func sleepNow() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw DisplaySleepError.commandFailed
        }
    }
}
