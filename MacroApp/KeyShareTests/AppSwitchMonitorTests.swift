import XCTest
@testable import KeyShare

class AppSwitchMonitorTests: XCTestCase {

    private var configManager: ConfigManager!
    private var profileManager: ProfileManager!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacroTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let configFile = tempDir.appendingPathComponent("config.json")
        configManager = ConfigManager(filePath: configFile, directoryPath: tempDir)
        profileManager = ProfileManager(configManager: configManager)
    }

    override func tearDown() {
        profileManager = nil
        configManager = nil
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        super.tearDown()
    }

    func testCreation() {
        let monitor = AppSwitchMonitor(
            profileManager: profileManager,
            configManager: configManager,
            browserMonitor: BrowserURLMonitor()
        )
        XCTAssertNotNil(monitor)
    }

    func testStartStopIdempotent() {
        let monitor = AppSwitchMonitor(
            profileManager: profileManager,
            configManager: configManager,
            browserMonitor: BrowserURLMonitor()
        )
        monitor.start()
        monitor.start()
        monitor.stop()
        monitor.stop()
    }

    // TODO: test that switching apps actually triggers profile change

    func testAutoSwitchRulesFromConfig() throws {
        try profileManager.addProfile(name: "safari", displayName: "Safari")
        configManager.config.autoSwitch["com.apple.Safari"] = "safari"
        XCTAssertEqual(configManager.config.autoSwitch["com.apple.Safari"], "safari")
    }

    func testUnknownBundleIDNoRule() {
        XCTAssertNil(configManager.config.autoSwitch["com.nonexistent.app"])
    }
}
