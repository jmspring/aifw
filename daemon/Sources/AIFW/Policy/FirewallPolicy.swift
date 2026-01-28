//
// FirewallPolicy.swift
// AIFW
//
// Policy data structures and loading
//

import Foundation

public struct FirewallPolicy: Codable {
    public let version: String
    public let sensitivePaths: [String]
    public let blockedCommands: [String]
    public let dangerousPatterns: [String]
    public let requireApproval: RequireApproval
    public let autoAllowPatterns: [String]
    public let allowedNetworkDestinations: [String]
    public let monitorOllamaRequests: Bool

    public struct RequireApproval: Codable {
        public let fileDelete: Bool
        public let fileWriteSensitive: Bool
        public let bashDangerous: Bool
        public let networkExternal: Bool
    }

    /// Load policy from JSON file
    public static func load(from path: String) throws -> FirewallPolicy {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw AIFWError.policyLoadFailed(
                path: path,
                underlying: NSError(domain: "AIFW", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found"])
            )
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        do {
            return try decoder.decode(FirewallPolicy.self, from: data)
        } catch {
            throw AIFWError.policyLoadFailed(path: path, underlying: error)
        }
    }

    /// Default policy for when no config file exists
    public static func defaultPolicy() -> FirewallPolicy {
        return FirewallPolicy(
            version: "1.0",
            sensitivePaths: [
                "~/.ssh",
                "~/.aws",
                "~/.config",
                "/etc",
                "/System",
                "/Library/Keychains"
            ],
            blockedCommands: [
                "rm -rf /",
                "mkfs",
                "dd if=/dev/zero",
                ":(){:|:&};:"  // fork bomb
            ],
            dangerousPatterns: [
                "sudo rm",
                "chmod 777",
                "| sh",
                "| bash",
                "> /dev/"
            ],
            requireApproval: RequireApproval(
                fileDelete: true,
                fileWriteSensitive: true,
                bashDangerous: true,
                networkExternal: true
            ),
            autoAllowPatterns: [
                "git status",
                "git diff",
                "git log",
                "ls ",
                "cat ",
                "grep ",
                "find ",
                "pwd",
                "which "
            ],
            allowedNetworkDestinations: [
                "localhost:11434",
                "127.0.0.1:11434",
                "::1:11434"
            ],
            monitorOllamaRequests: true
        )
    }
}

/// Policy decision types
public enum PolicyDecision: Equatable {
    case allow(reason: String)
    case deny(reason: String)
    case prompt(reason: String)
}

/// AIFW-specific errors
public enum AIFWError: Error, CustomStringConvertible {
    case policyLoadFailed(path: String, underlying: Error)
    case policyInvalid(reason: String)

    public var description: String {
        switch self {
        case .policyLoadFailed(let path, let error):
            return "Failed to load policy from \(path): \(error.localizedDescription)"
        case .policyInvalid(let reason):
            return "Invalid policy: \(reason)"
        }
    }
}
