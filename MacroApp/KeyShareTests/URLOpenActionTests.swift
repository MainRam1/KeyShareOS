import XCTest
@testable import KeyShare

class URLOpenActionTests: XCTestCase {

    private let action = URLOpenAction()

    func testActionType() {
        XCTAssertEqual(URLOpenAction.actionType, "open_url")
    }

    func testDoesNotRequireAccessibility() {
        XCTAssertFalse(action.requiresAccessibility)
    }

    func testValidHTTPSUrl() {
        XCTAssertTrue(action.validate(params: ["url": "https://example.com"]))
    }

    func testValidHTTPUrl() {
        XCTAssertTrue(action.validate(params: ["url": "http://example.com"]))
    }

    func testValidUrlWithPath() {
        XCTAssertTrue(action.validate(params: ["url": "https://github.com/user/repo"]))
    }

    func testValidUrlWithQueryString() {
        XCTAssertTrue(action.validate(params: ["url": "https://example.com/search?q=test"]))
    }

    func testMissingUrlParam() {
        XCTAssertFalse(action.validate(params: [:]))
    }

    func testWrongParamType() {
        XCTAssertFalse(action.validate(params: ["url": 123]))
    }

    func testEmptyString() {
        XCTAssertFalse(action.validate(params: ["url": ""]))
    }

    func testNonWebSchemeMailto() {
        XCTAssertFalse(action.validate(params: ["url": "mailto:user@example.com"]))
    }

    func testNonWebSchemeFile() {
        XCTAssertFalse(action.validate(params: ["url": "file:///tmp/test"]))
    }

    func testNonWebSchemeCustom() {
        XCTAssertFalse(action.validate(params: ["url": "slack://open"]))
    }

    func testNoScheme() {
        XCTAssertFalse(action.validate(params: ["url": "example.com"]))
    }
}
