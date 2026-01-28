//
// ActivityRecord.swift
// AIFW
//
// Data structure for logged activity
//

import Foundation

/// Represents a single monitored activity event
public struct ActivityRecord: Equatable {
    public let id: Int?
    public let timestamp: Date
    public let eventType: String
    public let processName: String?
    public let pid: Int32
    public let ppid: Int32
    public let path: String?
    public let command: String?
    public let destination: String?
    public let allowed: Bool
    public let reason: String?

    public init(
        id: Int? = nil,
        timestamp: Date,
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
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.processName = processName
        self.pid = pid
        self.ppid = ppid
        self.path = path
        self.command = command
        self.destination = destination
        self.allowed = allowed
        self.reason = reason
    }
}

/// Event type constants
public enum EventType {
    public static let fileRead = "file_read"
    public static let fileWrite = "file_write"
    public static let fileDelete = "file_delete"
    public static let processExec = "process_exec"
    public static let networkConnect = "network_connect"
    public static let ollamaRequest = "ollama_request"
    public static let ollamaResponse = "ollama_response"
}
