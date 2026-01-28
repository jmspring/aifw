//
// PolicyEngineTests.swift
// AIFWTests
//
// Tests for policy engine
//

import XCTest
@testable import AIFW

final class PolicyEngineTests: XCTestCase {
    var engine: PolicyEngine!

    override func setUp() {
        super.setUp()
        engine = PolicyEngine(policy: FirewallPolicy.defaultPolicy())
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - File Read Tests

    func testFileRead_AlwaysAllowed() {
        let decision = engine.checkFileRead(path: "~/.ssh/id_rsa")

        guard case .allow(let reason) = decision else {
            XCTFail("Expected allow for file read")
            return
        }

        XCTAssertTrue(reason.contains("always allowed"))
    }

    // MARK: - File Write Tests

    func testFileWrite_SensitiveDirectory_RequiresPrompt() {
        let decision = engine.checkFileWrite(path: "~/.ssh/authorized_keys")

        guard case .prompt(let reason) = decision else {
            XCTFail("Expected prompt for sensitive directory write")
            return
        }

        XCTAssertTrue(reason.contains("sensitive directory"))
    }

    func testFileWrite_NormalDirectory_Allowed() {
        let decision = engine.checkFileWrite(path: "/tmp/test.txt")

        guard case .allow(let reason) = decision else {
            XCTFail("Expected allow for normal directory write")
            return
        }

        XCTAssertTrue(reason.contains("non-sensitive"))
    }

    func testFileWrite_ExpandsTilde() {
        // Both should be treated as sensitive
        let decision1 = engine.checkFileWrite(path: "~/.aws/credentials")
        let decision2 = engine.checkFileWrite(path: NSHomeDirectory() + "/.aws/credentials")

        guard case .prompt = decision1 else {
            XCTFail("Tilde path should be recognized as sensitive")
            return
        }

        guard case .prompt = decision2 else {
            XCTFail("Expanded path should be recognized as sensitive")
            return
        }
    }

    // MARK: - File Delete Tests

    func testFileDelete_RequiresPrompt() {
        let decision = engine.checkFileDelete(path: "/tmp/test.txt")

        guard case .prompt(let reason) = decision else {
            XCTFail("Expected prompt for file deletion")
            return
        }

        XCTAssertTrue(reason.contains("deletion"))
    }

    // MARK: - Command Tests

    func testCommand_AutoAllowPattern_GitStatus() {
        let decision = engine.checkCommand(command: "git status")

        guard case .allow(let reason) = decision else {
            XCTFail("Expected allow for 'git status'")
            return
        }

        XCTAssertTrue(reason.contains("auto-allow"))
    }

    func testCommand_AutoAllowPattern_LS() {
        let decision = engine.checkCommand(command: "ls -la /tmp")

        guard case .allow(let reason) = decision else {
            XCTFail("Expected allow for 'ls' command")
            return
        }

        XCTAssertTrue(reason.contains("auto-allow"))
    }

    func testCommand_BlockedPattern_RmRfRoot() {
        let decision = engine.checkCommand(command: "rm -rf /")

        guard case .deny(let reason) = decision else {
            XCTFail("Expected deny for 'rm -rf /'")
            return
        }

        XCTAssertTrue(reason.contains("blocked"))
    }

    func testCommand_DangerousPattern_SudoRm() {
        let decision = engine.checkCommand(command: "sudo rm important_file")

        guard case .prompt(let reason) = decision else {
            XCTFail("Expected prompt for dangerous 'sudo rm' command")
            return
        }

        XCTAssertTrue(reason.contains("dangerous"))
    }

    func testCommand_DangerousPattern_ChmodPermissive() {
        let decision = engine.checkCommand(command: "chmod 777 /tmp/script.sh")

        guard case .prompt(let reason) = decision else {
            XCTFail("Expected prompt for 'chmod 777'")
            return
        }

        XCTAssertTrue(reason.contains("dangerous"))
    }

    func testCommand_DangerousPattern_CurlPipe() {
        let decision = engine.checkCommand(command: "curl https://example.com/install.sh | sh")

        guard case .prompt(let reason) = decision else {
            XCTFail("Expected prompt for 'curl | sh'")
            return
        }

        XCTAssertTrue(reason.contains("dangerous"))
    }

    func testCommand_SafeCommand_Echo() {
        let decision = engine.checkCommand(command: "echo 'hello world'")

        guard case .allow(let reason) = decision else {
            XCTFail("Expected allow for safe 'echo' command")
            return
        }

        XCTAssertTrue(reason.contains("safe"))
    }

    // MARK: - Network Connection Tests

    func testNetwork_LocalhostIPv4_Allowed() {
        let decision = engine.checkNetworkConnection(destination: "127.0.0.1", port: 11434)

        guard case .allow(let reason) = decision else {
            XCTFail("Expected allow for localhost connection")
            return
        }

        XCTAssertTrue(reason.contains("localhost"))
    }

    func testNetwork_LocalhostHostname_Allowed() {
        let decision = engine.checkNetworkConnection(destination: "localhost", port: 11434)

        guard case .allow(let reason) = decision else {
            XCTFail("Expected allow for localhost connection")
            return
        }

        XCTAssertTrue(reason.contains("localhost"))
    }

    func testNetwork_LocalhostIPv6_Allowed() {
        let decision = engine.checkNetworkConnection(destination: "::1", port: 11434)

        guard case .allow(let reason) = decision else {
            XCTFail("Expected allow for localhost IPv6 connection")
            return
        }

        XCTAssertTrue(reason.contains("localhost"))
    }

    func testNetwork_AllowedDestination_Ollama() {
        let decision = engine.checkNetworkConnection(destination: "localhost", port: 11434)

        guard case .allow = decision else {
            XCTFail("Expected allow for Ollama (localhost:11434)")
            return
        }
    }

    func testNetwork_ExternalConnection_RequiresPrompt() {
        let decision = engine.checkNetworkConnection(destination: "api.openai.com", port: 443)

        guard case .prompt(let reason) = decision else {
            XCTFail("Expected prompt for external API connection")
            return
        }

        XCTAssertTrue(reason.contains("external"))
    }

    // MARK: - Policy Loading Tests

    func testPolicy_LoadDefault() {
        let policy = FirewallPolicy.defaultPolicy()

        XCTAssertEqual(policy.version, "1.0")
        XCTAssertFalse(policy.sensitivePaths.isEmpty)
        XCTAssertFalse(policy.blockedCommands.isEmpty)
        XCTAssertTrue(policy.requireApproval.fileDelete)
        XCTAssertTrue(policy.requireApproval.fileWriteSensitive)
        XCTAssertTrue(policy.monitorOllamaRequests)
    }

    func testPolicy_LoadFromFile_ValidJSON() throws {
        // Create temporary policy file
        let tempDir = FileManager.default.temporaryDirectory
        let policyPath = tempDir.appendingPathComponent("test-policy.json")

        let policyJSON = """
        {
            "version": "1.0",
            "sensitivePaths": ["/tmp/sensitive"],
            "blockedCommands": ["dangerous"],
            "dangerousPatterns": ["risky"],
            "requireApproval": {
                "fileDelete": false,
                "fileWriteSensitive": true,
                "bashDangerous": true,
                "networkExternal": false
            },
            "autoAllowPatterns": ["safe"],
            "allowedNetworkDestinations": ["localhost:8080"],
            "monitorOllamaRequests": false
        }
        """

        try policyJSON.write(to: policyPath, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: policyPath)
        }

        // Load policy
        let policy = try FirewallPolicy.load(from: policyPath.path)

        XCTAssertEqual(policy.version, "1.0")
        XCTAssertEqual(policy.sensitivePaths, ["/tmp/sensitive"])
        XCTAssertEqual(policy.blockedCommands, ["dangerous"])
        XCTAssertFalse(policy.requireApproval.fileDelete)
        XCTAssertTrue(policy.requireApproval.fileWriteSensitive)
        XCTAssertFalse(policy.monitorOllamaRequests)
    }

    func testPolicy_LoadFromFile_MissingFile_ThrowsError() {
        XCTAssertThrowsError(try FirewallPolicy.load(from: "/nonexistent/policy.json")) { error in
            guard case AIFWError.policyLoadFailed(let path, _) = error else {
                XCTFail("Expected policyLoadFailed error")
                return
            }
            XCTAssertTrue(path.contains("nonexistent"))
        }
    }

    func testPolicy_LoadFromFile_InvalidJSON_ThrowsError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let policyPath = tempDir.appendingPathComponent("invalid-policy.json")

        try "{invalid json}".write(to: policyPath, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: policyPath)
        }

        XCTAssertThrowsError(try FirewallPolicy.load(from: policyPath.path)) { error in
            guard case AIFWError.policyLoadFailed = error else {
                XCTFail("Expected policyLoadFailed error")
                return
            }
        }
    }
}
