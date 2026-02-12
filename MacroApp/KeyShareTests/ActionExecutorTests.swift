import XCTest
@testable import KeyShare

final class MockAction: ActionExecutable {
    static let actionType = "mock_action"
    var executedParams: [String: Any]?
    var shouldValidate = true

    func validate(params: [String: Any]) -> Bool { shouldValidate }
    func execute(params: [String: Any]) async throws { executedParams = params }
}

class ActionExecutorTests: XCTestCase {

    func testRegisterAndExecute() async throws {
        let registry = ActionRegistry()
        let mock = MockAction()
        registry.register(mock)

        try await registry.execute(action: "mock_action", params: ["key": "value"])

        XCTAssertNotNil(mock.executedParams)
        XCTAssertEqual(mock.executedParams?["key"] as? String, "value")
    }

    func testRegisteredTypes() {
        let registry = ActionRegistry()
        let mock = MockAction()
        registry.register(mock)
        XCTAssertEqual(registry.registeredTypes, ["mock_action"])
    }

    func testRegisteredTypesSorted() {
        let registry = ActionRegistry()
        registry.register(KeyboardShortcutAction())
        registry.register(AppLaunchAction())
        registry.register(MediaControlAction())

        let types = registry.registeredTypes
        XCTAssertEqual(types, types.sorted())
    }

    func testUnknownActionThrows() async {
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

    func testInvalidParamsThrows() async {
        let registry = ActionRegistry()
        let mock = MockAction()
        mock.shouldValidate = false
        registry.register(mock)

        do {
            try await registry.execute(action: "mock_action", params: ["bad": "data"])
            XCTFail("Expected invalidParams error")
        } catch let error as ActionError {
            switch error {
            case .invalidParams(let action, _):
                XCTAssertEqual(action, "mock_action")
            default:
                XCTFail("Expected invalidParams, got \(error)")
            }
        } catch {
            XCTFail("Expected ActionError, got \(error)")
        }
    }

    func testEmptyRegistry() {
        let registry = ActionRegistry()
        XCTAssertTrue(registry.registeredTypes.isEmpty)
    }
}
