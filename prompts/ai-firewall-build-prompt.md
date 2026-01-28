↓
Activity Logger
```

## Security Model

- Daemon requires `com.apple.developer.endpoint-security.client` entitlement
- Must be code-signed with valid Developer ID
- Runs as root via sudo
- Cannot be bypassed by monitored process
```

### 6. Create GitHub Actions CI Workflow
```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-daemon:
    runs-on: macos-13
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Check Swift version
      run: swift --version
    
    - name: Build daemon
      working-directory: daemon
      run: swift build -c release
    
    - name: Run daemon tests
      working-directory: daemon
      run: swift test
  
  lint:
    runs-on: macos-13
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Install SwiftLint
      run: brew install swiftlint
    
    - name: Lint daemon
      working-directory: daemon
      run: swiftlint lint --strict || true
```

### 7. Create LICENSE
```
MIT License

Copyright (c) 2025 Jim Spring

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Verification

```bash
# Verify directory structure
tree -L 2

# Verify git status
git status

# Commit initial setup
git add .
git commit -m "Initial project setup with directory structure and documentation"
git push -u origin main
```

## Success Criteria

✅ Repository exists at github.com/jmspring/aifw  
✅ Directory structure is created  
✅ README.md describes the project  
✅ Architecture documentation exists  
✅ .gitignore properly excludes build artifacts  
✅ LICENSE file is present  
✅ GitHub Actions CI workflow is configured  

---

# STAGE 1: Core Daemon - Policy Engine and Basic Structure

**Branch**: `stage-1-policy-engine`

**Goal**: Create the Swift daemon package with policy loading and basic structure. No Endpoint Security yet—just the policy engine that can be tested independently.

## Deliverables

1. Swift package for daemon
2. Policy data structures
3. PolicyEngine that loads and evaluates JSON policies
4. Unit tests for policy evaluation
5. Sample policy.json template

## Tasks

### 1. Create Swift Package
```bash
cd daemon
swift package init --type executable --name AIFWDaemon
```

Edit `Package.swift`:
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AIFWDaemon",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "aifw-daemon", targets: ["AIFWDaemon"])
    ],
    targets: [
        .executableTarget(
            name: "AIFWDaemon",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "AIFWDaemonTests",
            dependencies: ["AIFWDaemon"],
            path: "Tests"
        )
    ]
)
```

### 2. Create Policy Structures (Sources/Policy.swift)
```swift
import Foundation

struct FirewallPolicy: Codable {
    let sensitivePaths: [String]
    let blockedCommands: [String]
    let dangerousPatterns: [String]
    let requireApproval: RequireApproval
    let autoAllowPatterns: [String]
    let allowedModelAPIs: [String]
    let monitorOllamaRequests: Bool
    
    struct RequireApproval: Codable {
        let fileDelete: Bool
        let fileWriteSensitive: Bool
        let bashDangerous: Bool
        let networkExternal: Bool
    }
    
    static func load(from path: String) throws -> FirewallPolicy {
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FirewallPolicy.self, from: data)
    }
    
    static func defaultPolicy() -> FirewallPolicy {
        return FirewallPolicy(
            sensitivePaths: [
                "~/.ssh",
                "~/.aws",
                "~/.config",
                "/etc",
                "/System"
            ],
            blockedCommands: [
                "rm -rf /",
                "mkfs",
                "dd if=/dev/zero",
                ":(){:|:&};:"
            ],
            dangerousPatterns: [
                "sudo rm",
                "chmod 777",
                "curl | sh",
                "wget | bash"
            ],
            requireApproval: RequireApproval(
                fileDelete: true,
                fileWriteSensitive: true,
                bashDangerous: true,
                networkExternal: true
            ),
            autoAllowPatterns: [
                "git status",
                "git diff",
                "git log",
                "ls ",
                "cat ",
                "grep ",
                "pwd"
            ],
            allowedModelAPIs: [
                "localhost:11434"
            ],
            monitorOllamaRequests: true
        )
    }
}

enum PolicyDecision {
    case allow(reason: String)
    case deny(reason: String)
    case prompt(reason: String)
}
```

### 3. Create Policy Engine (Sources/PolicyEngine.swift)
```swift
import Foundation

class PolicyEngine {
    private let policy: FirewallPolicy
    
    init(policy: FirewallPolicy) {
        self.policy = policy
    }
    
    convenience init(policyPath: String) throws {
        let policy = try FirewallPolicy.load(from: policyPath)
        self.init(policy: policy)
    }
    
    // Check file write operations
    func checkFileWrite(path: String) -> PolicyDecision {
        let expandedPath = NSString(string: path).expandingTildeInPath
        
        // Check sensitive paths
        for sensitivePath in policy.sensitivePaths {
            let expandedSensitive = NSString(string: sensitivePath).expandingTildeInPath
            if expandedPath.hasPrefix(expandedSensitive) {
                if policy.requireApproval.fileWriteSensitive {
                    return .prompt(reason: "write to sensitive directory: \(sensitivePath)")
                }
            }
        }
        
        return .allow(reason: "write to non-sensitive location")
    }
    
    // Check file delete operations
    func checkFileDelete(path: String) -> PolicyDecision {
        if policy.requireApproval.fileDelete {
            return .prompt(reason: "file deletion")
        }
        return .allow(reason: "deletion allowed by policy")
    }
    
    // Check bash command execution
    func checkBashCommand(command: String) -> PolicyDecision {
        // Check auto-allow patterns first
        for pattern in policy.autoAllowPatterns {
            if command.hasPrefix(pattern) {
                return .allow(reason: "auto-allow pattern: \(pattern)")
            }
        }
        
        // Check blocked commands
        for blocked in policy.blockedCommands {
            if command.contains(blocked) {
                return .deny(reason: "blocked command: \(blocked)")
            }
        }
        
        // Check dangerous patterns
        for pattern in policy.dangerousPatterns {
            if command.contains(pattern) {
                if policy.requireApproval.bashDangerous {
                    return .prompt(reason: "dangerous pattern: \(pattern)")
                }
            }
        }
        
        return .allow(reason: "safe command")
    }
    
    // Check network connections
    func checkNetworkConnection(destination: String, port: UInt16) -> PolicyDecision {
        let connectionString = "\(destination):\(port)"
        
        // Check if localhost
        let localAddresses = ["127.0.0.1", "::1", "localhost"]
        if localAddresses.contains(destination) {
            return .allow(reason: "local connection")
        }
        
        // Check allowed APIs
        for allowedAPI in policy.allowedModelAPIs {
            if connectionString == allowedAPI || destination == allowedAPI {
                return .allow(reason: "allowed API: \(allowedAPI)")
            }
        }
        
        // External connection
        if policy.requireApproval.networkExternal {
            return .prompt(reason: "external network connection")
        }
        
        return .allow(reason: "external connections allowed by policy")
    }
}
```

