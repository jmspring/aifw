# AIFW - AI Firewall Master Build Plan

## Project Overview

**Repository**: https://github.com/jmspring/aifw  
**Goal**: Build a macOS security monitoring system for AI coding agents using Endpoint Security framework  
**Analogy**: "Little Snitch for AI agents like OpenCode"

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│  OpenCode Process (Target)                      │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│  macOS Endpoint Security Framework              │
│  (Kernel-level event interception)              │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│  AIFW Daemon (Swift)                            │
│  ├─ ProcessTracker    (track PID trees)        │
│  ├─ PolicyEngine      (evaluate rules)         │
│  ├─ EventHandlers     (file/exec/network)      │
│  ├─ ActivityLogger    (SQLite storage)         │
│  └─ UserPrompt        (macOS dialogs)          │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│  Dashboard (SwiftUI) - Optional                 │
│  ├─ ActivityView      (event log)              │
│  ├─ StatsView         (analytics)              │
│  └─ PolicyEditor      (config UI)              │
└─────────────────────────────────────────────────┘
```

## Component Breakdown

### Core Components
1. **PolicyEngine** - Rule evaluation (file paths, commands, network)
2. **ActivityLogger** - SQLite-based event storage
3. **ProcessTracker** - PID tree management
4. **UserPrompt** - macOS dialog system
5. **EventHandlers** - ES event processing (file/exec/network)
6. **FirewallMonitor** - ES framework integration
7. **Dashboard** - SwiftUI monitoring app (optional)

### Shared Infrastructure
- Policy JSON schema
- Activity database schema
- Swift package configuration
- Testing utilities
- Installation scripts

## Development Approach

### Phase Structure
Each phase produces a working, tested component that can be:
- Built independently
- Tested in isolation
- Integrated incrementally
- Reviewed via PR

### Git Workflow
```bash
main
  ├── phase-0-setup           (repo initialization)
  ├── phase-1-policy          (PolicyEngine)
  ├── phase-2-logger          (ActivityLogger)
  ├── phase-3-tracker         (ProcessTracker)
  ├── phase-4-prompt          (UserPrompt)
  ├── phase-5-handlers        (EventHandlers)
  ├── phase-6-monitor         (FirewallMonitor)
  └── phase-7-dashboard       (Dashboard - optional)
```

Each phase:
1. Create feature branch
2. Implement component with tests
3. Run tests (`swift test`)
4. Create PR with detailed description
5. Merge after CI passes
6. Tag with version if appropriate

## Getting Started

Follow the phases in order. Each phase has its own detailed prompt:

1. **Phase 0**: Repository Setup ([prompts/phase-0-setup.md](prompts/phase-0-setup.md))
2. **Phase 1**: Policy Engine ([prompts/phase-1-policy.md](prompts/phase-1-policy.md))
3. **Phase 2**: Activity Logger ([prompts/phase-2-logger.md](prompts/phase-2-logger.md))
4. **Phase 3**: Process Tracker ([prompts/phase-3-tracker.md](prompts/phase-3-tracker.md))
5. **Phase 4**: User Prompt ([prompts/phase-4-prompt.md](prompts/phase-4-prompt.md))
6. **Phase 5**: Event Handlers ([prompts/phase-5-handlers.md](prompts/phase-5-handlers.md))
7. **Phase 6**: Firewall Monitor ([prompts/phase-6-monitor.md](prompts/phase-6-monitor.md))
8. **Phase 7**: Dashboard (Optional) ([prompts/phase-7-dashboard.md](prompts/phase-7-dashboard.md))

## Shared Context

All phases share this common context. Include this when working on any phase.

### Technology Stack
- **Language**: Swift 5.9+
- **Platform**: macOS 13.0+
- **Frameworks**: EndpointSecurity, Foundation, SQLite3, SwiftUI
- **Build**: Swift Package Manager
- **CI**: GitHub Actions

### Directory Structure
```
aifw/
├── .github/
│   └── workflows/
│       └── ci.yml
├── daemon/                 # Main Swift package
│   ├── Package.swift
│   ├── Sources/
│   │   └── AIFW/          # Library module
│   │       ├── Policy/
│   │       ├── Logger/
│   │       ├── Tracker/
│   │       ├── Prompt/
│   │       └── Monitor/
│   ├── Sources/
│   │   └── aifw-daemon/   # Executable
│   │       └── main.swift
│   ├── Tests/
│   │   └── AIFWTests/
│   └── AIFWDaemon.entitlements
├── dashboard/              # Optional SwiftUI app
├── scripts/
│   ├── install.sh
│   └── sign.sh
├── config/
│   └── policy.json.template
├── docs/
│   ├── architecture.md
│   └── usage.md
└── prompts/               # Build prompts (this directory)
    └── shared/            # Shared schemas and configs
