import ApplicationServices
import Cocoa
import Combine
import os

/// Application lifecycle manager and composition root.
/// All dependencies are created here and injected into components.
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Dependencies (composition root)

    private var configManager: ConfigManager!
    private var profileManager: ProfileManager!
    private var serialManager: SerialDeviceManager!
    private var statusBarController: StatusBarController!
    private var appSwitchMonitor: AppSwitchMonitor!
    private var deviceMonitor: DeviceMonitor!
    private var onboardingController: OnboardingWindowController?
    private var osdCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        // Register all action executors (including macro)
        ActionRegistry.shared.register(KeyboardShortcutAction())
        ActionRegistry.shared.register(AppLaunchAction())
        ActionRegistry.shared.register(TextTypeAction())
        ActionRegistry.shared.register(DesktopSwitchAction())
        ActionRegistry.shared.register(MediaControlAction())
        ActionRegistry.shared.register(URLOpenAction())
        ActionRegistry.shared.register(MacroAction())

        Log.general.info("Registered action types: \(ActionRegistry.shared.registeredTypes.joined(separator: ", "))")

        // Configuration & Profiles — dependency injection chain
        configManager = ConfigManager()
        profileManager = ProfileManager(configManager: configManager)
        serialManager = SerialDeviceManager()

        // Wire key press handling through ProfileManager
        serialManager.onDeviceMessage = { [weak self] message in
            guard let self = self else { return }

            if case .keyPress(let key) = message {
                guard let profile = self.profileManager.getActiveProfileBindings() else {
                    Log.actions.warning("No active profile bindings found")
                    return
                }

                guard let binding = profile.keys[String(key)] else {
                    #if DEBUG
                    Log.actions.debug("Key \(key) has no binding in profile '\(self.profileManager.activeProfile)'")
                    #endif
                    return
                }

                guard binding.action != "none" else { return }

                Task {
                    do {
                        try await ActionRegistry.shared.execute(
                            action: binding.action,
                            params: binding.actionParams
                        )
                        #if DEBUG
                        Log.actions.debug("Executed action '\(binding.action)' for key \(key)")
                        #endif
                    } catch {
                        Log.actions.error("Action '\(binding.action)' failed for key \(key): \(String(describing: error))")
                    }
                }
            }
        }

        // Status bar (menu bar icon + menu)
        statusBarController = StatusBarController(
            profileManager: profileManager,
            serialManager: serialManager,
            configManager: configManager
        )

        // Auto-switch monitor (watches active app)
        appSwitchMonitor = AppSwitchMonitor(
            profileManager: profileManager,
            configManager: configManager
        )
        appSwitchMonitor.start()

        // Device monitor (sleep/wake recovery)
        deviceMonitor = DeviceMonitor(serialManager: serialManager)
        deviceMonitor.start()

        // OSD overlay on profile switch (if enabled in settings)
        osdCancellable = profileManager.$activeProfile
            .dropFirst() // Skip initial value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profileName in
                guard let self = self else { return }
                if self.configManager.config.settings.showOSD {
                    let displayName = self.configManager.config.profiles[profileName]?.displayName
                        ?? profileName
                    OSDOverlay.shared.show(profileName: displayName)
                }
            }

        // Start device scanning
        serialManager.startScanning()

        // First-launch onboarding (if needed)
        if OnboardingWindowController.shouldShowOnboarding {
            onboardingController = OnboardingWindowController()
            onboardingController?.showWindow()
        } else {
            // Just check accessibility silently
            let granted = Permissions.checkAccessibility(prompt: false)
            Log.general.info("Accessibility permission: \(granted ? "granted" : "not granted")")
        }

        Log.general.info("KeyShare launched — config loaded from \(Constants.configFilePath.path)")
        Log.general.info("Active profile: \(self.profileManager.activeProfile)")
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = NSMenu()
        mainMenu.addItem(appMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    func applicationWillTerminate(_ notification: Notification) {
        deviceMonitor.stop()
        appSwitchMonitor.stop()
        serialManager.stopScanning()
        OSDOverlay.shared.dismiss()
    }
}