### 4. Create Tests (Tests/PolicyEngineTests.swift)
```swift
import XCTest
@testable import AIFWDaemon

final class PolicyEngineTests: XCTestCase {
    var engine: PolicyEngine!
    
    override func setUp() {
        super.setUp()
        engine = PolicyEngine(policy: FirewallPolicy.defaultPolicy())
    }
    
    // MARK: - File Write Tests
    
    func testFileWriteToSensitiveDirectory() {
        let decision = engine.checkFileWrite(path: "~/.ssh/authorized_keys")
        
        if case .prompt(let reason) = decision {
            XCTAssertTrue(reason.contains("sensitive directory"))
        } else {
            XCTFail("Expected prompt for sensitive directory write")
        }
    }
    
    func testFileWriteToNormalDirectory() {
        let decision = engine.checkFileWrite(path: "/tmp/test.txt")
        
        if case .allow(let reason) = decision {
            XCTAssertTrue(reason.contains("non-sensitive"))
        } else {
            XCTFail("Expected allow for normal directory write")
        }
    }
    
    // MARK: - File Delete Tests
    
    func testFileDelete() {
        let decision = engine.checkFileDelete(path: "/tmp/test.txt")
        
        if case .prompt = decision {
            // Expected - policy requires approval for deletes
        } else {
            XCTFail("Expected prompt for file deletion")
        }
    }
    
    // MARK: - Bash Command Tests
    
    func testAutoAllowCommand() {
        let decision = engine.checkBashCommand(command: "git status")
        
        if case .allow(let reason) = decision {
            XCTAssertTrue(reason.contains("auto-allow"))
        } else {
            XCTFail("Expected allow for 'git status'")
        }
    }
    
    func testBlockedCommand() {
        let decision = engine.checkBashCommand(command: "rm -rf /")
        
        if case .deny(let reason) = decision {
            XCTAssertTrue(reason.contains("blocked"))
        } else {
            XCTFail("Expected deny for 'rm -rf /'")
        }
    }
    
    func testDangerousCommand() {
        let decision = engine.checkBashCommand(command: "sudo rm important_file")
        
        if case .prompt(let reason) = decision {
            XCTAssertTrue(reason.contains("dangerous"))
        } else {
            XCTFail("Expected prompt for dangerous command")
        }
    }
    
    func testSafeCommand() {
        let decision = engine.checkBashCommand(command: "echo 'hello world'")
        
        if case .allow(let reason) = decision {
            XCTAssertTrue(reason.contains("safe"))
        } else {
            XCTFail("Expected allow for safe command")
        }
    }
    
    // MARK: - Network Connection Tests
    
    func testLocalConnection() {
        let decision = engine.checkNetworkConnection(destination: "127.0.0.1", port: 11434)
        
        if case .allow(let reason) = decision {
            XCTAssertTrue(reason.contains("local"))
        } else {
            XCTFail("Expected allow for local connection")
        }
    }
    
    func testAllowedAPIConnection() {
        let decision = engine.checkNetworkConnection(destination: "localhost", port: 11434)
        
        if case .allow = decision {
            // Expected
        } else {
            XCTFail("Expected allow for Ollama connection")
        }
    }
    
    func testExternalConnection() {
        let decision = engine.checkNetworkConnection(destination: "api.openai.com", port: 443)
        
        if case .prompt(let reason) = decision {
            XCTAssertTrue(reason.contains("external"))
        } else {
            XCTFail("Expected prompt for external connection")
        }
    }
    
    // MARK: - Policy Loading Tests
    
    func testLoadDefaultPolicy() {
        let policy = FirewallPolicy.defaultPolicy()
        
        XCTAssertFalse(policy.sensitivePaths.isEmpty)
        XCTAssertFalse(policy.blockedCommands.isEmpty)
        XCTAssertTrue(policy.requireApproval.fileDelete)
    }
}
```

### 5. Create Policy Template (config/policy.json.template)
```json
{
  "sensitivePaths": [
    "~/.ssh",
    "~/.aws",
    "~/.config",
    "/etc",
    "/System"
  ],
  "blockedCommands": [
    "rm -rf /",
    "mkfs",
    "dd if=/dev/zero",
    ":(){:|:&};:"
  ],
  "dangerousPatterns": [
    "sudo rm",
    "chmod 777",
    "curl | sh",
    "wget | bash"
  ],
  "requireApproval": {
    "fileDelete": true,
    "fileWriteSensitive": true,
    "bashDangerous": true,
    "networkExternal": true
  },
  "autoAllowPatterns": [
    "git status",
    "git diff",
    "git log",
    "ls ",
    "cat ",
    "grep ",
    "pwd",
    "which "
  ],
  "allowedModelAPIs": [
    "localhost:11434"
  ],
  "monitorOllamaRequests": true
}
```

