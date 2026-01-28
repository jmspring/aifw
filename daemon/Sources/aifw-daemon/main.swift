//
// main.swift
// aifw-daemon
//

import Foundation
import AIFW

print("AIFW Daemon v0.1.0")
print("Phase 3: Process Tracker\n")

let currentPID = getpid()
let tracker = ProcessTracker(rootPID: currentPID)

print("Process Tracking:")
print("   Root PID: \(currentPID)")
print("   Tracked PIDs: \(tracker.trackedPIDs.count)")
print("   Is current PID tracked? \(tracker.isTracked(currentPID))")

if let path = tracker.getProcessPath(currentPID) {
    print("   Current process path: \(path)")
}

print("\nProcessTracker working correctly")
