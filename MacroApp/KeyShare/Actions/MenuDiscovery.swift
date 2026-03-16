import AppKit
import ApplicationServices
import Foundation

struct BatchedMenuAttributes {
    let role: String?
    let title: String?
    let isEnabled: Bool
    let children: [AXUIElement]?
    let shortcutKey: String?
    let shortcutModifiers: [String]?
}

extension AppActionAction {

    static func batchAttributes(of element: AXUIElement) -> BatchedMenuAttributes {
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
            return BatchedMenuAttributes(
                role: nil, title: nil, isEnabled: true,
                children: nil, shortcutKey: nil, shortcutModifiers: nil
            )
        }

        let arr = rawValues as NSArray
        let count = arr.count
        let role: String? = count > 0 ? arr[0] as? String : nil
        let title: String? = count > 1 ? arr[1] as? String : nil
        let isEnabled: Bool = count > 2 ? ((arr[2] as? Bool) ?? true) : true
        let children: [AXUIElement]? = count > 3 ? (arr[3] as? [AXUIElement]) : nil

        var shortcutKey: String?
        var shortcutModifiers: [String]?
        if let char = (count > 4 ? arr[4] as? String : nil), !char.isEmpty {
            shortcutKey = char.lowercased()
            var mods: [String] = []
            if let modNum = (count > 5 ? arr[5] as? Int : nil) {
                if modNum & 8 == 0 { mods.append("cmd") }
                if modNum & 1 != 0 { mods.append("shift") }
                if modNum & 2 != 0 { mods.append("alt") }
                if modNum & 4 != 0 { mods.append("ctrl") }
            } else {
                mods.append("cmd")
            }
            shortcutModifiers = mods
        }

        return BatchedMenuAttributes(
            role: role, title: title, isEnabled: isEnabled,
            children: children, shortcutKey: shortcutKey, shortcutModifiers: shortcutModifiers
        )
    }

    static func discoverMenus(for bundleID: String) -> [MenuItemInfo]? {
        if let cached = menuCache[bundleID] { return cached }

        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleID
        }) else { return nil }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, axMessagingTimeout)

        var menuBarValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement, kAXMenuBarAttribute as CFString, &menuBarValue
        )
        guard result == .success, let menuBarRef = menuBarValue else { return nil }
        let menuBarElement = menuBarRef as! AXUIElement // swiftlint:disable:this force_cast

        var childrenValue: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(
            menuBarElement, kAXChildrenAttribute as CFString, &childrenValue
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
                    if batchAttributes(of: subChild).role == kAXMenuRole as String {
                        children = traverseMenu(element: subChild, parentPath: [title], depth: 0)
                    }
                }
            }

            menus.append(MenuItemInfo(
                title: title, isEnabled: true, isSeparator: false,
                children: children, path: [title],
                shortcutKey: nil, shortcutModifiers: nil
            ))
        }

        menuCache[bundleID] = menus
        return menus
    }

    private static func traverseMenu(
        element: AXUIElement, parentPath: [String], depth: Int
    ) -> [MenuItemInfo] {
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

            if attrs.title == nil || attrs.title?.isEmpty == true {
                items.append(MenuItemInfo(
                    title: "", isEnabled: false, isSeparator: true,
                    children: [], path: parentPath,
                    shortcutKey: nil, shortcutModifiers: nil
                ))
                continue
            }

            let itemTitle = attrs.title! // swiftlint:disable:this force_unwrapping
            let itemPath = parentPath + [itemTitle]

            var subItems: [MenuItemInfo] = []
            if let subChildren = attrs.children {
                for subChild in subChildren {
                    if batchAttributes(of: subChild).role == kAXMenuRole as String {
                        subItems = traverseMenu(element: subChild, parentPath: itemPath, depth: depth + 1)
                    }
                }
            }

            items.append(MenuItemInfo(
                title: itemTitle, isEnabled: attrs.isEnabled, isSeparator: false,
                children: subItems, path: itemPath,
                shortcutKey: attrs.shortcutKey, shortcutModifiers: attrs.shortcutModifiers
            ))
        }
        return items
    }
}
