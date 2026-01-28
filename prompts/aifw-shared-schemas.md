# AIFW Shared Schemas and Interfaces

This document defines the data structures and interfaces that are shared across all components. Reference this when implementing any phase.

## Policy Schema

### JSON Structure (policy.json)

```json
{
  "version": "1.0",
  "sensitivePaths": [
    "~/.ssh",
    "~/.aws",
    "~/.config",
    "/etc",
    "/System",
    "/Library/Keychains"
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
    "wget | bash",
    "> /dev/"
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
    "find ",
    "pwd",
    "which "
  ],
  "allowedNetworkDestinations": [
    "localhost:11434",
    "127.0.0.1:11434",
    "::1:11434"
  ],
  "monitorOllamaRequests": true
}
```

### Swift Structures

```swift
struct FirewallPolicy: Codable {
    let version: String
    let sensitivePaths: [String]
    let blockedCommands: [String]
    let dangerousPatterns: [String]
    let requireApproval: RequireApproval
    let autoAllowPatterns: [String]
    let allowedNetworkDestinations: [String]
    let monitorOllamaRequests: Bool
    
    struct RequireApproval: Codable {
        let fileDelete: Bool
        let fileWriteSensitive: Bool
        let bashDangerous: Bool
        let networkExternal: Bool
    }
}

public enum PolicyDecision {
    case allow(reason: String)
    case deny(reason: String)
    case prompt(reason: String)
}
```

## Activity Database Schema

### SQLite Schema

```sql
-- Activity log table
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

-- Indexes for query performance
CREATE INDEX IF NOT EXISTS idx_timestamp ON activity(timestamp);
CREATE INDEX IF NOT EXISTS idx_event_type ON activity(event_type);
CREATE INDEX IF NOT EXISTS idx_allowed ON activity(allowed);
CREATE INDEX IF NOT EXISTS idx_pid ON activity(pid);
CREATE INDEX IF NOT EXISTS idx_created_at ON activity(created_at);

-- Statistics view (optional, for dashboard)
CREATE VIEW IF NOT EXISTS activity_stats AS
SELECT 
    event_type,
    COUNT(*) as total,
    SUM(CASE WHEN allowed = 1 THEN 1 ELSE 0 END) as allowed_count,
    SUM(CASE WHEN allowed = 0 THEN 1 ELSE 0 END) as denied_count,
    date(created_at) as event_date
FROM activity
GROUP BY event_type, date(created_at);
```

### Swift Structure

```swift
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

enum EventType: String {
    case fileRead = "file_read"
    case fileWrite = "file_write"
    case fileDelete = "file_delete"
    case processExec = "process_exec"
    case networkConnect = "network_connect"
    case ollamaRequest = "ollama_request"
    case ollamaResponse = "ollama_response"
}
```

## Component Interfaces

### PolicyEngine Protocol

```swift
protocol PolicyEngineProtocol {
    func checkFileRead(path: String) -> PolicyDecision
    func checkFileWrite(path: String) -> PolicyDecision
    func checkFileDelete(path: String) -> PolicyDecision
    func checkCommand(command: String) -> PolicyDecision
    func checkNetworkConnection(destination: String, port: UInt16) -> PolicyDecision
}
```

### ActivityLogger Protocol

```swift
protocol ActivityLoggerProtocol {
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
```

### ProcessTracker Protocol

```swift
protocol ProcessTrackerProtocol {
    var rootPID: pid_t { get }
    var trackedPIDs: Set<pid_t> { get }
    
    func isTracked(_ pid: pid_t) -> Bool
    func getProcessPath(_ pid: pid_t) -> String?
    func refresh()
}
```

### UserPrompt Protocol

```swift
enum PromptResponse {
    case deny
    case allowOnce
    case allowAlways
}

protocol UserPromptProtocol {
    func showPrompt(
        title: String,
        message: String,
        details: String
    ) -> PromptResponse
}
```

## Error Handling

### Common Error Types

```swift
enum AIFWError: Error, CustomStringConvertible {
    // Policy errors
    case policyLoadFailed(path: String, underlying: Error)
    case policyInvalid(reason: String)
    
    // Logger errors
    case databaseOpenFailed(path: String)
    case databaseWriteFailed(reason: String)
    
    // Process tracking errors
    case processNotFound(pid: pid_t)
    case processInfoUnavailable(pid: pid_t)
    
    // Monitor errors
    case endpointSecurityInitFailed(code: Int)
    case endpointSecuritySubscribeFailed
    
    // Prompt errors
    case promptFailed(reason: String)
    
    var description: String {
        switch self {
        case .policyLoadFailed(let path, let error):
            return "Failed to load policy from \(path): \(error)"
        case .policyInvalid(let reason):
            return "Invalid policy: \(reason)"
        case .databaseOpenFailed(let path):
            return "Failed to open database at \(path)"
        case .databaseWriteFailed(let reason):
            return "Failed to write to database: \(reason)"
        case .processNotFound(let pid):
            return "Process \(pid) not found"
        case .processInfoUnavailable(let pid):
            return "Cannot get info for process \(pid)"
        case .endpointSecurityInitFailed(let code):
            return "Endpoint Security initialization failed with code \(code)"
        case .endpointSecuritySubscribeFailed:
            return "Failed to subscribe to Endpoint Security events"
        case .promptFailed(let reason):
            return "User prompt failed: \(reason)"
        }
    }
}
```

