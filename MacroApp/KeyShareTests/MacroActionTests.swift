import XCTest
@testable import KeyShare

class MacroActionTests: XCTestCase {

    private let macroAction = MacroAction()

    // MARK: - Validation

    func testValidSteps() {
        let params: [String: Any] = [
            "steps": [
                ["action": "keyboard_shortcut", "params": ["modifiers": ["cmd"], "key": "c"]],
                ["delay_ms": 500],
                ["action": "app_launch", "params": ["bundle_id": "com.apple.Terminal"]],
            ] as [[String: Any]],
        ]
        XCTAssertTrue(macroAction.validate(params: params))
    }

    func testEmptyStepsInvalid() {
        XCTAssertFalse(macroAction.validate(params: ["steps": [] as [[String: Any]]]))
    }

    func testMissingStepsInvalid() {
        XCTAssertFalse(macroAction.validate(params: [:]))
    }

    func testBadStepInvalid() {
        let params: [String: Any] = [
            "steps": [["invalid_key": "value"]] as [[String: Any]],
        ]
        XCTAssertFalse(macroAction.validate(params: params))
    }

    func testDelayOnlyStep() {
        let params: [String: Any] = [
            "steps": [["delay_ms": 100]] as [[String: Any]],
        ]
        XCTAssertTrue(macroAction.validate(params: params))
    }

    func testActionType() {
        XCTAssertEqual(MacroAction.actionType, "macro")
    }

    func testMaxSteps() {
        XCTAssertEqual(MacroAction.maxSteps, 20)
    }

    // MARK: - Execution

    func testDelayTiming() async throws {
        let params: [String: Any] = [
            "steps": [["delay_ms": 10]] as [[String: Any]],
        ]

        let start = Date()
        try await macroAction.execute(params: params)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertGreaterThanOrEqual(elapsed, 0.01)
    }

    func testBadParamsThrows() async {
        let params: [String: Any] = ["not_steps": "invalid"]
        do {
            try await macroAction.execute(params: params)
            XCTFail("Expected error for invalid params")
        } catch {
            guard case ActionError.invalidParams = error else {
                XCTFail("Expected invalidParams error, got \(error)")
                return
            }
        }
    }

    func testNestedMacroSkipped() async throws {
        let params: [String: Any] = [
            "steps": [
                ["delay_ms": 10],
                ["action": "macro", "params": ["steps": [["delay_ms": 10]]]],
                ["delay_ms": 10],
            ] as [[String: Any]],
        ]
        try await macroAction.execute(params: params)
    }

    func testMultipleDelays() async throws {
        let params: [String: Any] = [
            "steps": [
                ["delay_ms": 10],
                ["delay_ms": 10],
                ["delay_ms": 10],
            ] as [[String: Any]],
        ]

        let start = Date()
        try await macroAction.execute(params: params)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertGreaterThanOrEqual(elapsed, 0.03)
    }

    func testRegisteredInRegistry() {
        ActionRegistry.shared.register(MacroAction())
        XCTAssertTrue(ActionRegistry.shared.registeredTypes.contains("macro"))
    }
}
