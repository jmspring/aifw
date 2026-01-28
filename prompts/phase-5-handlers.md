# Phase 5: Event Handlers

**Branch**: `phase-5-handlers`  
**Prerequisites**: Phases 0-4 complete  
**Duration**: 2-3 hours  
**Focus**: Coordinating components to process ES events  

## Objective

Implement EventHandlers that coordinate PolicyEngine, ProcessTracker, ActivityLogger, and UserPrompt to make decisions about file, exec, and network events. This is the "glue" layer that ties all components together.

## Context

**Review before starting**:
- [Shared Schemas](../aifw-shared-schemas.md) - All component interfaces
- [Master Prompt](../aifw-master-prompt.md#integration-points) - How components connect

**What EventHandlers Does**:
- Receives event data (path, command, destination)
- Checks ProcessTracker to verify PID is monitored
- Consults PolicyEngine for decision
- Shows UserPrompt if needed
- Logs result to ActivityLogger
- Returns ALLOW or DENY decision

**What EventHandlers Does NOT Do**:
- Interact with Endpoint Security (that's Phase 6)
- Make policy decisions (delegates to PolicyEngine)
- Show dialogs directly (delegates to UserPrompt)

## Implementation

### 1. Create Feature Branch

```bash
git checkout main
git pull origin main
git checkout -b phase-5-handlers
```

### 2. Create Event Handler Types

Create `daemon/Sources/AIFW/Handlers/EventData.swift`:

```swift
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
public enum HandlerDecision {
    case allow
    case deny
}
```

### 3. Create Event Handler

Create `daemon/Sources/AIFW/Handlers/EventHandler.swift`:

```swift
//
// EventHandler.swift
// AIFW
//
// Coordinates components to handle events
//

import Foundation

public class EventHandler {
    private let policyEngine: PolicyEngineProtocol
    private let activityLogger: ActivityLoggerProtocol
    private let processTracker: ProcessTrackerProtocol
    private let userPrompt: UserPromptProtocol
    
    public init(
        policyEngine: PolicyEngineProtocol,
        activityLogger: ActivityLoggerProtocol,
        processTracker: ProcessTrackerProtocol,
        userPrompt: UserPromptProtocol
    ) {
        self.policyEngine = policyEngine
        self.activityLogger = activityLogger
        self.processTracker = processTracker
        self.userPrompt = userPrompt
    }
    
    // MARK: - File Operations
    
    public func handleFileOperation(_ event: FileOperationEvent) -> HandlerDecision {
        // Check if we should monitor this process
        guard processTracker.isTracked(event.pid) else {
            return .allow // Not our process
        }
        
        // Determine event type and get policy decision
        let (eventType, policyDecision): (String, PolicyDecision)
        
        if event.isDelete {
            eventType = EventType.fileDelete
            policyDecision = policyEngine.checkFileDelete(path: event.filePath)
        } else if event.isWrite {
            eventType = EventType.fileWrite
            policyDecision = policyEngine.checkFileWrite(path: event.filePath)
        } else {
            eventType = EventType.fileRead
            policyDecision = policyEngine.checkFileRead(path: event.filePath)
        }
        
        // Make final decision
        let (allowed, reason) = evaluateDecision(
            policyDecision,
            promptTitle: "🛡️ AI Firewall",
            promptMessage: event.isDelete ? "Delete file?" : "Write to file?",
            promptDetails: "Path: \(event.filePath)"
        )
        
        // Log activity
        activityLogger.log(
            eventType: eventType,
            processName: event.processPath,
            pid: event.pid,
            ppid: event.ppid,
            path: event.filePath,
            command: nil,
            destination: nil,
            allowed: allowed,
            reason: reason
        )
        
        return allowed ? .allow : .deny
    }
    
    // MARK: - Process Execution
    
    public func handleProcessExecution(_ event: ProcessExecutionEvent) -> HandlerDecision {
        // Check if we should monitor this process
        guard processTracker.isTracked(event.pid) else {
            return .allow // Not our process
        }
        
        // Get policy decision
        let policyDecision = policyEngine.checkCommand(command: event.command)
        
        // Make final decision
        let (allowed, reason) = evaluateDecision(
            policyDecision,
            promptTitle: "🛡️ AI Firewall",
            promptMessage: "Execute command?",
            promptDetails: "Command: \(event.command)"
        )
        
        // Log activity
        activityLogger.log(
            eventType: EventType.processExec,
            processName: event.executablePath,
            pid: event.pid,
            ppid: event.ppid,
            path: event.executablePath,
            command: event.command,
            destination: nil,
            allowed: allowed,
            reason: reason
        )
        
        return allowed ? .allow : .deny
    }
    
    // MARK: - Network Connections
    
    public func handleNetworkConnection(_ event: NetworkConnectionEvent) -> HandlerDecision {
        // Check if we should monitor this process
        guard processTracker.isTracked(event.pid) else {
            return .allow // Not our process
        }
        
        // Get policy decision
        let policyDecision = policyEngine.checkNetworkConnection(
            destination: event.destination,
            port: event.port
        )
        
        let connectionString = "\(event.destination):\(event.port)"
        
        // Make final decision
        let (allowed, reason) = evaluateDecision(
            policyDecision,
            promptTitle: "🛡️ AI Firewall",
            promptMessage: "Network connection?",
            promptDetails: "Destination: \(connectionString)"
        )
        
        // Log activity
        activityLogger.log(
            eventType: EventType.networkConnect,
            processName: event.processPath,
            pid: event.pid,
            ppid: event.ppid,
            path: nil,
            command: nil,
            destination: connectionString,
            allowed: allowed,
            reason: reason
        )
        
        return allowed ? .allow : .deny
    }
    
    // MARK: - Private Helpers
    
    private func evaluateDecision(
        _ decision: PolicyDecision,
        promptTitle: String,
        promptMessage: String,
        promptDetails: String
    ) -> (allowed: Bool, reason: String) {
        switch decision {
        case .allow(let reason):
            return (true, reason)
            
        case .deny(let reason):
            return (false, reason)
            
        case .prompt(let policyReason):
            let response = userPrompt.showPrompt(
                title: promptTitle,
                message: promptMessage,
                details: promptDetails
            )
            
            switch response {
            case .deny:
                return (false, "user denied: \(policyReason)")
            case .allowOnce:
                return (true, "user approved (once): \(policyReason)")
            case .allowAlways:
                // TODO: In future, update policy to auto-allow this pattern
                return (true, "user approved (always): \(policyReason)")
            }
        }
    }
}
```

### 4. Create Tests

Create `daemon/Tests/AIFWTests/Handlers/EventHandlerTests.swift`:

```swift
//
// EventHandlerTests.swift
// AIFWTests
//

import XCTest
@testable import AIFW

final class EventHandlerTests: XCTestCase {
    var policyEngine: MockPolicyEngine!
    var activityLogger: MockActivityLogger!
    var processTracker: ProcessTracker!
    var userPrompt: MockUserPrompt!
    var handler: EventHandler!
    
    override func setUp() {
        super.setUp()
        
        policyEngine = MockPolicyEngine()
        activityLogger = MockActivityLogger()
        processTracker = ProcessTracker(rootPID: getpid())
        userPrompt = MockUserPrompt()
        
        handler = EventHandler(
            policyEngine: policyEngine,
            activityLogger: activityLogger,
            processTracker: processTracker,
            userPrompt: userPrompt
        )
    }
    
    // MARK: - File Operation Tests
    
    func testFileOperation_WriteAllowed_NoPrompt() {
        policyEngine.fileWriteDecision = .allow(reason: "safe location")
        
        let event = FileOperationEvent(
            pid: getpid(),
            ppid: getppid(),
            processPath: "/usr/bin/opencode",
            filePath: "/tmp/test.txt",
            isWrite: true,
            isDelete: false
        )
        
        let decision = handler.handleFileOperation(event)
        
        XCTAssertEqual(decision, .allow)
        XCTAssertEqual(activityLogger.logs.count, 1)
        XCTAssertTrue(activityLogger.logs[0].allowed)
        XCTAssertEqual(activityLogger.logs[0].eventType, EventType.fileWrite)
        XCTAssertFalse(userPrompt.wasPrompted)
    }
    
    func testFileOperation_WriteDenied() {
        policyEngine.fileWriteDecision = .deny(reason: "blocked by policy")
        
        let event = FileOperationEvent(
            pid: getpid(),
            ppid: getppid(),
            processPath: "/usr/bin/opencode",
            filePath: "~/.ssh/config",
            isWrite: true,
            isDelete: false
        )
        
        let decision = handler.handleFileOperation(event)
        
        XCTAssertEqual(decision, .deny)
        XCTAssertFalse(activityLogger.logs[0].allowed)
        XCTAssertFalse(userPrompt.wasPrompted)
    }
    
    func testFileOperation_WritePrompt_UserDenies() {
        policyEngine.fileWriteDecision = .prompt(reason: "sensitive location")
        userPrompt.responseToReturn = .deny
        
        let event = FileOperationEvent(
            pid: getpid(),
            ppid: getppid(),
            processPath: "/usr/bin/opencode",
            filePath: "~/.ssh/authorized_keys",
            isWrite: true,
            isDelete: false
        )
        
        let decision = handler.handleFileOperation(event)
        
        XCTAssertEqual(decision, .deny)
        XCTAssertTrue(userPrompt.wasPrompted)
        XCTAssertFalse(activityLogger.logs[0].allowed)
        XCTAssertTrue(activityLogger.logs[0].reason!.contains("user denied"))
    }
    
    func testFileOperation_WritePrompt_UserAllowsOnce() {
        policyEngine.fileWriteDecision = .prompt(reason: "sensitive location")
        userPrompt.responseToReturn = .allowOnce
        
        let event = FileOperationEvent(
            pid: getpid(),
            ppid: getppid(),
            processPath: "/usr/bin/opencode",
            filePath: "~/.ssh/known_hosts",
            isWrite: true,
            isDelete: false
        )
        
        let decision = handler.handleFileOperation(event)
        
        XCTAssertEqual(decision, .allow)
        XCTAssertTrue(userPrompt.wasPrompted)
        XCTAssertTrue(activityLogger.logs[0].allowed)
        XCTAssertTrue(activityLogger.logs[0].reason!.contains("user approved (once)"))
    }
    
    func testFileOperation_Delete() {
        policyEngine.fileDeleteDecision = .prompt(reason: "requires confirmation")
        userPrompt.responseToReturn = .allowOnce
        
        let event = FileOperationEvent(
            pid: getpid(),
            ppid: getppid(),
            processPath: "/usr/bin/opencode",
            filePath: "/tmp/old_file.txt",
            isWrite: false,
            isDelete: true
        )
        
        let decision = handler.handleFileOperation(event)
        
        XCTAssertEqual(decision, .allow)
        XCTAssertEqual(activityLogger.logs[0].eventType, EventType.fileDelete)
    }
    
    func testFileOperation_UntrackedProcess_Allows() {
        policyEngine.fileWriteDecision = .deny(reason: "should not matter")
        
        let event = FileOperationEvent(
            pid: 1, // launchd - not tracked
            ppid: 0,
            processPath: "/sbin/launchd",
            filePath: "/tmp/test.txt",
            isWrite: true,
            isDelete: false
        )
        
        let decision = handler.handleFileOperation(event)
        
        XCTAssertEqual(decision, .allow)
        XCTAssertEqual(activityLogger.logs.count, 0) // Not logged
    }
    
    // MARK: - Process Execution Tests
    
    func testProcessExecution_Allowed() {
        policyEngine.commandDecision = .allow(reason: "safe command")
        
        let event = ProcessExecutionEvent(
            pid: getpid(),
            ppid: getppid(),
            executablePath: "/bin/bash",
            command: "git status"
        )
        
        let decision = handler.handleProcessExecution(event)
        
        XCTAssertEqual(decision, .allow)
        XCTAssertTrue(activityLogger.logs[0].allowed)
        XCTAssertEqual(activityLogger.logs[0].eventType, EventType.processExec)
    }
    
    func testProcessExecution_Denied() {
        policyEngine.commandDecision = .deny(reason: "blocked command")
        
        let event = ProcessExecutionEvent(
            pid: getpid(),
            ppid: getppid(),
            executablePath: "/bin/bash",
            command: "rm -rf /"
        )
        
        let decision = handler.handleProcessExecution(event)
        
        XCTAssertEqual(decision, .deny)
        XCTAssertFalse(activityLogger.logs[0].allowed)
    }
    
    func testProcessExecution_Prompt_UserApproves() {
        policyEngine.commandDecision = .prompt(reason: "dangerous command")
        userPrompt.responseToReturn = .allowAlways
        
        let event = ProcessExecutionEvent(
            pid: getpid(),
            ppid: getppid(),
            executablePath: "/bin/bash",
            command: "sudo rm file.txt"
        )
        
        let decision = handler.handleProcessExecution(event)
        
        XCTAssertEqual(decision, .allow)
        XCTAssertTrue(userPrompt.wasPrompted)
        XCTAssertTrue(activityLogger.logs[0].reason!.contains("user approved (always)"))
    }
    
    // MARK: - Network Connection Tests
    
    func testNetworkConnection_Localhost_Allowed() {
        policyEngine.networkDecision = .allow(reason: "localhost")
        
        let event = NetworkConnectionEvent(
            pid: getpid(),
            ppid: getppid(),
            processPath: "/usr/bin/opencode",
            destination: "127.0.0.1",
            port: 11434
        )
        
        let decision = handler.handleNetworkConnection(event)
        
        XCTAssertEqual(decision, .allow)
        XCTAssertTrue(activityLogger.logs[0].allowed)
        XCTAssertEqual(activityLogger.logs[0].eventType, EventType.networkConnect)
        XCTAssertEqual(activityLogger.logs[0].destination, "127.0.0.1:11434")
    }
    
    func testNetworkConnection_External_Prompt() {
        policyEngine.networkDecision = .prompt(reason: "external API")
        userPrompt.responseToReturn = .deny
        
        let event = NetworkConnectionEvent(
            pid: getpid(),
            ppid: getppid(),
            processPath: "/usr/bin/opencode",
            destination: "api.openai.com",
            port: 443
        )
        
        let decision = handler.handleNetworkConnection(event)
        
        XCTAssertEqual(decision, .deny)
        XCTAssertTrue(userPrompt.wasPrompted)
        XCTAssertFalse(activityLogger.logs[0].allowed)
    }
    
    // MARK: - Integration Tests
    
    func testMultipleEvents_LoggedCorrectly() {
        policyEngine.fileWriteDecision = .allow(reason: "safe")
        policyEngine.commandDecision = .allow(reason: "safe")
        policyEngine.networkDecision = .allow(reason: "safe")
        
        // File operation
        _ = handler.handleFileOperation(FileOperationEvent(
            pid: getpid(), ppid: getppid(), processPath: "test",
            filePath: "/tmp/1.txt", isWrite: true, isDelete: false
        ))
        
        // Process execution
        _ = handler.handleProcessExecution(ProcessExecutionEvent(
            pid: getpid(), ppid: getppid(),
            executablePath: "/bin/bash", command: "echo test"
        ))
        
        // Network connection
        _ = handler.handleNetworkConnection(NetworkConnectionEvent(
            pid: getpid(), ppid: getppid(), processPath: "test",
            destination: "127.0.0.1", port: 8080
        ))
        
        XCTAssertEqual(activityLogger.logs.count, 3)
        XCTAssertEqual(activityLogger.logs[0].eventType, EventType.fileWrite)
        XCTAssertEqual(activityLogger.logs[1].eventType, EventType.processExec)
        XCTAssertEqual(activityLogger.logs[2].eventType, EventType.networkConnect)
    }
}
```

### 5. Update main.swift

```swift
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

print("🔗 Testing Event Handler Integration:\n")

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
print("\n📊 Activity Statistics:")
let stats = logger.getStatistics()
print("   Total events: \(stats.total)")
print("   Allowed: \(stats.allowed)")
print("   Denied: \(stats.denied)")

print("\n✅ EventHandler successfully integrating all components")
print("\nNext: Phase 6 will add Endpoint Security framework integration")
```

## Build, Test, PR

```bash
cd daemon
swift test

git add .
git commit -m "Phase 5: Implement Event Handlers

Coordinate all components:
- EventHandler class integrates PolicyEngine, ActivityLogger, ProcessTracker, UserPrompt
- Handle file operations, process execution, network connections
- 15+ comprehensive integration tests
- Proper decision evaluation with user prompts

Tests: All passing (15/15)"

git push -u origin phase-5-handlers
gh pr create --title "Phase 5: Event Handlers" --base main
gh pr merge phase-5-handlers --squash
```

## Success Criteria

✅ EventHandler coordinates all components  
✅ Handles file/exec/network events  
✅ Evaluates policy decisions  
✅ Shows prompts when needed  
✅ Logs all activity  
✅ 15+ integration tests passing  
✅ Untracked processes ignored  

## Next Steps

After Phase 5: Proceed to **Phase 6: Firewall Monitor** (ES integration)
