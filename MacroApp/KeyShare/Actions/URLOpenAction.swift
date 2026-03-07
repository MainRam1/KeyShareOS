import AppKit
import Foundation

final class URLOpenAction: ActionExecutable {

    static let actionType = "open_url"

    func validate(params: [String: Any]) -> Bool {
        guard let urlString = params["url"] as? String,
              let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    func execute(params: [String: Any]) async throws {
        guard let urlString = params["url"] as? String,
              let url = URL(string: urlString) else {
            throw ActionError.invalidParams(Self.actionType, params)
        }
        if !NSWorkspace.shared.open(url) {
            throw ActionError.executionFailed(
                Self.actionType,
                NSError(domain: "KeyShare", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to open URL: \(urlString)"])
            )
        }
    }
}
