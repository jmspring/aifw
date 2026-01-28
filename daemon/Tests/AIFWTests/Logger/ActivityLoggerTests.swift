//
// ActivityLoggerTests.swift
// AIFWTests
//
// Tests for activity logger
//

import XCTest
@testable import AIFW

final class ActivityLoggerTests: XCTestCase {
    var logger: ActivityLogger!
    var testDBPath: String!

    override func setUp() {
        super.setUp()

        // Create temp database for testing
        let tempDir = FileManager.default.temporaryDirectory
        testDBPath = tempDir.appendingPathComponent("test-activity-\(UUID().uuidString).db").path
        logger = ActivityLogger(dbPath: testDBPath)
    }

    override func tearDown() {
        logger = nil
        try? FileManager.default.removeItem(atPath: testDBPath)
        super.tearDown()
    }

    // MARK: - Basic Logging Tests

    func testLog_SingleEntry_Success() {
        logger.log(
            eventType: EventType.fileWrite,
            processName: "opencode",
            pid: 1234,
            ppid: 1000,
            path: "/tmp/test.txt",
            command: nil,
            destination: nil,
            allowed: true,
            reason: "safe location"
        )

        let records = logger.getRecentActivity(limit: 10)
        XCTAssertEqual(records.count, 1)

        let record = records[0]
        XCTAssertEqual(record.eventType, EventType.fileWrite)
        XCTAssertEqual(record.processName, "opencode")
        XCTAssertEqual(record.pid, 1234)
        XCTAssertEqual(record.ppid, 1000)
        XCTAssertEqual(record.path, "/tmp/test.txt")
        XCTAssertNil(record.command)
        XCTAssertNil(record.destination)
        XCTAssertTrue(record.allowed)
        XCTAssertEqual(record.reason, "safe location")
        XCTAssertNotNil(record.id)
    }

    func testLog_FileWrite_AllFields() {
        logger.log(
            eventType: EventType.fileWrite,
            processName: "opencode",
            pid: 1234,
            ppid: 1000,
            path: "~/.ssh/config",
            command: nil,
            destination: nil,
            allowed: false,
            reason: "sensitive directory"
        )

        let records = logger.getRecentActivity(limit: 1)
        XCTAssertEqual(records.count, 1)
        XCTAssertFalse(records[0].allowed)
        XCTAssertEqual(records[0].path, "~/.ssh/config")
    }

