import Foundation

/// Conform to this and register in ActionRegistry to add new actions.
protocol ActionExecutable {
    static var actionType: String { get }
    func execute(params: [String: Any]) async throws
    func validate(params: [String: Any]) -> Bool

    /// Whether this action requires Accessibility permission.
    /// Checked centrally by ActionRegistry before calling execute().
    var requiresAccessibility: Bool { get }
}

extension ActionExecutable {
    var requiresAccessibility: Bool { false }
}

// MARK: - Errors

enum ActionError: Error, CustomStringConvertible {
    case unknownAction(String)
    case invalidParams(String, [String: Any])
    case executionFailed(String, Error)
    case accessibilityRequired

    var description: String {
        switch self {
        case .unknownAction(let action):
            return "Unknown action type: \(action)"
        case .invalidParams(let action, _):
            return "Invalid parameters for action: \(action)"
        case .executionFailed(let action, let error):
            return "Action '\(action)' failed: \(error)"
        case .accessibilityRequired:
            return "Accessibility permission required for this action"
        }
    }
}

// MARK: - Registry

/// This is the ONLY place where action type routing occurs.
final class ActionRegistry {
    static let shared = ActionRegistry()

    private var executors: [String: ActionExecutable] = [:]

    func register(_ executor: ActionExecutable) {
        executors[type(of: executor).actionType] = executor
    }

    func execute(action: String, params: [String: Any]) async throws {
        guard let executor = executors[action] else {
            throw ActionError.unknownAction(action)
        }
        guard executor.validate(params: params) else {
            throw ActionError.invalidParams(action, params)
        }
        if executor.requiresAccessibility {
            guard Permissions.isAccessibilityGranted() else {
                throw ActionError.accessibilityRequired
            }
        }
        try await executor.execute(params: params)
    }

    var registeredTypes: [String] {
        Array(executors.keys).sorted()
    }
}
