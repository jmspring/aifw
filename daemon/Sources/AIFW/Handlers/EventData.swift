//
// EventData.swift
// AIFW
//
// Event data structures
//

import Foundation

/// File operation event data
public struct FileOperationEvent {
    public let pid: Int32
    public let ppid: Int32
    public let processPath: String?
    public let filePath: String
    public let isWrite: Bool
    public let isDelete: Bool

    public init(pid: Int32, ppid: Int32, processPath: String?,
                filePath: String, isWrite: Bool, isDelete: Bool) {
        self.pid = pid
        self.ppid = ppid
        self.processPath = processPath
        self.filePath = filePath
        self.isWrite = isWrite
        self.isDelete = isDelete
    }
}

/// Process execution event data
public struct ProcessExecutionEvent {
    public let pid: Int32
    public let ppid: Int32
    public let executablePath: String
    public let command: String

    public init(pid: Int32, ppid: Int32, executablePath: String, command: String) {
        self.pid = pid
        self.ppid = ppid
        self.executablePath = executablePath
        self.command = command
    }
}

/// Network connection event data
public struct NetworkConnectionEvent {
    public let pid: Int32
    public let ppid: Int32
    public let processPath: String?
    public let destination: String
    public let port: UInt16

    public init(pid: Int32, ppid: Int32, processPath: String?,
                destination: String, port: UInt16) {
        self.pid = pid
        self.ppid = ppid
        self.processPath = processPath
        self.destination = destination
        self.port = port
    }
}

/// Handler decision
public enum HandlerDecision: Equatable {
    case allow
    case deny
}
