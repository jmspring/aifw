# AIFW Architecture

## Overview

AIFW (AI Firewall) uses macOS Endpoint Security framework to provide kernel-level monitoring and enforcement of operations performed by AI coding agents.

## Core Principles

1. **Kernel-Level Enforcement** - Cannot be bypassed by monitored process
2. **Policy-Driven** - JSON configuration controls all decisions
3. **User Control** - Interactive prompts for ambiguous operations
4. **Comprehensive Logging** - SQLite database records all activity
5. **Process Isolation** - Only monitors specified process tree

## System Architecture

### High-Level Flow

```
User starts OpenCode
         ↓
AIFW Daemon starts with OpenCode PID
         ↓
Daemon subscribes to Endpoint Security events
         ↓
OpenCode attempts operation (file/exec/network)
         ↓
Kernel sends authorization event to daemon
         ↓
Daemon evaluates operation against policy
         ↓
If policy says PROMPT → Show macOS dialog → User decides
If policy says ALLOW → Log and allow
If policy says DENY → Log and block
         ↓
Daemon responds ALLOW or DENY to kernel
         ↓
Operation proceeds or is blocked
         ↓
Activity logged to SQLite
```

## Components

### 1. PolicyEngine

**Responsibility**: Evaluate operations against configured rules

**Key Methods**:
- `checkFileWrite(path:) -> PolicyDecision`
- `checkFileDelete(path:) -> PolicyDecision`
- `checkCommand(command:) -> PolicyDecision`
- `checkNetworkConnection(destination:port:) -> PolicyDecision`

**Data Source**: JSON policy file at `~/.config/aifw/policy.json`

**Decision Types**:
- `.allow(reason)` - Automatically permit operation
- `.deny(reason)` - Automatically block operation
- `.prompt(reason)` - Ask user for decision

### 2. ActivityLogger

**Responsibility**: Store all monitored events in SQLite database

**Key Methods**:
- `log(eventType:processName:pid:ppid:path:command:destination:allowed:reason:)`
- `getRecentActivity(limit:) -> [ActivityRecord]`
- `getStatistics() -> (total, allowed, denied)`

**Data Storage**: `~/.config/aifw/activity.db`

