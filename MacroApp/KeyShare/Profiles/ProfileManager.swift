import Combine
import Foundation
import os

enum ProfileError: Error, CustomStringConvertible {
    case profileNotFound(String)
    case profileAlreadyExists(String)
    case cannotDeleteActiveProfile(String)
    case cannotDeleteLastProfile
    case invalidProfileName(String)

    var description: String {
        switch self {
        case .profileNotFound(let name):
            return "Profile not found: '\(name)'"
        case .profileAlreadyExists(let name):
            return "Profile already exists: '\(name)'"
        case .cannotDeleteActiveProfile(let name):
            return "Cannot delete the active profile: '\(name)'"
        case .cannotDeleteLastProfile:
            return "Cannot delete the last remaining profile"
        case .invalidProfileName(let name):
            return "Invalid profile name: '\(name)'"
        }
    }
}

final class ProfileManager: ObservableObject {

    @Published private(set) var activeProfile: String = ""
    @Published private(set) var availableProfiles: [String] = []

    private let configManager: ConfigManager
    private var cancellables = Set<AnyCancellable>()

    init(configManager: ConfigManager) {
        self.configManager = configManager

        let config = configManager.config
        self.activeProfile = config.activeProfile
        self.availableProfiles = config.resolvedProfileOrder

        configManager.$config
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newConfig in
                guard let self = self else { return }
                self.activeProfile = newConfig.activeProfile
                self.availableProfiles = newConfig.resolvedProfileOrder
            }
            .store(in: &cancellables)
    }

    func switchProfile(to name: String) throws {
        guard configManager.config.profiles[name] != nil else {
            throw ProfileError.profileNotFound(name)
        }

        try configManager.mutateConfig { config in
            config.activeProfile = name
        }
        activeProfile = name
        Log.profiles.info("ProfileManager: switched to profile '\(name)'")
    }

    func addProfile(name: String, displayName: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ProfileError.invalidProfileName(name)
        }

        guard configManager.config.profiles[trimmedName] == nil else {
            throw ProfileError.profileAlreadyExists(trimmedName)
        }

        var emptyKeys: [String: KeyBinding] = [:]
        for keyIndex in 1...Constants.numberOfKeys {
            emptyKeys[String(keyIndex)] = KeyBinding(
                action: "none",
                params: [:]
            )
        }

        let profile = Profile(displayName: displayName, keys: emptyKeys)
        try configManager.mutateConfig { config in
            var order = config.resolvedProfileOrder
            config.profiles[trimmedName] = profile
            order.append(trimmedName)
            config.profileOrder = order
        }
        availableProfiles = configManager.config.resolvedProfileOrder
        Log.profiles.info("ProfileManager: added profile '\(trimmedName)' ('\(displayName)')")
    }

    func deleteProfile(name: String) throws {
        guard configManager.config.profiles[name] != nil else {
            throw ProfileError.profileNotFound(name)
        }

        guard configManager.config.profiles.count > 1 else {
            throw ProfileError.cannotDeleteLastProfile
        }

        guard configManager.config.activeProfile != name else {
            throw ProfileError.cannotDeleteActiveProfile(name)
        }

        try configManager.mutateConfig { config in
            config.profiles.removeValue(forKey: name)
            config.autoSwitch = config.autoSwitch.filter { $0.value != name }
            var order = config.resolvedProfileOrder
            order.removeAll { $0 == name }
            config.profileOrder = order
        }
        availableProfiles = configManager.config.resolvedProfileOrder
        Log.profiles.info("ProfileManager: deleted profile '\(name)'")
    }

    func moveProfile(from source: String, to target: String) throws {
        guard source != target else { return }
        try configManager.mutateConfig { config in
            var order = config.resolvedProfileOrder
            guard let sourceIndex = order.firstIndex(of: source),
                  let targetIndex = order.firstIndex(of: target) else { return }
            order.remove(at: sourceIndex)
            order.insert(source, at: targetIndex)
            config.profileOrder = order
        }
        availableProfiles = configManager.config.resolvedProfileOrder
    }

    func renameProfile(_ name: String, displayName newDisplayName: String) throws {
        let trimmed = newDisplayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw ProfileError.invalidProfileName(newDisplayName)
        }
        guard configManager.config.profiles[name] != nil else {
            throw ProfileError.profileNotFound(name)
        }
        try configManager.mutateConfig { config in
            config.profiles[name]?.displayName = trimmed
        }
    }

    func getActiveProfileBindings() -> Profile? {
        return configManager.config.profiles[configManager.config.activeProfile]
    }
}
