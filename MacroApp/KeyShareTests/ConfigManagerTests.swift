import XCTest
@testable import KeyShare

final class ConfigManagerTests: XCTestCase {

    // MARK: - Defaults

    func testDefaultConfig() {
        let config = ConfigManager.defaultConfig()
        XCTAssertEqual(config.version, 1)
        XCTAssertEqual(config.activeProfile, "general")
        XCTAssertTrue(config.autoSwitch.isEmpty)
        XCTAssertFalse(config.settings.launchAtLogin)
        XCTAssertTrue(config.settings.showOSD)

        let profile = config.profiles["general"]!
        XCTAssertEqual(profile.displayName, "General")
        XCTAssertEqual(profile.keys.count, Constants.numberOfKeys)
        for i in 1...Constants.numberOfKeys {
            XCTAssertNotNil(profile.keys[String(i)], "Missing key \(i)")
        }
    }

    func testDefaultKeysAreNone() {
        let config = ConfigManager.defaultConfig()
        let profile = config.profiles["general"]!
        for (_, binding) in profile.keys {
            XCTAssertEqual(binding.action, "none")
            XCTAssertTrue(binding.params.isEmpty)
        }
    }

    // MARK: - ConfigError

    func testConfigErrorDescriptions() {
        let url = URL(fileURLWithPath: "/test")
        let underlying = NSError(domain: "test", code: 42)

        let errors: [ConfigError] = [
            .fileReadFailed(url, underlying),
            .fileWriteFailed(url, underlying),
            .decodingFailed(underlying),
            .encodingFailed(underlying),
            .validationFailed("test reason"),
            .directoryCreationFailed(url, underlying),
        ]

        for error in errors {
            XCTAssertFalse(error.description.isEmpty, "Error should have description: \(error)")
        }
    }

    func testValidationFailedIncludesReason() {
        let error = ConfigError.validationFailed("profiles empty")
        XCTAssertTrue(error.description.contains("profiles empty"))
    }

    func testDefaultConfigRoundTrips() throws {
        let config = ConfigManager.defaultConfig()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(MacroConfig.self, from: data)
        XCTAssertEqual(config, decoded)
    }

    // MARK: - Export/Import

    func testExportProfile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacroTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configFile = tempDir.appendingPathComponent("config.json")
        let cm = ConfigManager(filePath: configFile, directoryPath: tempDir)

        let data = try cm.exportProfile(name: "general")
        XCTAssertFalse(data.isEmpty)

        let decoded = try JSONDecoder().decode(Profile.self, from: data)
        XCTAssertEqual(decoded.displayName, "General")
    }

    func testExportMissingProfileThrows() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacroTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configFile = tempDir.appendingPathComponent("config.json")
        let cm = ConfigManager(filePath: configFile, directoryPath: tempDir)

        XCTAssertThrowsError(try cm.exportProfile(name: "nonexistent"))
    }

    func testImportRoundTrip() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacroTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configFile = tempDir.appendingPathComponent("config.json")
        let cm = ConfigManager(filePath: configFile, directoryPath: tempDir)

        let data = try cm.exportProfile(name: "general")
        let imported = try cm.decodeImportedProfile(from: data)
        XCTAssertEqual(imported.displayName, "General")
        XCTAssertEqual(imported.keys.count, Constants.numberOfKeys)
    }

    func testImportBadJSONThrows() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacroTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configFile = tempDir.appendingPathComponent("config.json")
        let cm = ConfigManager(filePath: configFile, directoryPath: tempDir)

        let invalidData = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try cm.decodeImportedProfile(from: invalidData))
    }
}
