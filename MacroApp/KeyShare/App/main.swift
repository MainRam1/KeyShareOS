import Cocoa

// KeyShare entry point.
// Using NSApplicationMain instead of @main App because:
// 1. LSUIElement menu bar apps work better with AppDelegate lifecycle
// 2. Targets macOS 13 (SwiftUI App lifecycle has quirks with LSUIElement)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
