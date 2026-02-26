import XCTest
@testable import KeyShare

final class OSDOverlayTests: XCTestCase {

    func testSharedExists() {
        XCTAssertNotNil(OSDOverlay.shared)
    }

    func testShowAndDismiss() {
        OSDOverlay.shared.show(profileName: "Test")
        OSDOverlay.shared.dismiss()
    }

    func testRapidShowCalls() {
        OSDOverlay.shared.show(profileName: "Profile 1")
        OSDOverlay.shared.show(profileName: "Profile 2")
        OSDOverlay.shared.show(profileName: "Profile 3")
        OSDOverlay.shared.dismiss()
    }

    func testDismissWithoutShow() {
        OSDOverlay.shared.dismiss()
    }
}
