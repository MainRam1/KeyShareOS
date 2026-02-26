import XCTest
@testable import KeyShare

class ConfigIntegrationTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacroConfigIntTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        super.tearDown()
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }

    private func makeConfigManager() -> ConfigManager {
        let configFile = tempDir.appendingPathComponent("config.json")
        return ConfigManager(filePath: configFile, directoryPath: tempDir)
    }

    private func makeConfigWithCustomBindings() -> MacroConfig {
        var keys: [String: KeyBinding] = [:]
        for i in 1...Constants.numberOfKeys {
            keys[String(i)] = KeyBinding(
                action: "keyboard_shortcut",
                params: [
                    "modifiers": AnyCodable(["cmd"]),
                    "key": AnyCodable("k\(i)"),
                ]
            )
        }

        return MacroConfig(
            version: 1,
            activeProfile: "general",
            profiles: [
                "general": Profile(displayName: "General", keys: keys),
            ],
            autoSwitch: [:],
            settings: AppSettings(launchAtLogin: false, showOSD: true)
        )
    }

    // MARK: - Reload

    func testReloadPicksUpDiskChanges() throws {
        let configFile = tempDir.appendingPathComponent("config.json")
        let configManager = ConfigManager(filePath: configFile, directoryPath: tempDir)

        XCTAssertEqual(configManager.config.activeProfile, "general")
        let initialBindings = configManager.config.profiles["general"]!
        for (_, binding) in initialBindings.keys {
            XCTAssertEqual(binding.action, "none")
        }

        let modifiedConfig = makeConfigWithCustomBindings()
        let data = try encoder.encode(modifiedConfig)
        try data.write(to: configFile, options: .atomic)

        configManager.load()

        XCTAssertEqual(configManager.config.activeProfile, "general")
        let reloadedProfile = configManager.config.profiles["general"]!
        XCTAssertEqual(reloadedProfile.keys.count, Constants.numberOfKeys)

        for i in 1...Constants.numberOfKeys {
            let binding = reloadedProfile.keys[String(i)]!
            XCTAssertEqual(binding.action, "keyboard_shortcut")
            XCTAssertEqual(binding.params["key"]?.stringValue, "k\(i)")
        }
    }

    func testReloadPreservesNewProfiles() throws {
        let configFile = tempDir.appendingPathComponent("config.json")
        let configManager = ConfigManager(filePath: configFile, directoryPath: tempDir)

        XCTAssertEqual(configManager.config.profiles.count, 1)

        var twoProfileConfig = ConfigManager.defaultConfig()
        var codingKeys: [String: KeyBinding] = [:]
        for i in 1...Constants.numberOfKeys {
            codingKeys[String(i)] = KeyBinding(
                action: "app_launch",
                params: ["bundle_id": AnyCodable("com.test.app\(i)")]
            )
        }
        twoProfileConfig.profiles["coding"] = Profile(
            displayName: "Coding",
            keys: codingKeys
        )

        let data = try encoder.encode(twoProfileConfig)
        try data.write(to: configFile, options: .atomic)

        configManager.load()

        XCTAssertEqual(configManager.config.profiles.count, 2)
        XCTAssertNotNil(configManager.config.profiles["general"])
        XCTAssertNotNil(configManager.config.profiles["coding"])
        XCTAssertEqual(
            configManager.config.profiles["coding"]?.displayName,
            "Coding"
        )

        let codingProfile = configManager.config.profiles["coding"]!
        for i in 1...Constants.numberOfKeys {
            let binding = codingProfile.keys[String(i)]!
            XCTAssertEqual(binding.action, "app_launch")
            XCTAssertEqual(binding.params["bundle_id"]?.stringValue, "com.test.app\(i)")
        }
    }

    func testReloadUpdatesSettings() throws {
        let configFile = tempDir.appendingPathComponent("config.json")
        let configManager = ConfigManager(filePath: configFile, directoryPath: tempDir)

        XCTAssertFalse(configManager.config.settings.launchAtLogin)
        XCTAssertTrue(configManager.config.settings.showOSD)

        var updatedConfig = configManager.config
        updatedConfig.settings.launchAtLogin = true
        updatedConfig.settings.showOSD = false

        let data = try encoder.encode(updatedConfig)
        try data.write(to: configFile, options: .atomic)

        configManager.load()

        XCTAssertTrue(configManager.config.settings.launchAtLogin)
        XCTAssertFalse(configManager.config.settings.showOSD)
    }
}
