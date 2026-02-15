import AppKit
import Foundation
import os

/// Auto-switches profiles when the active app matches an autoSwitch rule.
///
/// API constraints:
/// - Must use NSWorkspace.shared.notificationCenter (NOT NotificationCenter.default).
/// - Block-based observers are NOT auto-removed; must removeObserver in deinit.
final class AppSwitchMonitor {

    private let profileManager: ProfileManager
    private let configManager: ConfigManager
    private var observer: NSObjectProtocol?

    init(profileManager: ProfileManager, configManager: ConfigManager) {
        self.profileManager = profileManager
        self.configManager = configManager
    }

    func start() {
        guard observer == nil else { return }

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }

        Log.profiles.info("AppSwitchMonitor: started monitoring active application changes")
    }

    func stop() {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
            Log.profiles.info("AppSwitchMonitor: stopped monitoring")
        }
    }

    deinit {
        // Block-based observers are NOT auto-removed
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func handleAppActivation(_ notification: Notification) {
        // Extract the activated application from the notification's userInfo
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else {
            Log.profiles.warning("AppSwitchMonitor: could not extract NSRunningApplication from notification")
            return
        }

        // Some system processes have nil bundleIdentifier — guard against it
        guard let bundleID = app.bundleIdentifier else {
            return
        }

        // Look up the bundle ID in the auto-switch rules
        let autoSwitchRules = configManager.config.autoSwitch
        guard let targetProfile = autoSwitchRules[bundleID] else {
            return
        }

        // Only switch if we are not already on the target profile
        guard profileManager.activeProfile != targetProfile else {
            return
        }

        do {
            try profileManager.switchProfile(to: targetProfile)
            Log.profiles.info("AppSwitchMonitor: auto-switched to profile '\(targetProfile)' for app '\(bundleID)'")
        } catch {
            Log.profiles.error("AppSwitchMonitor: failed to auto-switch to profile '\(targetProfile)' for app '\(bundleID)': \(String(describing: error))")
        }
    }
}
