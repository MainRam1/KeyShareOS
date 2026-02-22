import Foundation
import os

/// Executes multi-step macro sequences with delays.
/// Each step is either an action (dispatched via ActionRegistry) or a delay.
final class MacroAction: ActionExecutable {

    static let actionType: String = "macro"

    static let maxSteps: Int = 20

    func execute(params: [String: Any]) async throws {
        guard let steps = params["steps"] as? [[String: Any]] else {
            throw ActionError.invalidParams("macro", params)
        }

        guard steps.count <= Self.maxSteps else {
            Log.actions.warning("MacroAction: step count \(steps.count) exceeds max \(Self.maxSteps), truncating")
            let truncated = Array(steps.prefix(Self.maxSteps))
            try await executeSteps(truncated)
            return
        }

        try await executeSteps(steps)
    }

    func validate(params: [String: Any]) -> Bool {
        guard let steps = params["steps"] as? [[String: Any]] else {
            return false
        }

        // Validate each step is either an action or a delay
        for step in steps {
            let hasAction = step["action"] is String
            let hasDelay = step["delay_ms"] is Int || step["delay_ms"] is Double
            if !hasAction && !hasDelay {
                return false
            }
        }

        return !steps.isEmpty
    }

    // MARK: - Private

    private func executeSteps(_ steps: [[String: Any]]) async throws {
        for (index, step) in steps.enumerated() {
            if let delayMs = step["delay_ms"] as? Int {
                // Delay step
                let nanoseconds = UInt64(delayMs) * 1_000_000
                try await Task.sleep(nanoseconds: nanoseconds)
                continue
            }

            if let delayMs = step["delay_ms"] as? Double {
                let nanoseconds = UInt64(delayMs * 1_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                continue
            }

            // Action step
            guard let action = step["action"] as? String else {
                Log.actions.warning("MacroAction: step \(index) has no action or delay_ms, skipping")
                continue
            }

            // Prevent recursive macro execution (no nested macros)
            guard action != Self.actionType else {
                Log.actions.warning("MacroAction: nested macro at step \(index) ignored (recursion not allowed)")
                continue
            }

            let stepParams = step["params"] as? [String: Any] ?? [:]

            do {
                try await ActionRegistry.shared.execute(action: action, params: stepParams)
            } catch {
                Log.actions.error("MacroAction: step \(index) (\(action)) failed: \(String(describing: error))")
                // Continue executing remaining steps on error (best-effort)
            }
        }
    }
}
