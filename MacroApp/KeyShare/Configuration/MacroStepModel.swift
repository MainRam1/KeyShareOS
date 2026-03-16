import Foundation

/// A single step in a macro: either an action or a delay.
struct MacroStepModel: Identifiable {
    let id: UUID
    var isDelay: Bool
    var delayMs: Int
    var actionType: String
    // keyboard_shortcut
    var useCmd: Bool = false
    var useShift: Bool = false
    var useCtrl: Bool = false
    var useAlt: Bool = false
    var shortcutKey: String = ""
    // app_launch
    var bundleID: String = ""
    var appName: String = ""
    // text_type
    var typeText: String = ""
    var typeMethod: String = "clipboard"
    // desktop_switch
    var switchDirection: String = "left"
    // media_control
    var mediaAction: String = "play_pause"
    var urlString: String = ""
    // app_action
    var appActionBundleID: String = ""
    var appActionAppName: String = ""
    var appActionMenuPath: [String] = []
    var appActionShortcutKey: String = ""
    var appActionShortcutModifiers: [String] = []

    init(id: UUID = UUID(), isDelay: Bool, delayMs: Int, actionType: String) {
        self.id = id
        self.isDelay = isDelay
        self.delayMs = delayMs
        self.actionType = actionType
    }

    static func newDelay() -> MacroStepModel {
        MacroStepModel(isDelay: true, delayMs: 200, actionType: "")
    }

    static func newAction() -> MacroStepModel {
        MacroStepModel(isDelay: false, delayMs: 0, actionType: "keyboard_shortcut")
    }

    private func buildModifiers() -> [String] {
        var mods: [String] = []
        if useCmd { mods.append("cmd") }
        if useShift { mods.append("shift") }
        if useCtrl { mods.append("ctrl") }
        if useAlt { mods.append("alt") }
        return mods
    }

    func toStepDict() -> [String: Any] {
        if isDelay {
            return ["delay_ms": delayMs]
        }

        switch actionType {
        case "keyboard_shortcut":
            return ["action": "keyboard_shortcut", "params": ["modifiers": buildModifiers(), "key": shortcutKey]]
        case "app_launch":
            var params: [String: Any] = ["bundle_id": bundleID]
            if !appName.isEmpty {
                params["app_name"] = appName
            }
            return ["action": "app_launch", "params": params]
        case "text_type":
            return ["action": "text_type", "params": ["text": typeText, "method": typeMethod]]
        case "desktop_switch":
            return ["action": "desktop_switch", "params": ["direction": switchDirection]]
        case "media_control":
            return ["action": "media_control", "params": ["action": mediaAction]]
        case "open_url":
            return ["action": "open_url", "params": ["url": urlString]]
        case "app_action":
            var params: [String: Any] = [
                "bundle_id": appActionBundleID,
                "menu_path": appActionMenuPath,
            ]
            if !appActionAppName.isEmpty {
                params["app_name"] = appActionAppName
            }
            if !appActionShortcutKey.isEmpty {
                params["shortcut_fallback"] = [
                    "key": appActionShortcutKey,
                    "modifiers": appActionShortcutModifiers,
                ] as [String: Any]
            }
            return ["action": "app_action", "params": params]
        default:
            return ["action": actionType, "params": [String: Any]()]
        }
    }

    init(from dict: [String: Any]) {
        self.id = UUID()

        if let delayValue = dict["delay_ms"] {
            self.isDelay = true
            self.actionType = ""
            if let intVal = delayValue as? Int {
                self.delayMs = intVal
            } else if let doubleVal = delayValue as? Double {
                self.delayMs = Int(doubleVal)
            } else {
                self.delayMs = 200
            }
            return
        }

        self.isDelay = false
        self.delayMs = 0
        self.actionType = dict["action"] as? String ?? "keyboard_shortcut"
        let params = dict["params"] as? [String: Any] ?? [:]

        switch actionType {
        case "keyboard_shortcut":
            let mods = params["modifiers"] as? [String] ?? []
            self.useCmd = mods.contains("cmd")
            self.useShift = mods.contains("shift")
            self.useCtrl = mods.contains("ctrl")
            self.useAlt = mods.contains("alt")
            self.shortcutKey = params["key"] as? String ?? ""
        case "app_launch":
            self.bundleID = params["bundle_id"] as? String ?? ""
            self.appName = params["app_name"] as? String ?? ""
        case "text_type":
            self.typeText = params["text"] as? String ?? ""
            self.typeMethod = params["method"] as? String ?? "clipboard"
        case "desktop_switch":
            self.switchDirection = params["direction"] as? String ?? "left"
        case "media_control":
            self.mediaAction = params["action"] as? String ?? "play_pause"
        case "open_url":
            self.urlString = params["url"] as? String ?? ""
        case "app_action":
            self.appActionBundleID = params["bundle_id"] as? String ?? ""
            self.appActionAppName = params["app_name"] as? String ?? ""
            self.appActionMenuPath = (params["menu_path"] as? [Any])?.compactMap { $0 as? String } ?? []
            if let fallback = params["shortcut_fallback"] as? [String: Any] {
                self.appActionShortcutKey = fallback["key"] as? String ?? ""
                self.appActionShortcutModifiers = (fallback["modifiers"] as? [Any])?.compactMap { $0 as? String } ?? []
            }
        default:
            break
        }
    }
}
