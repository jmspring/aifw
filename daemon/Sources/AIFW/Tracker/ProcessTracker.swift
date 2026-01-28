//
// ProcessTracker.swift
// AIFW
//
// Process tree management and PID tracking
//

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
        // PROC_PIDPATHINFO_MAXSIZE = 4 * MAXPATHLEN = 4 * 1024 = 4096
        let maxPathSize = 4096
        var buffer = [CChar](repeating: 0, count: maxPathSize)
        let result = proc_pidpath(pid, &buffer, UInt32(maxPathSize))
        guard result > 0 else { return nil }
        return String(cString: buffer)
    }

    public func refresh() {
        trackedPIDs.removeAll()
        buildProcessTree(from: rootPID)
    }
}
