//
// main.swift
// aifw-daemon
//

import Foundation
import AIFW

print("AIFW Daemon v0.1.0")
print("Phase 2: Activity Logger\n")

// Create logger in temp directory for demo
let tempDir = FileManager.default.temporaryDirectory
let dbPath = tempDir.appendingPathComponent("aifw-demo.db").path
let logger = ActivityLogger(dbPath: dbPath)

print("Demonstrating ActivityLogger:\n")

// Log various events
print("1. Logging file operations:")
logger.log(
    eventType: EventType.fileWrite,
    processName: "opencode",
    pid: 12345,
    ppid: 1000,
    path: "/tmp/test.txt",
    command: nil,
    destination: nil,
    allowed: true,
    reason: "non-sensitive location"
)
print("   Logged file write")

logger.log(
    eventType: EventType.fileWrite,
    processName: "opencode",
    pid: 12345,
    ppid: 1000,
    path: "~/.ssh/authorized_keys",
    command: nil,
    destination: nil,
    allowed: false,
    reason: "sensitive directory - user denied"
)
print("   Logged blocked sensitive write")

// Log command execution
print("\n2. Logging command execution:")
logger.log(
    eventType: EventType.processExec,
    processName: "/bin/bash",
    pid: 12346,
    ppid: 12345,
    path: "/bin/bash",
    command: "git status",
    destination: nil,
    allowed: true,
    reason: "auto-allow pattern"
)
print("   Logged safe command")

logger.log(
    eventType: EventType.processExec,
    processName: "/bin/bash",
    pid: 12347,
    ppid: 12345,
    path: "/bin/bash",
    command: "sudo rm important_file",
    destination: nil,
    allowed: false,
    reason: "dangerous pattern - user denied"
)
print("   Logged blocked dangerous command")

// Log network connection
print("\n3. Logging network connections:")
logger.log(
    eventType: EventType.networkConnect,
    processName: "opencode",
    pid: 12345,
    ppid: 1000,
    path: nil,
    command: nil,
    destination: "127.0.0.1:11434",
    allowed: true,
    reason: "ollama local connection"
)
print("   Logged Ollama connection")

// Display recent activity
print("\n4. Recent Activity:")
let records = logger.getRecentActivity(limit: 10)
for (index, record) in records.enumerated() {
    let status = record.allowed ? "ALLOW" : "DENY"
    print("   \(index + 1). [\(record.eventType)] \(status)")
    if let path = record.path {
        print("      Path: \(path)")
    }
    if let command = record.command {
        print("      Command: \(command)")
    }
    if let destination = record.destination {
        print("      Destination: \(destination)")
    }
    if let reason = record.reason {
        print("      Reason: \(reason)")
    }
}

// Display statistics
print("\n5. Statistics:")
let stats = logger.getStatistics()
print("   Total events: \(stats.total)")
print("   Allowed: \(stats.allowed)")
print("   Denied: \(stats.denied)")

print("\nActivityLogger working correctly")
print("Database: \(dbPath)")
