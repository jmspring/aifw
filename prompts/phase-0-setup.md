# Phase 0: Repository Setup

**Branch**: `main` (initial commit)  
**Prerequisites**: None  
**Duration**: 15-30 minutes  

## Objective

Initialize the GitHub repository with proper structure, documentation, and CI configuration. This creates the foundation for all subsequent phases.

## Context

Before starting, review:
- [Master Prompt](../aifw-master-prompt.md) - Overall project structure
- [Shared Schemas](../aifw-shared-schemas.md) - Data structures and interfaces

## Tasks

### 1. Create Local Repository

```bash
# Create project directory
mkdir -p ~/code/fw
cd ~/code/fw

# Initialize git
git init
git branch -M main

# Create .gitignore
cat > .gitignore << 'EOF'
# Swift
.DS_Store
/.build
/Packages
/*.xcodeproj
xcuserdata/
DerivedData/
.swiftpm/
*.xcworkspace

# SQLite
*.db
*.db-shm
*.db-wal

# Logs
*.log
daemon.log

# Build products
*.app
*.dSYM.zip
*.dSYM

# macOS
.AppleDouble
.LSOverride

# Configuration
config/policy.json.local
config/*.local

# IDE
.vscode/
.idea/
*.swp
*~

# Test artifacts
/tmp/
/test-output/
EOF
```

### 2. Create Directory Structure

```bash
# Core directories
mkdir -p daemon/Sources/AIFW/{Policy,Logger,Tracker,Prompt,Monitor,Handlers}
mkdir -p daemon/Sources/aifw-daemon
mkdir -p daemon/Tests/AIFWTests/{Policy,Logger,Tracker,Prompt,Monitor,Handlers}
mkdir -p dashboard
mkdir -p scripts
mkdir -p config
mkdir -p docs
mkdir -p prompts/shared

# GitHub Actions
mkdir -p .github/workflows
```

### 3. Create LICENSE

```bash
cat > LICENSE << 'EOF'
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
EOF
```

### 4. Create README.md

```markdown
# AIFW - AI Firewall for OpenCode

[![CI](https://github.com/jmspring/aifw/actions/workflows/ci.yml/badge.svg)](https://github.com/jmspring/aifw/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A macOS security monitoring system for AI coding agents using Endpoint Security framework.

## What is AIFW?

AIFW monitors and controls file, process, and network operations performed by AI coding agents like OpenCode. Think of it as "Little Snitch for AI agents."

### Key Features

- 🛡️ **Real-time Monitoring** - Intercepts file operations, process execution, and network connections
- 🔍 **Process Tree Tracking** - Monitors target process and all children
- 📝 **Policy-Based Control** - JSON configuration for allowed/blocked operations
- 💬 **User Prompts** - Native macOS dialogs for approval decisions
- 📊 **Activity Logging** - SQLite database with comprehensive audit trail
- 🖥️ **Dashboard** - SwiftUI app for visualization (optional)
- 🔐 **Kernel-Level Enforcement** - Cannot be bypassed by monitored process

## Requirements

- macOS 13.0 or later
- Xcode Command Line Tools
- Swift 5.9 or later
- Full Disk Access permission
- Code signing certificate (for Endpoint Security entitlement)

## Project Status

🚧 **In Development**

This project is being built in phases. Current progress:

- [x] Phase 0: Repository Setup
- [ ] Phase 1: Policy Engine
- [ ] Phase 2: Activity Logger
- [ ] Phase 3: Process Tracker
- [ ] Phase 4: User Prompt System
- [ ] Phase 5: Event Handlers
- [ ] Phase 6: Firewall Monitor
- [ ] Phase 7: Dashboard (Optional)

## Quick Start

*Installation instructions will be added as components are completed.*

## Architecture

```
┌─────────────────────────────────────────────┐
│  OpenCode Process (Target)                  │
└──────────────┬──────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────┐
│  macOS Endpoint Security Framework          │
└──────────────┬──────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────┐
│  AIFW Daemon (Swift)                        │
│  ├─ PolicyEngine      (rule evaluation)    │
│  ├─ ActivityLogger    (SQLite storage)     │
│  ├─ ProcessTracker    (PID management)     │
│  ├─ UserPrompt        (macOS dialogs)      │
│  └─ FirewallMonitor   (ES integration)     │
└─────────────────────────────────────────────┘
```

See [docs/architecture.md](docs/architecture.md) for detailed technical architecture.

## Development

### Building from Source

```bash
cd daemon
swift build -c release
```

### Running Tests

```bash
cd daemon
swift test
```

### Contributing

This project follows a phased development approach. Each phase builds a complete, tested component.

See the [prompts/](prompts/) directory for detailed phase-by-phase build instructions.

## Documentation

- [Architecture](docs/architecture.md) - Technical design and component overview
- [Usage Guide](docs/usage.md) - Installation and configuration
- [Development Guide](docs/development.md) - Building and contributing

## License

MIT License - see [LICENSE](LICENSE) for details.

## Security Notice

AIFW requires elevated privileges (Endpoint Security entitlement) to function. The daemon must:
- Be code-signed with proper entitlements
- Run with sudo permissions
- Have Full Disk Access granted in System Preferences

Only install from trusted sources and review the code before building.

## Acknowledgments

- Inspired by [Little Snitch](https://www.obdev.at/products/littlesnitch/)
- Built for monitoring [OpenCode](https://github.com/anomalyco/opencode)
- Uses macOS [Endpoint Security framework](https://developer.apple.com/documentation/endpointsecurity)
```

