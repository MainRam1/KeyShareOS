import XCTest
@testable import KeyShare

class ConfigValidationTests: XCTestCase {

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }

    // MARK: - Fixtures

    func testBasicConfigParses() throws {
        let data = try loadFixture("valid_basic")
        let config = try JSONDecoder().decode(MacroConfig.self, from: data)
        XCTAssertEqual(config.activeProfile, "general")
        XCTAssertEqual(config.profiles.count, 1)
        XCTAssertEqual(config.profiles["general"]?.keys.count, 9)
    }

    func testAllActionsConfigParses() throws {
        let data = try loadFixture("valid_all_actions")
        let config = try JSONDecoder().decode(MacroConfig.self, from: data)
        XCTAssertEqual(config.activeProfile, "all_actions")
        XCTAssertNotNil(config.profiles["all_actions"])

        let keys = config.profiles["all_actions"]!.keys
        XCTAssertEqual(keys["1"]?.action, "keyboard_shortcut")
        XCTAssertEqual(keys["3"]?.action, "app_launch")
        XCTAssertEqual(keys["4"]?.action, "text_type")
        XCTAssertEqual(keys["6"]?.action, "media_control")
        XCTAssertEqual(keys["8"]?.action, "desktop_switch")
    }

    func testMacrosConfigParses() throws {
        let data = try loadFixture("valid_macros")
        let config = try JSONDecoder().decode(MacroConfig.self, from: data)
        XCTAssertEqual(config.activeProfile, "macros")

        let keys = config.profiles["macros"]!.keys
        XCTAssertEqual(keys["1"]?.action, "macro")
        XCTAssertEqual(keys["2"]?.action, "macro")
    }

    func testBadSchemaThrows() {
        do {
            let data = try loadFixture("invalid_schema")
            _ = try JSONDecoder().decode(MacroConfig.self, from: data)
            XCTFail("Expected decoding error")
        } catch {
            // Expected — version is "not_a_number" instead of Int
        }
    }

    func testMissingProfileStillDecodes() throws {
        // The JSON itself is valid Codable — the active_profile "nonexistent" is a logical error
        // caught by ConfigManager.validate(), not by JSONDecoder
        let data = try loadFixture("invalid_missing_profile")
        let config = try JSONDecoder().decode(MacroConfig.self, from: data)
        XCTAssertEqual(config.activeProfile, "nonexistent")
        XCTAssertNil(config.profiles["nonexistent"])
    }

    // MARK: - Error Descriptions

    func testActionErrorDescriptions() {
        let unknown = ActionError.unknownAction("foo")
        XCTAssertTrue(unknown.description.contains("foo"))

        let invalid = ActionError.invalidParams("bar", [:])
        XCTAssertTrue(invalid.description.contains("bar"))

        let underlying = NSError(domain: "test", code: 1)
        let failed = ActionError.executionFailed("baz", underlying)
        XCTAssertTrue(failed.description.contains("baz"))

        let accessibility = ActionError.accessibilityRequired
        XCTAssertFalse(accessibility.description.isEmpty)
    }

    // MARK: - Round-Trip

    func testAllActionsRoundTrip() throws {
        let data = try loadFixture("valid_all_actions")
        let config = try JSONDecoder().decode(MacroConfig.self, from: data)

        let reEncoded = try encoder.encode(config)
        let reDecoded = try JSONDecoder().decode(MacroConfig.self, from: reEncoded)

        XCTAssertEqual(reDecoded.version, config.version)
        XCTAssertEqual(reDecoded.activeProfile, config.activeProfile)
        XCTAssertEqual(reDecoded.profiles.count, config.profiles.count)
        XCTAssertEqual(reDecoded.profiles["all_actions"]?.keys.count, 9)
        XCTAssertEqual(reDecoded.profiles["all_actions"]?.keys["1"]?.action, "keyboard_shortcut")
    }

    func testMacrosRoundTrip() throws {
        let data = try loadFixture("valid_macros")
        let config = try JSONDecoder().decode(MacroConfig.self, from: data)

        let reEncoded = try encoder.encode(config)
        let reDecoded = try JSONDecoder().decode(MacroConfig.self, from: reEncoded)

        XCTAssertEqual(reDecoded.version, config.version)
        XCTAssertEqual(reDecoded.activeProfile, config.activeProfile)
        XCTAssertEqual(reDecoded.profiles["macros"]?.keys["1"]?.action, "macro")
        XCTAssertEqual(reDecoded.profiles["macros"]?.keys["2"]?.action, "macro")
    }

    // regression for the app_launch persistence bug
    func testMacroStepDataSurvivesRoundTrip() throws {
        let data = try loadFixture("valid_macros")
        let config = try JSONDecoder().decode(MacroConfig.self, from: data)

        let reEncoded = try encoder.encode(config)
        let reDecoded = try JSONDecoder().decode(MacroConfig.self, from: reEncoded)

        let key1 = reDecoded.profiles["macros"]?.keys["1"]
        XCTAssertEqual(key1?.action, "macro")

        let stepsValue = key1?.params["steps"]?.anyValue
        let stepsArray = stepsValue as? [[String: Any]]
        XCTAssertNotNil(stepsArray, "Steps array must survive AnyCodable round-trip")
        XCTAssertEqual(stepsArray?.count, 3)

        let step0 = stepsArray?[0]
        XCTAssertEqual(step0?["action"] as? String, "app_launch")
        let step0Params = step0?["params"] as? [String: Any]
        XCTAssertEqual(step0Params?["bundle_id"] as? String, "com.apple.Terminal")

        let step1 = stepsArray?[1]
        XCTAssertNotNil(step1?["delay_ms"])

        let step2 = stepsArray?[2]
        XCTAssertEqual(step2?["action"] as? String, "text_type")
        let step2Params = step2?["params"] as? [String: Any]
        XCTAssertEqual(step2Params?["text"] as? String, "echo hello\n")
        XCTAssertEqual(step2Params?["method"] as? String, "clipboard")

        let key2 = reDecoded.profiles["macros"]?.keys["2"]
        XCTAssertEqual(key2?.action, "macro")
        let key2Steps = key2?.params["steps"]?.anyValue as? [[String: Any]]
        XCTAssertNotNil(key2Steps)
        XCTAssertEqual(key2Steps?.count, 3)

        let shortcutStep = key2Steps?[0]
        let shortcutParams = shortcutStep?["params"] as? [String: Any]
        XCTAssertEqual(shortcutParams?["key"] as? String, "c")
    }

    func testAnyCodableArrayOfDictsRoundTrip() throws {
        let steps: [[String: Any]] = [
            ["action": "app_launch", "params": ["bundle_id": "com.apple.Terminal"]],
            ["delay_ms": 500],
            ["action": "text_type", "params": ["text": "hello", "method": "clipboard"]],
        ]
        let original = AnyCodable(steps)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        let result = decoded.anyValue as? [[String: Any]]
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 3)

        let step0 = result?[0]
        XCTAssertEqual(step0?["action"] as? String, "app_launch")
        let step0Params = step0?["params"] as? [String: Any]
        XCTAssertEqual(step0Params?["bundle_id"] as? String, "com.apple.Terminal")
    }

    func testNestedMacroStepsRoundTrip() throws {
        let config = MacroConfig(
            version: 1,
            activeProfile: "test",
            profiles: [
                "test": Profile(
                    displayName: "Test",
                    keys: [
                        "1": KeyBinding(action: "macro", params: [
                            "steps": AnyCodable([
                                ["action": "app_launch", "params": ["bundle_id": "com.apple.Safari"]] as [String: Any],
                                ["delay_ms": 200] as [String: Any],
                                ["action": "keyboard_shortcut", "params": ["modifiers": ["cmd"], "key": "l"]] as [String: Any],
                            ] as [[String: Any]]),
                        ]),
                    ]
                ),
            ],
            autoSwitch: [:],
            settings: AppSettings(launchAtLogin: false, showOSD: true)
        )

        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let firstEncode = try enc.encode(config)
        let decoded = try JSONDecoder().decode(MacroConfig.self, from: firstEncode)
        let secondEncode = try enc.encode(decoded)

        XCTAssertEqual(firstEncode, secondEncode, "JSON must be byte-identical after round-trip")

        let steps = decoded.profiles["test"]?.keys["1"]?.params["steps"]?.anyValue as? [[String: Any]]
        XCTAssertEqual(steps?.count, 3)
        let appStep = steps?[0]
        let appParams = appStep?["params"] as? [String: Any]
        XCTAssertEqual(appParams?["bundle_id"] as? String, "com.apple.Safari")
    }

    // MARK: - AnyCodable Equality

    func testAnyCodableNestedEquality() {
        let a = AnyCodable([["key": "value"]] as [[String: String]])
        let b = AnyCodable([["key": "value"]] as [[String: String]])
        XCTAssertEqual(a, b)

        let c = AnyCodable(["outer": ["inner": "value"]] as [String: Any])
        let d = AnyCodable(["outer": ["inner": "value"]] as [String: Any])
        XCTAssertEqual(c, d)
    }

    func testAnyCodableScalarEquality() {
        XCTAssertEqual(AnyCodable("hello"), AnyCodable("hello"))
        XCTAssertEqual(AnyCodable(42), AnyCodable(42))
        XCTAssertEqual(AnyCodable(3.14), AnyCodable(3.14))
        XCTAssertEqual(AnyCodable(true), AnyCodable(true))
        XCTAssertNotEqual(AnyCodable("a"), AnyCodable("b"))
        XCTAssertNotEqual(AnyCodable("1"), AnyCodable(1))
    }

    func testAnyCodableInequality() {
        XCTAssertNotEqual(AnyCodable([1, 2, 3]), AnyCodable([1, 2, 4]))
        XCTAssertNotEqual(
            AnyCodable(["key": "value1"] as [String: Any]),
            AnyCodable(["key": "value2"] as [String: Any])
        )
    }

    // MARK: - Key Swapping

    func testSwapBothConfigured() {
        var config = MacroConfig.testConfig
        config.swapKeys(1, 3, in: "test")

        let key1 = config.profiles["test"]?.keys["1"]
        let key3 = config.profiles["test"]?.keys["3"]

        XCTAssertEqual(key1?.action, "app_launch")
        XCTAssertEqual(key1?.params["bundle_id"]?.stringValue, "com.apple.Terminal")
        XCTAssertEqual(key3?.action, "keyboard_shortcut")
        XCTAssertEqual(key3?.params["key"]?.stringValue, "c")
    }

    func testSwapOneUnconfigured() {
        var config = MacroConfig.testConfig
        var profile = config.profiles["test"]!
        profile.keys.removeValue(forKey: "99")
        config.profiles["test"] = profile

        let originalKey5 = config.profiles["test"]?.keys["5"]
        XCTAssertNotNil(originalKey5)

        config.swapKeys(5, 99, in: "test")

        let key5 = config.profiles["test"]?.keys["5"]
        let key99 = config.profiles["test"]?.keys["99"]

        XCTAssertEqual(key5?.action, "none")
        XCTAssertEqual(key99?.action, "media_control")
        XCTAssertEqual(key99?.params["action"]?.stringValue, "play_pause")
    }

    func testSwapSameKey() {
        var config = MacroConfig.testConfig
        let originalKey5 = config.profiles["test"]?.keys["5"]

        config.swapKeys(5, 5, in: "test")

        let key5 = config.profiles["test"]?.keys["5"]
        XCTAssertEqual(key5?.action, originalKey5?.action)
    }

    func testSwapPersistsThroughRoundTrip() throws {
        var config = MacroConfig.testConfig
        config.swapKeys(1, 3, in: "test")

        let enc = JSONEncoder()
        enc.outputFormatting = .sortedKeys
        let data = try enc.encode(config)
        let decoded = try JSONDecoder().decode(MacroConfig.self, from: data)

        let key1 = decoded.profiles["test"]?.keys["1"]
        let key3 = decoded.profiles["test"]?.keys["3"]

        XCTAssertEqual(key1?.action, "app_launch")
        XCTAssertEqual(key1?.params["bundle_id"]?.stringValue, "com.apple.Terminal")
        XCTAssertEqual(key3?.action, "keyboard_shortcut")
        XCTAssertEqual(key3?.params["key"]?.stringValue, "c")
    }

    // MARK: - Helpers

    private func loadFixture(_ name: String) throws -> Data {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // KeyShareTests/
            .deletingLastPathComponent() // KeyShare/
            .deletingLastPathComponent() // MacroApp/ (repo root)
        let fixtureURL = projectRoot
            .appendingPathComponent("tests")
            .appendingPathComponent("fixtures")
            .appendingPathComponent("configs")
            .appendingPathComponent("\(name).json")
        return try Data(contentsOf: fixtureURL)
    }
}
