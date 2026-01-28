# Phase 4: User Prompt System

**Branch**: `phase-4-prompt`  
**Prerequisites**: Phases 0-3 complete  
**Duration**: 1 hour  
**Focus**: macOS native dialog system for user decisions  

## Objective

Implement the UserPrompt component that displays native macOS dialogs when policy decisions require user approval. This provides the interactive layer between the firewall and the user.

## Context

**Review before starting**:
- [Shared Schemas](../aifw-shared-schemas.md#user-prompt-protocol) - UserPrompt interface
- [Master Prompt](../aifw-master-prompt.md#component-breakdown) - UserPrompt role

**What UserPrompt Does**:
- Shows native macOS dialogs via AppleScript
- Three-button interface: Deny / Allow Once / Allow Always
- Blocks until user responds
- Protocol-based for testing (mock implementation)

**What UserPrompt Does NOT Do**:
- Make policy decisions (that's PolicyEngine)
- Log activity (that's ActivityLogger)
- Interact with ES framework (that's Phase 6)

## Implementation

### 1. Create Feature Branch

```bash
git checkout main
git pull origin main
git checkout -b phase-4-prompt
```

### 2. Create Prompt Response Types

Create `daemon/Sources/AIFW/Prompt/PromptResponse.swift`:

```swift
//
// PromptResponse.swift
// AIFW
//
// User prompt response types
//

import Foundation

/// User's response to a prompt
public enum PromptResponse: Equatable {
    case deny
    case allowOnce
    case allowAlways
}
```

### 3. Create User Prompt Protocol

Create `daemon/Sources/AIFW/Prompt/UserPrompt.swift`:

```swift
//
// UserPrompt.swift
// AIFW
//
// Native macOS dialog system
//

import Foundation

/// Protocol for showing user prompts
public protocol UserPromptProtocol {
    func showPrompt(
        title: String,
        message: String,
        details: String
    ) -> PromptResponse
}

/// Real implementation using AppleScript
public class UserPrompt: UserPromptProtocol {
    public init() {}
    
    public func showPrompt(
        title: String,
        message: String,
        details: String
    ) -> PromptResponse {
        // Escape strings for AppleScript
        let escapedMessage = escapeForAppleScript(message)
        let escapedDetails = escapeForAppleScript(details)
        let escapedTitle = escapeForAppleScript(title)
        
        let script = """
        display dialog "\(escapedMessage)\\n\\n\(escapedDetails)\\n\\nAllow this action?" ¬
        buttons {"Deny", "Allow Once", "Allow Always"} ¬
        default button "Deny" ¬
        with title "\(escapedTitle)" ¬
        with icon caution
        """
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Suppress error output
        
        do {
            try task.run()
            task.waitUntilExit()
            
            // Check if user cancelled (exit code 1)
            guard task.terminationStatus == 0 else {
                return .deny
            }
            
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
            print("⚠️  Error showing prompt: \(error)")
        }
        
        // Default to deny on any error
        return .deny
    }
    
    private func escapeForAppleScript(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

/// Mock implementation for testing
public class MockUserPrompt: UserPromptProtocol {
    public var responseToReturn: PromptResponse = .deny
    public var promptHistory: [(title: String, message: String, details: String)] = []
    
    public init(defaultResponse: PromptResponse = .deny) {
        self.responseToReturn = defaultResponse
    }
    
    public func showPrompt(
        title: String,
        message: String,
        details: String
    ) -> PromptResponse {
        promptHistory.append((title, message, details))
        return responseToReturn
    }
    
    // Test helpers
    public var wasPrompted: Bool {
        return !promptHistory.isEmpty
    }
    
    public var promptCount: Int {
        return promptHistory.count
    }
    
    public var lastPrompt: (title: String, message: String, details: String)? {
        return promptHistory.last
    }
    
    public func reset() {
        promptHistory.removeAll()
        responseToReturn = .deny
    }
}
```

### 4. Create Comprehensive Tests

Create `daemon/Tests/AIFWTests/Prompt/UserPromptTests.swift`:

```swift
//
// UserPromptTests.swift
// AIFWTests
//
// Tests for user prompt system
//

import XCTest
@testable import AIFW

final class UserPromptTests: XCTestCase {
    
    // MARK: - Mock Prompt Tests
    
    func testMockPrompt_Deny_Default() {
        let mock = MockUserPrompt()
        
        let response = mock.showPrompt(
            title: "Test",
            message: "Test message",
            details: "Test details"
        )
        
        XCTAssertEqual(response, .deny)
        XCTAssertTrue(mock.wasPrompted)
        XCTAssertEqual(mock.promptCount, 1)
    }
    
    func testMockPrompt_AllowOnce() {
        let mock = MockUserPrompt(defaultResponse: .allowOnce)
        
        let response = mock.showPrompt(
            title: "Test",
            message: "Test message",
            details: "Test details"
        )
        
        XCTAssertEqual(response, .allowOnce)
    }
    
    func testMockPrompt_AllowAlways() {
        let mock = MockUserPrompt(defaultResponse: .allowAlways)
        
        let response = mock.showPrompt(
            title: "Test",
            message: "Test message",
            details: "Test details"
        )
        
        XCTAssertEqual(response, .allowAlways)
    }
    
    func testMockPrompt_CapturesHistory() {
        let mock = MockUserPrompt()
        
        mock.showPrompt(
            title: "Title 1",
            message: "Message 1",
            details: "Details 1"
        )
        
        mock.showPrompt(
            title: "Title 2",
            message: "Message 2",
            details: "Details 2"
        )
        
        XCTAssertEqual(mock.promptCount, 2)
        XCTAssertEqual(mock.promptHistory.count, 2)
        
        XCTAssertEqual(mock.promptHistory[0].title, "Title 1")
        XCTAssertEqual(mock.promptHistory[1].title, "Title 2")
    }
    
    func testMockPrompt_LastPrompt() {
        let mock = MockUserPrompt()
        
        XCTAssertNil(mock.lastPrompt)
        
        mock.showPrompt(
            title: "First",
            message: "Message 1",
            details: "Details 1"
        )
        
        mock.showPrompt(
            title: "Second",
            message: "Message 2",
            details: "Details 2"
        )
        
        XCTAssertEqual(mock.lastPrompt?.title, "Second")
        XCTAssertEqual(mock.lastPrompt?.message, "Message 2")
    }
    
    func testMockPrompt_Reset() {
        let mock = MockUserPrompt(defaultResponse: .allowOnce)
        
        mock.showPrompt(
            title: "Test",
            message: "Message",
            details: "Details"
        )
        
        XCTAssertEqual(mock.promptCount, 1)
        XCTAssertEqual(mock.responseToReturn, .allowOnce)
        
        mock.reset()
        
        XCTAssertEqual(mock.promptCount, 0)
        XCTAssertEqual(mock.responseToReturn, .deny)
        XCTAssertFalse(mock.wasPrompted)
    }
    
    func testMockPrompt_MultipleCallsWithDifferentResponses() {
        let mock = MockUserPrompt()
        
        // First call - deny
        mock.responseToReturn = .deny
        let response1 = mock.showPrompt(
            title: "Test 1",
            message: "Message",
            details: "Details"
        )
        
        // Second call - allow once
        mock.responseToReturn = .allowOnce
        let response2 = mock.showPrompt(
            title: "Test 2",
            message: "Message",
            details: "Details"
        )
        
        // Third call - allow always
        mock.responseToReturn = .allowAlways
        let response3 = mock.showPrompt(
            title: "Test 3",
            message: "Message",
            details: "Details"
        )
        
        XCTAssertEqual(response1, .deny)
        XCTAssertEqual(response2, .allowOnce)
        XCTAssertEqual(response3, .allowAlways)
        XCTAssertEqual(mock.promptCount, 3)
    }
    
    // MARK: - Protocol Tests
    
    func testPromptProtocol_WorksWithMock() {
        let prompt: UserPromptProtocol = MockUserPrompt(defaultResponse: .allowOnce)
        
        let response = prompt.showPrompt(
            title: "Test",
            message: "Message",
            details: "Details"
        )
        
        XCTAssertEqual(response, .allowOnce)
    }
    
    func testPromptProtocol_CanSwitchImplementations() {
        var prompt: UserPromptProtocol = MockUserPrompt(defaultResponse: .deny)
        
        let response1 = prompt.showPrompt(
            title: "Test",
            message: "Message",
            details: "Details"
        )
        XCTAssertEqual(response1, .deny)
        
        // Switch to different mock
        prompt = MockUserPrompt(defaultResponse: .allowAlways)
        
        let response2 = prompt.showPrompt(
            title: "Test",
            message: "Message",
            details: "Details"
        )
        XCTAssertEqual(response2, .allowAlways)
    }
    
    // MARK: - Real Prompt Tests (Commented - requires user interaction)
    
    /*
    // MANUAL TEST: Uncomment to test real macOS dialogs
    func testRealPrompt_ShowsDialog() {
        let prompt = UserPrompt()
        
        let response = prompt.showPrompt(
            title: "🛡️ AI Firewall Test",
            message: "This is a test of the user prompt system",
            details: "Please click any button to test.\n\nPath: /tmp/test.txt"
        )
        
        print("User response: \(response)")
        // Can't assert since it depends on user input
    }
    
    func testRealPrompt_SpecialCharacters() {
        let prompt = UserPrompt()
        
        let response = prompt.showPrompt(
            title: "Test \"Special\" Characters",
            message: "Message with\nnewlines and \"quotes\"",
            details: "Path: /Users/test/file's\\ path"
        )
        
        print("User response: \(response)")
    }
    */
}
```

### 5. Create Test Utility for Manual Testing

Create `daemon/Sources/test-prompt/main.swift`:

```swift
//
// main.swift
// test-prompt
//
// Manual test utility for user prompts
//

import Foundation
import AIFW

print("🛡️ AIFW User Prompt Test Utility")
print("=================================\n")

let prompt = UserPrompt()

// Test 1: File write to sensitive location
print("Test 1: Simulating file write to ~/.ssh/config")
let response1 = prompt.showPrompt(
    title: "🛡️ AI Firewall",
    message: "OpenCode wants to write to a sensitive file",
    details: "Path: ~/.ssh/config\n\nThis directory contains SSH keys and configurations."
)
print("Result: \(response1)\n")

// Test 2: Dangerous command
print("Test 2: Simulating dangerous command execution")
let response2 = prompt.showPrompt(
    title: "🛡️ AI Firewall",
    message: "OpenCode wants to execute a dangerous command",
    details: "Command: sudo rm -rf /tmp/important\n\n⚠️ This command could delete important files."
)
print("Result: \(response2)\n")

// Test 3: External network connection
print("Test 3: Simulating external API connection")
let response3 = prompt.showPrompt(
    title: "🛡️ AI Firewall",
    message: "OpenCode wants to connect to an external API",
    details: "Destination: api.openai.com:443\n\nThis will send data to external servers."
)
print("Result: \(response3)\n")

// Test 4: Special characters
print("Test 4: Testing special characters in prompts")
let response4 = prompt.showPrompt(
    title: "Test \"Quotes\" and 'Apostrophes'",
    message: "Testing special\ncharacters",
    details: "Path: /Users/test/file's\\path with \"quotes\""
)
print("Result: \(response4)\n")

print("✅ All tests complete")
print("\nNote: The actual response depends on which button you clicked.")
```

### 6. Update Package.swift

Add the test-prompt executable to `daemon/Package.swift`:

```swift
// Add to products array:
.executable(
    name: "test-prompt",
    targets: ["test-prompt"]
)

// Add to targets array:
.executableTarget(
    name: "test-prompt",
    dependencies: ["AIFW"],
    path: "Sources/test-prompt"
)
```

### 7. Update main.swift to Demonstrate

Update `daemon/Sources/aifw-daemon/main.swift`:

```swift
//
// main.swift
// aifw-daemon
//

import Foundation
import AIFW

print("AIFW Daemon v0.1.0")
print("Phase 4: User Prompt System\n")

// Test with mock (no user interaction needed)
print("📱 Testing with Mock Prompts:\n")

let mockPrompt = MockUserPrompt(defaultResponse: .allowOnce)

let response1 = mockPrompt.showPrompt(
    title: "AI Firewall",
    message: "Write to sensitive file?",
    details: "Path: ~/.ssh/config"
)
print("1. Mock response (Allow Once): \(response1)")

mockPrompt.responseToReturn = .deny
let response2 = mockPrompt.showPrompt(
    title: "AI Firewall",
    message: "Execute dangerous command?",
    details: "Command: sudo rm important_file"
)
print("2. Mock response (Deny): \(response2)")

mockPrompt.responseToReturn = .allowAlways
let response3 = mockPrompt.showPrompt(
    title: "AI Firewall",
    message: "Connect to external API?",
    details: "Destination: api.openai.com:443"
)
print("3. Mock response (Allow Always): \(response3)")

// Show mock statistics
print("\n📊 Mock Prompt Statistics:")
print("   Total prompts: \(mockPrompt.promptCount)")
print("   Was prompted: \(mockPrompt.wasPrompted)")
if let last = mockPrompt.lastPrompt {
    print("   Last prompt title: \(last.title)")
}

print("\n✅ UserPrompt system working correctly")
print("\n💡 To test real macOS dialogs:")
print("   Run: swift run test-prompt")
```

## Build and Test

```bash
cd daemon

# Build
swift build

# Run all tests
swift test

# Should see output like:
# Test Suite 'All tests' passed at ...
# Executed 10+ tests, with 0 failures

# Run main daemon (shows mock prompts)
swift run aifw-daemon

# Run manual test utility (shows REAL macOS dialogs)
swift run test-prompt

# Click different buttons to test all responses
```

## Create Pull Request

```bash
# Ensure all tests pass
swift test

# Commit changes
git add daemon/
git commit -m "Phase 4: Implement User Prompt System

Implement native macOS dialog system:
- PromptResponse enum (Deny/AllowOnce/AllowAlways)
- UserPrompt using AppleScript
- MockUserPrompt for testing
- 10+ comprehensive unit tests
- Manual test utility for real dialogs
- Protocol-based design for testability

Key Features:
✅ Native macOS dialogs via AppleScript
✅ Three-button interface
✅ Proper string escaping
✅ Mock implementation for tests
✅ Protocol for dependency injection
✅ Error handling (defaults to deny)
✅ Test utility for manual verification

Tests: All passing (10/10)
Manual Test: swift run test-prompt"

# Push branch
git push -u origin phase-4-prompt

# Create PR
gh pr create \
  --title "Phase 4: User Prompt System" \
  --body "Implements native macOS dialog system with comprehensive tests.

## Changes
- Add PromptResponse enum
- Implement UserPrompt with AppleScript
- Add MockUserPrompt for testing
- Add 10+ unit tests
- Create test-prompt utility
- Update main.swift with demonstration

## Testing
- All 10 unit tests passing
- Mock tests cover all response types
- Manual test utility available: \`swift run test-prompt\`
- Tested with special characters and edge cases

## Usage
\`\`\`swift
let prompt = UserPrompt()
let response = prompt.showPrompt(
    title: \"AI Firewall\",
    message: \"Allow this action?\",
    details: \"Path: ~/.ssh/config\"
)
\`\`\`

## Next Phase
Phase 5 will implement EventHandlers (ES event processing)" \
  --base main

# After CI passes and review, merge
gh pr merge phase-4-prompt --squash
```

## Success Criteria

✅ UserPrompt shows native macOS dialogs  
✅ Three-button interface works correctly  
✅ MockUserPrompt available for testing  
✅ Protocol-based design allows dependency injection  
✅ String escaping handles special characters  
✅ Error handling defaults to deny  
✅ 10+ unit tests all passing  
✅ Manual test utility works  
✅ Code builds without warnings  
✅ PR created, CI passes, merged to main  

## Next Steps

After Phase 4 is merged:
1. Tag release: `git tag v0.1.0-phase4 && git push --tags`
2. Proceed to **Phase 5: Event Handlers**

## Troubleshooting

**AppleScript dialogs don't appear**:
- Check System Preferences → Security & Privacy → Accessibility
- Ensure Terminal/IDE has permission to control the computer
- Try running from Terminal directly (not from IDE)

**Process.launchPath deprecated warning**:
- This is expected on macOS 13+
- Will be replaced with executableURL in production
- Works fine for development/testing

**Tests hang**:
- Ensure using MockUserPrompt in tests (not real UserPrompt)
- Real UserPrompt blocks waiting for user input
- Only use real prompts in manual test utility

**Escape sequences not working**:
- Verify escapeForAppleScript() handles all special characters
- Test with manual test utility
- Check AppleScript syntax in generated script
