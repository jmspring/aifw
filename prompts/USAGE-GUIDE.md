# AIFW Build Prompts - User Guide

This guide explains how to use the modular prompt system to build the AIFW project using AI coding agents like Claude Code or OpenCode.

## 📚 Overview

The AIFW project is built through **8 phases**, each producing a tested, working component:

```
Phase 0: Repository Setup     → GitHub repo, CI, directory structure
Phase 1: Policy Engine        → Rule evaluation logic
Phase 2: Activity Logger      → SQLite event storage
Phase 3: Process Tracker      → PID tree management
Phase 4: User Prompt          → macOS dialog system
Phase 5: Event Handlers       → ES event processing
Phase 6: Firewall Monitor     → ES framework integration
Phase 7: Dashboard (Optional) → SwiftUI monitoring app
```

Each phase follows the pattern:
1. Create feature branch
2. Implement component
3. Write comprehensive tests
4. Run tests (`swift test`)
5. Create PR
6. Merge after CI passes

## 🎯 Before You Start

### Requirements

- **macOS 13.0+** (required for Endpoint Security)
- **Xcode Command Line Tools**: `xcode-select --install`
- **Swift 5.9+**: Check with `swift --version`
- **Git**: For version control
- **GitHub CLI** (recommended): `brew install gh`
- **AI Coding Agent**: Claude Code or OpenCode

### Setup

1. **Clone/Download the Prompts**
   ```bash
   mkdir -p ~/code/fw/prompts
   cd ~/code/fw/prompts
   # Copy all .md files here
   ```

2. **Authenticate with GitHub**
   ```bash
   gh auth login
   # Follow prompts to authenticate
   ```

3. **Create GitHub Repository** (if not exists)
   ```bash
   gh repo create jmspring/aifw --public --description "AI Firewall for OpenCode"
   ```

## 🚀 Using with Claude Code

### Initial Setup (One Time)

```bash
# Navigate to where you want to work
cd ~/code/fw

# Start Claude Code
claude
```

### Phase 0: Repository Setup

In Claude Code:
```
Read and follow all instructions in ~/code/fw/prompts/phase-0-setup.md

Create the AIFW repository structure at github.com/jmspring/aifw
```

**What Claude Code will do**:
- Create directory structure
- Initialize git repository
- Create README, LICENSE, docs
- Set up GitHub Actions CI
- Create initial Package.swift
- Commit and push to GitHub

**Verify**:
```bash
cd ~/code/fw
git log  # Should see initial commit
tree -L 2  # Should see proper structure
```

### Phase 1: Policy Engine

After Phase 0 is complete:

```
Checkout main branch and pull latest changes.

Read ~/code/fw/prompts/shared-schemas.md to understand the PolicyEngine interfaces.

Then read and follow all instructions in ~/code/fw/prompts/phase-1-policy.md

Create the PolicyEngine component with comprehensive tests.
```

**What Claude Code will do**:
- Create `phase-1-policy` branch
- Implement FirewallPolicy struct
- Implement PolicyEngine class
- Create 25+ unit tests
- Update main.swift with demo
- Run tests
- Create PR

**Verify**:
```bash
cd ~/code/fw/daemon
swift test  # Should see all tests passing

# Check PR was created
gh pr list
```

**Important**: Review the PR and merge it:
```bash
gh pr view 1  # Review changes
gh pr merge 1 --squash  # Merge after CI passes
```

### Continuing to Next Phases

For each subsequent phase, follow the same pattern:

```
Checkout main and pull latest.

Read ~/code/fw/prompts/phase-N-<component>.md

Implement the component following all instructions in the prompt.

Run tests and create a PR.
```

## 🔧 Using with OpenCode

OpenCode works similarly but with slightly different syntax:

```bash
# Start OpenCode in project directory
cd ~/code/fw
opencode
```

### Phase 0

```
Create a new project at ~/code/fw

Read the file ~/code/fw/prompts/phase-0-setup.md

Follow all instructions in that file to set up the AIFW repository structure.

Push the initial commit to github.com/jmspring/aifw
```

### Phase 1

```
Read ~/code/fw/prompts/aifw-shared-schemas.md to understand the data structures.

Read ~/code/fw/prompts/phase-1-policy.md

Implement the PolicyEngine component as described, including all tests.

Create a PR for phase-1-policy branch.
```

## 📋 General Workflow

### Step-by-Step Process

For each phase:

1. **Read the Master Prompt** (first time only)
   ```
   Read ~/code/fw/prompts/aifw-master-prompt.md to understand the overall architecture
   ```

2. **Read Shared Schemas** (first time only)
   ```
   Read ~/code/fw/prompts/aifw-shared-schemas.md to understand the interfaces
   ```

