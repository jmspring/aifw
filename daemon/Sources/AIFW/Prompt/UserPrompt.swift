//
// UserPrompt.swift
// AIFW
//
// Native macOS dialog system
//

import Foundation

/// Protocol for showing user prompts
public protocol UserPromptProtocol {
    func showPrompt(
        title: String,
        message: String,
        details: String
    ) -> PromptResponse
}

/// Real implementation using AppleScript
public class UserPrompt: UserPromptProtocol {
    public init() {}

    public func showPrompt(
        title: String,
        message: String,
        details: String
    ) -> PromptResponse {
        // Escape strings for AppleScript
        let escapedMessage = escapeForAppleScript(message)
        let escapedDetails = escapeForAppleScript(details)
        let escapedTitle = escapeForAppleScript(title)

        let script = """
        display dialog "\(escapedMessage)\\n\\n\(escapedDetails)\\n\\nAllow this action?" \
        buttons {"Deny", "Allow Once", "Allow Always"} \
        default button "Deny" \
        with title "\(escapedTitle)" \
        with icon caution
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Suppress error output

        do {
            try task.run()
            task.waitUntilExit()

            // Check if user cancelled (exit code 1)
            guard task.terminationStatus == 0 else {
                return .deny
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                if output.contains("Allow Always") {
                    return .allowAlways
                } else if output.contains("Allow Once") {
                    return .allowOnce
                } else {
                    return .deny
                }
            }
        } catch {
            print("Error showing prompt: \(error)")
        }

        // Default to deny on any error
        return .deny
    }

    private func escapeForAppleScript(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

/// Mock implementation for testing
public class MockUserPrompt: UserPromptProtocol {
    public var responseToReturn: PromptResponse = .deny
    public var promptHistory: [(title: String, message: String, details: String)] = []

    public init(defaultResponse: PromptResponse = .deny) {
        self.responseToReturn = defaultResponse
    }

    public func showPrompt(
        title: String,
        message: String,
        details: String
    ) -> PromptResponse {
        promptHistory.append((title, message, details))
        return responseToReturn
    }

    // Test helpers
    public var wasPrompted: Bool {
        return !promptHistory.isEmpty
    }

    public var promptCount: Int {
        return promptHistory.count
    }

    public var lastPrompt: (title: String, message: String, details: String)? {
        return promptHistory.last
    }

    public func reset() {
        promptHistory.removeAll()
        responseToReturn = .deny
    }
}
