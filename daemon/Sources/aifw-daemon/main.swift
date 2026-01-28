//
// main.swift
// aifw-daemon
//

import Foundation
import AIFW

print("AIFW Daemon v0.1.0")
print("Phase 5: Event Handlers\n")

// Create all components
let policy = FirewallPolicy.defaultPolicy()
let policyEngine = PolicyEngine(policy: policy)

let tempDir = FileManager.default.temporaryDirectory
let dbPath = tempDir.appendingPathComponent("aifw-demo.db").path
let logger = ActivityLogger(dbPath: dbPath)

let tracker = ProcessTracker(rootPID: getpid())
let prompt = MockUserPrompt(defaultResponse: .allowOnce)

// Create event handler
let handler = EventHandler(
    policyEngine: policyEngine,
    activityLogger: logger,
    processTracker: tracker,
    userPrompt: prompt
)

print("Testing Event Handler Integration:\n")

// Test 1: File write
print("1. File Write Event:")
let fileEvent = FileOperationEvent(
    pid: getpid(),
    ppid: getppid(),
    processPath: "/usr/bin/opencode",
    filePath: "/tmp/test.txt",
    isWrite: true,
    isDelete: false
)
let decision1 = handler.handleFileOperation(fileEvent)
print("   Decision: \(decision1)")

// Test 2: Command execution
print("\n2. Command Execution Event:")
let execEvent = ProcessExecutionEvent(
    pid: getpid(),
    ppid: getppid(),
    executablePath: "/bin/bash",
    command: "git status"
)
let decision2 = handler.handleProcessExecution(execEvent)
print("   Decision: \(decision2)")

// Test 3: Network connection
print("\n3. Network Connection Event:")
let netEvent = NetworkConnectionEvent(
    pid: getpid(),
    ppid: getppid(),
    processPath: "/usr/bin/opencode",
    destination: "127.0.0.1",
    port: 11434
)
let decision3 = handler.handleNetworkConnection(netEvent)
print("   Decision: \(decision3)")

// Show statistics
print("\nActivity Statistics:")
let stats = logger.getStatistics()
print("   Total events: \(stats.total)")
print("   Allowed: \(stats.allowed)")
print("   Denied: \(stats.denied)")

print("\nEventHandler successfully integrating all components")
print("\nNext: Phase 6 will add Endpoint Security framework integration")
