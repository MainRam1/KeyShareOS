import XCTest
@testable import KeyShare

final class ProfileReorderTests: XCTestCase {

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

    func testDefaultOrderIsSorted() {
        XCTAssertEqual(
            profileManager.availableProfiles,
            configManager.config.profiles.keys.sorted()
        )
    }

    func testResolvedOrderWithNilProfileOrder() {
        XCTAssertNil(configManager.config.profileOrder)
        XCTAssertEqual(
            configManager.config.resolvedProfileOrder,
            configManager.config.profiles.keys.sorted()
        )
    }

    func testCustomOrderPersists() throws {
        try profileManager.addProfile(name: "alpha", displayName: "Alpha")
        try profileManager.addProfile(name: "beta", displayName: "Beta")

        let defaultProfile = configManager.config.profiles.keys.first { $0 != "alpha" && $0 != "beta" }!

        try profileManager.moveProfile(from: "beta", to: "alpha")

        let order = configManager.config.resolvedProfileOrder
        let betaIdx = order.firstIndex(of: "beta")!
        let alphaIdx = order.firstIndex(of: "alpha")!
        XCTAssertTrue(betaIdx < alphaIdx, "beta should appear before alpha after move")
        XCTAssertTrue(order.contains(defaultProfile))
    }

    func testResolvedOrderRemovesStaleEntries() throws {
        try profileManager.addProfile(name: "keep", displayName: "Keep")

        try configManager.mutateConfig { config in
            config.profileOrder = ["gone", "keep"] + config.profiles.keys.sorted()
        }

        let resolved = configManager.config.resolvedProfileOrder
        XCTAssertFalse(resolved.contains("gone"))
        XCTAssertTrue(resolved.contains("keep"))
    }

    func testResolvedOrderAppendsMissingEntries() throws {
        try profileManager.addProfile(name: "existing", displayName: "Existing")

        let existingKeys = Array(configManager.config.profiles.keys)
        try configManager.mutateConfig { config in
            config.profileOrder = [existingKeys.first!]
        }

        let resolved = configManager.config.resolvedProfileOrder
        for key in existingKeys {
            XCTAssertTrue(resolved.contains(key), "Missing key: \(key)")
        }
    }

    func testMoveProfileReorders() throws {
        try profileManager.addProfile(name: "a", displayName: "A")
        try profileManager.addProfile(name: "b", displayName: "B")
        try profileManager.addProfile(name: "c", displayName: "C")

        try profileManager.moveProfile(from: "c", to: "a")

        let order = profileManager.availableProfiles
        let cIdx = order.firstIndex(of: "c")!
        let aIdx = order.firstIndex(of: "a")!
        XCTAssertTrue(cIdx < aIdx, "c should be before a after move")
    }

    func testMoveProfileSameNoOp() throws {
        try profileManager.addProfile(name: "solo", displayName: "Solo")
        let before = profileManager.availableProfiles

        try profileManager.moveProfile(from: "solo", to: "solo")

        XCTAssertEqual(profileManager.availableProfiles, before)
    }

    func testMoveProfilePersistsThroughRoundTrip() throws {
        try profileManager.addProfile(name: "first", displayName: "First")
        try profileManager.addProfile(name: "second", displayName: "Second")

        try profileManager.moveProfile(from: "second", to: "first")

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(configManager.config)
        let decoded = try JSONDecoder().decode(MacroConfig.self, from: data)

        XCTAssertNotNil(decoded.profileOrder)
        XCTAssertEqual(decoded.resolvedProfileOrder, configManager.config.resolvedProfileOrder)
    }

    func testAddProfileAppendsToOrder() throws {
        let beforeCount = profileManager.availableProfiles.count

        try profileManager.addProfile(name: "newone", displayName: "New One")

        XCTAssertEqual(profileManager.availableProfiles.last, "newone")
        XCTAssertEqual(profileManager.availableProfiles.count, beforeCount + 1)
    }

    func testDeleteProfileRemovesFromOrder() throws {
        try profileManager.addProfile(name: "doomed", displayName: "Doomed")
        XCTAssertTrue(profileManager.availableProfiles.contains("doomed"))

        try profileManager.deleteProfile(name: "doomed")
        XCTAssertFalse(profileManager.availableProfiles.contains("doomed"))
        if let order = configManager.config.profileOrder {
            XCTAssertFalse(order.contains("doomed"))
        }
    }

    func testRenameProfileUpdatesDisplayName() throws {
        try profileManager.addProfile(name: "myprofile", displayName: "Old Name")

        try profileManager.renameProfile("myprofile", displayName: "New Name")

        XCTAssertEqual(configManager.config.profiles["myprofile"]?.displayName, "New Name")
    }

    func testRenameProfileEmptyNameThrows() throws {
        try profileManager.addProfile(name: "rp", displayName: "RP")

        XCTAssertThrowsError(try profileManager.renameProfile("rp", displayName: "   ")) { error in
            guard case ProfileError.invalidProfileName = error else {
                XCTFail("Expected invalidProfileName, got \(error)")
                return
            }
        }
    }

    func testRenameProfileMissingProfileThrows() {
        XCTAssertThrowsError(try profileManager.renameProfile("ghost", displayName: "Name")) { error in
            guard case ProfileError.profileNotFound = error else {
                XCTFail("Expected profileNotFound, got \(error)")
                return
            }
        }
    }

    func testRenameDoesNotAffectActiveProfile() throws {
        try profileManager.addProfile(name: "renamed", displayName: "Before")
        try profileManager.switchProfile(to: "renamed")
        let activeBefore = profileManager.activeProfile

        try profileManager.renameProfile("renamed", displayName: "After")

        XCTAssertEqual(profileManager.activeProfile, activeBefore)
        XCTAssertEqual(configManager.config.activeProfile, activeBefore)
    }

    func testRenameDoesNotAffectAutoSwitch() throws {
        try profileManager.addProfile(name: "astest", displayName: "AS")
        configManager.config.autoSwitch["com.test.App"] = "astest"

        try profileManager.renameProfile("astest", displayName: "New AS")

        XCTAssertEqual(configManager.config.autoSwitch["com.test.App"], "astest")
    }

    func testProfileOrderRoundTrip() throws {
        try profileManager.addProfile(name: "x", displayName: "X")
        try profileManager.addProfile(name: "y", displayName: "Y")
        try profileManager.addProfile(name: "z", displayName: "Z")

        try profileManager.moveProfile(from: "z", to: "x")

        let encoder = JSONEncoder()
        let data = try encoder.encode(configManager.config)
        let decoded = try JSONDecoder().decode(MacroConfig.self, from: data)

        XCTAssertEqual(decoded.profileOrder, configManager.config.profileOrder)
        XCTAssertEqual(decoded.resolvedProfileOrder, configManager.config.resolvedProfileOrder)
    }
}
