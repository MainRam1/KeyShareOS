import CoreGraphics
import Foundation

/// All key press simulation goes through here.
enum KeyEventHelper {

    static func postKeyPress(keyCode: CGKeyCode, flags: CGEventFlags = []) throws {
        let source = CGEventSource(stateID: .combinedSessionState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            throw ActionError.executionFailed(
                "CGEvent creation failed for keyCode \(keyCode)",
                NSError(domain: "KeyEventHelper", code: -1)
            )
        }

        if !flags.isEmpty {
            keyDown.flags = flags
            keyUp.flags = flags
        }

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
