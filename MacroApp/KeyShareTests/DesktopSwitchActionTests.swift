import XCTest
@testable import KeyShare

class DesktopSwitchActionTests: XCTestCase {

    private let action = DesktopSwitchAction()

    func testActionType() {
        XCTAssertEqual(DesktopSwitchAction.actionType, "desktop_switch")
    }

    // MARK: - Directions

    func testValidDirections() {
        XCTAssertTrue(action.validate(params: ["direction": "left"]))
        XCTAssertTrue(action.validate(params: ["direction": "right"]))
    }

    func testInvalidDirections() {
        XCTAssertFalse(action.validate(params: ["direction": "up"]))
        XCTAssertFalse(action.validate(params: ["direction": "down"]))
    }

    // MARK: - Desktop Numbers

    func testDesktops1Through9() {
        for i in 1...9 {
            XCTAssertTrue(action.validate(params: ["desktop": i]),
                          "Desktop \(i) should be valid")
        }
    }

    func testOutOfRangeDesktops() {
        XCTAssertFalse(action.validate(params: ["desktop": 0]))
        XCTAssertFalse(action.validate(params: ["desktop": 10]))
        XCTAssertFalse(action.validate(params: ["desktop": -1]))
    }

    func testEmptyParams() {
        XCTAssertFalse(action.validate(params: [:]))
    }

    // MARK: - Key Codes

    func testNumberKeyCodes() {
        for i in 1...9 {
            XCTAssertNotNil(Constants.KeyCodes.numberKey(i),
                            "Number key \(i) should have a key code")
        }
        XCTAssertNotNil(Constants.KeyCodes.numberKey(0))
        XCTAssertNil(Constants.KeyCodes.numberKey(10))
    }

    func testNumberKeyCodesDistinct() {
        var codes = Set<CGKeyCode>()
        for i in 0...9 {
            if let code = Constants.KeyCodes.numberKey(i) {
                codes.insert(code)
            }
        }
        XCTAssertEqual(codes.count, 10, "All 10 number keys should have distinct codes")
    }
}
