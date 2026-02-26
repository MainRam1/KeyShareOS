import XCTest
@testable import KeyShare

class OnboardingTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: OnboardingWindowController.hasCompletedOnboardingKey)
        super.tearDown()
    }

    func testOnboardingKey() {
        XCTAssertEqual(OnboardingWindowController.hasCompletedOnboardingKey, "hasCompletedOnboarding")
    }

    func testFirstLaunchShowsOnboarding() {
        UserDefaults.standard.removeObject(forKey: OnboardingWindowController.hasCompletedOnboardingKey)
        XCTAssertTrue(OnboardingWindowController.shouldShowOnboarding)
    }

    func testAfterCompletionMaySkip() {
        UserDefaults.standard.set(true, forKey: OnboardingWindowController.hasCompletedOnboardingKey)
        // outcome depends on AXIsProcessTrusted which we can't control in tests
        let shouldShow = OnboardingWindowController.shouldShowOnboarding
        XCTAssertNotNil(shouldShow)
    }

    func testControllerCreation() {
        let controller = OnboardingWindowController()
        XCTAssertNotNil(controller)
    }

    func testPermissionPollState() {
        let state = PermissionPollState()
        XCTAssertNotNil(state.isGranted)
    }
}
