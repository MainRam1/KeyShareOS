import XCTest
@testable import KeyShare

final class ConfigSchemaTests: XCTestCase {

    // MARK: - Test Config

    func testTestConfigStructure() {
        let config = MacroConfig.testConfig
        XCTAssertEqual(config.version, 1)
        XCTAssertEqual(config.activeProfile, "test")

        let profile = config.profiles["test"]
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.keys.count, 9)
        XCTAssertEqual(profile?.displayName, "Test Profile")
    }

    func testTestConfigSettings() {
        XCTAssertEqual(MacroConfig.testConfig.settings.launchAtLogin, false)
        XCTAssertEqual(MacroConfig.testConfig.settings.showOSD, true)
    }

    func testJSONRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(MacroConfig.testConfig)
        let decoded = try JSONDecoder().decode(MacroConfig.self, from: data)

        XCTAssertEqual(decoded.version, MacroConfig.testConfig.version)
        XCTAssertEqual(decoded.activeProfile, MacroConfig.testConfig.activeProfile)
        XCTAssertEqual(decoded.settings, MacroConfig.testConfig.settings)
        XCTAssertEqual(decoded.autoSwitch, MacroConfig.testConfig.autoSwitch)

        let profile = decoded.profiles["test"]
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.displayName, "Test Profile")
        XCTAssertEqual(profile?.keys.count, 9)

        let key3 = profile?.keys["3"]
        XCTAssertEqual(key3?.action, "app_launch")
        XCTAssertEqual(key3?.params["bundle_id"]?.stringValue, "com.apple.Terminal")
    }

    // MARK: - AnyCodable

    func testAnyCodableRoundTrips() throws {
        let stringVal = AnyCodable("hello")
        let stringData = try JSONEncoder().encode(stringVal)
        let decodedString = try JSONDecoder().decode(AnyCodable.self, from: stringData)
        XCTAssertEqual(decodedString.stringValue, "hello")

        let intVal = AnyCodable(42)
        let intData = try JSONEncoder().encode(intVal)
        let decodedInt = try JSONDecoder().decode(AnyCodable.self, from: intData)
        XCTAssertEqual(decodedInt.intValue, 42)

        let doubleVal = AnyCodable(3.14)
        let doubleData = try JSONEncoder().encode(doubleVal)
        let decodedDouble = try JSONDecoder().decode(AnyCodable.self, from: doubleData)
        XCTAssertEqual(decodedDouble.anyValue as? Double, 3.14)

        let boolVal = AnyCodable(true)
        let boolData = try JSONEncoder().encode(boolVal)
        let decodedBool = try JSONDecoder().decode(AnyCodable.self, from: boolData)
        XCTAssertEqual(decodedBool.anyValue as? Bool, true)
    }

    func testAnyCodableEquality() {
        XCTAssertEqual(AnyCodable("a"), AnyCodable("a"))
        XCTAssertEqual(AnyCodable(1), AnyCodable(1))
        XCTAssertEqual(AnyCodable(true), AnyCodable(true))
        XCTAssertEqual(AnyCodable(2.5), AnyCodable(2.5))

        XCTAssertNotEqual(AnyCodable("a"), AnyCodable("b"))
        XCTAssertNotEqual(AnyCodable(1), AnyCodable(2))
        XCTAssertNotEqual(AnyCodable("1"), AnyCodable(1))
        XCTAssertNotEqual(AnyCodable(true), AnyCodable(1))
    }

    func testAnyCodableAccessors() {
        XCTAssertEqual(AnyCodable("hello").stringValue, "hello")
        XCTAssertNil(AnyCodable(42).stringValue)

        XCTAssertEqual(AnyCodable(42).intValue, 42)
        XCTAssertNil(AnyCodable("hello").intValue)

        XCTAssertEqual(AnyCodable("test").anyValue as? String, "test")
    }

    // MARK: - KeyBinding

    func testKeyBindingActionParams() {
        let binding = KeyBinding(
            action: "keyboard_shortcut",
            params: [
                "key": AnyCodable("c"),
                "modifiers": AnyCodable(["cmd"]),
            ]
        )

        let actionParams = binding.actionParams
        XCTAssertEqual(actionParams["key"] as? String, "c")

        let modifiers = actionParams["modifiers"] as? [String]
        XCTAssertEqual(modifiers, ["cmd"])
    }

    // MARK: - AppSettings

    func testAppSettingsSnakeCaseEncoding() throws {
        let settings = AppSettings(launchAtLogin: true, showOSD: false)
        let data = try JSONEncoder().encode(settings)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["launch_at_login"])
        XCTAssertNotNil(json["show_osd"])
        XCTAssertNil(json["launchAtLogin"])
        XCTAssertNil(json["showOSD"])
    }

    func testAppSettingsSnakeCaseDecoding() throws {
        let json = #"{"launch_at_login": true, "show_osd": false}"#
        let data = json.data(using: .utf8)!
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertFalse(settings.showOSD)
    }
}