### 6. Create Placeholder main.swift
```swift
// Sources/main.swift
import Foundation

print("AIFW Daemon - Stage 1")
print("Policy Engine implemented and tested")

// Load default policy
let policy = FirewallPolicy.defaultPolicy()
let engine = PolicyEngine(policy: policy)

// Test a few operations
print("\nTesting policy engine:")
print("Write to ~/.ssh: \(engine.checkFileWrite(path: "~/.ssh/test"))")
print("Command 'git status': \(engine.checkBashCommand(command: "git status"))")
print("Command 'rm -rf /': \(engine.checkBashCommand(command: "rm -rf /"))")
print("Connect to localhost:11434: \(engine.checkNetworkConnection(destination: "127.0.0.1", port: 11434))")
```

## Build and Test

```bash
cd daemon

# Build
swift build

# Run tests
swift test

# Run the executable (should print test output)
swift run
```

## Create PR

```bash
# Commit changes
git add daemon/ config/
git commit -m "Stage 1: Implement policy engine with comprehensive tests

- Add Policy and PolicyEngine classes
- Implement decision logic for file/exec/network operations
- Add comprehensive unit tests
- Create policy.json template
- All tests passing"

# Push and create PR
git push -u origin stage-1-policy-engine

# Create PR via GitHub CLI or web interface
gh pr create --title "Stage 1: Policy Engine Implementation" \
  --body "Implements the core policy engine with comprehensive tests. All tests passing." \
  --base main
```

## Success Criteria

✅ Policy data structures defined  
✅ PolicyEngine implements all check methods  
✅ Unit tests cover all decision paths  
✅ Tests pass: `swift test`  
✅ Default policy loads correctly  
✅ Policy template created  
✅ PR created and merged to main  

---

# STAGE 2: Activity Logger with SQLite

**Branch**: `stage-2-activity-logger`

**Goal**: Implement SQLite-based activity logging system that can be tested independently.

## Deliverables

1. ActivityLogger class with SQLite integration
2. Database schema for activity table
3. Query methods for reading activity
4. Unit tests for logging operations
5. Test database utilities

## Tasks

### 1. Create ActivityLogger (Sources/ActivityLogger.swift)
```swift
import Foundation
import SQLite3

struct ActivityRecord {
    let id: Int?
    let timestamp: Date
    let eventType: String
    let processName: String?
    let pid: Int32
    let ppid: Int32
    let path: String?
    let command: String?
    let destination: String?
    let allowed: Bool
    let reason: String?
}

class ActivityLogger {
    private var db: OpaquePointer?
    private let dbPath: String
    
    init(dbPath: String) {
        self.dbPath = NSString(string: dbPath).expandingTildeInPath
        
        // Ensure directory exists
        let directory = (self.dbPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )
        
        // Open database
        if sqlite3_open(self.dbPath, &db) != SQLITE_OK {
            print("Error opening database at \(self.dbPath)")
        }
        
        createTables()
    }
    
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
            reason TEXT
        );
        
        CREATE INDEX IF NOT EXISTS idx_timestamp ON activity(timestamp);
        CREATE INDEX IF NOT EXISTS idx_event_type ON activity(event_type);
        CREATE INDEX IF NOT EXISTS idx_allowed ON activity(allowed);
        CREATE INDEX IF NOT EXISTS idx_pid ON activity(pid);
        """
        
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, createTableSQL, nil, nil, &error) != SQLITE_OK {
            let errorMessage = String(cString: error!)
            print("Error creating tables: \(errorMessage)")
            sqlite3_free(error)
        }
    }
    
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
    ) {
        let insertSQL = """
        INSERT INTO activity 
        (timestamp, event_type, process_name, pid, ppid, path, command, destination, allowed, reason)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else {
            print("Error preparing insert statement")
            return
        }
        
        defer { sqlite3_finalize(stmt) }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        sqlite3_bind_text(stmt, 1, timestamp, -1, nil)
        sqlite3_bind_text(stmt, 2, eventType, -1, nil)
        sqlite3_bind_text(stmt, 3, processName, -1, nil)
        sqlite3_bind_int(stmt, 4, pid)
        sqlite3_bind_int(stmt, 5, ppid)
        sqlite3_bind_text(stmt, 6, path, -1, nil)
        sqlite3_bind_text(stmt, 7, command, -1, nil)
        sqlite3_bind_text(stmt, 8, destination, -1, nil)
        sqlite3_bind_int(stmt, 9, allowed ? 1 : 0)
        sqlite3_bind_text(stmt, 10, reason, -1, nil)
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("Error inserting activity record")
        }
    }
    
    func getRecentActivity(limit: Int = 100) -> [ActivityRecord] {
        let querySQL = "SELECT * FROM activity ORDER BY id DESC LIMIT ?"
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK else {
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
    
    func getStatistics() -> (total: Int, allowed: Int, denied: Int) {
        let querySQL = """
        SELECT 
            COUNT(*) as total,
            SUM(CASE WHEN allowed = 1 THEN 1 ELSE 0 END) as allowed_count,
            SUM(CASE WHEN allowed = 0 THEN 1 ELSE 0 END) as denied_count
        FROM activity
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK else {
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
    
    func clearAll() {
        sqlite3_exec(db, "DELETE FROM activity", nil, nil, nil)
    }
    
    deinit {
        sqlite3_close(db)
    }
}
```

