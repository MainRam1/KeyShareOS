import AppKit
import ApplicationServices
import Foundation
import os

final class AppActionAction: ActionExecutable {

    static let actionType = "app_action"
    var requiresAccessibility: Bool { true }

    private static let activationTimeout: TimeInterval = 0.5
    private static let activationPollInterval: TimeInterval = 0.05
    static let axMessagingTimeout: Float = 2.0
    static let maxMenuDepth = 10

    static var menuCache: [String: [MenuItemInfo]] = [:]

    static func clearMenuCache(for bundleID: String? = nil) {
        if let bundleID = bundleID {
            menuCache.removeValue(forKey: bundleID)
        } else {
            menuCache.removeAll()
        }
    }

    func validate(params: [String: Any]) -> Bool {
        guard let bundleID = params["bundle_id"] as? String, !bundleID.isEmpty else {
            return false
        }
        guard let menuPath = params["menu_path"] as? [String], !menuPath.isEmpty else {
            return false
        }
        return menuPath.allSatisfy { !$0.isEmpty }
    }

    func execute(params: [String: Any]) async throws {
        guard let bundleID = params["bundle_id"] as? String,
              let menuPath = params["menu_path"] as? [String] else {
            throw ActionError.invalidParams(Self.actionType, params)
        }

        let app = try await activateApp(bundleID: bundleID)
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, Self.axMessagingTimeout)

        if let menuItem = resolveMenuPath(appElement: appElement, path: menuPath) {
            let pressResult = AXUIElementPerformAction(menuItem, kAXPressAction as CFString)
            if pressResult == .success {
                Log.actions.info("AppActionAction: triggered '\(menuPath.joined(separator: " > "))' in \(bundleID)")
                return
            }
            Log.actions.warning("AppActionAction: AXPress failed (\(pressResult.rawValue)), trying fallback")
        } else {
            Log.actions.warning("AppActionAction: '\(menuPath.joined(separator: " > "))' not found in \(bundleID)")
        }

        if let fallback = params["shortcut_fallback"] as? [String: Any],
           let key = fallback["key"] as? String,
           let modifiers = fallback["modifiers"] as? [String] {
            try executeShortcutFallback(key: key, modifiers: modifiers)
            Log.actions.info("AppActionAction: used shortcut fallback for \(bundleID)")
            return
        }

        throw ActionError.executionFailed(
            Self.actionType,
            NSError(domain: "KeyShare", code: 1,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Menu item '\(menuPath.joined(separator: " > "))' not found in \(bundleID)"])
        )
    }

    private func activateApp(bundleID: String) async throws -> NSRunningApplication {
        var app = NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleID
        }

        if app == nil {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                do {
                    app = try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
                } catch {
                    throw ActionError.executionFailed(Self.actionType, error)
                }
            } else {
                throw ActionError.executionFailed(
                    Self.actionType,
                    NSError(domain: "KeyShare", code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Application not found: \(bundleID)"])
                )
            }
        }

        guard let runningApp = app else {
            throw ActionError.executionFailed(
                Self.actionType,
                NSError(domain: "KeyShare", code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to get running app: \(bundleID)"])
            )
        }

        if #available(macOS 14.0, *) {
            runningApp.activate()
        } else {
            runningApp.activate(options: [.activateIgnoringOtherApps])
        }

        let deadline = Date().addingTimeInterval(Self.activationTimeout)
        while !runningApp.isActive && Date() < deadline {
            try await Task.sleep(nanoseconds: UInt64(Self.activationPollInterval * 1_000_000_000))
        }

        return runningApp
    }

    private func resolveMenuPath(appElement: AXUIElement, path: [String]) -> AXUIElement? {
        var menuBarRef: CFTypeRef?
        let menuBarResult = AXUIElementCopyAttributeValue(
            appElement, kAXMenuBarAttribute as CFString, &menuBarRef
        )
        guard menuBarResult == .success, let menuBarRef = menuBarRef else {
            Log.actions.warning("AppActionAction: could not get menu bar (\(menuBarResult.rawValue))")
            return nil
        }
        let menuBar = menuBarRef as! AXUIElement // swiftlint:disable:this force_cast

        return resolvePathSegments(element: menuBar, remainingPath: path, depth: 0)
    }

    private func resolvePathSegments(
        element: AXUIElement, remainingPath: [String], depth: Int
    ) -> AXUIElement? {
        guard depth < Self.maxMenuDepth, !remainingPath.isEmpty else { return nil }

        let targetTitle = remainingPath[0]
        let isLastSegment = remainingPath.count == 1

        var childrenValue: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(
            element, kAXChildrenAttribute as CFString, &childrenValue
        )
        guard childrenResult == .success,
              let children = childrenValue as? [AXUIElement] else { return nil }

        for child in children {
            guard axTitle(of: child) == targetTitle else { continue }

            if isLastSegment {
                if axRole(of: child) == kAXMenuBarItemRole as String { return nil }
                return child
            }

            var subChildrenValue: CFTypeRef?
            let subResult = AXUIElementCopyAttributeValue(
                child, kAXChildrenAttribute as CFString, &subChildrenValue
            )
            if subResult == .success, let subChildren = subChildrenValue as? [AXUIElement] {
                for subChild in subChildren {
                    let subRole = axRole(of: subChild)
                    if subRole == kAXMenuRole as String || subRole == kAXMenuBarItemRole as String {
                        if let found = resolvePathSegments(
                            element: subChild,
                            remainingPath: Array(remainingPath.dropFirst()),
                            depth: depth + 1
                        ) { return found }
                    }
                }
                if let found = resolvePathSegments(
                    element: child,
                    remainingPath: Array(remainingPath.dropFirst()),
                    depth: depth + 1
                ) { return found }
            }
        }
        return nil
    }

    private func axTitle(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private func axRole(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private func executeShortcutFallback(key: String, modifiers: [String]) throws {
        guard let keyCode = Constants.KeyCodes.fromName(key) else {
            throw ActionError.executionFailed(
                Self.actionType,
                NSError(domain: "KeyShare", code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown key: \(key)"])
            )
        }

        let flags = Constants.KeyCodes.modifierFlags(from: modifiers)
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