    func testLog_CommandExecution_AllFields() {
        logger.log(
            eventType: EventType.processExec,
            processName: "/bin/bash",
            pid: 5678,
            ppid: 1234,
            path: "/bin/bash",
            command: "git status",
            destination: nil,
            allowed: true,
            reason: "auto-allow pattern"
        )

        let records = logger.getRecentActivity(limit: 1)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].command, "git status")
        XCTAssertEqual(records[0].eventType, EventType.processExec)
    }

    func testLog_NetworkConnection_AllFields() {
        logger.log(
            eventType: EventType.networkConnect,
            processName: "opencode",
            pid: 1234,
            ppid: 1000,
            path: nil,
            command: nil,
            destination: "127.0.0.1:11434",
            allowed: true,
            reason: "ollama local"
        )

        let records = logger.getRecentActivity(limit: 1)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].destination, "127.0.0.1:11434")
        XCTAssertEqual(records[0].eventType, EventType.networkConnect)
    }

    // MARK: - Multiple Entry Tests

    func testLog_MultipleEntries_OrderedByRecent() {
        // Log in specific order
        logger.log(
            eventType: "first",
            processName: "test",
            pid: 1,
            ppid: 0,
            path: nil,
            command: nil,
            destination: nil,
            allowed: true,
            reason: nil
        )

        Thread.sleep(forTimeInterval: 0.01) // Small delay to ensure different timestamps

        logger.log(
            eventType: "second",
            processName: "test",
            pid: 2,
            ppid: 0,
            path: nil,
            command: nil,
            destination: nil,
            allowed: true,
            reason: nil
        )

        Thread.sleep(forTimeInterval: 0.01)

        logger.log(
            eventType: "third",
            processName: "test",
            pid: 3,
            ppid: 0,
            path: nil,
            command: nil,
            destination: nil,
            allowed: true,
            reason: nil
        )

        let records = logger.getRecentActivity(limit: 10)
        XCTAssertEqual(records.count, 3)

        // Should be in reverse chronological order (most recent first)
        XCTAssertEqual(records[0].eventType, "third")
        XCTAssertEqual(records[1].eventType, "second")
        XCTAssertEqual(records[2].eventType, "first")
    }

    func testLog_ManyEntries_LimitWorks() {
        // Log 20 entries
        for i in 0..<20 {
            logger.log(
                eventType: "test",
                processName: "test",
                pid: Int32(i),
                ppid: 1000,
                path: nil,
                command: nil,
                destination: nil,
                allowed: true,
                reason: nil
            )
        }

        // Request only 5
        let records = logger.getRecentActivity(limit: 5)
        XCTAssertEqual(records.count, 5)

        // Should get the most recent 5 (PIDs 19, 18, 17, 16, 15)
        XCTAssertEqual(records[0].pid, 19)
        XCTAssertEqual(records[4].pid, 15)
    }

    // MARK: - Statistics Tests

    func testStatistics_Empty_ReturnsZeros() {
        let stats = logger.getStatistics()
        XCTAssertEqual(stats.total, 0)
        XCTAssertEqual(stats.allowed, 0)
        XCTAssertEqual(stats.denied, 0)
    }

    func testStatistics_MixedResults_CountsCorrectly() {
        // Log 10 entries: 8 allowed, 2 denied (deny when i % 5 == 0, i.e., 0 and 5)
        for i in 0..<10 {
            logger.log(
                eventType: "test",
                processName: "test",
                pid: Int32(i),
                ppid: 1000,
                path: nil,
                command: nil,
                destination: nil,
                allowed: i % 5 != 0, // Deny every 5th entry (0 and 5)
                reason: nil
            )
        }

        let stats = logger.getStatistics()
        XCTAssertEqual(stats.total, 10)
        XCTAssertEqual(stats.allowed, 8)
        XCTAssertEqual(stats.denied, 2)
    }

    func testStatistics_AllAllowed() {
        for i in 0..<5 {
            logger.log(
                eventType: "test",
                processName: "test",
                pid: Int32(i),
                ppid: 1000,
                path: nil,
                command: nil,
                destination: nil,
                allowed: true,
                reason: nil
            )
        }

        let stats = logger.getStatistics()
        XCTAssertEqual(stats.total, 5)
        XCTAssertEqual(stats.allowed, 5)
        XCTAssertEqual(stats.denied, 0)
    }

    func testStatistics_AllDenied() {
        for i in 0..<5 {
            logger.log(
                eventType: "test",
                processName: "test",
                pid: Int32(i),
                ppid: 1000,
                path: nil,
                command: nil,
                destination: nil,
                allowed: false,
                reason: nil
            )
        }

        let stats = logger.getStatistics()
        XCTAssertEqual(stats.total, 5)
        XCTAssertEqual(stats.allowed, 0)
        XCTAssertEqual(stats.denied, 5)
    }

    // MARK: - Clear Tests

    func testClearAll_RemovesAllEntries() {
        // Log some entries
        for i in 0..<5 {
            logger.log(
                eventType: "test",
                processName: "test",
                pid: Int32(i),
                ppid: 1000,
                path: nil,
                command: nil,
                destination: nil,
                allowed: true,
                reason: nil
            )
        }

        XCTAssertEqual(logger.getRecentActivity(limit: 10).count, 5)

        // Clear
        logger.clearAll()

        // Should be empty
        XCTAssertEqual(logger.getRecentActivity(limit: 10).count, 0)

        let stats = logger.getStatistics()
        XCTAssertEqual(stats.total, 0)
    }

    // MARK: - Null Field Tests

    func testLog_NullOptionalFields_Success() {
        logger.log(
            eventType: "test",
            processName: nil,
            pid: 1234,
            ppid: 1000,
            path: nil,
            command: nil,
            destination: nil,
            allowed: true,
            reason: nil
        )

        let records = logger.getRecentActivity(limit: 1)
        XCTAssertEqual(records.count, 1)
        XCTAssertNil(records[0].processName)
        XCTAssertNil(records[0].path)
        XCTAssertNil(records[0].command)
        XCTAssertNil(records[0].destination)
        XCTAssertNil(records[0].reason)
    }

    // MARK: - Database Persistence Tests

    func testDatabase_Persists_BetweenInstances() {
        // Log entry with first instance
        logger.log(
            eventType: "persistent",
            processName: "test",
            pid: 9999,
            ppid: 1000,
            path: "/tmp/persistent.txt",
            command: nil,
            destination: nil,
            allowed: true,
            reason: "test persistence"
        )

        // Close first instance
        logger = nil

        // Create new instance with same database
        let logger2 = ActivityLogger(dbPath: testDBPath)

        // Should still have the record
        let records = logger2.getRecentActivity(limit: 10)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].pid, 9999)
        XCTAssertEqual(records[0].path, "/tmp/persistent.txt")
    }
}