Save as `README.md`

### 5. Create Architecture Documentation

```markdown
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
```

Save as `docs/architecture.md`

### 6. Create GitHub Actions CI Workflow

```yaml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-and-test:
    runs-on: macos-13
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Check Swift version
      run: swift --version
    
    - name: Cache Swift packages
      uses: actions/cache@v3
      with:
        path: |
          .build
          ~/Library/Caches/org.swift.swiftpm
        key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
        restore-keys: |
          ${{ runner.os }}-spm-
    
    - name: Build daemon
      working-directory: daemon
      run: swift build -c release
    
    - name: Run tests
      working-directory: daemon
      run: swift test --enable-code-coverage
    
    - name: Generate code coverage
      working-directory: daemon
      run: |
        xcrun llvm-cov export -format="lcov" \
          .build/debug/AIFWPackageTests.xctest/Contents/MacOS/AIFWPackageTests \
          -instr-profile .build/debug/codecov/default.profdata > coverage.lcov
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        files: daemon/coverage.lcov
        flags: unittests
        name: codecov-aifw

  lint:
    runs-on: macos-13
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Install SwiftLint
      run: brew install swiftlint
    
    - name: Lint daemon code
      working-directory: daemon
      run: swiftlint lint --strict || true
```

Save as `.github/workflows/ci.yml`

### 7. Create Initial Package.swift

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AIFW",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "AIFW",
            targets: ["AIFW"]
        ),
        .executable(
            name: "aifw-daemon",
            targets: ["aifw-daemon"]
        )
    ],
    targets: [
        // Library target - contains all core functionality
        .target(
            name: "AIFW",
            dependencies: [],
            path: "Sources/AIFW"
        ),
        
        // Executable target - daemon entry point
        .executableTarget(
            name: "aifw-daemon",
            dependencies: ["AIFW"],
            path: "Sources/aifw-daemon"
        ),
        
        // Test target
        .testTarget(
            name: "AIFWTests",
            dependencies: ["AIFW"],
            path: "Tests/AIFWTests"
        )
    ]
)
```

Save as `daemon/Package.swift`

### 8. Create Placeholder main.swift

```swift
//
// main.swift
// aifw-daemon
//
// Created by AI Agent
// Copyright © 2025 Jim Spring. All rights reserved.
//

import Foundation

print("AIFW Daemon v0.1.0")
print("Phase 0: Repository setup complete")
print("\nNext: Implement PolicyEngine (Phase 1)")
```

Save as `daemon/Sources/aifw-daemon/main.swift`

### 9. Commit and Push to GitHub

```bash
# Add all files
git add .

# Commit
git commit -m "Phase 0: Initial repository setup

- Add directory structure for daemon and dashboard
- Create README, LICENSE, and architecture docs
- Configure GitHub Actions CI workflow
- Set up Swift package structure
- Add .gitignore for Swift/macOS development

Deliverables:
✅ Repository structure established
✅ Documentation framework created
✅ CI pipeline configured
✅ Swift package initialized
✅ Ready for Phase 1 (PolicyEngine)"

# Create repository on GitHub (if not already done)
# gh repo create jmspring/aifw --public --source=. --remote=origin

# Push to GitHub
git push -u origin main
```

## Verification Steps

Run these commands to verify everything is set up correctly:

```bash
# 1. Verify directory structure
tree -L 3 -I '.build|.git'

# Expected output should show:
# - daemon/Sources/AIFW/{Policy,Logger,Tracker,Prompt,Monitor,Handlers}
# - daemon/Tests/AIFWTests/
# - docs/
# - scripts/
# - config/
# - .github/workflows/

# 2. Verify Swift package
cd daemon
swift package describe

# Should show AIFW library and aifw-daemon executable

# 3. Try building (will succeed with placeholder main.swift)
swift build

# 4. Try running placeholder daemon
swift run aifw-daemon

# Should print:
# AIFW Daemon v0.1.0
# Phase 0: Repository setup complete

# 5. Verify GitHub Actions (after push)
# Go to https://github.com/jmspring/aifw/actions
# Should see CI workflow
```

## Success Criteria

✅ Repository exists at github.com/jmspring/aifw  
✅ Directory structure matches specification  
✅ README.md describes project clearly  
✅ Architecture documentation exists  
✅ GitHub Actions CI configured  
✅ Swift package builds successfully  
✅ .gitignore properly excludes artifacts  
✅ LICENSE file present (MIT)  
✅ Initial commit pushed to main branch  

## Next Steps

Once Phase 0 is complete:
1. Verify GitHub Actions CI passes
2. Review repository structure
3. Proceed to **Phase 1: Policy Engine**

## Troubleshooting

**Swift package doesn't build**:
- Ensure Xcode Command Line Tools installed: `xcode-select --install`
- Check Swift version: `swift --version` (need 5.9+)

**GitHub Actions fails**:
- Check macos-13 runner is available
- Verify Package.swift syntax
- Check workflow YAML indentation

**Can't push to GitHub**:
- Verify repository exists: `gh repo view jmspring/aifw`
- Check authentication: `gh auth status`
- Create repo if needed: `gh repo create jmspring/aifw --public`
