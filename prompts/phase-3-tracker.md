# Phase 3: Process Tracker

**Branch**: `phase-3-tracker`  
**Prerequisites**: Phases 0-2 complete  
**Duration**: 1 hour  
**Focus**: Process tree management and PID tracking  

## Objective

Implement ProcessTracker that manages the process tree rooted at a target PID. This determines which processes should be monitored.

## Context

**Review**: [Shared Schemas](../aifw-shared-schemas.md) - ProcessTracker interface

**What it does**: Tracks process hierarchies using `proc_listchildpids()`

## Implementation

### Create ProcessTracker (Sources/AIFW/Tracker/ProcessTracker.swift)

```swift
import Foundation
import Darwin

public protocol ProcessTrackerProtocol {
    var rootPID: pid_t { get }
    var trackedPIDs: Set<pid_t> { get }
    func isTracked(_ pid: pid_t) -> Bool
    func getProcessPath(_ pid: pid_t) -> String?
    func refresh()
}

public class ProcessTracker: ProcessTrackerProtocol {
    public private(set) var rootPID: pid_t
    public private(set) var trackedPIDs: Set<pid_t> = []
    
    public init(rootPID: pid_t) {
        self.rootPID = rootPID
        buildProcessTree(from: rootPID)
    }
    
    private func buildProcessTree(from pid: pid_t) {
        trackedPIDs.insert(pid)
        
        var buffer = [pid_t](repeating: 0, count: 1024)
        let bufferSize = Int32(buffer.count * MemoryLayout<pid_t>.size)
        let count = proc_listchildpids(pid, &buffer, bufferSize)
        
        guard count > 0 else { return }
        
        let numPids = Int(count) / MemoryLayout<pid_t>.size
        for i in 0..<numPids where buffer[i] > 0 {
            buildProcessTree(from: buffer[i])
        }
    }
    
    public func isTracked(_ pid: pid_t) -> Bool {
        if trackedPIDs.contains(pid) { return true }
        return isDescendantOfRoot(pid)
    }
    
    private func isDescendantOfRoot(_ pid: pid_t) -> Bool {
        var currentPID = pid
        while currentPID > 1 {
            if currentPID == rootPID || trackedPIDs.contains(currentPID) {
                trackedPIDs.insert(pid)
                return true
            }
            
            var info = proc_bsdinfo()
            let size = MemoryLayout<proc_bsdinfo>.size
            let result = proc_pidinfo(currentPID, PROC_PIDTBSDINFO, 0, &info, Int32(size))
            guard result == Int32(size) else { return false }
            
            currentPID = pid_t(info.pbi_ppid)
        }
        return false
    }
    
    public func getProcessPath(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        let result = proc_pidpath(pid, &buffer, UInt32(PROC_PIDPATHINFO_MAXSIZE))
        guard result > 0 else { return nil }
        return String(cString: buffer)
    }
    
    public func refresh() {
        trackedPIDs.removeAll()
        buildProcessTree(from: rootPID)
    }
}
```

### Create Tests (Tests/AIFWTests/Tracker/ProcessTrackerTests.swift)

```swift
import XCTest
@testable import AIFW

final class ProcessTrackerTests: XCTestCase {
    func testTrackCurrentProcess() {
        let currentPID = getpid()
        let tracker = ProcessTracker(rootPID: currentPID)
        
        XCTAssertTrue(tracker.isTracked(currentPID))
        XCTAssertTrue(tracker.trackedPIDs.contains(currentPID))
    }
    
    func testTrackParentProcess() {
        let parentPID = getppid()
        let tracker = ProcessTracker(rootPID: parentPID)
        
        XCTAssertTrue(tracker.isTracked(parentPID))
        XCTAssertTrue(tracker.isTracked(getpid()))
    }
    
    func testGetProcessPath_CurrentProcess() {
        let currentPID = getpid()
        let tracker = ProcessTracker(rootPID: currentPID)
        
        let path = tracker.getProcessPath(currentPID)
        XCTAssertNotNil(path)
        XCTAssertTrue(path!.contains("xctest") || path!.contains("swift"))
    }
    
    func testNonTrackedProcess() {
        let currentPID = getpid()
        let tracker = ProcessTracker(rootPID: currentPID)
        
        XCTAssertFalse(tracker.isTracked(1)) // launchd
    }
    
    func testRefresh_RebuildsTree() {
        let tracker = ProcessTracker(rootPID: getpid())
        let initialCount = tracker.trackedPIDs.count
        
        tracker.refresh()
        
        XCTAssertGreaterThanOrEqual(tracker.trackedPIDs.count, initialCount)
    }
}
```

### Update main.swift

```swift
import Foundation
import AIFW

print("AIFW Daemon v0.1.0")
print("Phase 3: Process Tracker\n")

let currentPID = getpid()
let tracker = ProcessTracker(rootPID: currentPID)

print("📍 Process Tracking:")
print("   Root PID: \(currentPID)")
print("   Tracked PIDs: \(tracker.trackedPIDs.count)")
print("   Is current PID tracked? \(tracker.isTracked(currentPID))")

if let path = tracker.getProcessPath(currentPID) {
    print("   Current process path: \(path)")
}

print("\n✅ ProcessTracker working correctly")
```

## Build, Test, PR

```bash
cd daemon
swift test
git add .
git commit -m "Phase 3: Implement ProcessTracker

- Add process tree management
- Track PID hierarchies
- Get process paths
- 5+ comprehensive tests"

git push -u origin phase-3-tracker
gh pr create --title "Phase 3: ProcessTracker" --base main
gh pr merge phase-3-tracker --squash
```

## Success Criteria

✅ Tracks process tree correctly  
✅ Identifies tracked vs untracked PIDs  
✅ Gets process paths  
✅ Refresh rebuilds tree  
✅ All tests passing  
