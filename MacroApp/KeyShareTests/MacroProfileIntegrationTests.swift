import XCTest
@testable import KeyShare

/// Records execution order for integration testing.
private final class TrackingMockAction: ActionExecutable {
    static let actionType = "tracking_mock"
    private(set) var executionLog: [(params: [String: Any], timestamp: Date)] = []

    var shouldValidate = true

    func validate(params: [String: Any]) -> Bool { shouldValidate }

    func execute(params: [String: Any]) async throws {
        executionLog.append((params: params, timestamp: Date()))
    }
}

class MacroProfileIntegrationTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacroProfileIntTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        super.tearDown()
    }

    private func makeConfigManager() -> ConfigManager {
        let configFile = tempDir.appendingPathComponent("config.json")
        return ConfigManager(filePath: configFile, directoryPath: tempDir)
    }

    // MARK: - Macro Execution

    func testStepsExecuteInOrder() async throws {
        let registry = ActionRegistry()
        let trackingAction = TrackingMockAction()
        registry.register(trackingAction)

        let steps: [[String: Any]] = [
            ["action": "tracking_mock", "params": ["step": "first"]],
            ["delay_ms": 50],
            ["action": "tracking_mock", "params": ["step": "second"]],
            ["delay_ms": 50],
            ["action": "tracking_mock", "params": ["step": "third"]],
        ]

        let startTime = Date()
        for step in steps {
            if let delayMs = step["delay_ms"] as? Int {
                let nanoseconds = UInt64(delayMs) * 1_000_000
                try await Task.sleep(nanoseconds: nanoseconds)
                continue
            }
            if let action = step["action"] as? String,
               let params = step["params"] as? [String: Any] {
                try await registry.execute(action: action, params: params)
            }
        }
        let totalElapsed = Date().timeIntervalSince(startTime)

        XCTAssertEqual(trackingAction.executionLog.count, 3)

        XCTAssertEqual(trackingAction.executionLog[0].params["step"] as? String, "first")
        XCTAssertEqual(trackingAction.executionLog[1].params["step"] as? String, "second")
        XCTAssertEqual(trackingAction.executionLog[2].params["step"] as? String, "third")

        for i in 1..<trackingAction.executionLog.count {
            XCTAssertGreaterThanOrEqual(
                trackingAction.executionLog[i].timestamp,
                trackingAction.executionLog[i - 1].timestamp,
                "Step \(i) should execute after step \(i - 1)"
            )
        }

        XCTAssertGreaterThanOrEqual(totalElapsed, 0.1, "Should wait at least 100ms for two delays")
    }

    func testDelayOnlySteps() async throws {
        let registry = ActionRegistry()
        let trackingAction = TrackingMockAction()
        registry.register(trackingAction)

        let steps: [[String: Any]] = [
            ["delay_ms": 20],
            ["delay_ms": 20],
        ]

        let startTime = Date()
        for step in steps {
            if let delayMs = step["delay_ms"] as? Int {
                let nanoseconds = UInt64(delayMs) * 1_000_000
                try await Task.sleep(nanoseconds: nanoseconds)
            }
        }
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertEqual(trackingAction.executionLog.count, 0)
        XCTAssertGreaterThanOrEqual(elapsed, 0.04)
    }

    func testUnknownActionRejected() async {
        let registry = ActionRegistry()

        do {
            try await registry.execute(action: "nonexistent", params: [:])
            XCTFail("Expected unknownAction error")
        } catch let error as ActionError {
            switch error {
            case .unknownAction(let action):
                XCTAssertEqual(action, "nonexistent")
            default:
                XCTFail("Expected unknownAction, got \(error)")
            }
        } catch {
            XCTFail("Expected ActionError, got \(error)")
        }
    }

    // MARK: - Profile Switching

    func testProfileSwitchUpdatesBindings() throws {
        let configManager = makeConfigManager()
        let profileManager = ProfileManager(configManager: configManager)

        XCTAssertEqual(profileManager.activeProfile, "general")
        let generalBindings = profileManager.getActiveProfileBindings()
        XCTAssertNotNil(generalBindings)
        for (_, binding) in generalBindings!.keys {
            XCTAssertEqual(binding.action, "none")
        }

        try profileManager.addProfile(name: "coding", displayName: "Coding")

        var codingKeys: [String: KeyBinding] = [:]
        for i in 1...Constants.numberOfKeys {
            codingKeys[String(i)] = KeyBinding(
                action: "keyboard_shortcut",
                params: [
                    "modifiers": AnyCodable(["cmd"]),
                    "key": AnyCodable(String(UnicodeScalar(96 + i)!)),
                ]
            )
        }
        configManager.config.profiles["coding"]?.keys = codingKeys

        try profileManager.switchProfile(to: "coding")
        XCTAssertEqual(profileManager.activeProfile, "coding")

        let activeBindings = profileManager.getActiveProfileBindings()
        XCTAssertNotNil(activeBindings)
        XCTAssertEqual(activeBindings!.displayName, "Coding")

        for i in 1...Constants.numberOfKeys {
            let binding = activeBindings!.keys[String(i)]!
            XCTAssertEqual(binding.action, "keyboard_shortcut")
            let expectedKey = String(UnicodeScalar(96 + i)!)
            XCTAssertEqual(binding.params["key"]?.stringValue, expectedKey)
        }
    }

    func testProfileSwitchPersists() throws {
        let configFile = tempDir.appendingPathComponent("config.json")
        let configManager = ConfigManager(filePath: configFile, directoryPath: tempDir)
        let profileManager = ProfileManager(configManager: configManager)

        try profileManager.addProfile(name: "design", displayName: "Design")
        try profileManager.switchProfile(to: "design")
        XCTAssertEqual(profileManager.activeProfile, "design")

        let configManager2 = ConfigManager(filePath: configFile, directoryPath: tempDir)
        let profileManager2 = ProfileManager(configManager: configManager2)

        XCTAssertEqual(configManager2.config.activeProfile, "design")
        XCTAssertEqual(profileManager2.activeProfile, "design")
        XCTAssertTrue(profileManager2.availableProfiles.contains("design"))
        XCTAssertTrue(profileManager2.availableProfiles.contains("general"))
    }

    func testAutoSwitchChain() throws {
        let configManager = makeConfigManager()
        let profileManager = ProfileManager(configManager: configManager)

        try profileManager.addProfile(name: "browser", displayName: "Browser")
        try profileManager.addProfile(name: "editor", displayName: "Editor")

        configManager.config.autoSwitch["com.apple.Safari"] = "browser"
        configManager.config.autoSwitch["com.microsoft.VSCode"] = "editor"

        let safariProfile = configManager.config.autoSwitch["com.apple.Safari"]!
        try profileManager.switchProfile(to: safariProfile)
        XCTAssertEqual(profileManager.activeProfile, "browser")

        let browserBindings = profileManager.getActiveProfileBindings()
        XCTAssertNotNil(browserBindings)
        XCTAssertEqual(browserBindings!.displayName, "Browser")

        let vscodeProfile = configManager.config.autoSwitch["com.microsoft.VSCode"]!
        try profileManager.switchProfile(to: vscodeProfile)
        XCTAssertEqual(profileManager.activeProfile, "editor")

        let editorBindings = profileManager.getActiveProfileBindings()
        XCTAssertNotNil(editorBindings)
        XCTAssertEqual(editorBindings!.displayName, "Editor")

        try profileManager.switchProfile(to: "general")
        XCTAssertEqual(profileManager.activeProfile, "general")

        let generalBindings = profileManager.getActiveProfileBindings()
        XCTAssertNotNil(generalBindings)
        XCTAssertEqual(generalBindings!.displayName, "General")
    }
}