3. **Start the Phase**
   ```
   Read ~/code/fw/prompts/phase-N-<name>.md
   
   Follow all instructions in that file:
   - Create feature branch
   - Implement the component
   - Write tests
   - Update main.swift if needed
   - Run swift test
   - Create PR
   ```

4. **Verify Tests Pass**
   ```bash
   cd ~/code/fw/daemon
   swift test
   ```

5. **Review and Merge PR**
   ```bash
   gh pr view <number>
   gh pr checks  # Wait for CI to pass
   gh pr merge <number> --squash
   ```

6. **Move to Next Phase**
   ```bash
   git checkout main
   git pull
   ```

## 💡 Best Practices

### Working with AI Agents

**DO**:
- ✅ Let the AI read the entire prompt before starting
- ✅ Reference shared schemas when needed
- ✅ Ask the AI to run tests after implementation
- ✅ Have the AI create the PR with detailed description
- ✅ Review the code before merging

**DON'T**:
- ❌ Skip phases (they build on each other)
- ❌ Merge PRs without CI passing
- ❌ Skip writing tests
- ❌ Modify multiple components in one phase

### Code Review Checklist

Before merging each PR, verify:

- [ ] All tests pass locally (`swift test`)
- [ ] CI passes on GitHub Actions
- [ ] Code follows Swift conventions
- [ ] All public APIs have tests
- [ ] Documentation is clear
- [ ] No TODOs or FIXMEs left
- [ ] Commit message is descriptive

### Troubleshooting

**"Tests fail in CI but pass locally"**:
- Check Swift version matches (5.9+)
- Verify all files are committed
- Check file paths (case-sensitive in CI)

**"AI gets confused about what to do"**:
- Have it re-read the phase prompt
- Reference the specific section causing confusion
- Point it to shared schemas for interface definitions

**"Package doesn't build"**:
- Run `swift package clean`
- Delete `.build` directory
- Verify Package.swift syntax

**"PR creation fails"**:
- Check GitHub authentication: `gh auth status`
- Verify repository exists: `gh repo view jmspring/aifw`
- Ensure branch is pushed: `git push -u origin <branch>`

## 🎓 Example Session (Phase 0)

Here's a complete example of building Phase 0 with Claude Code:

```bash
# Terminal 1: Start Claude Code
cd ~/code/fw
claude

# Claude Code Session:
User: "Create a new directory ~/code/fw and initialize it as a git repository. 
       Read ~/code/fw/prompts/phase-0-setup.md and follow ALL instructions 
       in that file to set up the AIFW project structure."

Claude: [Creates directory, initializes git, creates all files...]

User: "Now verify the setup is correct by running the verification steps 
       in the phase-0-setup.md file."

Claude: [Runs tree, swift package describe, swift build, swift run...]

User: "Everything looks good. Commit the changes and push to GitHub."

Claude: [Creates commit, pushes to GitHub...]

User: "Check that GitHub Actions CI is set up correctly."

Claude: [Verifies workflow file, checks GitHub Actions page...]
```

At this point, you have:
- ✅ Repository created
- ✅ Structure established  
- ✅ CI configured
- ✅ Initial commit pushed

Now move to Phase 1!

## 🎓 Example Session (Phase 1)

```bash
# Still in Claude Code:

User: "Checkout the main branch and pull latest changes. 
       Read ~/code/fw/prompts/aifw-shared-schemas.md to understand 
       the PolicyEngine interfaces."

Claude: [Reads schemas document...]

User: "Now read ~/code/fw/prompts/phase-1-policy.md and implement 
       the PolicyEngine component exactly as described, including all tests."

Claude: [Creates branch, implements PolicyEngine, writes tests...]

User: "Run swift test to verify all tests pass."

Claude: [Runs tests, reports results...]

User: "All tests passed! Now create a PR following the instructions in 
       phase-1-policy.md"

Claude: [Creates commit, pushes branch, creates PR...]

User: "Show me the PR details."

Claude: [Displays PR URL and description...]

# Terminal 2: Review and merge
gh pr view 1
gh pr checks  # Wait for CI
gh pr merge 1 --squash

# Back to Claude Code
User: "The PR has been merged. Update to main branch and show me 
       that PolicyEngine is working."

Claude: [Checks out main, pulls, runs demo...]
```

## 📊 Progress Tracking

### Recommended Approach

Create a checklist in your project:

