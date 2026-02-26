import XCTest
@testable import KeyShare

final class MediaControlActionTests: XCTestCase {

    private let action = MediaControlAction()

    func testActionType() {
        XCTAssertEqual(MediaControlAction.actionType, "media_control")
    }

    // MARK: - Validation

    func testAllValidActions() {
        for name in ["play_pause", "next", "prev", "vol_up", "vol_down", "mute"] {
            XCTAssertTrue(action.validate(params: ["action": name]), "\(name) should be valid")
        }
    }

    func testInvalidActions() {
        XCTAssertFalse(action.validate(params: ["action": "rewind"]))
        XCTAssertFalse(action.validate(params: [:]))
        XCTAssertFalse(action.validate(params: ["action": 123]))
    }

    // MARK: - Constants

    func testMediaKeysDistinct() {
        let keys: [UInt32] = [
            Constants.MediaKeys.play,
            Constants.MediaKeys.next,
            Constants.MediaKeys.previous,
            Constants.MediaKeys.soundUp,
            Constants.MediaKeys.soundDown,
            Constants.MediaKeys.mute,
        ]
        XCTAssertEqual(Set(keys).count, keys.count, "All media key codes should be distinct")
    }

    func testMediaKeyValues() {
        XCTAssertEqual(Constants.MediaKeys.soundUp, 0)
        XCTAssertEqual(Constants.MediaKeys.soundDown, 1)
        XCTAssertEqual(Constants.MediaKeys.mute, 7)
        XCTAssertEqual(Constants.MediaKeys.play, 16)
        XCTAssertEqual(Constants.MediaKeys.next, 17)
        XCTAssertEqual(Constants.MediaKeys.previous, 18)
    }

    // MARK: - Player Bundle IDs

    func testKnownPlayers() {
        XCTAssertTrue(Constants.mediaPlayerBundleIDs.contains("com.spotify.client"))
        XCTAssertTrue(Constants.mediaPlayerBundleIDs.contains("com.apple.Music"))
    }

    func testBrowsersExcluded() {
        XCTAssertFalse(Constants.mediaPlayerBundleIDs.contains("com.google.Chrome"))
        XCTAssertFalse(Constants.mediaPlayerBundleIDs.contains("com.apple.Safari"))
        XCTAssertFalse(Constants.mediaPlayerBundleIDs.contains("org.mozilla.firefox"))
    }

    func testPlayerListNotEmpty() {
        XCTAssertFalse(Constants.mediaPlayerBundleIDs.isEmpty)
        XCTAssertGreaterThanOrEqual(Constants.mediaPlayerBundleIDs.count, 10)
    }
}
