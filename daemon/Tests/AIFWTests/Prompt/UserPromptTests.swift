//
// UserPromptTests.swift
// AIFWTests
//
// Tests for user prompt system
//

import XCTest
@testable import AIFW

final class UserPromptTests: XCTestCase {

    // MARK: - Mock Prompt Tests

    func testMockPrompt_Deny_Default() {
        let mock = MockUserPrompt()

        let response = mock.showPrompt(
            title: "Test",
            message: "Test message",
            details: "Test details"
        )

        XCTAssertEqual(response, .deny)
        XCTAssertTrue(mock.wasPrompted)
        XCTAssertEqual(mock.promptCount, 1)
    }

    func testMockPrompt_AllowOnce() {
        let mock = MockUserPrompt(defaultResponse: .allowOnce)

        let response = mock.showPrompt(
            title: "Test",
            message: "Test message",
            details: "Test details"
        )

        XCTAssertEqual(response, .allowOnce)
    }

    func testMockPrompt_AllowAlways() {
        let mock = MockUserPrompt(defaultResponse: .allowAlways)

        let response = mock.showPrompt(
            title: "Test",
            message: "Test message",
            details: "Test details"
        )

        XCTAssertEqual(response, .allowAlways)
    }

    func testMockPrompt_CapturesHistory() {
        let mock = MockUserPrompt()

        _ = mock.showPrompt(
            title: "Title 1",
            message: "Message 1",
            details: "Details 1"
        )

        _ = mock.showPrompt(
            title: "Title 2",
            message: "Message 2",
            details: "Details 2"
        )

        XCTAssertEqual(mock.promptCount, 2)
        XCTAssertEqual(mock.promptHistory.count, 2)

        XCTAssertEqual(mock.promptHistory[0].title, "Title 1")
        XCTAssertEqual(mock.promptHistory[1].title, "Title 2")
    }

    func testMockPrompt_LastPrompt() {
        let mock = MockUserPrompt()

        XCTAssertNil(mock.lastPrompt)

        _ = mock.showPrompt(
            title: "First",
            message: "Message 1",
            details: "Details 1"
        )

        _ = mock.showPrompt(
            title: "Second",
            message: "Message 2",
            details: "Details 2"
        )

        XCTAssertEqual(mock.lastPrompt?.title, "Second")
        XCTAssertEqual(mock.lastPrompt?.message, "Message 2")
    }

    func testMockPrompt_Reset() {
        let mock = MockUserPrompt(defaultResponse: .allowOnce)

        _ = mock.showPrompt(
            title: "Test",
            message: "Message",
            details: "Details"
        )

        XCTAssertEqual(mock.promptCount, 1)
        XCTAssertEqual(mock.responseToReturn, .allowOnce)

        mock.reset()

        XCTAssertEqual(mock.promptCount, 0)
        XCTAssertEqual(mock.responseToReturn, .deny)
        XCTAssertFalse(mock.wasPrompted)
    }

    func testMockPrompt_MultipleCallsWithDifferentResponses() {
        let mock = MockUserPrompt()

        // First call - deny
        mock.responseToReturn = .deny
        let response1 = mock.showPrompt(
            title: "Test 1",
            message: "Message",
            details: "Details"
        )

        // Second call - allow once
        mock.responseToReturn = .allowOnce
        let response2 = mock.showPrompt(
            title: "Test 2",
            message: "Message",
            details: "Details"
        )

        // Third call - allow always
        mock.responseToReturn = .allowAlways
        let response3 = mock.showPrompt(
            title: "Test 3",
            message: "Message",
            details: "Details"
        )

        XCTAssertEqual(response1, .deny)
        XCTAssertEqual(response2, .allowOnce)
        XCTAssertEqual(response3, .allowAlways)
        XCTAssertEqual(mock.promptCount, 3)
    }

    // MARK: - Protocol Tests

    func testPromptProtocol_WorksWithMock() {
        let prompt: UserPromptProtocol = MockUserPrompt(defaultResponse: .allowOnce)

        let response = prompt.showPrompt(
            title: "Test",
            message: "Message",
            details: "Details"
        )

        XCTAssertEqual(response, .allowOnce)
    }

    func testPromptProtocol_CanSwitchImplementations() {
        var prompt: UserPromptProtocol = MockUserPrompt(defaultResponse: .deny)

        let response1 = prompt.showPrompt(
            title: "Test",
            message: "Message",
            details: "Details"
        )
        XCTAssertEqual(response1, .deny)

        // Switch to different mock
        prompt = MockUserPrompt(defaultResponse: .allowAlways)

        let response2 = prompt.showPrompt(
            title: "Test",
            message: "Message",
            details: "Details"
        )
        XCTAssertEqual(response2, .allowAlways)
    }

    // MARK: - PromptResponse Tests

    func testPromptResponse_Equatable() {
        XCTAssertEqual(PromptResponse.deny, PromptResponse.deny)
        XCTAssertEqual(PromptResponse.allowOnce, PromptResponse.allowOnce)
        XCTAssertEqual(PromptResponse.allowAlways, PromptResponse.allowAlways)
        XCTAssertNotEqual(PromptResponse.deny, PromptResponse.allowOnce)
        XCTAssertNotEqual(PromptResponse.allowOnce, PromptResponse.allowAlways)
    }
}
