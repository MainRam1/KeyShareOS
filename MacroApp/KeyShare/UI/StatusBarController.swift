import Cocoa
import Combine
import os

/// Owns the NSStatusItem and its menu. Watches ProfileManager and SerialDeviceManager to keep the menu updated.
final class StatusBarController: NSObject {

    /// Strong reference -- system does NOT retain the status item.
    private let statusItem: NSStatusItem
    private let profileManager: ProfileManager
    private let serialManager: SerialDeviceManager
    private let configManager: ConfigManager
    private var cancellables = Set<AnyCancellable>()
    private var isDeviceConnected: Bool = false

    /// Created lazily on first open.
    private var preferencesWindowController: PreferencesWindowController?

    // MARK: - Menu Item Tags

    private enum MenuTag {
        static let profileHeader = 100
        static let profileItemBase = 200
    }

    // MARK: - SF Symbol Names

    private enum SymbolName {
        static let connected = "keyboard"
        static let disconnected = "keyboard.badge.ellipsis"
    }

    init(
        profileManager: ProfileManager,
        serialManager: SerialDeviceManager,
        configManager: ConfigManager
    ) {
        self.profileManager = profileManager
        self.serialManager = serialManager
        self.configManager = configManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        super.init()

        configureButton()
        buildMenu()
        subscribeToProfileChanges()
        subscribeToConnectionState()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        let symbolName = serialManager.isConnected
            ? SymbolName.connected
            : SymbolName.disconnected
        applyIcon(symbolName: symbolName, to: button)
        isDeviceConnected = serialManager.isConnected
    }

    private func applyIcon(symbolName: String, to button: NSStatusBarButton) {
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "KeyShare"
        )
        image?.isTemplate = true
        button.image = image
    }

    // MARK: - Menu Construction

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // -- Profile header
        let headerTitle = "Profile: \(profileManager.activeProfile)"
        let headerItem = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
        headerItem.tag = MenuTag.profileHeader
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // -- Profile list (radio-style selection)
        for (index, profileName) in profileManager.availableProfiles.enumerated() {
            let item = NSMenuItem(
                title: displayName(for: profileName),
                action: #selector(profileMenuItemClicked(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = MenuTag.profileItemBase + index
            item.representedObject = profileName
            item.state = (profileName == profileManager.activeProfile) ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // -- Preferences
        let prefsItem = NSMenuItem(
            title: "Preferences\u{2026}",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        // -- Quit
        let quitItem = NSMenuItem(
            title: "Quit KeyShare",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    /// Returns the display name for a profile, falling back to the raw key.
    private func displayName(for profileName: String) -> String {
        return configManager.config.profiles[profileName]?.displayName ?? profileName
    }

    // MARK: - Menu Actions

    @objc private func profileMenuItemClicked(_ sender: NSMenuItem) {
        guard let profileName = sender.representedObject as? String else { return }

        do {
            try profileManager.switchProfile(to: profileName)
        } catch {
            Log.general.error("StatusBarController: failed to switch profile: \(String(describing: error))")
        }
    }

    @objc private func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(
                profileManager: profileManager,
                configManager: configManager
            )
        }
        preferencesWindowController?.showWindow()
    }

    // MARK: - Reactive Subscriptions

    /// Rebuilds the menu when profiles change.
    private func subscribeToProfileChanges() {
        // Merge both publishers so any profile change triggers a single rebuild.
        profileManager.$activeProfile
            .combineLatest(profileManager.$availableProfiles)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.buildMenu()
            }
            .store(in: &cancellables)
    }

    private func subscribeToConnectionState() {
        serialManager.onConnectionStateChanged = { [weak self] connected in
            DispatchQueue.main.async {
                self?.updateConnectionIcon(connected: connected)
            }
        }
    }

    private func updateConnectionIcon(connected: Bool) {
        guard connected != isDeviceConnected else { return }
        isDeviceConnected = connected

        guard let button = statusItem.button else { return }

        let symbolName = connected ? SymbolName.connected : SymbolName.disconnected
        applyIcon(symbolName: symbolName, to: button)

        Log.general.info("StatusBarController: device \(connected ? "connected" : "disconnected")")
    }
}