```

### Coding Standards

**File Headers**:
```swift
//
// Filename.swift
// AIFW
//
// Created by AI Agent on [date]
// Copyright © 2025 Jim Spring. All rights reserved.
//

import Foundation
```

**Testing Standards**:
- Unit tests for all public APIs
- Test file naming: `ComponentNameTests.swift`
- Test class naming: `final class ComponentNameTests: XCTestCase`
- Arrange-Act-Assert pattern
- Descriptive test names: `testComponentDoesExpectedBehaviorWhenCondition`

**Error Handling**:
```swift
enum AIFWError: Error {
    case componentSpecificError(String)
}
```

**Logging**:
```swift
// Use print for now, structured logging can be added later
print("✅ Success message")
print("⚠️  Warning message")
print("❌ Error message")
```

### Common Dependencies

**Package.swift template**:
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AIFW",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "AIFW", targets: ["AIFW"]),
        .executable(name: "aifw-daemon", targets: ["aifw-daemon"])
    ],
    targets: [
        .target(
            name: "AIFW",
            dependencies: [],
            path: "Sources/AIFW"
        ),
        .executableTarget(
            name: "aifw-daemon",
            dependencies: ["AIFW"],
            path: "Sources/aifw-daemon"
        ),
        .testTarget(
            name: "AIFWTests",
            dependencies: ["AIFW"],
            path: "Tests"
        )
    ]
)
```

### Testing Utilities

**Test Base Class** (create in Phase 1):
```swift
import XCTest

class AIFWTestCase: XCTestCase {
    var tempDir: String!
    
    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path
        try? FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }
}
```

## Integration Points

### Between Components

**PolicyEngine → EventHandlers**:
```swift
// EventHandlers use PolicyEngine to make decisions
let decision = policyEngine.checkFileWrite(path: "/tmp/file.txt")
```

**ActivityLogger → All Components**:
```swift
// All components log to ActivityLogger
logger.log(
    eventType: "file_write",
    processName: "opencode",
    pid: 1234,
    ppid: 1000,
    path: "/tmp/file.txt",
    allowed: true,
    reason: "safe location"
)
```

**ProcessTracker → FirewallMonitor**:
```swift
// FirewallMonitor uses ProcessTracker to filter events
guard processTracker.isTracked(pid) else {
    // Ignore events from untracked processes
    return
}
```

**UserPrompt → EventHandlers**:
```swift
// EventHandlers use UserPrompt for user decisions
let response = userPrompt.showPrompt(
    title: "AI Firewall",
    message: "Write to sensitive file?",
    details: path
)
```

## Success Criteria (Overall)

At the end of all phases, the system should:

✅ Monitor OpenCode process tree in real-time  
✅ Intercept file operations (read/write/delete)  
✅ Intercept process execution (bash commands)  
✅ Intercept network connections (Ollama, external APIs)  
✅ Apply policy rules to allow/deny/prompt  
✅ Show native macOS dialogs for user decisions  
✅ Log all activity to SQLite database  
✅ Provide dashboard for monitoring (optional)  
✅ Cannot be bypassed (kernel-level enforcement)  
✅ Install and run automatically  

## Next Steps

Start with **Phase 0: Repository Setup** to initialize the project structure, then proceed through each phase in order.

Each phase prompt is self-contained but assumes you've completed previous phases and have the shared context available.
