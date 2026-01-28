//
// MockComponents.swift
// AIFW
//
// Mock implementations for testing
//

import Foundation

/// Mock policy engine for testing
public class MockPolicyEngine: PolicyEngineProtocol {
    public var fileReadDecision: PolicyDecision = .allow(reason: "mock default")
    public var fileWriteDecision: PolicyDecision = .allow(reason: "mock default")
    public var fileDeleteDecision: PolicyDecision = .prompt(reason: "mock default")
    public var commandDecision: PolicyDecision = .allow(reason: "mock default")
    public var networkDecision: PolicyDecision = .allow(reason: "mock default")

    public init() {}

    public func checkFileRead(path: String) -> PolicyDecision {
        return fileReadDecision
    }

    public func checkFileWrite(path: String) -> PolicyDecision {
        return fileWriteDecision
    }

    public func checkFileDelete(path: String) -> PolicyDecision {
        return fileDeleteDecision
    }

    public func checkCommand(command: String) -> PolicyDecision {
        return commandDecision
    }

    public func checkNetworkConnection(destination: String, port: UInt16) -> PolicyDecision {
        return networkDecision
    }
}

/// Mock activity logger for testing
public class MockActivityLogger: ActivityLoggerProtocol {
    public struct LogEntry {
        public let eventType: String
        public let processName: String?
        public let pid: Int32
        public let ppid: Int32
        public let path: String?
        public let command: String?
        public let destination: String?
        public let allowed: Bool
        public let reason: String?
    }

    public var logs: [LogEntry] = []

    public init() {}

    public func log(
        eventType: String,
        processName: String?,
        pid: Int32,
        ppid: Int32,
        path: String?,
        command: String?,
        destination: String?,
        allowed: Bool,
        reason: String?
    ) {
        logs.append(LogEntry(
            eventType: eventType,
            processName: processName,
            pid: pid,
            ppid: ppid,
            path: path,
            command: command,
            destination: destination,
            allowed: allowed,
            reason: reason
        ))
    }

    public func getRecentActivity(limit: Int) -> [ActivityRecord] {
        return []
    }

    public func getStatistics() -> (total: Int, allowed: Int, denied: Int) {
        let allowed = logs.filter { $0.allowed }.count
        let denied = logs.filter { !$0.allowed }.count
        return (logs.count, allowed, denied)
    }

    public func clearAll() {
        logs.removeAll()
    }
}
