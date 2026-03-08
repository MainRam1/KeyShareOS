import Foundation

struct MacroConfig: Codable, Equatable {
    var version: Int
    var activeProfile: String
    var profileOrder: [String]?
    var profiles: [String: Profile]
    var autoSwitch: [String: String]
    var settings: AppSettings

    enum CodingKeys: String, CodingKey {
        case version
        case activeProfile = "active_profile"
        case profileOrder = "profile_order"
        case profiles
        case autoSwitch = "auto_switch"
        case settings
    }

    var resolvedProfileOrder: [String] {
        guard let order = profileOrder else {
            return profiles.keys.sorted()
        }
        let existing = Set(profiles.keys)
        let filtered = order.filter { existing.contains($0) }
        let missing = profiles.keys.filter { !filtered.contains($0) }.sorted()
        let result = filtered + missing
        return result.isEmpty ? profiles.keys.sorted() : result
    }
}

struct Profile: Codable, Equatable {
    var displayName: String
    var keys: [String: KeyBinding]

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case keys
    }
}

struct KeyBinding: Codable, Equatable {
    var action: String
    var params: [String: AnyCodable]
    var displayName: String? = nil

    enum CodingKeys: String, CodingKey {
        case action, params
        case displayName = "display_name"
    }
}

struct AppSettings: Codable, Equatable {
    var launchAtLogin: Bool
    var showOSD: Bool

    enum CodingKeys: String, CodingKey {
        case launchAtLogin = "launch_at_login"
        case showOSD = "show_osd"
    }
}

struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) {
        if value is [AnyCodable] || value is [String: AnyCodable] {
            self.value = value
        } else if let array = value as? [Any] {
            self.value = array.map { AnyCodable($0) }
        } else if let dict = value as? [String: Any] {
            self.value = dict.mapValues { AnyCodable($0) }
        } else {
            self.value = value
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [AnyCodable]:
            try container.encode(array)
        case let dict as [String: AnyCodable]:
            try container.encode(dict)
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: container.codingPath,
                                                           debugDescription: "Unsupported type"))
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (let l as String, let r as String): return l == r
        case (let l as Int, let r as Int): return l == r
        case (let l as Double, let r as Double): return l == r
        case (let l as Bool, let r as Bool): return l == r
        case (let l as [AnyCodable], let r as [AnyCodable]): return l == r
        case (let l as [String: AnyCodable], let r as [String: AnyCodable]): return l == r
        default: return false
        }
    }

    var stringValue: String? { value as? String }
    var intValue: Int? { value as? Int }

    var anyValue: Any {
        switch value {
        case let array as [AnyCodable]:
            return array.map { $0.anyValue }
        case let dict as [String: AnyCodable]:
            return dict.mapValues { $0.anyValue }
        default:
            return value
        }
    }
}

extension KeyBinding {
    var actionParams: [String: Any] {
        params.mapValues { $0.anyValue }
    }
}

#if DEBUG
extension MacroConfig {
    static let testConfig = MacroConfig(
        version: 1,
        activeProfile: "test",
        profileOrder: nil,
        profiles: [
            "test": Profile(
                displayName: "Test Profile",
                keys: [
                    "1": KeyBinding(action: "keyboard_shortcut", params: [
                        "modifiers": AnyCodable(["cmd"]),
                        "key": AnyCodable("c"),
                    ]),
                    "2": KeyBinding(action: "keyboard_shortcut", params: [
                        "modifiers": AnyCodable(["cmd"]),
                        "key": AnyCodable("v"),
                    ]),
                    "3": KeyBinding(action: "app_launch", params: [
                        "bundle_id": AnyCodable("com.apple.Terminal"),
                    ]),
                    "4": KeyBinding(action: "text_type", params: [
                        "text": AnyCodable("Hello from KeyShare!"),
                        "method": AnyCodable("clipboard"),
                    ]),
                    "5": KeyBinding(action: "media_control", params: [
                        "action": AnyCodable("play_pause"),
                    ]),
                    "6": KeyBinding(action: "media_control", params: [
                        "action": AnyCodable("vol_up"),
                    ]),
                    "7": KeyBinding(action: "media_control", params: [
                        "action": AnyCodable("vol_down"),
                    ]),
                    "8": KeyBinding(action: "desktop_switch", params: [
                        "direction": AnyCodable("left"),
                    ]),
                    "9": KeyBinding(action: "desktop_switch", params: [
                        "direction": AnyCodable("right"),
                    ]),
                ]
            ),
        ],
        autoSwitch: [:],
        settings: AppSettings(launchAtLogin: false, showOSD: true)
    )
}
#endif

extension MacroConfig {
    mutating func swapKeys(_ keyA: Int, _ keyB: Int, in profileName: String) {
        guard var profile = profiles[profileName] else { return }
        let a = String(keyA)
        let b = String(keyB)
        let tempA = profile.keys[a]
        let tempB = profile.keys[b]
        profile.keys[a] = tempB ?? KeyBinding(action: "none", params: [:])
        profile.keys[b] = tempA ?? KeyBinding(action: "none", params: [:])
        profiles[profileName] = profile
    }
}
