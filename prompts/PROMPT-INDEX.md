# AIFW Build Prompts - Complete Index

## ✅ Available Prompts (Ready to Use)

### Core Documentation
1. **README.md** - Start here! Overview and quick start guide
2. **USAGE-GUIDE.md** - Complete tutorial with examples
3. **aifw-master-prompt.md** - Architecture and component overview
4. **aifw-shared-schemas.md** - Data structures and interfaces

### Phase Prompts (Implementation Guides)
5. **phase-0-setup.md** - Repository setup (30 min) ✅ Complete
6. **phase-1-policy.md** - Policy Engine (1-2 hrs) ✅ Complete  
7. **phase-2-logger.md** - Activity Logger (1-2 hrs) ✅ Complete
8. **phase-3-tracker.md** - Process Tracker (1 hr) ✅ Complete

## 🚧 Prompts To Be Created

You can create these following the same pattern as phases 1-3:

### Phase 4: User Prompt (1 hour)
- **File**: `phase-4-prompt.md`
- **Component**: `Sources/AIFW/Prompt/UserPrompt.swift`
- **What it does**: macOS dialog system using AppleScript
- **Tests**: Mock prompt for testing, real prompts for demo
- **Key features**:
  - Show native macOS dialogs
  - Three-button interface (Deny/Allow Once/Allow Always)
  - Protocol-based for testing

### Phase 5: Event Handlers (2-3 hours)
- **File**: `phase-5-handlers.md`
- **Component**: `Sources/AIFW/Handlers/EventHandlers.swift`
- **What it does**: Process ES events (file/exec/network)
- **Tests**: Mock all components to test in isolation
- **Key features**:
  - Handle ES_EVENT_TYPE_AUTH_OPEN
  - Handle ES_EVENT_TYPE_AUTH_UNLINK
  - Handle ES_EVENT_TYPE_AUTH_EXEC
  - Coordinate PolicyEngine, ActivityLogger, ProcessTracker, UserPrompt

### Phase 6: Firewall Monitor (2-3 hours)
- **File**: `phase-6-monitor.md`
- **Component**: `Sources/AIFW/Monitor/FirewallMonitor.swift`
- **What it does**: ES framework integration
- **Tests**: Requires sudo, test with real processes
- **Key features**:
  - Initialize ES client with es_new_client()
  - Subscribe to events
  - Route events to handlers
  - Respond ALLOW/DENY to kernel
- **Requirements**:
  - Code signing with entitlements
  - Runs as root (sudo)
  - Must be tested on actual macOS

### Phase 7: Dashboard (3-4 hours, Optional)
- **File**: `phase-7-dashboard.md`
- **Component**: `dashboard/` separate package
- **What it does**: SwiftUI monitoring app
- **Tests**: SwiftUI preview tests
- **Key features**:
  - ActivityView - real-time event stream
  - StatsView - charts and statistics
  - PolicyView - edit policy JSON
  - Auto-refresh every 2 seconds

## 📊 Progress Tracking

```markdown
## Your Build Progress

- [ ] Phase 0: Repository Setup (30 min)
- [ ] Phase 1: Policy Engine (1-2 hrs)  
- [ ] Phase 2: Activity Logger (1-2 hrs)
- [ ] Phase 3: Process Tracker (1 hr)
- [ ] Phase 4: User Prompt (1 hr)
- [ ] Phase 5: Event Handlers (2-3 hrs)
- [ ] Phase 6: Firewall Monitor (2-3 hrs)
- [ ] Phase 7: Dashboard (3-4 hrs, optional)

Total: ~12-18 hours
```

## 🚀 Quick Start

1. **Read** `README.md` for overview
2. **Read** `USAGE-GUIDE.md` for detailed instructions
3. **Start with** `phase-0-setup.md`
4. **Continue through** phases 1-3 using the provided prompts
5. **Create phases 4-7** using phases 1-3 as templates

## 📝 Template for Creating Missing Phases