### 2. Create Tests (Tests/ActivityLoggerTests.swift)
```swift
import XCTest
@testable import AIFWDaemon

final class ActivityLoggerTests: XCTestCase {
    var logger: ActivityLogger!
    var testDBPath: String!
    
    override func setUp() {
        super.setUp()
        
        // Create temp database for testing
        let tempDir = NSTemporaryDirectory()
        testDBPath = "\(tempDir)test-activity-\(UUID().uuidString).db"
        logger = ActivityLogger(dbPath: testDBPath)
    }
    
    override func tearDown() {
        logger = nil
        try? FileManager.default.removeItem(atPath: testDBPath)
        super.tearDown()
    }
    
    func testLogActivity() {
        logger.log(
            eventType: "file_write",
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
        XCTAssertEqual(records[0].eventType, "file_write")
        XCTAssertEqual(records[0].pid, 1234)
        XCTAssertEqual(records[0].path, "/tmp/test.txt")
        XCTAssertTrue(records[0].allowed)
    }
    
    func testLogMultipleActivities() {
        // Log file write
        logger.log(
            eventType: "file_write",
            processName: "opencode",
            pid: 1234,
            ppid: 1000,
            path: "~/.ssh/config",
            command: nil,
            destination: nil,
            allowed: false,
            reason: "sensitive directory"
        )
        
        // Log command execution
        logger.log(
            eventType: "exec",
            processName: "bash",
            pid: 1235,
            ppid: 1234,
            path: "/bin/bash",
            command: "git status",
            destination: nil,
            allowed: true,
            reason: "auto-allow pattern"
        )
        
        // Log network connection
        logger.log(
            eventType: "network_connect",
            processName: "opencode",
            pid: 1234,
            ppid: 1000,
            path: nil,
            command: nil,
            destination: "127.0.0.1:11434",
            allowed: true,
            reason: "ollama local"
        )
        
        let records = logger.getRecentActivity(limit: 10)
        XCTAssertEqual(records.count, 3)
        
        // Verify records are in reverse chronological order
        XCTAssertEqual(records[0].eventType, "network_connect")
        XCTAssertEqual(records[1].eventType, "exec")
        XCTAssertEqual(records[2].eventType, "file_write")
    }
    
    func testStatistics() {
        // Log mixed allowed/denied activities
        for i in 0..<10 {
            logger.log(
                eventType: "test",
                processName: "test",
                pid: Int32(i),
                ppid: 1000,
                path: nil,
                command: nil,
                destination: nil,
                allowed: i % 2 == 0,
                reason: nil
            )
        }
        
        let stats = logger.getStatistics()
        XCTAssertEqual(stats.total, 10)
        XCTAssertEqual(stats.allowed, 5)
        XCTAssertEqual(stats.denied, 5)
    }
    
    func testClearAll() {
        logger.log(
            eventType: "test",
            processName: "test",
            pid: 1234,
            ppid: 1000,
            path: nil,
            command: nil,
            destination: nil,
            allowed: true,
            reason: nil
        )
        
        XCTAssertEqual(logger.getRecentActivity(limit: 10).count, 1)
        
        logger.clearAll()
        
        XCTAssertEqual(logger.getRecentActivity(limit: 10).count, 0)
    }
    
    func testLimitParameter() {
        // Log 20 activities
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
    }
}
```

### 3. Update main.swift to test logger
```swift
// Sources/main.swift
import Foundation

print("AIFW Daemon - Stage 2")
print("Activity Logger implemented and tested")

// Create logger in temp directory
let tempDir = NSTemporaryDirectory()
let dbPath = "\(tempDir)aifw-test.db"
let logger = ActivityLogger(dbPath: dbPath)

// Test logging
logger.log(
    eventType: "file_write",
    processName: "opencode",
    pid: 12345,
    ppid: 1000,
    path: "/tmp/test.txt",
    command: nil,
    destination: nil,
    allowed: true,
    reason: "test write"
)

logger.log(
    eventType: "exec",
    processName: "bash",
    pid: 12346,
    ppid: 12345,
    path: "/bin/bash",
    command: "git status",
    destination: nil,
    allowed: true,
    reason: "safe command"
)

// Display recent activity
let records = logger.getRecentActivity(limit: 10)
print("\nRecent activity (\(records.count) records):")
for record in records {
    print("- [\(record.eventType)] \(record.allowed ? "ALLOW" : "DENY"): \(record.reason ?? "no reason")")
}

// Display statistics
let stats = logger.getStatistics()
print("\nStatistics:")
print("Total: \(stats.total)")
print("Allowed: \(stats.allowed)")
print("Denied: \(stats.denied)")

print("\nDatabase created at: \(dbPath)")
```

## Build and Test

```bash
cd daemon

# Build
swift build

# Run tests
swift test

# Run executable to see it work
swift run

# Inspect the test database
sqlite3 /tmp/aifw-test.db "SELECT * FROM activity"
```

## Create PR

```bash
git add daemon/
git commit -m "Stage 2: Implement SQLite activity logger with comprehensive tests

- Add ActivityLogger class with SQLite integration
- Implement activity logging and querying
- Add statistics aggregation
- Add comprehensive unit tests
- All tests passing"

git push -u origin stage-2-activity-logger

gh pr create --title "Stage 2: Activity Logger Implementation" \
  --body "Implements SQLite-based activity logging with comprehensive tests. All tests passing." \
  --base main
```

## Success Criteria

✅ ActivityLogger class implemented  
✅ SQLite database schema created  
✅ Log/query/statistics methods working  
✅ Unit tests cover all functionality  
✅ Tests pass: `swift test`  
✅ Manual testing shows working database  
✅ PR created and merged to main  

---

# STAGE 3: Process Tree Tracking and User Prompts

**Branch**: `stage-3-process-tracking`

**Goal**: Implement process tree tracking (without ES) and macOS user prompt system that can be tested independently.

## Deliverables

1. ProcessTracker class for managing PID trees
2. UserPrompt class for macOS dialogs
3. Unit tests (mocked dialogs)
4. Integration tests with real processes
5. Command-line test utility

## Tasks

