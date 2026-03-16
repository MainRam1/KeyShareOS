import Foundation

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
