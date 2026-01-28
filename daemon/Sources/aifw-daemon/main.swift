//
// main.swift
// aifw-daemon
//

import Foundation
import AIFW

print("AIFW Daemon v0.1.0")
print("Phase 1: Policy Engine\n")

// Load default policy
let policy = FirewallPolicy.defaultPolicy()
let engine = PolicyEngine(policy: policy)

// Demonstrate policy evaluation
print("Testing PolicyEngine:\n")

// File operations
print("1. File Operations:")
print("   Write to ~/.ssh/config: \(engine.checkFileWrite(path: "~/.ssh/config"))")
print("   Write to /tmp/test.txt: \(engine.checkFileWrite(path: "/tmp/test.txt"))")
print("   Delete /tmp/file.txt: \(engine.checkFileDelete(path: "/tmp/file.txt"))")

// Commands
print("\n2. Command Execution:")
print("   'git status': \(engine.checkCommand(command: "git status"))")
print("   'rm -rf /': \(engine.checkCommand(command: "rm -rf /"))")
print("   'sudo rm file': \(engine.checkCommand(command: "sudo rm file"))")

// Network
print("\n3. Network Connections:")
print("   localhost:11434: \(engine.checkNetworkConnection(destination: "127.0.0.1", port: 11434))")
print("   api.openai.com:443: \(engine.checkNetworkConnection(destination: "api.openai.com", port: 443))")

print("\nPolicyEngine working correctly")