### 1. Create ProcessTracker (Sources/ProcessTracker.swift)
```swift
import Foundation
import Darwin

class ProcessTracker {
    private(set) var trackedPIDs: Set<pid_t> = []
    private let rootPID: pid_t
    
    init(rootPID: pid_t) {
        self.rootPID = rootPID
        buildProcessTree(from: rootPID)
    }
    
    private func buildProcessTree(from pid: pid_t) {
        trackedPIDs.insert(pid)
        
        // Get child processes using proc_listchildpids
        var buffer = [pid_t](repeating: 0, count: 1024)
        let bufferSize = Int32(buffer.count * MemoryLayout<pid_t>.size)
        let count = proc_listchildpids(pid, &buffer, bufferSize)
        
        guard count > 0 else { return }
        
        let numPids = Int(count) / MemoryLayout<pid_t>.size
        for i in 0..<numPids where buffer[i] > 0 {
            buildProcessTree(from: buffer[i])
        }
    }
    
    func isTracked(_ pid: pid_t) -> Bool {
        if trackedPIDs.contains(pid) {
            return true
        }
        
        // Walk up parent chain
        return isDescendantOfRoot(pid)
    }
    
    private func isDescendantOfRoot(_ pid: pid_t) -> Bool {
        var currentPID = pid
        
        while currentPID > 1 {
            if currentPID == rootPID || trackedPIDs.contains(currentPID) {
                trackedPIDs.insert(pid) // Cache for future lookups
                return true
            }
            
            // Get parent PID
            var info = proc_bsdinfo()
            let size = MemoryLayout<proc_bsdinfo>.size
            let result = proc_pidinfo(
                currentPID,
                PROC_PIDTBSDINFO,
                0,
                &info,
                Int32(size)
            )
            
            guard result == Int32(size) else { return false }
            currentPID = pid_t(info.pbi_ppid)
        }
        
        return false
    }
    
    func getProcessPath(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        let result = proc_pidpath(pid, &buffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))
        
        guard result > 0 else { return nil }
        return String(cString: buffer)
    }
    
    func refresh() {
        trackedPIDs.removeAll()
        buildProcessTree(from: rootPID)
    }
}
```

### 2. Create UserPrompt (Sources/UserPrompt.swift)
```swift
import Foundation

enum PromptResponse {
    case deny
    case allowOnce
    case allowAlways
}

protocol UserPromptProtocol {
    func showPrompt(title: String, message: String, details: String) -> PromptResponse
}

class UserPrompt: UserPromptProtocol {
    func showPrompt(title: String, message: String, details: String) -> PromptResponse {
        let script = """
        display dialog "\(message)\\n\\n\(details)\\n\\nAllow this action?" ¬
        buttons {"Deny", "Allow Once", "Allow Always"} ¬
        default button "Deny" ¬
        with title "\(title)" ¬
        with icon caution
        """
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                if output.contains("Allow Always") {
                    return .allowAlways
                } else if output.contains("Allow Once") {
                    return .allowOnce
                } else {
                    return .deny
                }
            }
        } catch {
            print("Error showing prompt: \(error)")
        }
        
        return .deny // Default to deny on error
    }
}

// Mock for testing
class MockUserPrompt: UserPromptProtocol {
    var responseToReturn: PromptResponse = .deny
    var lastTitle: String?
    var lastMessage: String?
    var lastDetails: String?
    var promptCount = 0
    
    func showPrompt(title: String, message: String, details: String) -> PromptResponse {
        lastTitle = title
        lastMessage = message
        lastDetails = details
        promptCount += 1
        return responseToReturn
    }
}
```

### 3. Create Tests (Tests/ProcessTrackerTests.swift)
```swift
import XCTest
@testable import AIFWDaemon

final class ProcessTrackerTests: XCTestCase {
    func testTrackCurrentProcess() {
        let currentPID = getpid()
        let tracker = ProcessTracker(rootPID: currentPID)
        
        XCTAssertTrue(tracker.isTracked(currentPID))
        XCTAssertTrue(tracker.trackedPIDs.contains(currentPID))
    }
    
    func testTrackParentProcess() {
        let parentPID = getppid()
        let tracker = ProcessTracker(rootPID: parentPID)
        
        XCTAssertTrue(tracker.isTracked(parentPID))
        XCTAssertTrue(tracker.isTracked(getpid()))
    }
    
    func testGetProcessPath() {
        let currentPID = getpid()
        let tracker = ProcessTracker(rootPID: currentPID)
        
        if let path = tracker.getProcessPath(currentPID) {
            XCTAssertTrue(path.contains("xctest") || path.contains("swift"))
        } else {
            XCTFail("Should be able to get path for current process")
        }
    }
    
    func testNonTrackedProcess() {
        let currentPID = getpid()
        let tracker = ProcessTracker(rootPID: currentPID)
        
        // PID 1 (launchd) should not be tracked
        XCTAssertFalse(tracker.isTracked(1))
    }
}
```

### 4. Create Tests (Tests/UserPromptTests.swift)
```swift
import XCTest
@testable import AIFWDaemon

final class UserPromptTests: XCTestCase {
    func testMockPromptDeny() {
        let mock = MockUserPrompt()
        mock.responseToReturn = .deny
        
        let response = mock.showPrompt(
            title: "Test",
            message: "Test message",
            details: "Test details"
        )
        
        XCTAssertEqual(response, .deny)
        XCTAssertEqual(mock.lastTitle, "Test")
        XCTAssertEqual(mock.lastMessage, "Test message")
        XCTAssertEqual(mock.promptCount, 1)
    }
    
    func testMockPromptAllowOnce() {
        let mock = MockUserPrompt()
        mock.responseToReturn = .allowOnce
        
        let response = mock.showPrompt(
            title: "Test",
            message: "Test message",
            details: "Test details"
        )
        
        XCTAssertEqual(response, .allowOnce)
    }
    
    func testMockPromptAllowAlways() {
        let mock = MockUserPrompt()
        mock.responseToReturn = .allowAlways
        
        let response = mock.showPrompt(
            title: "Test",
            message: "Test message",
            details: "Test details"
        )
        
        XCTAssertEqual(response, .allowAlways)
    }
}
```

