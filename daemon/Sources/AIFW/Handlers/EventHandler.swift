//
// EventHandler.swift
// AIFW
//
// Coordinates components to handle events
//

import Foundation

public class EventHandler {
    private let policyEngine: PolicyEngineProtocol
    private let activityLogger: ActivityLoggerProtocol
    private let processTracker: ProcessTrackerProtocol
    private let userPrompt: UserPromptProtocol

    public init(
        policyEngine: PolicyEngineProtocol,
        activityLogger: ActivityLoggerProtocol,
        processTracker: ProcessTrackerProtocol,
        userPrompt: UserPromptProtocol
    ) {
        self.policyEngine = policyEngine
        self.activityLogger = activityLogger
        self.processTracker = processTracker
        self.userPrompt = userPrompt
    }

    // MARK: - File Operations

    public func handleFileOperation(_ event: FileOperationEvent) -> HandlerDecision {
        // Check if we should monitor this process
        guard processTracker.isTracked(event.pid) else {
            return .allow // Not our process
        }

        // Determine event type and get policy decision
        let eventType: String
        let policyDecision: PolicyDecision

        if event.isDelete {
            eventType = EventType.fileDelete
            policyDecision = policyEngine.checkFileDelete(path: event.filePath)
        } else if event.isWrite {
            eventType = EventType.fileWrite
            policyDecision = policyEngine.checkFileWrite(path: event.filePath)
        } else {
            eventType = EventType.fileRead
            policyDecision = policyEngine.checkFileRead(path: event.filePath)
        }

        // Make final decision
        let (allowed, reason) = evaluateDecision(
            policyDecision,
            promptTitle: "AI Firewall",
            promptMessage: event.isDelete ? "Delete file?" : "Write to file?",
            promptDetails: "Path: \(event.filePath)"
        )

        // Log activity
        activityLogger.log(
            eventType: eventType,
            processName: event.processPath,
            pid: event.pid,
            ppid: event.ppid,
            path: event.filePath,
            command: nil,
            destination: nil,
            allowed: allowed,
            reason: reason
        )

        return allowed ? .allow : .deny
    }

    // MARK: - Process Execution

    public func handleProcessExecution(_ event: ProcessExecutionEvent) -> HandlerDecision {
        // Check if we should monitor this process
        guard processTracker.isTracked(event.pid) else {
            return .allow // Not our process
        }

        // Get policy decision
        let policyDecision = policyEngine.checkCommand(command: event.command)

        // Make final decision
        let (allowed, reason) = evaluateDecision(
            policyDecision,
            promptTitle: "AI Firewall",
            promptMessage: "Execute command?",
            promptDetails: "Command: \(event.command)"
        )

        // Log activity
        activityLogger.log(
            eventType: EventType.processExec,
            processName: event.executablePath,
            pid: event.pid,
            ppid: event.ppid,
            path: event.executablePath,
            command: event.command,
            destination: nil,
            allowed: allowed,
            reason: reason
        )

        return allowed ? .allow : .deny
    }

    // MARK: - Network Connections

    public func handleNetworkConnection(_ event: NetworkConnectionEvent) -> HandlerDecision {
        // Check if we should monitor this process
        guard processTracker.isTracked(event.pid) else {
            return .allow // Not our process
        }

        // Get policy decision
        let policyDecision = policyEngine.checkNetworkConnection(
            destination: event.destination,
            port: event.port
        )

        let connectionString = "\(event.destination):\(event.port)"

        // Make final decision
        let (allowed, reason) = evaluateDecision(
            policyDecision,
            promptTitle: "AI Firewall",
            promptMessage: "Network connection?",
            promptDetails: "Destination: \(connectionString)"
        )

        // Log activity
        activityLogger.log(
            eventType: EventType.networkConnect,
            processName: event.processPath,
            pid: event.pid,
            ppid: event.ppid,
            path: nil,
            command: nil,
            destination: connectionString,
            allowed: allowed,
            reason: reason
        )

        return allowed ? .allow : .deny
    }

    // MARK: - Private Helpers

    private func evaluateDecision(
        _ decision: PolicyDecision,
        promptTitle: String,
        promptMessage: String,
        promptDetails: String
    ) -> (allowed: Bool, reason: String) {
        switch decision {
        case .allow(let reason):
            return (true, reason)

        case .deny(let reason):
            return (false, reason)

        case .prompt(let policyReason):
            let response = userPrompt.showPrompt(
                title: promptTitle,
                message: promptMessage,
                details: promptDetails
            )

            switch response {
            case .deny:
                return (false, "user denied: \(policyReason)")
            case .allowOnce:
                return (true, "user approved (once): \(policyReason)")
            case .allowAlways:
                return (true, "user approved (always): \(policyReason)")
            }
        }
    }
}
