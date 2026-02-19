import Cocoa
import SwiftUI

/// Hosts the preferences window. Since KeyShare is LSUIElement (no Dock icon),
/// uses `NSApp.activate(ignoringOtherApps:)` to bring the window to front.
final class PreferencesWindowController {

    private var window: NSWindow?
    private let profileManager: ProfileManager
    private let configManager: ConfigManager

    init(profileManager: ProfileManager, configManager: ConfigManager) {
        self.profileManager = profileManager
        self.configManager = configManager
    }

    func showWindow() {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = PreferencesContentView(
            profileManager: profileManager,
            configManager: configManager
        )
        let hostingController = NSHostingController(rootView: contentView)

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "KeyShare Preferences"
        newWindow.setContentSize(NSSize(width: UIConstants.windowDefaultWidth, height: UIConstants.windowDefaultHeight))
        newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        newWindow.minSize = NSSize(width: UIConstants.windowMinWidth, height: UIConstants.windowMinHeight)
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        self.window = newWindow
    }
}