Each phase should include:

```markdown
# Phase N: Component Name

**Branch**: `phase-N-component`
**Prerequisites**: Phases 0-(N-1) complete
**Duration**: X hours
**Focus**: What this component does

## Objective
Clear statement of what gets built

## Context
- Links to shared schemas
- What it does / doesn't do
- Integration points

## Implementation
### 1. Create Feature Branch
### 2. Create Component Files
   - Full Swift code with documentation
### 3. Create Protocol/Interface
### 4. Create Tests
   - 10+ comprehensive tests
   - Mock dependencies
### 5. Update main.swift
   - Demonstration code

## Build and Test
Verification steps

## Create Pull Request
Git workflow commands

## Success Criteria
Checklist of deliverables

## Next Steps
What comes after

## Troubleshooting
Common issues and solutions
```

## 📚 How to Use These Prompts

### With Claude Code
```bash
claude
"Read ~/code/fw/prompts/phase-0-setup.md and implement it"
```

### With OpenCode
```bash
opencode
"Read phase-0-setup.md and follow all instructions"
```

## 🎯 What You're Building

```
AIFW - AI Firewall for OpenCode
    ├── PolicyEngine ✅ (Phase 1)
    ├── ActivityLogger ✅ (Phase 2)
    ├── ProcessTracker ✅ (Phase 3)
    ├── UserPrompt 🚧 (Phase 4)
    ├── EventHandlers 🚧 (Phase 5)
    ├── FirewallMonitor 🚧 (Phase 6)
    └── Dashboard 🚧 (Phase 7, optional)
```

## ✨ Key Features of This Prompt System

1. **Modular** - Each phase is independent
2. **Incremental** - Build working software at each step
3. **Test-Driven** - Comprehensive tests for every component
4. **Git-Based** - Proper branching, PRs, CI
5. **AI-Friendly** - Clear, structured instructions
6. **Well-Documented** - Extensive inline documentation

## 📖 Files You Have

| File | Purpose | Size | Status |
|------|---------|------|--------|
| README.md | Entry point, navigation | ~4 KB | ✅ |
| USAGE-GUIDE.md | Complete tutorial | ~15 KB | ✅ |
| aifw-master-prompt.md | Architecture overview | ~8 KB | ✅ |
| aifw-shared-schemas.md | Schemas and interfaces | ~12 KB | ✅ |
| phase-0-setup.md | Repository setup | ~18 KB | ✅ |
| phase-1-policy.md | Policy engine | ~20 KB | ✅ |
| phase-2-logger.md | Activity logger | ~22 KB | ✅ |
| phase-3-tracker.md | Process tracker | ~5 KB | ✅ |
| phase-4-prompt.md | User prompts | - | 🚧 |
| phase-5-handlers.md | Event handlers | - | 🚧 |
| phase-6-monitor.md | ES monitor | - | 🚧 |
| phase-7-dashboard.md | Dashboard UI | - | 🚧 |

## 🎓 Learning Path

**Week 1**: Foundations
- Day 1: Phase 0 (setup) + Phase 1 (policy)
- Day 2: Phase 2 (logger)
- Day 3: Phase 3 (tracker)

**Week 2**: Integration
- Day 4: Phase 4 (prompts)
- Day 5-6: Phase 5 (handlers)

**Week 3**: Completion
- Day 7-8: Phase 6 (monitor)
- Day 9-10: Phase 7 (dashboard, optional)

## 🆘 Need Help?

1. Check USAGE-GUIDE.md troubleshooting section
2. Review shared-schemas.md for interfaces
3. Look at completed phases as examples
4. Ensure prerequisites are met

## 🎉 Success!

You now have:
- ✅ 4 complete, detailed phase prompts
- ✅ Comprehensive documentation
- ✅ Testing strategies
- ✅ Git workflows
- ✅ Architecture guides
- ✅ Usage tutorials

**Ready to build?** Start with `README.md`!
