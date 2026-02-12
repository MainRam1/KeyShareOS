import XCTest
@testable import KeyShare

class ConstantsTests: XCTestCase {

    // MARK: - Key Names

    func testFromName() {
        XCTAssertEqual(Constants.KeyCodes.fromName("c"), 0x08)
    }

    func testFromNameCaseInsensitive() {
        XCTAssertEqual(Constants.KeyCodes.fromName("C"), Constants.KeyCodes.fromName("c"))
    }

    func testFromNameUnknown() {
        XCTAssertNil(Constants.KeyCodes.fromName("nonexistent"))
    }

    func testLetterKeys() {
        XCTAssertEqual(Constants.KeyCodes.fromName("a"), 0x00)
        XCTAssertEqual(Constants.KeyCodes.fromName("v"), 0x09)
        XCTAssertEqual(Constants.KeyCodes.fromName("z"), 0x06)
    }

    func testFunctionKeys() {
        XCTAssertEqual(Constants.KeyCodes.fromName("f1"), 0x7A)
        XCTAssertEqual(Constants.KeyCodes.fromName("f12"), 0x6F)
    }

    func testSpecialKeys() {
        XCTAssertEqual(Constants.KeyCodes.fromName("return"), 0x24)
        XCTAssertEqual(Constants.KeyCodes.fromName("space"), 0x31)
        XCTAssertEqual(Constants.KeyCodes.fromName("escape"), 0x35)
        XCTAssertEqual(Constants.KeyCodes.fromName("tab"), 0x30)
    }

    // MARK: - Number Keys

    func testNumberKeys() {
        for number in 0...9 {
            XCTAssertNotNil(Constants.KeyCodes.numberKey(number), "numberKey(\(number)) should not be nil")
        }
        XCTAssertNil(Constants.KeyCodes.numberKey(10))
        XCTAssertNil(Constants.KeyCodes.numberKey(-1))
    }

    func testNumberKeyValues() {
        // not sequential in ANSI layout
        XCTAssertEqual(Constants.KeyCodes.numberKey(1), 0x12)
        XCTAssertEqual(Constants.KeyCodes.numberKey(5), 0x17)
        XCTAssertEqual(Constants.KeyCodes.numberKey(0), 0x1D)
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

    func testAllModifiersCombined() {
        let flags = Constants.KeyCodes.modifierFlags(from: ["cmd", "shift", "ctrl", "alt"])
        XCTAssertTrue(flags.contains(.maskCommand))
        XCTAssertTrue(flags.contains(.maskShift))
        XCTAssertTrue(flags.contains(.maskControl))
        XCTAssertTrue(flags.contains(.maskAlternate))
    }

    func testEmptyAndUnknownModifiers() {
        XCTAssertTrue(Constants.KeyCodes.modifierFlags(from: []).isEmpty)
        XCTAssertTrue(Constants.KeyCodes.modifierFlags(from: ["unknown"]).isEmpty)
    }
}