## Configuration Paths

### Standard Paths

```swift
struct AIFWPaths {
    static let configDir = "~/.config/aifw"
    static let policyFile = "~/.config/aifw/policy.json"
    static let databaseFile = "~/.config/aifw/activity.db"
    static let logFile = "~/.config/aifw/daemon.log"
    
    static func expandTilde(_ path: String) -> String {
        return NSString(string: path).expandingTildeInPath
    }
    
    static func ensureConfigDirectory() throws {
        let expanded = expandTilde(configDir)
        try FileManager.default.createDirectory(
            atPath: expanded,
            withIntermediateDirectories: true
        )
    }
}
```

## Testing Mocks

### Mock Policy Engine

```swift
class MockPolicyEngine: PolicyEngineProtocol {
    var fileWriteDecision: PolicyDecision = .allow(reason: "mock")
    var fileDeleteDecision: PolicyDecision = .prompt(reason: "mock")
    var commandDecision: PolicyDecision = .allow(reason: "mock")
    var networkDecision: PolicyDecision = .prompt(reason: "mock")
    
    func checkFileRead(path: String) -> PolicyDecision {
        return .allow(reason: "mock always allows read")
    }
    
    func checkFileWrite(path: String) -> PolicyDecision {
        return fileWriteDecision
    }
    
    func checkFileDelete(path: String) -> PolicyDecision {
        return fileDeleteDecision
    }
    
    func checkCommand(command: String) -> PolicyDecision {
        return commandDecision
    }
    
    func checkNetworkConnection(destination: String, port: UInt16) -> PolicyDecision {
        return networkDecision
    }
}
```

### Mock Activity Logger

```swift
class MockActivityLogger: ActivityLoggerProtocol {
    var logs: [ActivityRecord] = []
    
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
        let record = ActivityRecord(
            id: logs.count + 1,
            timestamp: Date(),
            eventType: eventType,
            processName: processName,
            pid: pid,
            ppid: ppid,
            path: path,
            command: command,
            destination: destination,
            allowed: allowed,
            reason: reason
        )
        logs.append(record)
    }
    
    func getRecentActivity(limit: Int) -> [ActivityRecord] {
        return Array(logs.suffix(limit))
    }
    
    func getStatistics() -> (total: Int, allowed: Int, denied: Int) {
        let total = logs.count
        let allowed = logs.filter { $0.allowed }.count
        let denied = logs.filter { !$0.allowed }.count
        return (total, allowed, denied)
    }
    
    func clearAll() {
        logs.removeAll()
    }
}
```

### Mock User Prompt

```swift
class MockUserPrompt: UserPromptProtocol {
    var responseToReturn: PromptResponse = .deny
    var promptHistory: [(title: String, message: String, details: String)] = []
    
    func showPrompt(title: String, message: String, details: String) -> PromptResponse {
        promptHistory.append((title, message, details))
        return responseToReturn
    }
    
    var wasPrompted: Bool {
        return !promptHistory.isEmpty
    }
    
    var promptCount: Int {
        return promptHistory.count
    }
}
```

## Constants

```swift
enum AIFWConstants {
    // Version
    static let version = "0.1.0"
    
    // Network
    static let ollamaDefaultPort: UInt16 = 11434
    static let localhostAddresses = ["127.0.0.1", "::1", "localhost"]
    
    // Timing
    static let dashboardRefreshInterval: TimeInterval = 2.0
    
    // Limits
    static let maxActivityRecords = 10000
    static let defaultActivityLimit = 100
    
    // Event Types
    enum EventTypes {
        static let fileRead = "file_read"
        static let fileWrite = "file_write"
        static let fileDelete = "file_delete"
        static let processExec = "process_exec"
        static let networkConnect = "network_connect"
        static let ollamaRequest = "ollama_request"
        static let ollamaResponse = "ollama_response"
    }
}
```

## Usage Examples

### Loading Policy

```swift
do {
    let policy = try FirewallPolicy.load(from: AIFWPaths.policyFile)
    let engine = PolicyEngine(policy: policy)
} catch {
    print("⚠️  Failed to load policy: \(error)")
    let engine = PolicyEngine(policy: .defaultPolicy())
}
```

### Logging Activity

```swift
logger.log(
    eventType: AIFWConstants.EventTypes.fileWrite,
    processName: "opencode",
    pid: 12345,
    ppid: 1000,
    path: "/tmp/test.txt",
    command: nil,
    destination: nil,
    allowed: true,
    reason: "non-sensitive location"
)
```

### Checking Policy

```swift
let decision = policyEngine.checkFileWrite(path: "~/.ssh/config")
switch decision {
case .allow(let reason):
    print("Allowed: \(reason)")
case .deny(let reason):
    print("Denied: \(reason)")
case .prompt(let reason):
    let response = userPrompt.showPrompt(
        title: "AI Firewall",
        message: "Write to sensitive file?",
        details: "~/.ssh/config"
    )
    // Handle response
}
```

---

**Note**: All implementations should follow these schemas exactly to ensure compatibility between components.
