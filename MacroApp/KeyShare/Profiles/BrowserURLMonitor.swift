import AppKit
import ApplicationServices
import Combine
import CoreServices
import Foundation
import os

final class BrowserURLMonitor: ObservableObject {

    @Published private(set) var activeDomain: String?

    private var observers: [pid_t: AXObserver] = [:]
    private var appElements: [pid_t: AXUIElement] = [:]
    private var browserPIDs: [String: pid_t] = [:]
    private var debounceWorkItem: DispatchWorkItem?
    private var workspaceObservers: [NSObjectProtocol] = []

    private static let debounceInterval: TimeInterval = 0.15

    func start() {
        guard workspaceObservers.isEmpty else { return }

        let activateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
        workspaceObservers.append(activateObserver)

        let terminateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppTermination(notification)
        }
        workspaceObservers.append(terminateObserver)

        for app in NSWorkspace.shared.runningApplications {
            if let bundleID = app.bundleIdentifier,
               Constants.supportedBrowsers.contains(bundleID) {
                attachObserver(to: app)
            }
        }

        Log.profiles.info("BrowserURLMonitor: started")
    }

    func stop() {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()

        for pid in Array(observers.keys) {
            detachObserver(for: pid)
        }

        debounceWorkItem?.cancel()
        activeDomain = nil

        Log.profiles.info("BrowserURLMonitor: stopped")
    }

    deinit {
        stop()
    }

    func queryCurrentDomain() -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier,
              Constants.supportedBrowsers.contains(bundleID) else {
            return nil
        }
        return queryBrowserURL(bundleID: bundleID)
    }

    private func attachObserver(to app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier,
              Constants.supportedBrowsers.contains(bundleID) else { return }

        let pid = app.processIdentifier
        guard observers[pid] == nil else { return }

        guard Permissions.isAccessibilityGranted() else {
            Log.profiles.warning("BrowserURLMonitor: Accessibility not granted, skipping observer for \(bundleID)")
            return
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var observer: AXObserver?
        let result = AXObserverCreate(pid, browserTitleChangedCallback, &observer)

        guard result == .success, let observer = observer else {
            Log.profiles.error("BrowserURLMonitor: AXObserverCreate failed for \(bundleID) (error \(result.rawValue))")
            return
        }

        let appElement = AXUIElementCreateApplication(pid)

        let titleResult = AXObserverAddNotification(
            observer, appElement,
            kAXTitleChangedNotification as CFString, refcon
        )
        if titleResult != .success {
            Log.profiles.warning("BrowserURLMonitor: failed to add title notification for \(bundleID) (error \(titleResult.rawValue))")
        }

        let windowResult = AXObserverAddNotification(
            observer, appElement,
            kAXFocusedWindowChangedNotification as CFString, refcon
        )
        if windowResult != .success {
            Log.profiles.warning("BrowserURLMonitor: failed to add window notification for \(bundleID) (error \(windowResult.rawValue))")
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        observers[pid] = observer
        appElements[pid] = appElement
        browserPIDs[bundleID] = pid

        Log.profiles.info("BrowserURLMonitor: attached observer to \(bundleID) (pid \(pid))")
    }

    private func detachObserver(for pid: pid_t) {
        guard let observer = observers[pid] else { return }

        if let appElement = appElements[pid] {
            AXObserverRemoveNotification(observer, appElement, kAXTitleChangedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXFocusedWindowChangedNotification as CFString)
        }

        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        observers.removeValue(forKey: pid)
        appElements.removeValue(forKey: pid)
        browserPIDs = browserPIDs.filter { $0.value != pid }

        Log.profiles.info("BrowserURLMonitor: detached observer for pid \(pid)")
    }

    fileprivate func handleTitleChanged() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.resolveCurrentDomain()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.debounceInterval,
            execute: workItem
        )
    }

    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else { return }

        if Constants.supportedBrowsers.contains(bundleID) {
            attachObserver(to: app)
            resolveCurrentDomain()
        } else {
            activeDomain = nil
        }
    }

    private func handleAppTermination(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
        let pid = app.processIdentifier
        if observers[pid] != nil {
            detachObserver(for: pid)
        }
    }

    private func resolveCurrentDomain() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier,
              Constants.supportedBrowsers.contains(bundleID) else {
            activeDomain = nil
            return
        }

        let domain = queryBrowserURL(bundleID: bundleID)
        if domain != activeDomain {
            activeDomain = domain
            if let domain = domain {
                Log.profiles.info("BrowserURLMonitor: active domain changed to '\(domain)'")
            }
        }
    }

    private func queryBrowserURL(bundleID: String) -> String? {
        let script: String
        switch bundleID {
        case Constants.safariBundleID:
            script = "tell application \"Safari\" to return URL of current tab of front window"
        case Constants.chromeBundleID:
            script = "tell application \"Google Chrome\" to return URL of active tab of front window"
        default:
            return nil
        }

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        let result = appleScript.executeAndReturnError(&error) as NSAppleEventDescriptor?

        guard let urlString = result?.stringValue else {
            if let error = error {
                Log.profiles.debug("BrowserURLMonitor: AppleScript error for \(bundleID): \(error)")
            }
            return nil
        }

        return extractDomain(from: urlString)
    }

    static func extractDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host(percentEncoded: false) else { return nil }
        let normalized = host.lowercased()
        if normalized.hasPrefix("www.") {
            return String(normalized.dropFirst(4))
        }
        return normalized
    }

    private func extractDomain(from urlString: String) -> String? {
        Self.extractDomain(from: urlString)
    }
}

private func browserTitleChangedCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }
    let monitor = Unmanaged<BrowserURLMonitor>.fromOpaque(refcon).takeUnretainedValue()
    monitor.handleTitleChanged()
}
