//
// PolicyEngine.swift
// AIFW
//
// Evaluates operations against policy rules
//

import Foundation

/// Protocol for policy evaluation
public protocol PolicyEngineProtocol {
    func checkFileRead(path: String) -> PolicyDecision
    func checkFileWrite(path: String) -> PolicyDecision
    func checkFileDelete(path: String) -> PolicyDecision
    func checkCommand(command: String) -> PolicyDecision
    func checkNetworkConnection(destination: String, port: UInt16) -> PolicyDecision
}

/// Policy engine implementation
public class PolicyEngine: PolicyEngineProtocol {
    private let policy: FirewallPolicy

    public init(policy: FirewallPolicy) {
        self.policy = policy
    }

    /// Convenience initializer that loads from file
    public convenience init(policyPath: String) throws {
        let policy = try FirewallPolicy.load(from: policyPath)
        self.init(policy: policy)
    }

    // MARK: - File Operations

    public func checkFileRead(path: String) -> PolicyDecision {
        // Currently always allow reads
        // Could add policy for sensitive file reads in the future
        return .allow(reason: "file reads always allowed")
    }

    public func checkFileWrite(path: String) -> PolicyDecision {
        let expandedPath = NSString(string: path).expandingTildeInPath

        // Check if path is in sensitive directories
        for sensitivePath in policy.sensitivePaths {
            let expandedSensitive = NSString(string: sensitivePath).expandingTildeInPath

            if expandedPath.hasPrefix(expandedSensitive) {
                if policy.requireApproval.fileWriteSensitive {
                    return .prompt(reason: "write to sensitive directory: \(sensitivePath)")
                } else {
                    return .deny(reason: "sensitive directory write blocked: \(sensitivePath)")
                }
            }
        }

        return .allow(reason: "write to non-sensitive location")
    }

    public func checkFileDelete(path: String) -> PolicyDecision {
        if policy.requireApproval.fileDelete {
            return .prompt(reason: "file deletion requires approval")
        }
        return .allow(reason: "file deletion allowed by policy")
    }

    // MARK: - Command Execution

    public func checkCommand(command: String) -> PolicyDecision {
        // Check auto-allow patterns first (most common case)
        for pattern in policy.autoAllowPatterns {
            if command.hasPrefix(pattern) {
                return .allow(reason: "matches auto-allow pattern: \(pattern)")
            }
        }

        // Check blocked commands (should never run)
        for blocked in policy.blockedCommands {
            if command.contains(blocked) {
                return .deny(reason: "blocked command pattern: \(blocked)")
            }
        }

        // Check dangerous patterns (require user approval)
        for pattern in policy.dangerousPatterns {
            if command.contains(pattern) {
                if policy.requireApproval.bashDangerous {
                    return .prompt(reason: "dangerous pattern detected: \(pattern)")
                } else {
                    return .deny(reason: "dangerous pattern blocked: \(pattern)")
                }
            }
        }

        // Unknown command - safe by default
        return .allow(reason: "command appears safe")
    }

    // MARK: - Network Connections

    public func checkNetworkConnection(destination: String, port: UInt16) -> PolicyDecision {
        let connectionString = "\(destination):\(port)"

        // Check if localhost
        let localhostAddresses = ["127.0.0.1", "::1", "localhost"]
        if localhostAddresses.contains(destination) {
            return .allow(reason: "localhost connection")
        }

        // Check allowed destinations
        for allowed in policy.allowedNetworkDestinations {
            if connectionString == allowed || destination == allowed {
                return .allow(reason: "allowed network destination: \(allowed)")
            }
        }

        // External connection
        if policy.requireApproval.networkExternal {
            return .prompt(reason: "external network connection")
        }

        return .allow(reason: "external connections allowed by policy")
    }
}
