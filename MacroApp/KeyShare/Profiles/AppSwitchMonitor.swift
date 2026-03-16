import AppKit
import Combine
import Foundation
import os

final class AppSwitchMonitor {

    private let profileManager: ProfileManager
    private let configManager: ConfigManager
    private let browserMonitor: BrowserURLMonitor
    private var observer: NSObjectProtocol?
    private var domainCancellable: AnyCancellable?

    init(profileManager: ProfileManager, configManager: ConfigManager, browserMonitor: BrowserURLMonitor) {
        self.profileManager = profileManager
        self.configManager = configManager
        self.browserMonitor = browserMonitor
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

        domainCancellable = browserMonitor.$activeDomain
            .receive(on: DispatchQueue.main)
            .sink { [weak self] domain in
                self?.handleDomainChange(domain)
            }

        browserMonitor.start()

        Log.profiles.info("AppSwitchMonitor: started monitoring active application and website changes")
    }

    func stop() {
        browserMonitor.stop()
        domainCancellable?.cancel()
        domainCancellable = nil

        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
            Log.profiles.info("AppSwitchMonitor: stopped monitoring")
        }
    }

    deinit {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func handleDomainChange(_ domain: String?) {
        guard let domain = domain else { return }

        let websiteRules = configManager.config.websiteSwitch ?? [:]
        guard let targetProfile = websiteRules[domain] else { return }

        guard profileManager.activeProfile != targetProfile else { return }

        do {
            try profileManager.switchProfile(to: targetProfile)
            Log.profiles.info("AppSwitchMonitor: website-switched to profile '\(targetProfile)' for domain '\(domain)'")
        } catch {
            Log.profiles.error("AppSwitchMonitor: failed to website-switch to '\(targetProfile)' for domain '\(domain)': \(String(describing: error))")
        }
    }

    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else {
            Log.profiles.warning("AppSwitchMonitor: could not extract NSRunningApplication from notification")
            return
        }

        guard let bundleID = app.bundleIdentifier else {
            return
        }

        if Constants.supportedBrowsers.contains(bundleID) {
            if let domain = browserMonitor.queryCurrentDomain() {
                let websiteRules = configManager.config.websiteSwitch ?? [:]
                if let targetProfile = websiteRules[domain] {
                    if profileManager.activeProfile != targetProfile {
                        do {
                            try profileManager.switchProfile(to: targetProfile)
                            Log.profiles.info("AppSwitchMonitor: website-switched to profile '\(targetProfile)' for domain '\(domain)'")
                        } catch {
                            Log.profiles.error("AppSwitchMonitor: failed to website-switch: \(String(describing: error))")
                        }
                    }
                    return
                }
            }
        }

        let autoSwitchRules = configManager.config.autoSwitch
        guard let targetProfile = autoSwitchRules[bundleID] else {
            return
        }

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
