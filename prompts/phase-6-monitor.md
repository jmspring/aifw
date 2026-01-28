# Phase 6: Firewall Monitor (Endpoint Security Integration)

**Branch**: `phase-6-monitor`  
**Prerequisites**: Phases 0-5 complete  
**Duration**: 2-3 hours  
**Focus**: Kernel-level event interception with macOS Endpoint Security  

## Objective

Implement FirewallMonitor that integrates with macOS Endpoint Security framework to intercept file, process, and network events at the kernel level. This is the core that makes AIFW actually enforce policies.

## Context

**Review before starting**:
- [Shared Schemas](../aifw-shared-schemas.md) - All component interfaces
- [Master Prompt](../aifw-master-prompt.md#security-model) - ES requirements

**What FirewallMonitor Does**:
- Initializes ES client with proper entitlements
- Subscribes to AUTH events (file/exec/network)
- Routes events to EventHandler
- Responds ALLOW/DENY to kernel
- Requires sudo + code signing

**What FirewallMonitor Does NOT Do**:
- Make decisions (delegates to EventHandler)
- Show prompts (EventHandler does that)
- Store logs (EventHandler does that)

## ⚠️ Critical Requirements

**Before implementing**:
1. **Code Signing**: Must have valid Developer ID certificate
2. **Entitlements**: Requires `com.apple.developer.endpoint-security.client`
3. **Root Access**: Must run with `sudo`
4. **Full Disk Access**: Enable in System Settings

## Implementation

### 1. Create Feature Branch

```bash
git checkout main
git pull origin main
git checkout -b phase-6-monitor
```

### 2. Create Entitlements File

Create `daemon/AIFWDaemon.entitlements`:

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

### 3. Update Package.swift

Add Endpoint Security framework:

```swift
// Add to AIFW target:
.target(
    name: "AIFW",
    dependencies: [],
    path: "Sources/AIFW",
    linkerSettings: [
        .linkedFramework("EndpointSecurity")
    ]
)
```

### 4. Create Firewall Monitor

Create `daemon/Sources/AIFW/Monitor/FirewallMonitor.swift`:

```swift
//
// FirewallMonitor.swift
// AIFW
//
// Endpoint Security framework integration
//

import Foundation
import EndpointSecurity

public class FirewallMonitor {
    private var esClient: OpaquePointer?
    private let eventHandler: EventHandler
    private let processTracker: ProcessTrackerProtocol
    private var isRunning = false
    
    public init(eventHandler: EventHandler, processTracker: ProcessTrackerProtocol) {
        self.eventHandler = eventHandler
        self.processTracker = processTracker
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Lifecycle
    
    public func start() throws {
        guard !isRunning else { return }
        
        print("🔒 Initializing Endpoint Security client...")
        
        // Create ES client
        let result = es_new_client(&esClient) { client, message in
            // This closure is called by ES framework for each event
            // We need to capture 'self' to access our instance methods
            guard let client = client, let message = message else { return }
            
            // Get the monitor instance from client context
            guard let context = es_client_get_userdata(client) else { return }
            let monitor = Unmanaged<FirewallMonitor>.fromOpaque(context).takeUnretainedValue()
            
            monitor.handleMessage(client: client, message: message)
        }
        
        guard result == ES_NEW_CLIENT_RESULT_SUCCESS, let client = esClient else {
            throw NSError(domain: "AIFW", code: Int(result.rawValue),
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create ES client"])
        }
        
        // Set user data to reference self
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        es_client_set_userdata(client, selfPtr)
        
        // Subscribe to events
        var events: [es_event_type_t] = [
            ES_EVENT_TYPE_AUTH_OPEN,      // File open/write
            ES_EVENT_TYPE_AUTH_UNLINK,    // File delete
            ES_EVENT_TYPE_AUTH_EXEC,      // Process execution
            // ES_EVENT_TYPE_AUTH_CONNECT // Network (optional - not all macOS versions)
        ]
        
        let subscribeResult = es_subscribe(client, &events, UInt32(events.count))
        guard subscribeResult == ES_RETURN_SUCCESS else {
            throw NSError(domain: "AIFW", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to subscribe to events"])
        }
        
        isRunning = true
        print("✅ Endpoint Security client started")
        print("📡 Monitoring events for PID \(processTracker.rootPID)...")
    }
    
    public func stop() {
        guard isRunning, let client = esClient else { return }
        
        print("🛑 Stopping Endpoint Security client...")
        
        es_unsubscribe_all(client)
        es_delete_client(client)
        esClient = nil
        isRunning = false
        
        print("✅ Endpoint Security client stopped")
    }
    
    // MARK: - Event Handling
    
    private func handleMessage(client: OpaquePointer, message: UnsafePointer<es_message_t>) {
        let event = message.pointee
        
        // Dispatch based on event type
        switch event.event_type {
        case ES_EVENT_TYPE_AUTH_OPEN:
            handleFileOpen(client: client, message: message)
            
        case ES_EVENT_TYPE_AUTH_UNLINK:
            handleFileDelete(client: client, message: message)
            
        case ES_EVENT_TYPE_AUTH_EXEC:
            handleExec(client: client, message: message)
            
        default:
            // Unknown event - allow by default
            es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false)
        }
    }
    
    private func handleFileOpen(client: OpaquePointer, message: UnsafePointer<es_message_t>) {
        let event = message.pointee
        let openEvent = event.event.open
        
        // Get file path
        guard let pathStr = stringFromToken(openEvent.file.pointee.path) else {
            es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false)
            return
        }
        
        // Check if write operation
        let isWrite = (openEvent.fflag & Int32(FWRITE)) != 0
        
        guard isWrite else {
            // Read-only access - allow
            es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false)
            return
        }
        
        // Get process info
        let process = event.process.pointee
        let pid = audit_token_to_pid(process.audit_token)
        let ppid = process.ppid
        
        let processPath = stringFromToken(process.executable.pointee.path)
        
        // Create event data
        let fileEvent = FileOperationEvent(
            pid: pid,
            ppid: ppid,
            processPath: processPath,
            filePath: pathStr,
            isWrite: true,
            isDelete: false
        )
        
        // Handle event
        let decision = eventHandler.handleFileOperation(fileEvent)
        
        // Respond to kernel
        let authResult: es_auth_result_t = (decision == .allow) ?
            ES_AUTH_RESULT_ALLOW : ES_AUTH_RESULT_DENY
        es_respond_auth_result(client, message, authResult, false)
    }
    
    private func handleFileDelete(client: OpaquePointer, message: UnsafePointer<es_message_t>) {
        let event = message.pointee
        let unlinkEvent = event.event.unlink
        
        // Get file path
        guard let pathStr = stringFromToken(unlinkEvent.target.pointee.path) else {
            es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false)
            return
        }
        
        // Get process info
        let process = event.process.pointee
        let pid = audit_token_to_pid(process.audit_token)
        let ppid = process.ppid
        let processPath = stringFromToken(process.executable.pointee.path)
        
        // Create event data
        let fileEvent = FileOperationEvent(
            pid: pid,
            ppid: ppid,
            processPath: processPath,
            filePath: pathStr,
            isWrite: false,
            isDelete: true
        )
        
        // Handle event
        let decision = eventHandler.handleFileOperation(fileEvent)
        
        // Respond to kernel
        let authResult: es_auth_result_t = (decision == .allow) ?
            ES_AUTH_RESULT_ALLOW : ES_AUTH_RESULT_DENY
        es_respond_auth_result(client, message, authResult, false)
    }
    
    private func handleExec(client: OpaquePointer, message: UnsafePointer<es_message_t>) {
        let event = message.pointee
        let execEvent = event.event.exec
        
        // Get executable path
        guard let execPath = stringFromToken(execEvent.target.pointee.executable.pointee.path) else {
            es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false)
            return
        }
        
        // Extract command line arguments
        var command = execPath
        let args = execEvent.target.pointee.arguments
        
        for i in 0..<es_exec_arg_count(&args) {
            if let arg = es_exec_arg(&args, i),
               let argStr = stringFromToken(arg.pointee) {
                command += " " + argStr
            }
        }
        
        // Get process info
        let process = event.process.pointee
        let pid = audit_token_to_pid(process.audit_token)
        let ppid = process.ppid
        
        // Create event data
        let execEventData = ProcessExecutionEvent(
            pid: pid,
            ppid: ppid,
            executablePath: execPath,
            command: command
        )
        
        // Handle event
        let decision = eventHandler.handleProcessExecution(execEventData)
        
        // Respond to kernel
        let authResult: es_auth_result_t = (decision == .allow) ?
            ES_AUTH_RESULT_ALLOW : ES_AUTH_RESULT_DENY
        es_respond_auth_result(client, message, authResult, false)
    }
    
    // MARK: - Helpers
    
    private func stringFromToken(_ token: es_string_token_t) -> String? {
        guard token.length > 0, let data = token.data else { return nil }
        return String(bytes: UnsafeBufferPointer(start: data, count: Int(token.length)),
                     encoding: .utf8)
    }
}
```

### 5. Create Code Signing Script

Create `scripts/sign.sh`:

```bash
#!/bin/bash

set -e

echo "🔏 Code Signing AIFW Daemon"
echo "============================"

# Configuration
BINARY=".build/release/aifw-daemon"
ENTITLEMENTS="daemon/AIFWDaemon.entitlements"
IDENTITY="Developer ID Application"

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo "❌ Binary not found: $BINARY"
    echo "   Run: swift build -c release"
    exit 1
fi

# Check if entitlements file exists
if [ ! -f "$ENTITLEMENTS" ]; then
    echo "❌ Entitlements file not found: $ENTITLEMENTS"
    exit 1
fi

# Sign the binary
echo "📝 Signing with identity: $IDENTITY"
codesign --force \
         --sign "$IDENTITY" \
         --entitlements "$ENTITLEMENTS" \
         --options runtime \
         "$BINARY"

# Verify signature
echo ""
echo "✅ Verifying signature..."
codesign --verify --verbose "$BINARY"

# Check entitlements
echo ""
echo "📋 Entitlements:"
codesign --display --entitlements - "$BINARY"

echo ""
echo "✅ Code signing complete!"
echo ""
echo "Next steps:"
echo "  1. Run with sudo: sudo $BINARY <target-pid>"
echo "  2. Grant Full Disk Access in System Settings if needed"
```

Make it executable:

```bash
chmod +x scripts/sign.sh
```

### 6. Update main.swift

```swift
//
// main.swift
// aifw-daemon
//

import Foundation
import AIFW

print("AIFW Daemon v0.1.0")
print("Phase 6: Firewall Monitor (Endpoint Security)\n")

// Check for root
guard getuid() == 0 else {
    print("❌ This daemon requires root privileges")
    print("   Run with: sudo \(CommandLine.arguments[0]) <target-pid>")
    exit(1)
}

// Check for target PID argument
guard CommandLine.arguments.count > 1,
      let targetPID = Int32(CommandLine.arguments[1]) else {
    print("❌ Usage: sudo \(CommandLine.arguments[0]) <target-pid>")
    print("\nExample:")
    print("  # Start target process")
    print("  opencode &")
    print("  TARGET_PID=$!")
    print("  ")
    print("  # Start firewall")
    print("  sudo \(CommandLine.arguments[0]) $TARGET_PID")
    exit(1)
}

print("🎯 Target PID: \(targetPID)")

// Initialize components
let policy = FirewallPolicy.defaultPolicy()
let policyEngine = PolicyEngine(policy: policy)

let dbPath = NSHomeDirectory() + "/.config/aifw/activity.db"
let logger = ActivityLogger(dbPath: dbPath)

let tracker = ProcessTracker(rootPID: targetPID)
print("📍 Tracking \(tracker.trackedPIDs.count) process(es)")

let prompt = UserPrompt() // Real prompts!

let eventHandler = EventHandler(
    policyEngine: policyEngine,
    activityLogger: logger,
    processTracker: tracker,
    userPrompt: prompt
)

// Create and start monitor
let monitor = FirewallMonitor(
    eventHandler: eventHandler,
    processTracker: tracker
)

do {
    try monitor.start()
    
    print("\n✅ AIFW is now monitoring PID \(targetPID)")
    print("Press Ctrl+C to stop\n")
    
    // Set up signal handler
    signal(SIGINT) { _ in
        print("\n\n🛑 Stopping AIFW...")
        exit(0)
    }
    
    // Run loop
    RunLoop.main.run()
    
} catch {
    print("❌ Failed to start monitor: \(error)")
    exit(1)
}
```

### 7. Create Installation Documentation

Create `docs/usage.md`:

```markdown
# AIFW Usage Guide

## Prerequisites

- macOS 13.0 or later
- Xcode Command Line Tools
- Valid code signing certificate
- Administrator access (sudo)

## Building

\`\`\`bash
cd daemon
swift build -c release
\`\`\`

## Code Signing

AIFW requires code signing with Endpoint Security entitlement:

\`\`\`bash
# Sign the binary
./scripts/sign.sh

# Verify
codesign --verify --verbose .build/release/aifw-daemon
\`\`\`

## Running

1. **Start target process** (e.g., opencode):
\`\`\`bash
opencode &
TARGET_PID=$!
\`\`\`

2. **Run AIFW** with sudo:
\`\`\`bash
sudo .build/release/aifw-daemon $TARGET_PID
\`\`\`

3. **Grant permissions** if prompted:
   - System Settings → Privacy & Security → Full Disk Access
   - Add Terminal or your IDE

## Configuration

Edit policy at: `~/.config/aifw/policy.json`

Default policy is created automatically on first run.

## Activity Logs

View logs:
\`\`\`bash
sqlite3 ~/.config/aifw/activity.db "SELECT * FROM activity ORDER BY id DESC LIMIT 10"
\`\`\`

## Troubleshooting

**"Operation not permitted"**:
- Ensure binary is code-signed
- Check Full Disk Access permissions
- Run with sudo

**"Failed to create ES client"**:
- Verify entitlements: `codesign --display --entitlements - aifw-daemon`
- Check for other ES clients running
- Reboot and try again

**Dialogs not showing**:
- Grant Accessibility permissions
- Test with: `swift run test-prompt`
\`\`\`

## Build and Test

```bash
cd daemon

# Build release
swift build -c release

# Sign binary
./scripts/sign.sh

# Manual test (requires target process)
# Start a sleep process as target
sleep 1000 &
TARGET_PID=$!

# Run firewall
sudo .build/release/aifw-daemon $TARGET_PID

# In another terminal, try operations as the target process
# They should be monitored and logged
```

## Create Pull Request

```bash
git add daemon/ scripts/ docs/
git commit -m "Phase 6: Implement Firewall Monitor with Endpoint Security

Complete ES framework integration:
- FirewallMonitor class with ES client
- Handle AUTH_OPEN, AUTH_UNLINK, AUTH_EXEC events
- Code signing script with entitlements
- Updated main.swift for production use
- Usage documentation

Key Features:
✅ Kernel-level event interception
✅ ES client lifecycle management
✅ Event routing to handlers
✅ ALLOW/DENY responses to kernel
✅ Code signing with entitlements
✅ Root permission checks
✅ Production-ready daemon

Note: Requires manual testing with actual target process
Cannot be fully tested in CI due to ES requirements"

git push -u origin phase-6-monitor
gh pr create --title "Phase 6: Firewall Monitor (ES Integration)" --base main
gh pr merge phase-6-monitor --squash
```

## Success Criteria

✅ FirewallMonitor integrates with ES framework  
✅ Handles AUTH events correctly  
✅ Routes events to EventHandler  
✅ Responds to kernel properly  
✅ Code signing script works  
✅ Entitlements configured  
✅ Usage documentation complete  
✅ Works with real target process  

## Next Steps

After Phase 6: Proceed to **Phase 7: Dashboard** (SwiftUI UI - optional)
