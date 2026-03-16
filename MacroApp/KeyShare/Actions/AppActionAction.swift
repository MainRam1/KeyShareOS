import AppKit
import ApplicationServices
import Foundation
import os

final class AppActionAction: ActionExecutable {

    static let actionType = "app_action"
    var requiresAccessibility: Bool { true }

    private static let activationTimeout: TimeInterval = 0.5
    private static let activationPollInterval: TimeInterval = 0.05
    private static let axMessagingTimeout: Float = 2.0
    private static let maxMenuDepth = 10

    private static var menuCache: [String: [MenuItemInfo]] = [:]

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
        let pid = app.processIdentifier

        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, Self.axMessagingTimeout)

        if let menuItem = resolveMenuPath(appElement: appElement, path: menuPath) {
            let pressResult = AXUIElementPerformAction(menuItem, kAXPressAction as CFString)
            if pressResult == .success {
                Log.actions.info("AppActionAction: triggered menu item '\(menuPath.joined(separator: " > "))' in \(bundleID)")
                return
            }
            Log.actions.warning("AppActionAction: AXPress failed (error \(pressResult.rawValue)), trying shortcut fallback")
        } else {
            Log.actions.warning("AppActionAction: menu path '\(menuPath.joined(separator: " > "))' not found in \(bundleID)")
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
        var menuBarValue: CFTypeRef?
        let menuBarResult = AXUIElementCopyAttributeValue(
            appElement, kAXMenuBarAttribute as CFString, &menuBarValue
        )
        guard menuBarResult == .success, let menuBar = menuBarValue else {
            Log.actions.warning("AppActionAction: could not get menu bar (error \(menuBarResult.rawValue))")
            return nil
        }

        // swiftlint:disable:next force_cast
        return resolvePathSegments(
            element: menuBar as! AXUIElement,
            remainingPath: path,
            depth: 0
        )
    }

    private func resolvePathSegments(
        element: AXUIElement,
        remainingPath: [String],
        depth: Int
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
            let title = axTitle(of: child)

            if title == targetTitle {
                if isLastSegment {
                    let role = axRole(of: child)
                    if role == kAXMenuBarItemRole as String {
                        return nil
                    }
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
                            ) {
                                return found
                            }
                        }
                    }
                    if let found = resolvePathSegments(
                        element: child,
                        remainingPath: Array(remainingPath.dropFirst()),
                        depth: depth + 1
                    ) {
                        return found
                    }
                }
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

    private static func batchAttributes(of element: AXUIElement) -> (
        role: String?, title: String?, isEnabled: Bool, children: [AXUIElement]?,
        shortcutKey: String?, shortcutModifiers: [String]?
    ) {
        let attrNames = [
            kAXRoleAttribute as CFString,
            kAXTitleAttribute as CFString,
            kAXEnabledAttribute as CFString,
            kAXChildrenAttribute as CFString,
            "AXMenuItemCmdChar" as CFString,
            "AXMenuItemCmdModifiers" as CFString,
        ] as CFArray

        var values: CFArray?
        let result = AXUIElementCopyMultipleAttributeValues(
            element, attrNames, AXCopyMultipleAttributeOptions(rawValue: 0), &values
        )

        guard result == .success, let rawValues = values else {
            return (nil, nil, true, nil, nil, nil)
        }

        let nsArray = rawValues as NSArray
        let count = nsArray.count

        let role: String? = count > 0 ? nsArray[0] as? String : nil
        let title: String? = count > 1 ? nsArray[1] as? String : nil
        let isEnabled: Bool = count > 2 ? ((nsArray[2] as? Bool) ?? true) : true
        let children: [AXUIElement]? = count > 3 ? (nsArray[3] as? [AXUIElement]) : nil

        var shortcutKey: String?
        var shortcutModifiers: [String]?
        if let char = (count > 4 ? nsArray[4] as? String : nil), !char.isEmpty {
            shortcutKey = char.lowercased()
            var mods: [String] = []
            if let modNum = (count > 5 ? nsArray[5] as? Int : nil) {
                if modNum & 8 == 0 { mods.append("cmd") }
                if modNum & 1 != 0 { mods.append("shift") }
                if modNum & 2 != 0 { mods.append("alt") }
                if modNum & 4 != 0 { mods.append("ctrl") }
            } else {
                mods.append("cmd")
            }
            shortcutModifiers = mods
        }

        return (role, title, isEnabled, children, shortcutKey, shortcutModifiers)
    }

    static func discoverMenus(for bundleID: String) -> [MenuItemInfo]? {
        if let cached = menuCache[bundleID] {
            return cached
        }

        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleID
        }) else { return nil }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, axMessagingTimeout)

        var menuBarValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement, kAXMenuBarAttribute as CFString, &menuBarValue
        )
        guard result == .success, let menuBar = menuBarValue else { return nil }

        var childrenValue: CFTypeRef?
        // swiftlint:disable:next force_cast
        let childrenResult = AXUIElementCopyAttributeValue(
            menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &childrenValue
        )
        guard childrenResult == .success,
              let menuBarItems = childrenValue as? [AXUIElement] else { return nil }

        var menus: [MenuItemInfo] = []
        for item in menuBarItems {
            let attrs = batchAttributes(of: item)
            guard let title = attrs.title, !title.isEmpty else { continue }
            if title == "Apple" { continue }

            var children: [MenuItemInfo] = []
            if let subChildren = attrs.children {
                for subChild in subChildren {
                    let subAttrs = batchAttributes(of: subChild)
                    if subAttrs.role == kAXMenuRole as String {
                        children = traverseMenu(element: subChild, parentPath: [title], depth: 0)
                    }
                }
            }

            menus.append(MenuItemInfo(
                title: title,
                isEnabled: true,
                isSeparator: false,
                children: children,
                path: [title],
                shortcutKey: nil,
                shortcutModifiers: nil
            ))
        }

        menuCache[bundleID] = menus
        return menus
    }

    private static func traverseMenu(element: AXUIElement, parentPath: [String], depth: Int) -> [MenuItemInfo] {
        guard depth < maxMenuDepth else { return [] }

        var childrenValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element, kAXChildrenAttribute as CFString, &childrenValue
        )
        guard result == .success, let children = childrenValue as? [AXUIElement] else { return [] }

        var items: [MenuItemInfo] = []
        for child in children {
            let attrs = batchAttributes(of: child)
            guard attrs.role == kAXMenuItemRole as String else { continue }

            let isSeparator = attrs.title == nil || attrs.title?.isEmpty == true

            if isSeparator {
                items.append(MenuItemInfo(
                    title: "",
                    isEnabled: false,
                    isSeparator: true,
                    children: [],
                    path: parentPath,
                    shortcutKey: nil,
                    shortcutModifiers: nil
                ))
                continue
            }

            let itemTitle = attrs.title!
            let itemPath = parentPath + [itemTitle]

            var subItems: [MenuItemInfo] = []
            if let subChildren = attrs.children {
                for subChild in subChildren {
                    let subAttrs = batchAttributes(of: subChild)
                    if subAttrs.role == kAXMenuRole as String {
                        subItems = traverseMenu(element: subChild, parentPath: itemPath, depth: depth + 1)
                    }
                }
            }

            items.append(MenuItemInfo(
                title: itemTitle,
                isEnabled: attrs.isEnabled,
                isSeparator: false,
                children: subItems,
                path: itemPath,
                shortcutKey: attrs.shortcutKey,
                shortcutModifiers: attrs.shortcutModifiers
            ))
        }

        return items
    }
}

struct MenuItemInfo: Identifiable {
    let id = UUID()
    let title: String
    let isEnabled: Bool
    let isSeparator: Bool
    let children: [MenuItemInfo]
    let path: [String]
    let shortcutKey: String?
    let shortcutModifiers: [String]?

    var hasSubmenu: Bool { !children.isEmpty }
    var hasShortcut: Bool { shortcutKey != nil }

    var shortcutDisplay: String? {
        guard let key = shortcutKey, let mods = shortcutModifiers else { return nil }
        let modSymbols = mods.map { mod -> String in
            switch mod {
            case "cmd": return "\u{2318}"
            case "shift": return "\u{21E7}"
            case "alt": return "\u{2325}"
            case "ctrl": return "\u{2303}"
            default: return mod
            }
        }
        return modSymbols.joined() + key.uppercased()
    }
}
