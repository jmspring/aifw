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

    func testFileOperation_Read() {
        policyEngine.fileReadDecision = .allow(reason: "reads allowed")

        let event = FileOperationEvent(
            pid: getpid(),
            ppid: getppid(),
            processPath: "/usr/bin/opencode",
            filePath: "/etc/passwd",
            isWrite: false,
            isDelete: false
        )

        let decision = handler.handleFileOperation(event)

        XCTAssertEqual(decision, .allow)
        XCTAssertEqual(activityLogger.logs[0].eventType, EventType.fileRead)
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

    func testProcessExecution_UntrackedProcess() {
        policyEngine.commandDecision = .deny(reason: "should not matter")

        let event = ProcessExecutionEvent(
            pid: 1,
            ppid: 0,
            executablePath: "/sbin/launchd",
            command: "some command"
        )

        let decision = handler.handleProcessExecution(event)

        XCTAssertEqual(decision, .allow)
        XCTAssertEqual(activityLogger.logs.count, 0)
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

    func testNetworkConnection_UntrackedProcess() {
        policyEngine.networkDecision = .deny(reason: "should not matter")

        let event = NetworkConnectionEvent(
            pid: 1,
            ppid: 0,
            processPath: "/sbin/launchd",
            destination: "example.com",
            port: 443
        )

        let decision = handler.handleNetworkConnection(event)

        XCTAssertEqual(decision, .allow)
        XCTAssertEqual(activityLogger.logs.count, 0)
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

    func testMockLoggerStatistics() {
        policyEngine.fileWriteDecision = .allow(reason: "safe")
        policyEngine.commandDecision = .deny(reason: "blocked")

        _ = handler.handleFileOperation(FileOperationEvent(
            pid: getpid(), ppid: getppid(), processPath: "test",
            filePath: "/tmp/1.txt", isWrite: true, isDelete: false
        ))

        _ = handler.handleProcessExecution(ProcessExecutionEvent(
            pid: getpid(), ppid: getppid(),
            executablePath: "/bin/bash", command: "rm -rf /"
        ))

        let stats = activityLogger.getStatistics()
        XCTAssertEqual(stats.total, 2)
        XCTAssertEqual(stats.allowed, 1)
        XCTAssertEqual(stats.denied, 1)
    }
}
