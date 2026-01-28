//
// AIFWTests.swift
// AIFWTests
//
// Created by AI Agent
// Copyright © 2025 Jim Spring. All rights reserved.
//

import XCTest
@testable import AIFW

final class AIFWTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(AIFW.version, "0.1.0")
    }
}
