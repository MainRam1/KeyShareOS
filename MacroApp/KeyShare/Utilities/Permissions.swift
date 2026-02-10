import ApplicationServices
import Foundation

enum Permissions {

    static func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    /// When `prompt` is true, macOS shows the system dialog if not trusted.
    @discardableResult
    static func checkAccessibility(prompt: Bool = false) -> Bool {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }
}
