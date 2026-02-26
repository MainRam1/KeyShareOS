import XCTest
@testable import KeyShare

final class KeyboardShortcutActionTests: XCTestCase {

    private let action = KeyboardShortcutAction()

    func testActionType() {
        XCTAssertEqual(KeyboardShortcutAction.actionType, "keyboard_shortcut")
    }

    // MARK: - Key Codes

    func testKeyCodeLetter() {
        XCTAssertNotNil(Constants.KeyCodes.fromName("c"))
        XCTAssertEqual(Constants.KeyCodes.fromName("c"), Constants.KeyCodes.c)
    }

    func testKeyCodeCaseInsensitive() {
        XCTAssertEqual(Constants.KeyCodes.fromName("C"), Constants.KeyCodes.fromName("c"))
    }

    func testKeyCodeNumber() {
        XCTAssertNotNil(Constants.KeyCodes.fromName("1"))
        XCTAssertEqual(Constants.KeyCodes.fromName("1"), Constants.KeyCodes.n1)
    }

    func testKeyCodeFunctionKey() {
        XCTAssertNotNil(Constants.KeyCodes.fromName("f1"))
        XCTAssertEqual(Constants.KeyCodes.fromName("f1"), Constants.KeyCodes.f1)
    }

    func testSpecialKeys() {
        for key in ["return", "tab", "space", "delete", "escape"] {
            XCTAssertNotNil(Constants.KeyCodes.fromName(key), "\(key) should resolve")
        }
    }

    func testArrowKeys() {
        for key in ["left", "right", "up", "down"] {
            XCTAssertNotNil(Constants.KeyCodes.fromName(key), "\(key) should resolve")
        }
    }

    func testUnknownKeyReturnsNil() {
        XCTAssertNil(Constants.KeyCodes.fromName("nonexistent"))
    }

    // MARK: - Modifiers

    func testSingleModifiers() {
        XCTAssertTrue(Constants.KeyCodes.modifierFlags(from: ["cmd"]).contains(.maskCommand))
        XCTAssertTrue(Constants.KeyCodes.modifierFlags(from: ["command"]).contains(.maskCommand))
        XCTAssertTrue(Constants.KeyCodes.modifierFlags(from: ["shift"]).contains(.maskShift))
        XCTAssertTrue(Constants.KeyCodes.modifierFlags(from: ["ctrl"]).contains(.maskControl))
        XCTAssertTrue(Constants.KeyCodes.modifierFlags(from: ["control"]).contains(.maskControl))
        XCTAssertTrue(Constants.KeyCodes.modifierFlags(from: ["alt"]).contains(.maskAlternate))
        XCTAssertTrue(Constants.KeyCodes.modifierFlags(from: ["option"]).contains(.maskAlternate))
    }

    func testCombinedModifiers() {
        let flags = Constants.KeyCodes.modifierFlags(from: ["cmd", "shift", "alt"])
        XCTAssertTrue(flags.contains(.maskCommand))
        XCTAssertTrue(flags.contains(.maskShift))
        XCTAssertTrue(flags.contains(.maskAlternate))
    }

    func testEmptyModifiers() {
        XCTAssertTrue(Constants.KeyCodes.modifierFlags(from: []).isEmpty)
    }

    func testUnknownModifierIgnored() {
        XCTAssertTrue(Constants.KeyCodes.modifierFlags(from: ["unknown"]).isEmpty)
    }

    // MARK: - Validation

    func testAllLetterKeys() {
        for letter in "abcdefghijklmnopqrstuvwxyz" {
            XCTAssertTrue(action.validate(params: ["key": String(letter)]),
                          "Should validate key '\(letter)'")
        }
    }

    func testEmptyModifiersArray() {
        XCTAssertTrue(action.validate(params: ["key": "a", "modifiers": [] as [String]]))
    }
}
