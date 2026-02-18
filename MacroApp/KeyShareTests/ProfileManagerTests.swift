import XCTest
@testable import KeyShare

final class ProfileManagerTests: XCTestCase {

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

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertFalse(profileManager.activeProfile.isEmpty)
        XCTAssertFalse(profileManager.availableProfiles.isEmpty)
        XCTAssertEqual(profileManager.availableProfiles, profileManager.availableProfiles.sorted())
        XCTAssertTrue(profileManager.availableProfiles.contains(profileManager.activeProfile))
    }

    // MARK: - Switching

    func testSwitchProfile() throws {
        try profileManager.addProfile(name: "test", displayName: "Test")
        try profileManager.switchProfile(to: "test")
        XCTAssertEqual(profileManager.activeProfile, "test")
    }

    func testSwitchToMissingProfileThrows() {
        XCTAssertThrowsError(try profileManager.switchProfile(to: "nonexistent")) { error in
            guard case ProfileError.profileNotFound = error else {
                XCTFail("Expected profileNotFound, got \(error)")
                return
            }
        }
    }

    // MARK: - Adding

    func testAddProfile() throws {
        try profileManager.addProfile(name: "coding", displayName: "Coding")
        XCTAssertTrue(profileManager.availableProfiles.contains("coding"))

        let profile = configManager.config.profiles["coding"]
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.keys.count, Constants.numberOfKeys)
    }

    func testAddDuplicateThrows() throws {
        try profileManager.addProfile(name: "dup", displayName: "Dup")
        XCTAssertThrowsError(try profileManager.addProfile(name: "dup", displayName: "Dup2")) { error in
            guard case ProfileError.profileAlreadyExists = error else {
                XCTFail("Expected profileAlreadyExists, got \(error)")
                return
            }
        }
    }

    func testAddBadNameThrows() {
        XCTAssertThrowsError(try profileManager.addProfile(name: "", displayName: "Empty")) { error in
            guard case ProfileError.invalidProfileName = error else {
                XCTFail("Expected invalidProfileName, got \(error)")
                return
            }
        }

        XCTAssertThrowsError(try profileManager.addProfile(name: "  ", displayName: "Spaces")) { error in
            guard case ProfileError.invalidProfileName = error else {
                XCTFail("Expected invalidProfileName, got \(error)")
                return
            }
        }
    }

    // MARK: - Deleting

    func testDeleteProfile() throws {
        try profileManager.addProfile(name: "deleteme", displayName: "Delete Me")
        try profileManager.deleteProfile(name: "deleteme")
        XCTAssertFalse(profileManager.availableProfiles.contains("deleteme"))
    }

    func testDeleteActiveProfileThrows() throws {
        try profileManager.addProfile(name: "extra", displayName: "Extra")
        XCTAssertThrowsError(try profileManager.deleteProfile(name: profileManager.activeProfile)) { error in
            guard case ProfileError.cannotDeleteActiveProfile = error else {
                XCTFail("Expected cannotDeleteActiveProfile, got \(error)")
                return
            }
        }
    }

    func testDeleteLastProfileThrows() {
        XCTAssertThrowsError(try profileManager.deleteProfile(name: profileManager.activeProfile)) { error in
            XCTAssertTrue(error is ProfileError)
        }
    }

    func testDeleteMissingProfileThrows() {
        XCTAssertThrowsError(try profileManager.deleteProfile(name: "ghost")) { error in
            guard case ProfileError.profileNotFound = error else {
                XCTFail("Expected profileNotFound, got \(error)")
                return
            }
        }
    }

    func testDeleteCleansAutoSwitch() throws {
        try profileManager.addProfile(name: "safari", displayName: "Safari")
        configManager.config.autoSwitch["com.apple.Safari"] = "safari"
        try profileManager.deleteProfile(name: "safari")
        XCTAssertNil(configManager.config.autoSwitch["com.apple.Safari"])
    }

    // MARK: - Bindings

    func testActiveBindings() {
        let bindings = profileManager.getActiveProfileBindings()
        XCTAssertNotNil(bindings)
        XCTAssertEqual(bindings?.keys.count, Constants.numberOfKeys)
    }

    func testProfileErrorDescriptions() {
        let errors: [ProfileError] = [
            .profileNotFound("test"),
            .profileAlreadyExists("test"),
            .cannotDeleteActiveProfile("test"),
            .cannotDeleteLastProfile,
            .invalidProfileName(""),
        ]

        for error in errors {
            XCTAssertFalse(error.description.isEmpty, "Error should have description: \(error)")
        }
    }
}
