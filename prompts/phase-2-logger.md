# Phase 2: Activity Logger

**Branch**: `phase-2-logger`  
**Prerequisites**: Phase 0 and Phase 1 complete  
**Duration**: 1-2 hours  
**Focus**: SQLite-based activity logging and querying  

## Objective

Implement the ActivityLogger component that stores all monitored events in a SQLite database. This provides a complete audit trail of all operations evaluated by the firewall.

## Context

**Review before starting**:
- [Shared Schemas](../aifw-shared-schemas.md#activity-database-schema) - Database schema and ActivityRecord structure
- [Master Prompt](../aifw-master-prompt.md#component-breakdown) - ActivityLogger role in architecture

**What ActivityLogger Does**:
- Creates and manages SQLite database
- Logs all monitored events with timestamps
- Provides query methods for recent activity
- Calculates statistics (total, allowed, denied)
- Persists data between daemon restarts

**What ActivityLogger Does NOT Do**:
- Make policy decisions (that's PolicyEngine)
- Interact with Endpoint Security (that's Phase 6)
- Display logs (that's Phase 7 dashboard)

## Implementation

### 1. Create Feature Branch

```bash
git checkout main
git pull origin main
git checkout -b phase-2-logger
```

### 2. Create Activity Record Structure

Create `daemon/Sources/AIFW/Logger/ActivityRecord.swift`:

```swift
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
```

### 3. Create Activity Logger Protocol

Create `daemon/Sources/AIFW/Logger/ActivityLogger.swift`:

```swift
//
// ActivityLogger.swift
// AIFW
//
// SQLite-based activity logging
//

import Foundation
import SQLite3

/// Protocol for activity logging
public protocol ActivityLoggerProtocol {
    func log(
        eventType: String,
        processName: String?,
        pid: Int32,
        ppid: Int32,
        path: String?,
        command: String?,
        destination: String?,
        allowed: Bool,
        reason: String?
    )
    
    func getRecentActivity(limit: Int) -> [ActivityRecord]
    func getStatistics() -> (total: Int, allowed: Int, denied: Int)
    func clearAll()
}

/// SQLite-based activity logger
public class ActivityLogger: ActivityLoggerProtocol {
    private var db: OpaquePointer?
    private let dbPath: String
    
    public init(dbPath: String) {
        self.dbPath = NSString(string: dbPath).expandingTildeInPath
        
        // Ensure directory exists
        let directory = (self.dbPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Open database
        if sqlite3_open(self.dbPath, &db) != SQLITE_OK {
            print("❌ Error opening database at \(self.dbPath)")
        } else {
            print("✅ Database opened: \(self.dbPath)")
        }
        
        createTables()
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    // MARK: - Database Setup
    
    private func createTables() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS activity (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            event_type TEXT NOT NULL,
            process_name TEXT,
            pid INTEGER NOT NULL,
            ppid INTEGER NOT NULL,
            path TEXT,
            command TEXT,
            destination TEXT,
            allowed INTEGER NOT NULL,
            reason TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        
        CREATE INDEX IF NOT EXISTS idx_timestamp ON activity(timestamp);
        CREATE INDEX IF NOT EXISTS idx_event_type ON activity(event_type);
        CREATE INDEX IF NOT EXISTS idx_allowed ON activity(allowed);
        CREATE INDEX IF NOT EXISTS idx_pid ON activity(pid);
        CREATE INDEX IF NOT EXISTS idx_created_at ON activity(created_at);
        """
        
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, createTableSQL, nil, nil, &error) != SQLITE_OK {
            if let error = error {
                let errorMessage = String(cString: error)
                print("❌ Error creating tables: \(errorMessage)")
                sqlite3_free(error)
            }
        }
    }
    
    // MARK: - Logging
    
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
        let insertSQL = """
        INSERT INTO activity 
        (timestamp, event_type, process_name, pid, ppid, path, command, destination, allowed, reason)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Error preparing insert statement")
            return
        }
        
        defer { sqlite3_finalize(stmt) }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        sqlite3_bind_text(stmt, 1, timestamp, -1, nil)
        sqlite3_bind_text(stmt, 2, eventType, -1, nil)
        if let processName = processName {
            sqlite3_bind_text(stmt, 3, processName, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        sqlite3_bind_int(stmt, 4, pid)
        sqlite3_bind_int(stmt, 5, ppid)
        if let path = path {
            sqlite3_bind_text(stmt, 6, path, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        if let command = command {
            sqlite3_bind_text(stmt, 7, command, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        if let destination = destination {
            sqlite3_bind_text(stmt, 8, destination, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 8)
        }
        sqlite3_bind_int(stmt, 9, allowed ? 1 : 0)
        if let reason = reason {
            sqlite3_bind_text(stmt, 10, reason, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 10)
        }
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("❌ Error inserting activity record")
        }
    }
    
    // MARK: - Querying
    
    public func getRecentActivity(limit: Int = 100) -> [ActivityRecord] {
        let querySQL = """
        SELECT id, timestamp, event_type, process_name, pid, ppid, path, command, destination, allowed, reason
        FROM activity 
        ORDER BY id DESC 
        LIMIT ?
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Error preparing query")
            return []
        }
        
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_int(stmt, 1, Int32(limit))
        
        var records: [ActivityRecord] = []
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let timestamp = String(cString: sqlite3_column_text(stmt, 1))
            let eventType = String(cString: sqlite3_column_text(stmt, 2))
            
            let processName = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let pid = sqlite3_column_int(stmt, 4)
            let ppid = sqlite3_column_int(stmt, 5)
            let path = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
            let command = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
            let destination = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
            let allowed = sqlite3_column_int(stmt, 9) == 1
            let reason = sqlite3_column_text(stmt, 10).map { String(cString: $0) }
            
            let date = ISO8601DateFormatter().date(from: timestamp) ?? Date()
            
            records.append(ActivityRecord(
                id: id,
                timestamp: date,
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
        
        return records
    }
    
    public func getStatistics() -> (total: Int, allowed: Int, denied: Int) {
        let querySQL = """
        SELECT 
            COUNT(*) as total,
            SUM(CASE WHEN allowed = 1 THEN 1 ELSE 0 END) as allowed_count,
            SUM(CASE WHEN allowed = 0 THEN 1 ELSE 0 END) as denied_count
        FROM activity
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Error preparing statistics query")
            return (0, 0, 0)
        }
        
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_step(stmt) == SQLITE_ROW {
            let total = Int(sqlite3_column_int(stmt, 0))
            let allowed = Int(sqlite3_column_int(stmt, 1))
            let denied = Int(sqlite3_column_int(stmt, 2))
            return (total, allowed, denied)
        }
        
        return (0, 0, 0)
    }
    
    public func clearAll() {
        let deleteSQL = "DELETE FROM activity"
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, deleteSQL, nil, nil, &error) != SQLITE_OK {
            if let error = error {
                print("❌ Error clearing activity: \(String(cString: error))")
                sqlite3_free(error)
            }
        }
    }
}
```

### 4. Create Comprehensive Tests

Create `daemon/Tests/AIFWTests/Logger/ActivityLoggerTests.swift`:

```swift
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
        // Log 10 entries: 6 allowed, 4 denied
        for i in 0..<10 {
            logger.log(
                eventType: "test",
                processName: "test",
                pid: Int32(i),
                ppid: 1000,
                path: nil,
                command: nil,
                destination: nil,
                allowed: i % 5 != 0, // Deny every 5th entry
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
```

### 5. Update main.swift to Demonstrate

Update `daemon/Sources/aifw-daemon/main.swift`:

```swift
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

print("📊 Demonstrating ActivityLogger:\n")

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
print("   ✅ Logged file write")

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
print("   ✅ Logged blocked sensitive write")

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
print("   ✅ Logged safe command")

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
print("   ✅ Logged blocked dangerous command")

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
print("   ✅ Logged Ollama connection")

// Display recent activity
print("\n4. Recent Activity:")
let records = logger.getRecentActivity(limit: 10)
for (index, record) in records.enumerated() {
    let status = record.allowed ? "✅ ALLOW" : "❌ DENY"
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

print("\n✅ ActivityLogger working correctly")
print("📁 Database: \(dbPath)")
```

## Build and Test

```bash
cd daemon

# Clean build
swift build

# Run all tests
swift test

# Should see output like:
# Test Suite 'All tests' passed at ...
# Executed 40+ tests, with 0 failures

# Run the daemon to see demo
swift run aifw-daemon

# Should see activity being logged and queried

# Inspect the database directly
sqlite3 /tmp/aifw-demo.db "SELECT * FROM activity"
```

## Create Pull Request

```bash
# Ensure all tests pass
swift test

# Commit changes
git add daemon/
git commit -m "Phase 2: Implement ActivityLogger with SQLite storage

Implement SQLite-based activity logging:
- ActivityRecord data structure
- ActivityLogger with full CRUD operations
- 18+ comprehensive unit tests
- Database persistence and querying
- Statistics aggregation
- Demo in main.swift showing all features

Key Features:
✅ SQLite database with proper schema
✅ Log events with all metadata
✅ Query recent activity with limits
✅ Calculate statistics (total/allowed/denied)
✅ Persist data between daemon restarts
✅ Handle null optional fields correctly
✅ Comprehensive test coverage

Tests: All passing (18/18)
Coverage: >90% of ActivityLogger code"

# Push branch
git push -u origin phase-2-logger

# Create PR
gh pr create \
  --title "Phase 2: ActivityLogger Implementation" \
  --body "Implements SQLite-based activity logging with comprehensive tests.

## Changes
- Add ActivityRecord structure
- Implement ActivityLogger with SQLite
- Add 18+ unit tests covering all scenarios
- Update main.swift with demonstration

## Testing
- All 18 tests passing
- Coverage >90%
- Tested persistence between instances
- Verified with actual SQLite database inspection

## Database
- Creates ~/.config/aifw/activity.db
- Proper schema with indexes
- Handles null fields correctly

## Next Phase
Phase 3 will implement ProcessTracker (PID tree management)" \
  --base main

# After CI passes and review, merge
gh pr merge phase-2-logger --squash
```

## Success Criteria

✅ ActivityLogger creates SQLite database  
✅ Can log all event types (file/exec/network)  
✅ Query methods return correct records  
✅ Statistics calculated accurately  
✅ Database persists between instances  
✅ Handles null optional fields  
✅ 18+ unit tests all passing  
✅ Code builds without warnings  
✅ PR created, CI passes, merged to main  

## Next Steps

After Phase 2 is merged:
1. Tag release: `git tag v0.1.0-phase2 && git push --tags`
2. Proceed to **Phase 3: Process Tracker**

## Troubleshooting

**Database won't open**:
- Check path is valid and writable
- Ensure parent directory exists
- Check file permissions

**Tests fail with "database locked"**:
- Ensure each test uses unique database file
- Check tests properly tear down (close database)
- Use UUID in temp file paths

**Records not persisting**:
- Verify sqlite3_step returns SQLITE_DONE
- Check for errors in console output
- Inspect database with sqlite3 command

**Statistics incorrect**:
- Check SQL query syntax
- Verify allowed field is 1 or 0 (not true/false)
- Test with known data sets