### 5. Create Test Utility (Sources/test-prompt.swift)
```swift
// Create a separate executable for testing prompts
// Add to Package.swift:
/*
.executableTarget(
    name: "test-prompt",
    dependencies: ["AIFWDaemon"],
    path: "Sources/TestPrompt"
)
*/

import Foundation

print("Testing User Prompt System")
print("=========================")

let prompt = UserPrompt()

print("\nShowing test prompt...")
let response = prompt.showPrompt(
    title: "🛡️ AIFW Test",
    message: "Testing the prompt system",
    details: "This is a test of the user prompt system.\n\nClick any button to test."
)

print("\nResponse: \(response)")

switch response {
case .deny:
    print("User clicked: Deny")
case .allowOnce:
    print("User clicked: Allow Once")
case .allowAlways:
    print("User clicked: Allow Always")
}
```

### 6. Update main.swift
```swift
// Sources/main.swift
import Foundation

print("AIFW Daemon - Stage 3")
print("Process Tracking and User Prompts")

// Test process tracking
print("\nProcess Tracking:")
let currentPID = getpid()
let tracker = ProcessTracker(rootPID: currentPID)

print("Current PID: \(currentPID)")
print("Tracked PIDs: \(tracker.trackedPIDs.count)")
print("Is current PID tracked? \(tracker.isTracked(currentPID))")

if let path = tracker.getProcessPath(currentPID) {
    print("Current process path: \(path)")
}

// Test user prompt (mock)
print("\nUser Prompt (Mock):")
let mockPrompt = MockUserPrompt()
mockPrompt.responseToReturn = .allowOnce

let response = mockPrompt.showPrompt(
    title: "Test",
    message: "Would you like to allow this?",
    details: "Path: /tmp/test.txt"
)

print("Mock response: \(response)")
print("Prompt was called \(mockPrompt.promptCount) time(s)")

print("\n✅ Stage 3 components working")
print("Run 'swift run test-prompt' to test real macOS dialogs")
```

## Build and Test

```bash
cd daemon

# Build
swift build

# Run tests
swift test

# Run main executable
swift run

# Test real prompts (optional - requires user interaction)
# swift run test-prompt
```

## Create PR

```bash
git add daemon/
git commit -m "Stage 3: Implement process tracking and user prompts

- Add ProcessTracker for managing PID trees
- Implement user prompt system with macOS dialogs
- Add mock prompt for testing
- Create test utility for manual prompt testing
- Add comprehensive unit tests
- All tests passing"

git push -u origin stage-3-process-tracking

gh pr create --title "Stage 3: Process Tracking and User Prompts" \
  --body "Implements process tree tracking and macOS dialog system with comprehensive tests. All tests passing." \
  --base main
```

## Success Criteria

✅ ProcessTracker tracks PID trees correctly  
✅ User prompt shows macOS dialogs  
✅ Mock prompts work for testing  
✅ Unit tests pass  
✅ Test utility demonstrates real prompts  
✅ PR created and merged to main  

---

# STAGE 4: Endpoint Security Integration

**Branch**: `stage-4-endpoint-security`

**Goal**: Integrate macOS Endpoint Security framework to intercept file operations, exec, and network events. This requires code signing and entitlements.

## Deliverables

1. FirewallMonitor class using Endpoint Security
2. Integration of all previous components
3. Entitlements file
4. Code signing instructions
5. Integration tests (requires sudo)
6. Working daemon that monitors a target PID

## Tasks

### 1. Add Endpoint Security to Package.swift
```
ai-firewall/
├── daemon/                          # Swift daemon using Endpoint Security
│   ├── Package.swift
│   ├── Sources/
│   │   ├── main.swift              # Entry point
│   │   ├── FirewallMonitor.swift   # ES monitoring logic
│   │   ├── PolicyEngine.swift      # Policy evaluation
│   │   ├── ActivityLogger.swift    # SQLite logging
│   │   ├── NetworkMonitor.swift    # Network connection tracking
│   │   └── UserPrompt.swift        # macOS dialog prompts
│   └── AIFirewallDaemon.entitlements
├── dashboard/                       # SwiftUI dashboard app
│   ├── Package.swift
│   ├── Sources/
│   │   ├── ContentView.swift       # Main UI
│   │   ├── ActivityView.swift      # Activity log viewer
│   │   ├── PolicyEditor.swift      # Policy configuration UI
│   │   └── StatsView.swift         # Statistics dashboard
│   └── Info.plist
├── launcher/
│   └── ai-firewall-launcher.sh     # Startup script
├── config/
│   └── policy.json                 # Default policy configuration
├── launchd/
│   └── com.ai-firewall.daemon.plist
├── install.sh                       # Installation script
└── README.md
```

## Core Components

### 1. Swift Daemon (daemon/Sources/main.swift)
Create a daemon that:
- Uses Endpoint Security framework to intercept system calls
- Monitors a specific OpenCode process tree (passed as PID argument)
- Intercepts these event types:
  - `ES_EVENT_TYPE_AUTH_OPEN` - File opens (check for write flag)
  - `ES_EVENT_TYPE_AUTH_UNLINK` - File deletions
  - `ES_EVENT_TYPE_AUTH_EXEC` - Process execution (bash commands)
  - `ES_EVENT_TYPE_AUTH_CONNECT` - Network connections
- Responds with `ES_AUTH_RESULT_ALLOW` or `ES_AUTH_RESULT_DENY`
- Logs all activity to SQLite database