```markdown
## AIFW Build Progress

- [x] Phase 0: Repository Setup
  - Completed: 2025-01-27
  - PR: #1
  - Tag: v0.1.0-phase0
  
- [x] Phase 1: Policy Engine  
  - Completed: 2025-01-27
  - PR: #2
  - Tag: v0.1.0-phase1
  - Tests: 25/25 passing

- [ ] Phase 2: Activity Logger
  - Started: TBD
  
- [ ] Phase 3: Process Tracker
- [ ] Phase 4: User Prompt
- [ ] Phase 5: Event Handlers
- [ ] Phase 6: Firewall Monitor
- [ ] Phase 7: Dashboard
```

### Tagging Releases

After each phase:
```bash
git tag v0.1.0-phase1 -m "Phase 1: PolicyEngine complete"
git push --tags
```

## 🔄 Iterating on a Phase

If you need to make changes after a phase is merged:

```bash
# Create fix branch
git checkout -b fix-phase1-issue

# Make changes
# Run tests
swift test

# Create PR
git commit -am "Fix issue in PolicyEngine"
git push -u origin fix-phase1-issue
gh pr create --base main --title "Fix: PolicyEngine issue"
```

## 🎯 Success Criteria

After completing all phases, you should have:

- ✅ Complete Swift package that builds
- ✅ All tests passing (100+ tests total)
- ✅ Working daemon that monitors processes
- ✅ SQLite database logging all activity
- ✅ Policy-based decision making
- ✅ User prompt system
- ✅ GitHub repository with full history
- ✅ CI/CD pipeline running
- ✅ Comprehensive documentation

## 📚 Phase Summary Reference

Quick reference for what each phase delivers:

| Phase | Component | Key Files | Tests | Duration |
|-------|-----------|-----------|-------|----------|
| 0 | Setup | README, Package.swift | - | 30min |
| 1 | PolicyEngine | Policy.swift, PolicyEngine.swift | 25+ | 1-2hr |
| 2 | ActivityLogger | ActivityLogger.swift | 15+ | 1-2hr |
| 3 | ProcessTracker | ProcessTracker.swift | 10+ | 1hr |
| 4 | UserPrompt | UserPrompt.swift | 8+ | 1hr |
| 5 | EventHandlers | EventHandlers.swift | 20+ | 2-3hr |
| 6 | FirewallMonitor | FirewallMonitor.swift | 15+ | 2-3hr |
| 7 | Dashboard | ContentView.swift, etc. | 10+ | 3-4hr |

**Total Estimated Time**: 12-18 hours spread across 1-2 weeks

## 🎬 Getting Started Now

Ready to begin? Here's your first command:

### For Claude Code:
```bash
cd ~/code/fw
claude

# Then say:
"Read ~/code/fw/prompts/phase-0-setup.md and set up the AIFW repository 
at github.com/jmspring/aifw following all instructions."
```

### For OpenCode:
```bash
cd ~/code/fw  
opencode

# Then say:
"Read ~/code/fw/prompts/phase-0-setup.md and implement everything described 
to create the AIFW repository structure."
```

## 🆘 Getting Help

**If you get stuck**:

1. **Re-read the phase prompt** - Most issues are addressed in the detailed instructions
2. **Check shared schemas** - For interface definitions and data structures
3. **Review the master prompt** - For overall architecture context
4. **Check troubleshooting section** - Common issues and solutions
5. **Ask the AI to explain** - "Explain what you're doing in this step"

**Common Questions**:

**Q: Can I skip phases?**  
A: No - each phase builds on previous ones. They must be done in order.

**Q: Can I work on multiple phases at once?**  
A: Not recommended - keep PRs focused. Finish and merge one phase before starting the next.

**Q: What if tests fail?**  
A: Have the AI fix them. Don't merge until all tests pass.

**Q: Do I need to review every line of code?**  
A: Yes, especially for security-critical components. This is a system-level security tool.

**Q: Can I modify the prompts?**  
A: Yes! They're templates. Adapt them to your needs.

## 📖 Additional Resources

- **Swift Documentation**: https://swift.org/documentation/
- **Endpoint Security**: https://developer.apple.com/documentation/endpointsecurity
- **SQLite3**: https://www.sqlite.org/docs.html
- **SwiftUI**: https://developer.apple.com/documentation/swiftui
- **GitHub CLI**: https://cli.github.com/manual/

## 🎉 Completion

When all phases are complete:

1. **Test the full system**:
   ```bash
   cd ~/code/fw/daemon
   swift build -c release
   
   # Test with a target process
   sleep 1000 &
   TARGET_PID=$!
   sudo .build/release/aifw-daemon $TARGET_PID
   ```

2. **Write final documentation**
3. **Create release**: `gh release create v1.0.0`
4. **Share with community**

You now have a complete, working AI firewall system! 🎊

---

**Happy Building!** 🚀

If you have questions or improvements to these prompts, please open an issue or PR in the prompts repository.
