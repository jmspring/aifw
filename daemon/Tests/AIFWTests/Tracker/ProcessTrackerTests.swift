//
// ProcessTrackerTests.swift
// AIFWTests
//
// Tests for process tracker
//

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
        XCTAssertTrue(path!.contains("xctest") || path!.contains("swift") || path!.contains("Test"))
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

    func testRootPID_IsSet() {
        let currentPID = getpid()
        let tracker = ProcessTracker(rootPID: currentPID)

        XCTAssertEqual(tracker.rootPID, currentPID)
    }

    func testGetProcessPath_InvalidPID_ReturnsNil() {
        let tracker = ProcessTracker(rootPID: getpid())

        let path = tracker.getProcessPath(999999)
        XCTAssertNil(path)
    }
}