**Schema**: See [Shared Schemas](../aifw-shared-schemas.md#activity-database-schema)

### 3. ProcessTracker

**Responsibility**: Manage process tree and determine which PIDs to monitor

**Key Methods**:
- `isTracked(_ pid:) -> Bool`
- `getProcessPath(_ pid:) -> String?`
- `refresh()` - Rebuild process tree

**Implementation**: Uses `proc_listchildpids()` to walk process tree

### 4. UserPrompt

**Responsibility**: Display native macOS dialogs for user decisions

**Key Methods**:
- `showPrompt(title:message:details:) -> PromptResponse`

**Implementation**: Uses AppleScript via `osascript`

**Responses**:
- `.deny` - Block operation
- `.allowOnce` - Allow this time only
- `.allowAlways` - Allow and add to policy

### 5. EventHandlers

**Responsibility**: Handle specific Endpoint Security event types

**Event Types**:
- `AUTH_OPEN` - File open operations (check for write flag)
- `AUTH_UNLINK` - File deletion
- `AUTH_EXEC` - Process execution
- `AUTH_CONNECT` - Network connections (optional)

**Flow for Each Event**:
1. Extract event details (path, command, destination)
2. Check if process is tracked
3. Consult PolicyEngine for decision
4. Prompt user if needed
5. Log activity
6. Respond to kernel (ALLOW or DENY)

### 6. FirewallMonitor

**Responsibility**: Integrate all components with Endpoint Security framework

**Key Responsibilities**:
- Initialize ES client with `es_new_client()`
- Subscribe to event types
- Route events to appropriate handlers
- Manage lifecycle (start/stop)

**Privileges Required**:
- Must run as root
- Requires `com.apple.developer.endpoint-security.client` entitlement
- Must be code-signed

### 7. Dashboard (Optional)

**Responsibility**: Provide GUI for monitoring and configuration

**Views**:
- **ActivityView** - Real-time event stream
- **StatsView** - Aggregated statistics and charts
- **PolicyView** - Edit policy configuration

**Data Source**: Reads from same SQLite database as daemon

## Data Flow

### File Write Example

```
1. OpenCode calls open("/tmp/file.txt", O_WRONLY)
                 ↓
2. Kernel checks Endpoint Security subscribers
                 ↓
3. Kernel sends ES_EVENT_TYPE_AUTH_OPEN to AIFW Daemon
                 ↓
4. FirewallMonitor receives event
                 ↓
5. EventHandler extracts: path="/tmp/file.txt", flags=WRITE
                 ↓
6. ProcessTracker confirms PID is tracked
                 ↓
7. PolicyEngine.checkFileWrite("/tmp/file.txt")
                 ↓
8. PolicyEngine checks path against sensitivePaths
                 ↓
9. Returns .allow(reason: "non-sensitive location")
                 ↓
10. ActivityLogger logs: event_type="file_write", allowed=true
                 ↓
11. FirewallMonitor responds: ES_AUTH_RESULT_ALLOW
                 ↓
12. Kernel allows the operation
                 ↓
13. OpenCode's open() call succeeds
```

### Command Execution Example (Dangerous)

```
1. OpenCode calls exec("/bin/bash", ["sudo", "rm", "-rf", "/tmp/important"])
                 ↓
2. Kernel sends ES_EVENT_TYPE_AUTH_EXEC to AIFW Daemon
                 ↓
3. EventHandler extracts command: "sudo rm -rf /tmp/important"
                 ↓
4. PolicyEngine.checkCommand("sudo rm -rf /tmp/important")
                 ↓
5. Matches dangerousPattern "sudo rm"
                 ↓
6. Returns .prompt(reason: "dangerous pattern: sudo rm")
                 ↓
7. UserPrompt shows macOS dialog
                 ↓
8. User clicks "Deny"
                 ↓
9. ActivityLogger logs: event_type="exec", allowed=false, reason="user denied"
                 ↓
10. FirewallMonitor responds: ES_AUTH_RESULT_DENY
                 ↓
11. Kernel blocks the operation
                 ↓
12. OpenCode's exec() call fails with EACCES
```

## Security Model

### Privileges

**Daemon Requirements**:
- Root privileges (via sudo)
- Endpoint Security entitlement
- Code signed with valid Developer ID

**Why These Are Needed**:
- ES framework requires root
- Entitlement proves daemon is authorized
- Code signing prevents tampering

### Bypass Prevention

AIFW cannot be bypassed because:
1. Events are intercepted at kernel level
2. Daemon responds before operation completes
3. No file descriptors or sockets are exposed
4. Process cannot kill daemon (different privilege level)

### Attack Surface

Potential risks:
- Malicious policy file (mitigated by validation)
- SQLite injection (mitigated by parameterized queries)
- AppleScript injection (mitigated by escaping)
- Privilege escalation (mitigated by minimal permissions)

## Performance Considerations

### Event Handling

- Events processed synchronously
- ~1-10 microseconds per event
- User prompts block until user responds
- SQLite writes are batched

### Memory Usage

- Minimal baseline: ~10-20 MB
- Process tree cache: ~100 bytes per PID
- SQLite buffer pool: ~2 MB
- Total expected: <50 MB

### Scalability

Tested with:
- 1000+ file operations per second
- 100+ process spawns per second
- Process trees up to 50 PIDs

## Future Enhancements

- Network connection monitoring
- HTTP request/response inspection for Ollama
- Policy hot-reloading
- Dashboard with real-time updates
- Distributed logging (syslog integration)
- Policy templates for different AI agents

## References

- [Endpoint Security Framework](https://developer.apple.com/documentation/endpointsecurity)
- [macOS Security](https://support.apple.com/guide/security/welcome/web)
- [System Integrity Protection](https://support.apple.com/en-us/HT204899)
