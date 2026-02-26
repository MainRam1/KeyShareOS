import XCTest
@testable import KeyShare

final class TextTypeActionTests: XCTestCase {

    private let action = TextTypeAction()

    func testActionType() {
        XCTAssertEqual(TextTypeAction.actionType, "text_type")
    }

    func testValidText() {
        XCTAssertTrue(action.validate(params: ["text": "hello"]))
        XCTAssertTrue(action.validate(params: ["text": "hello", "method": "clipboard"]))
        XCTAssertTrue(action.validate(params: ["text": "hello", "method": "keystroke"]))
        // defaults to clipboard when unspecified
        XCTAssertTrue(action.validate(params: ["text": "test"]))
    }

    func testEdgeCaseText() {
        XCTAssertTrue(action.validate(params: ["text": ""]))
        XCTAssertTrue(action.validate(params: ["text": "line1\nline2\nline3"]))
        XCTAssertTrue(action.validate(params: ["text": "Hello 🌍 こんにちは"]))
    }

    func testInvalidParams() {
        XCTAssertFalse(action.validate(params: [:]))
        XCTAssertFalse(action.validate(params: ["text": "hello", "method": "invalid"]))
        XCTAssertFalse(action.validate(params: ["text": 123]))
    }
}
