//
// main.swift
// test-prompt
//
// Manual test utility for user prompts
//

import Foundation
import AIFW

print("AIFW User Prompt Test Utility")
print("=================================\n")

let prompt = UserPrompt()

// Test 1: File write to sensitive location
print("Test 1: Simulating file write to ~/.ssh/config")
let response1 = prompt.showPrompt(
    title: "AI Firewall",
    message: "OpenCode wants to write to a sensitive file",
    details: "Path: ~/.ssh/config\n\nThis directory contains SSH keys and configurations."
)
print("Result: \(response1)\n")

// Test 2: Dangerous command
print("Test 2: Simulating dangerous command execution")
let response2 = prompt.showPrompt(
    title: "AI Firewall",
    message: "OpenCode wants to execute a dangerous command",
    details: "Command: sudo rm -rf /tmp/important\n\nThis command could delete important files."
)
print("Result: \(response2)\n")

// Test 3: External network connection
print("Test 3: Simulating external API connection")
let response3 = prompt.showPrompt(
    title: "AI Firewall",
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

print("All tests complete")
print("\nNote: The actual response depends on which button you clicked.")
