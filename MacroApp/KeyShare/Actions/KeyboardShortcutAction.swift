import CoreGraphics
import Foundation

/// Posts CGEvent key events. Requires Accessibility.
final class KeyboardShortcutAction: ActionExecutable {

    static let actionType = "keyboard_shortcut"
    var requiresAccessibility: Bool { true }

    func validate(params: [String: Any]) -> Bool {
        guard params["key"] is String else { return false }
        // modifiers is optional (can be empty for single key)
        if let modifiers = params["modifiers"] {
            guard modifiers is [String] else { return false }
        }
        return true
    }

    func execute(params: [String: Any]) async throws {
        guard let keyName = params["key"] as? String,
              let keyCode = Constants.KeyCodes.fromName(keyName) else {
            throw ActionError.invalidParams(Self.actionType, params)
        }

        let modifierNames = params["modifiers"] as? [String] ?? []
        let flags = Constants.KeyCodes.modifierFlags(from: modifierNames)

        try KeyEventHelper.postKeyPress(keyCode: keyCode, flags: flags)
    }
}
