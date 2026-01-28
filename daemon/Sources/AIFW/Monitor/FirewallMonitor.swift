//
// FirewallMonitor.swift
// AIFW
//
// Endpoint Security framework integration
//

import Foundation

#if canImport(EndpointSecurity)
import EndpointSecurity

public class FirewallMonitor {
    private var esClient: OpaquePointer?
    private let eventHandler: EventHandler
    private let processTracker: ProcessTrackerProtocol
    private var isRunning = false

    public init(eventHandler: EventHandler, processTracker: ProcessTrackerProtocol) {
        self.eventHandler = eventHandler
        self.processTracker = processTracker
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    public func start() throws {
        guard !isRunning else { return }

        print("Initializing Endpoint Security client...")

        // Create ES client
        let result = es_new_client(&esClient) { [weak self] client, message in
            guard let self = self else { return }
            self.handleMessage(client: client, message: message)
        }

        guard result == ES_NEW_CLIENT_RESULT_SUCCESS, let client = esClient else {
            let errorMessage: String
            switch result {
            case ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED:
                errorMessage = "Not entitled - missing com.apple.developer.endpoint-security.client"
            case ES_NEW_CLIENT_RESULT_ERR_NOT_PRIVILEGED:
                errorMessage = "Not privileged - must run as root"
            case ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED:
                errorMessage = "Not permitted - check Full Disk Access"
            case ES_NEW_CLIENT_RESULT_ERR_INVALID_ARGUMENT:
                errorMessage = "Invalid argument"
            case ES_NEW_CLIENT_RESULT_ERR_TOO_MANY_CLIENTS:
                errorMessage = "Too many ES clients running"
            case ES_NEW_CLIENT_RESULT_ERR_INTERNAL:
                errorMessage = "Internal error"
            default:
                errorMessage = "Unknown error: \(result.rawValue)"
            }
            throw NSError(domain: "AIFW", code: Int(result.rawValue),
                         userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        // Subscribe to events
        var events: [es_event_type_t] = [
            ES_EVENT_TYPE_AUTH_OPEN,      // File open/write
            ES_EVENT_TYPE_AUTH_UNLINK,    // File delete
            ES_EVENT_TYPE_AUTH_EXEC       // Process execution
        ]

        let subscribeResult = es_subscribe(client, &events, UInt32(events.count))
        guard subscribeResult == ES_RETURN_SUCCESS else {
            es_delete_client(client)
            esClient = nil
            throw NSError(domain: "AIFW", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to subscribe to events"])
        }

        isRunning = true
        print("Endpoint Security client started")
        print("Monitoring events for PID \(processTracker.rootPID)...")
    }

    public func stop() {
        guard isRunning, let client = esClient else { return }

        print("Stopping Endpoint Security client...")

        es_unsubscribe_all(client)
        es_delete_client(client)
        esClient = nil
        isRunning = false

        print("Endpoint Security client stopped")
    }

    // MARK: - Event Handling

    private func handleMessage(client: OpaquePointer, message: UnsafePointer<es_message_t>) {
        let event = message.pointee

        // Dispatch based on event type
        switch event.event_type {
        case ES_EVENT_TYPE_AUTH_OPEN:
            handleFileOpen(client: client, message: message)

        case ES_EVENT_TYPE_AUTH_UNLINK:
            handleFileDelete(client: client, message: message)

        case ES_EVENT_TYPE_AUTH_EXEC:
            handleExec(client: client, message: message)

        default:
            // Unknown event - allow by default
            es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false)
        }
    }

    private func handleFileOpen(client: OpaquePointer, message: UnsafePointer<es_message_t>) {
        let event = message.pointee
        let openEvent = event.event.open

        // Get file path
        guard let pathStr = stringFromToken(openEvent.file.pointee.path) else {
            es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false)
            return
        }

        // Check if write operation
        let isWrite = (openEvent.fflag & Int32(FWRITE)) != 0

        guard isWrite else {
            // Read-only access - allow
            es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false)
            return
        }

        // Get process info
        let process = event.process.pointee
        let pid = audit_token_to_pid(process.audit_token)
        let ppid = process.ppid

        let processPath = stringFromToken(process.executable.pointee.path)

        // Create event data
        let fileEvent = FileOperationEvent(
            pid: pid,
            ppid: ppid,
            processPath: processPath,
            filePath: pathStr,
            isWrite: true,
            isDelete: false
        )

        // Handle event
        let decision = eventHandler.handleFileOperation(fileEvent)

        // Respond to kernel
        let authResult: es_auth_result_t = (decision == .allow) ?
            ES_AUTH_RESULT_ALLOW : ES_AUTH_RESULT_DENY
        es_respond_auth_result(client, message, authResult, false)
    }

    private func handleFileDelete(client: OpaquePointer, message: UnsafePointer<es_message_t>) {
        let event = message.pointee
        let unlinkEvent = event.event.unlink

        // Get file path
        guard let pathStr = stringFromToken(unlinkEvent.target.pointee.path) else {
            es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false)
            return
        }

        // Get process info
        let process = event.process.pointee
        let pid = audit_token_to_pid(process.audit_token)
        let ppid = process.ppid
        let processPath = stringFromToken(process.executable.pointee.path)

        // Create event data
        let fileEvent = FileOperationEvent(
            pid: pid,
            ppid: ppid,
            processPath: processPath,
            filePath: pathStr,
            isWrite: false,
            isDelete: true
        )

        // Handle event
        let decision = eventHandler.handleFileOperation(fileEvent)

        // Respond to kernel
        let authResult: es_auth_result_t = (decision == .allow) ?
            ES_AUTH_RESULT_ALLOW : ES_AUTH_RESULT_DENY
        es_respond_auth_result(client, message, authResult, false)
    }

    private func handleExec(client: OpaquePointer, message: UnsafePointer<es_message_t>) {
        let event = message.pointee
        let execEvent = event.event.exec

        // Get executable path
        guard let execPath = stringFromToken(execEvent.target.pointee.executable.pointee.path) else {
            es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false)
            return
        }

        // Build command from executable path
        let command = execPath

        // Get process info
        let process = event.process.pointee
        let pid = audit_token_to_pid(process.audit_token)
        let ppid = process.ppid

        // Create event data
        let execEventData = ProcessExecutionEvent(
            pid: pid,
            ppid: ppid,
            executablePath: execPath,
            command: command
        )

        // Handle event
        let decision = eventHandler.handleProcessExecution(execEventData)

        // Respond to kernel
        let authResult: es_auth_result_t = (decision == .allow) ?
            ES_AUTH_RESULT_ALLOW : ES_AUTH_RESULT_DENY
        es_respond_auth_result(client, message, authResult, false)
    }

    // MARK: - Helpers

    private func stringFromToken(_ token: es_string_token_t) -> String? {
        guard token.length > 0, let data = token.data else { return nil }
        let buffer = UnsafeBufferPointer(start: data, count: Int(token.length))
        return String(decoding: buffer.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

#else

// Stub implementation when EndpointSecurity is not available
public class FirewallMonitor {
    private let eventHandler: EventHandler
    private let processTracker: ProcessTrackerProtocol

    public init(eventHandler: EventHandler, processTracker: ProcessTrackerProtocol) {
        self.eventHandler = eventHandler
        self.processTracker = processTracker
    }

    public func start() throws {
        print("Warning: EndpointSecurity framework not available")
        print("FirewallMonitor running in stub mode (no actual monitoring)")
        print("This is expected during development/testing without proper SDK")
    }

    public func stop() {
        print("FirewallMonitor stopped (stub mode)")
    }
}

#endif
