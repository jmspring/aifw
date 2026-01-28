# AIFW Build Prompts

Modular, phase-based prompts for building the AIFW (AI Firewall) project using AI coding agents.

## 📦 What's Included

| File | Description |
|------|-------------|
| **USAGE-GUIDE.md** | **START HERE** - Complete guide for using these prompts |
| aifw-master-prompt.md | Overall architecture and component overview |
| aifw-shared-schemas.md | Data structures and interfaces used across all components |
| phase-0-setup.md | Repository initialization and structure |
| phase-1-policy.md | Policy engine implementation |
| phase-2-logger.md | Activity logger (SQLite) - *to be created* |
| phase-3-tracker.md | Process tracker - *to be created* |
| phase-4-prompt.md | User prompt system - *to be created* |
| phase-5-handlers.md | Event handlers - *to be created* |
| phase-6-monitor.md | Firewall monitor (ES integration) - *to be created* |
| phase-7-dashboard.md | Dashboard (SwiftUI) - *to be created* |

## 🚀 Quick Start

### 1. Prerequisites

- macOS 13.0+
- Xcode Command Line Tools: `xcode-select --install`
- Swift 5.9+: `swift --version`
- GitHub CLI: `brew install gh`
- AI coding agent (Claude Code or OpenCode)

### 2. Setup Prompts

```bash
# Create directory for prompts
mkdir -p ~/code/fw/prompts
cd ~/code/fw/prompts

# Copy all .md files here
# (or git clone if these are in a repo)
```

### 3. Start Building

**With Claude Code:**
```bash
cd ~/code/fw
claude

# Then say:
"Read ~/code/fw/prompts/USAGE-GUIDE.md and 
~/code/fw/prompts/phase-0-setup.md, then set up the AIFW repository."
```

**With OpenCode:**
```bash
cd ~/code/fw
opencode

# Then say:
"Read ~/code/fw/prompts/phase-0-setup.md and implement all instructions."
```

## 📚 Documentation Structure

```
USAGE-GUIDE.md                    ← Read this first!
    ├─ How to use prompts
    ├─ Workflow examples
    ├─ Troubleshooting
    └─ Success criteria

aifw-master-prompt.md             ← Architecture overview
    ├─ Component breakdown
    ├─ Integration points
    └─ Overall success criteria

aifw-shared-schemas.md            ← Reference during development
    ├─ Policy JSON structure
    ├─ Database schemas
    ├─ Component interfaces
    └─ Testing mocks

phase-N-*.md                      ← Implementation prompts
    ├─ Objective
    ├─ Implementation steps
    ├─ Tests
    ├─ Git workflow
    └─ Success criteria
```

## 🎯 The Build Process

Each phase follows this pattern:

```
1. Read the phase prompt
2. Create feature branch
3. Implement component
4. Write comprehensive tests
5. Run tests (swift test)
6. Create PR
7. Merge after CI passes
8. Move to next phase
```

## 📊 What You'll Build

```
Phase 0: Repository Setup     [30 min]
    └─ GitHub repo, CI, structure

Phase 1: Policy Engine        [1-2 hrs]
    └─ Rule evaluation logic
    
Phase 2: Activity Logger      [1-2 hrs]
    └─ SQLite event storage
    
Phase 3: Process Tracker      [1 hr]
    └─ PID tree management
    
Phase 4: User Prompt          [1 hr]
    └─ macOS dialog system
    
Phase 5: Event Handlers       [2-3 hrs]
    └─ ES event processing
    
Phase 6: Firewall Monitor     [2-3 hrs]
    └─ ES framework integration
    
Phase 7: Dashboard (Optional) [3-4 hrs]
    └─ SwiftUI monitoring app

Total: ~12-18 hours over 1-2 weeks
```

## ✨ Key Features

- **Modular**: Each phase is independent and testable
- **Incremental**: Build working software at each step
- **Test-Driven**: Comprehensive tests for every component
- **Git-Based**: Proper branching, PRs, and CI
- **AI-Friendly**: Clear, structured instructions
- **Documented**: Extensive inline documentation

## 🎓 Example Session

Complete example for Phase 0:

```bash
# Terminal
cd ~/code/fw
claude

# Claude Code
User: "Read ~/code/fw/prompts/phase-0-setup.md and follow all 
       instructions to set up the AIFW repository"

Claude: [Creates structure, initializes git, sets up CI...]

User: "Run the verification steps from the prompt"

Claude: [Verifies structure, builds package, runs tests...]

User: "Push to GitHub"

Claude: [Commits and pushes...]
```

Done! Now move to Phase 1.

## 📋 Phase Status Template

Track your progress:

```markdown
## AIFW Build Progress

- [ ] Phase 0: Repository Setup
- [ ] Phase 1: Policy Engine  
- [ ] Phase 2: Activity Logger
- [ ] Phase 3: Process Tracker
- [ ] Phase 4: User Prompt
- [ ] Phase 5: Event Handlers
- [ ] Phase 6: Firewall Monitor
- [ ] Phase 7: Dashboard
```

## 🔍 Finding What You Need

**"How do I start?"**  
→ Read `USAGE-GUIDE.md`

**"What's the overall architecture?"**  
→ Read `aifw-master-prompt.md`

**"What are the data structures?"**  
→ Read `aifw-shared-schemas.md`

**"How do I implement component X?"**  
→ Read `phase-N-*.md` for that component

**"How do components connect?"**  
→ See integration points in `aifw-master-prompt.md`

**"What should I test?"**  
→ Each phase prompt has test requirements

## 🛠️ Customization

These prompts are templates. You can:

- ✅ Adjust implementation details
- ✅ Add additional features
- ✅ Change testing strategies
- ✅ Modify file structure
- ✅ Adapt for different AI agents

Just maintain:
- Phase order (dependencies)
- Test coverage requirements
- Git workflow (branch → test → PR → merge)

## 🆘 Common Issues

**"AI gets confused"**  
→ Have it re-read the specific section causing confusion

**"Tests fail"**  
→ Have AI fix them before merging

**"Build errors"**  
→ Check Swift version, run `swift package clean`

**"PR creation fails"**  
→ Verify GitHub auth: `gh auth status`

See `USAGE-GUIDE.md` troubleshooting section for more.

## 🎯 Success Criteria

After all phases, you'll have:

✅ Working macOS security monitor  
✅ Kernel-level enforcement (Endpoint Security)  
✅ Policy-based decision making  
✅ SQLite activity logging  
✅ User prompt system  
✅ 100+ passing tests  
✅ Complete documentation  
✅ CI/CD pipeline  

## 📚 Resources

- **Swift**: https://swift.org/documentation/
- **Endpoint Security**: https://developer.apple.com/documentation/endpointsecurity
- **SQLite**: https://www.sqlite.org/docs.html
- **GitHub CLI**: https://cli.github.com/manual/

## 🤝 Contributing

Found an issue or improvement?

1. Open an issue describing the problem
2. Submit a PR with fixes
3. Update this README if needed

## 📄 License

These prompts are provided as-is for building the AIFW project.

The AIFW project itself is MIT licensed - see the project LICENSE file.

## 🎉 Let's Build!

Ready to start? Open `USAGE-GUIDE.md` and follow along.

**First Command:**
```bash
cd ~/code/fw && claude
# Then: "Read ~/code/fw/prompts/USAGE-GUIDE.md"
```

Happy building! 🚀
