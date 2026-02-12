import XCTest
@testable import KeyShare

class ActionValidationTests: XCTestCase {

    // MARK: - Keyboard Shortcut

    func testShortcutValidation() {
        let action = KeyboardShortcutAction()
        XCTAssertTrue(action.validate(params: ["key": "c"]))
        XCTAssertTrue(action.validate(params: ["key": "c", "modifiers": ["cmd"]]))
        XCTAssertTrue(action.validate(params: ["key": "c", "modifiers": ["cmd", "shift"]]))

        XCTAssertFalse(action.validate(params: [:]))  // needs key
        XCTAssertFalse(action.validate(params: ["key": 123]))
        XCTAssertFalse(action.validate(params: ["key": "c", "modifiers": "cmd"]))
    }

    // MARK: - App Launch

    func testAppLaunchValidation() {
        let action = AppLaunchAction()
        XCTAssertTrue(action.validate(params: ["bundle_id": "com.apple.Terminal"]))
        XCTAssertFalse(action.validate(params: [:]))
        XCTAssertFalse(action.validate(params: ["bundle_id": 123]))
    }

    // MARK: - Text Type

    func testTextTypeValidation() {
        let action = TextTypeAction()
        XCTAssertTrue(action.validate(params: ["text": "hello"]))
        XCTAssertTrue(action.validate(params: ["text": "hello", "method": "clipboard"]))
        XCTAssertTrue(action.validate(params: ["text": "hello", "method": "keystroke"]))

        XCTAssertFalse(action.validate(params: [:]))
        XCTAssertFalse(action.validate(params: ["text": "hello", "method": "invalid"]))
    }

    // MARK: - Desktop Switch

    func testDesktopSwitchDirections() {
        let action = DesktopSwitchAction()
        XCTAssertTrue(action.validate(params: ["direction": "left"]))
        XCTAssertTrue(action.validate(params: ["direction": "right"]))
        XCTAssertFalse(action.validate(params: ["direction": "up"]))
        XCTAssertFalse(action.validate(params: [:]))
    }

    func testDesktopSwitchNumbers() {
        let action = DesktopSwitchAction()
        for i in 1...9 {
            XCTAssertTrue(action.validate(params: ["desktop": i]), "Desktop \(i) should be valid")
        }
        XCTAssertFalse(action.validate(params: ["desktop": 0]))
        XCTAssertFalse(action.validate(params: ["desktop": 10]))
    }

    // MARK: - Media Control

    func testMediaControlAllValidActions() {
        let action = MediaControlAction()
        for name in ["play_pause", "next", "prev", "vol_up", "vol_down", "mute"] {
            XCTAssertTrue(action.validate(params: ["action": name]), "\(name) should be valid")
        }
    }

    func testMediaControlInvalid() {
        let action = MediaControlAction()
        XCTAssertFalse(action.validate(params: [:]))
        XCTAssertFalse(action.validate(params: ["action": "invalid"]))
    }
}
