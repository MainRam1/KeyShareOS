import AppKit
import Foundation

/// Launches or activates an app by bundle ID.
final class AppLaunchAction: ActionExecutable {

    static let actionType = "app_launch"

    func validate(params: [String: Any]) -> Bool {
        return params["bundle_id"] is String
    }

    func execute(params: [String: Any]) async throws {
        guard let bundleID = params["bundle_id"] as? String else {
            throw ActionError.invalidParams(Self.actionType, params)
        }

        // Check if already running — activate it
        if let runningApp = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleID }) {
            runningApp.activate(options: [.activateIgnoringOtherApps])
            return
        }

        // Not running — launch it
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleID
        ) else {
            throw ActionError.executionFailed(
                Self.actionType,
                NSError(domain: "KeyShare", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "App not found: \(bundleID)"])
            )
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                if let error = error {
                    continuation.resume(throwing: ActionError.executionFailed(Self.actionType, error))
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