### 2. Policy Engine (daemon/Sources/PolicyEngine.swift)
Implement policy checking for:
- **Sensitive directories**: `~/.ssh`, `~/.aws`, `~/.config`, `/etc`, `/System`
- **Blocked commands**: `rm -rf /`, `mkfs`, `dd if=/dev/zero`, fork bomb patterns
- **Dangerous patterns**: `sudo rm`, `chmod 777`, `curl | sh`, `wget | bash`
- **Network destinations**: Allow localhost:11434 (Ollama), prompt for external APIs
- **Auto-allow patterns**: `git status`, `ls`, `cat`, `grep`, etc.

Policy JSON structure:
```json
{
  "sensitivePaths": ["~/.ssh", "~/.aws", "~/.config", "/etc", "/System"],
  "blockedCommands": ["rm -rf /", "mkfs", "dd if=/dev/zero", ":(){:|:&};:"],
  "dangerousPatterns": ["sudo rm", "chmod 777", "curl | sh", "wget | bash"],
  "requireApproval": {
    "fileDelete": true,
    "fileWriteSensitive": true,
    "bashDangerous": true,
    "networkExternal": true
  },
  "autoAllowPatterns": ["git status", "git diff", "ls ", "cat ", "grep ", "pwd"],
  "allowedModelAPIs": ["localhost:11434"],
  "monitorOllamaRequests": true
}
```

### 3. Activity Logger (daemon/Sources/ActivityLogger.swift)
SQLite database schema:
```sql
CREATE TABLE activity (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    event_type TEXT NOT NULL,
    process_name TEXT,
    pid INTEGER,
    ppid INTEGER,
    path TEXT,
    command TEXT,
    destination TEXT,  -- for network events
    allowed INTEGER NOT NULL,
    reason TEXT
);

CREATE INDEX idx_timestamp ON activity(timestamp);
CREATE INDEX idx_event_type ON activity(event_type);
CREATE INDEX idx_allowed ON activity(allowed);
```

### 4. User Prompt System (daemon/Sources/UserPrompt.swift)
Use AppleScript to show native macOS dialogs:
```applescript
display dialog "🛡️ AI Firewall Alert\n\nOpenCode wants to: [OPERATION]\n\n[DETAILS]\n\nAllow this action?" ¬
buttons {"Deny", "Allow Once", "Allow Always"} ¬
default button "Deny" ¬
with title "AI Firewall" ¬
with icon caution
```

Handle three responses:
- **Deny**: Return false, block operation
- **Allow Once**: Return true, allow this time only
- **Allow Always**: Return true, add to auto-allow rules

### 5. Process Tree Tracking
The daemon must:
- Accept OpenCode's root PID as argument
- Walk the process tree to find all child processes
- Use `proc_listchildpids()` to enumerate children
- Cache PIDs in a Set for fast lookup
- Update when new processes spawn

### 6. Network Monitoring (daemon/Sources/NetworkMonitor.swift)
For `ES_EVENT_TYPE_AUTH_CONNECT` events:
- Extract IPv4/IPv6 address and port from `sockaddr`
- Detect Ollama connections: `127.0.0.1:11434`
- Detect external model APIs: `api.anthropic.com`, `api.openai.com`, etc.
- Optionally implement HTTP proxy on port 11435 to inspect Ollama requests/responses
- Log all network connections with destination info

### 7. SwiftUI Dashboard (dashboard/Sources/ContentView.swift)
Create a dashboard app that:
- Reads from the SQLite activity database
- Shows real-time activity feed (auto-refresh every 2 seconds)
- Displays statistics:
  - Total events
  - Allowed vs blocked
  - Events by type (file, exec, network)
  - Top accessed paths
  - Top executed commands
- Allows filtering: All / Blocked / Approved
- Shows event details on selection
- Provides policy editor interface

### 8. Installation System
Create `install.sh` that:
- Builds the Swift daemon with release configuration
- Signs the daemon with entitlements (requires Developer ID)
- Copies binaries to `/usr/local/bin/`
- Creates config directory `~/.config/ai-firewall/`
- Installs default policy.json
- Sets up LaunchAgent plist
- Provides instructions for granting Full Disk Access

Entitlements file (daemon/AIFirewallDaemon.entitlements):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.endpoint-security.client</key>
    <true/>
</dict>
</plist>
```

### 9. Launcher Script (launcher/ai-firewall-launcher.sh)
Bash script that:
- Polls for OpenCode process: `pgrep -f opencode`
- When found, launches daemon: `sudo ai-firewall-daemon $PID`
- Monitors OpenCode process lifecycle
- Stops daemon when OpenCode exits
- Restarts monitoring loop

## Technical Requirements

### Swift Package Manager Configuration
daemon/Package.swift:
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AIFirewallDaemon",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ai-firewall-daemon", targets: ["AIFirewallDaemon"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AIFirewallDaemon",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("EndpointSecurity"),
                .linkedFramework("Foundation")
            ]
        )
    ]
)
```

dashboard/Package.swift:
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AIFirewallDashboard",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ai-firewall-dashboard", targets: ["AIFirewallDashboard"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AIFirewallDashboard",
            dependencies: []
        )
    ]
)
```

### Key Swift APIs to Use

**Endpoint Security:**
```swift
import EndpointSecurity

// Create client
es_new_client(&client) { client, message in
    // Handle events
}

// Subscribe to events
es_subscribe(client, events, UInt32(events.count))

// Respond to authorization events
es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false)
```

**Process Information:**
```swift
// Get PID from audit token
let pid = audit_token_to_pid(process.audit_token)

// Get process path
var buffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
proc_pidpath(pid, &buffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))

// List child processes
var children = [pid_t](repeating: 0, count: 1024)
proc_listchildpids(pid, &children, Int32(children.count * MemoryLayout<pid_t>.size))

// Get process info
var info = proc_bsdinfo()
proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size))
let ppid = pid_t(info.pbi_ppid)
```

**Network Address Parsing:**
```swift
import Darwin

