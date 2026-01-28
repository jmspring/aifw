//
// main.swift
// aifw-daemon
//

import Foundation
import AIFW

print("AIFW Daemon v0.1.0")
print("Phase 6: Firewall Monitor (Endpoint Security)\n")

// Check for root
guard getuid() == 0 else {
    print("Error: This daemon requires root privileges")
    print("   Run with: sudo \(CommandLine.arguments[0]) <target-pid>")
    exit(1)
}

// Check for target PID argument
guard CommandLine.arguments.count > 1,
      let targetPID = Int32(CommandLine.arguments[1]) else {
    print("Error: Usage: sudo \(CommandLine.arguments[0]) <target-pid>")
    print("\nExample:")
    print("  # Start target process")
    print("  opencode &")
    print("  TARGET_PID=$!")
    print("  ")
    print("  # Start firewall")
    print("  sudo \(CommandLine.arguments[0]) $TARGET_PID")
    exit(1)
}

print("Target PID: \(targetPID)")

// Initialize components
let policy = FirewallPolicy.defaultPolicy()
let policyEngine = PolicyEngine(policy: policy)

let dbPath = NSHomeDirectory() + "/.config/aifw/activity.db"
let logger = ActivityLogger(dbPath: dbPath)

let tracker = ProcessTracker(rootPID: targetPID)
print("Tracking \(tracker.trackedPIDs.count) process(es)")

let prompt = UserPrompt() // Real prompts!

let eventHandler = EventHandler(
    policyEngine: policyEngine,
    activityLogger: logger,
    processTracker: tracker,
    userPrompt: prompt
)

// Create and start monitor
let monitor = FirewallMonitor(
    eventHandler: eventHandler,
    processTracker: tracker
)

do {
    try monitor.start()

    print("\nAIFW is now monitoring PID \(targetPID)")
    print("Press Ctrl+C to stop\n")

    // Set up signal handler
    signal(SIGINT) { _ in
        print("\n\nStopping AIFW...")
        exit(0)
    }

    // Run loop
    RunLoop.main.run()

} catch {
    print("Error: Failed to start monitor: \(error.localizedDescription)")
    exit(1)
}
