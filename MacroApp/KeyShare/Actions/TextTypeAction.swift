import AppKit
import CoreGraphics
import Foundation

/// Types text via clipboard paste (default) or keystroke simulation.
/// Both methods require Accessibility.
final class TextTypeAction: ActionExecutable {

    static let actionType = "text_type"
    var requiresAccessibility: Bool { true }

    func validate(params: [String: Any]) -> Bool {
        guard params["text"] is String else { return false }
        if let method = params["method"] as? String {
            return method == "clipboard" || method == "keystroke"
        }
        return true // method defaults to "clipboard"
    }

    func execute(params: [String: Any]) async throws {
        guard let text = params["text"] as? String else {
            throw ActionError.invalidParams(Self.actionType, params)
        }

        let method = params["method"] as? String ?? "clipboard"

        switch method {
        case "keystroke":
            typeViaKeystrokes(text)
        default:
            typeViaClipboard(text)
        }
    }

    // MARK: - Clipboard Method

    private func typeViaClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Brief delay for pasteboard propagation
        usleep(50_000) // 50ms

        // Simulate Cmd+V
        try? KeyEventHelper.postKeyPress(keyCode: Constants.KeyCodes.v, flags: .maskCommand)
    }

    // MARK: - Keystroke Method

    private func typeViaKeystrokes(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)

        for char in text {
            let utf16 = Array(String(char).utf16)

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

            keyDown?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            keyUp?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)

            usleep(5_000) // 5ms between keystrokes for reliability
        }
    }
}