// Parse sockaddr to IP:port
let address = event.connect.address.pointee
switch Int32(address.sa_family) {
case AF_INET:
    let addr = withUnsafePointer(to: address) { ptr in
        ptr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
    }
    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
    inet_ntop(AF_INET, &addr.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
    let ip = String(cString: buffer)
    let port = addr.sin_port.bigEndian
    
case AF_INET6:
    // Similar for IPv6
}
```

**SQLite:**
```swift
import SQLite3

var db: OpaquePointer?
sqlite3_open(dbPath, &db)

var stmt: OpaquePointer?
sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
sqlite3_bind_text(stmt, 1, value, -1, nil)
sqlite3_step(stmt)
sqlite3_finalize(stmt)
```

## Implementation Plan

### Phase 1: Core Daemon (Highest Priority)
1. Create Swift package structure
2. Implement PolicyEngine with JSON loading
3. Implement ActivityLogger with SQLite
4. Implement FirewallMonitor with ES framework
5. Handle AUTH_OPEN, AUTH_UNLINK, AUTH_EXEC events
6. Add process tree tracking
7. Implement UserPrompt with AppleScript

### Phase 2: Network Monitoring
1. Add ES_EVENT_TYPE_AUTH_CONNECT handling
2. Implement NetworkMonitor for connection tracking
3. Add Ollama detection (127.0.0.1:11434)
4. Add external API detection and blocking
5. Optional: HTTP proxy for deep packet inspection

### Phase 3: Dashboard
1. Create SwiftUI app structure
2. Implement ActivityView with SQLite reading
3. Add real-time refresh (Timer every 2s)
4. Create StatsView with aggregations
5. Implement PolicyEditor for JSON config
6. Add filtering and search

### Phase 4: Installation & Distribution
1. Create install.sh script
2. Build signing and entitlements
3. Create LaunchAgent plist
4. Write comprehensive README
5. Add usage examples

## Expected Behavior

### When OpenCode starts:
1. User runs `opencode` in terminal
2. Launcher detects OpenCode PID
3. Daemon starts with `sudo ai-firewall-daemon $PID`
4. Dashboard can be launched to view activity

### When OpenCode tries to write to ~/.ssh:
1. ES intercepts `open()` syscall with WRITE flag
2. Daemon checks policy: sensitive directory
3. Shows AppleScript dialog to user
4. User chooses: Deny / Allow Once / Allow Always
5. Logs decision to SQLite
6. Returns ALLOW or DENY to kernel

### When OpenCode runs `rm -rf somedir`:
1. ES intercepts `exec()` syscall
2. Daemon extracts command and arguments
3. Checks against dangerous patterns
4. If matches, shows prompt to user
5. Logs command and decision
6. Returns ALLOW or DENY

### When OpenCode connects to Ollama:
1. ES intercepts `connect()` to 127.0.0.1:11434
2. Daemon recognizes Ollama connection
3. Logs as "ollama_connect"
4. Auto-allows (local connection)

### When OpenCode tries to connect to api.anthropic.com:
1. ES intercepts `connect()` to external IP
2. Daemon detects external API
3. Shows prompt: "OpenCode wants to use Anthropic Claude API"
4. User decides whether to allow
5. Logs decision with destination info

## Testing Strategy

### Manual Tests:
1. **File operations**: Ask OpenCode to create file in ~/.ssh
2. **Delete operations**: Ask OpenCode to delete a file
3. **Dangerous commands**: Ask OpenCode to run `sudo rm`
4. **Network**: Configure OpenCode to use different model APIs
5. **Process spawning**: Ask OpenCode to spawn subprocesses

### Verification:
- Check SQLite database for logged events
- Verify AppleScript dialogs appear
- Confirm blocked operations don't execute
- Monitor dashboard for real-time updates

## Security Considerations

1. **Daemon runs as root**: Required for Endpoint Security
2. **Signing required**: Must be signed with entitlements
3. **Policy storage**: Protect ~/.config/ai-firewall/policy.json permissions
4. **Database security**: SQLite db should be readable only by user
5. **Bypass prevention**: Can't be bypassed - kernel-level enforcement

## Deliverables

1. Working Swift daemon that monitors OpenCode
2. SwiftUI dashboard for viewing activity
3. Installation script
4. Default policy configuration
5. LaunchAgent for automatic startup
6. Comprehensive README with:
   - Installation instructions
   - Usage examples
   - Policy configuration guide
   - Troubleshooting section
   - Architecture documentation

## Success Criteria

✅ Daemon successfully intercepts file, exec, and network operations
✅ User prompts appear for policy-flagged operations
✅ Activity is logged to SQLite database
✅ Dashboard displays real-time activity
✅ Blocked operations are prevented at kernel level
✅ Ollama connections are detected and logged
✅ External API connections require approval
✅ Installation script works on clean macOS system

## Additional Notes

- **macOS Version**: Requires macOS 13.0+ for Endpoint Security
- **Xcode**: Needs Xcode Command Line Tools
- **Permissions**: Must grant Full Disk Access in System Settings
- **Code Signing**: For distribution, needs Apple Developer ID
- **Performance**: Minimal overhead, events processed in microseconds

## Getting Started

To build this project:

```bash
# Clone or create directory structure
mkdir -p ai-firewall/{daemon,dashboard,launcher,config,launchd}

# Start with daemon
cd daemon
swift package init --type executable

# Build
swift build -c release

# Test (requires sudo)
sudo .build/release/ai-firewall-daemon $(pgrep opencode | head -1)
```

---

**Note for AI Assistant**: This is a systems programming project requiring deep knowledge of:
- macOS Endpoint Security framework
- Swift systems programming
- Unix process management
- Network programming (BSD sockets)
- SQLite database operations
- SwiftUI for macOS

Start with Phase 1 (Core Daemon) and build incrementally. Each component should be tested independently before integration.
