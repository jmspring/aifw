# AIFW - AI Firewall for OpenCode

[![CI](https://github.com/jmspring/aifw/actions/workflows/ci.yml/badge.svg)](https://github.com/jmspring/aifw/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A macOS security monitoring system for AI coding agents using Endpoint Security framework.

## What is AIFW?

AIFW monitors and controls file, process, and network operations performed by AI coding agents like OpenCode. Think of it as "Little Snitch for AI agents."

### Key Features

- **Real-time Monitoring** - Intercepts file operations, process execution, and network connections
- **Process Tree Tracking** - Monitors target process and all children
- **Policy-Based Control** - JSON configuration for allowed/blocked operations
- **User Prompts** - Native macOS dialogs for approval decisions
- **Activity Logging** - SQLite database with comprehensive audit trail
- **Dashboard** - SwiftUI app for visualization (optional)
- **Kernel-Level Enforcement** - Cannot be bypassed by monitored process

## Requirements

- macOS 13.0 or later
- Xcode Command Line Tools
- Swift 5.9 or later
- Full Disk Access permission
- Code signing certificate (for Endpoint Security entitlement)

## Project Status

**In Development**

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
