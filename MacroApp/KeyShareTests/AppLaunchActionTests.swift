import XCTest
@testable import KeyShare

class AppLaunchActionTests: XCTestCase {

    private let action = AppLaunchAction()

    func testActionType() {
        XCTAssertEqual(AppLaunchAction.actionType, "app_launch")
    }

    func testValidBundleIDs() {
        XCTAssertTrue(action.validate(params: ["bundle_id": "com.apple.Safari"]))
        XCTAssertTrue(action.validate(params: ["bundle_id": "com.microsoft.VSCode"]))
        // empty string is technically valid — fails at execution time
        XCTAssertTrue(action.validate(params: ["bundle_id": ""]))
    }

    func testMissingBundleID() {
        XCTAssertFalse(action.validate(params: [:]))
    }

    func testWrongType() {
        XCTAssertFalse(action.validate(params: ["bundle_id": 123]))
    }

    func testExtraParamsIgnored() {
        XCTAssertTrue(action.validate(params: ["bundle_id": "com.apple.Terminal", "extra": "ignored"]))
    }
}
