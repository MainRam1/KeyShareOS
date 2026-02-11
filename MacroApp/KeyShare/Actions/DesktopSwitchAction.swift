import CoreGraphics
import Foundation

/// Switches macOS Spaces via Ctrl+Arrow (relative) or Ctrl+N (absolute).
/// Requires Accessibility.
final class DesktopSwitchAction: ActionExecutable {

    static let actionType = "desktop_switch"
    var requiresAccessibility: Bool { true }

    func validate(params: [String: Any]) -> Bool {
        // Must have either "direction" (left/right) or "desktop" (1-9)
        if let direction = params["direction"] as? String {
            return direction == "left" || direction == "right"
        }
        if let desktop = params["desktop"] as? Int {
            return desktop >= 1 && desktop <= 9
        }
        return false
    }

    func execute(params: [String: Any]) async throws {
        if let direction = params["direction"] as? String {
            try switchRelative(direction: direction)
        } else if let desktop = params["desktop"] as? Int {
            try switchAbsolute(desktop: desktop)
        }
    }

    // MARK: - Relative Switching (Ctrl+Arrow, enabled by default)

    private func switchRelative(direction: String) throws {
        let arrowKey: CGKeyCode = direction == "left"
            ? Constants.KeyCodes.leftArrow
            : Constants.KeyCodes.rightArrow

        try KeyEventHelper.postKeyPress(keyCode: arrowKey, flags: .maskControl)
    }

    // MARK: - Absolute Switching (Ctrl+N, user must enable in System Settings)

    private func switchAbsolute(desktop: Int) throws {
        guard let numberKeyCode = Constants.KeyCodes.numberKey(desktop) else { return }

        try KeyEventHelper.postKeyPress(keyCode: numberKeyCode, flags: .maskControl)
    }
}
