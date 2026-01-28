//
// main.swift
// aifw-daemon
//

import Foundation
import AIFW

print("AIFW Daemon v0.1.0")
print("Phase 4: User Prompt System\n")

// Test with mock (no user interaction needed)
print("Testing with Mock Prompts:\n")

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
print("\nMock Prompt Statistics:")
print("   Total prompts: \(mockPrompt.promptCount)")
print("   Was prompted: \(mockPrompt.wasPrompted)")
if let last = mockPrompt.lastPrompt {
    print("   Last prompt title: \(last.title)")
}

print("\nUserPrompt system working correctly")
print("\nTo test real macOS dialogs:")
print("   Run: swift run test-prompt")
