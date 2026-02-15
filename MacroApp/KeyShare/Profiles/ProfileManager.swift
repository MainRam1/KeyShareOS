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

/// Handles profile switching, creation, and deletion. Syncs with ConfigManager via Combine.
final class ProfileManager: ObservableObject {

    @Published private(set) var activeProfile: String = ""
    /// Sorted.
    @Published private(set) var availableProfiles: [String] = []

    private let configManager: ConfigManager
    private var cancellables = Set<AnyCancellable>()

    init(configManager: ConfigManager) {
        self.configManager = configManager

        // Seed initial state from current config
        let config = configManager.config
        self.activeProfile = config.activeProfile
        self.availableProfiles = config.profiles.keys.sorted()

        // Rebuild when config changes.
        configManager.$config
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newConfig in
                guard let self = self else { return }
                self.activeProfile = newConfig.activeProfile
                self.availableProfiles = newConfig.profiles.keys.sorted()
            }
            .store(in: &cancellables)
    }

    /// - Throws: `ProfileError.profileNotFound` if the profile does not exist.
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

    /// - Throws: `ProfileError.invalidProfileName` or `.profileAlreadyExists`.
    func addProfile(name: String, displayName: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ProfileError.invalidProfileName(name)
        }

        guard configManager.config.profiles[trimmedName] == nil else {
            throw ProfileError.profileAlreadyExists(trimmedName)
        }

        // Create profile with empty bindings for all 9 keys
        var emptyKeys: [String: KeyBinding] = [:]
        for keyIndex in 1...Constants.numberOfKeys {
            emptyKeys[String(keyIndex)] = KeyBinding(
                action: "none",
                params: [:]
            )
        }

        let profile = Profile(displayName: displayName, keys: emptyKeys)
        try configManager.mutateConfig { config in
            config.profiles[trimmedName] = profile
        }
        availableProfiles = configManager.config.profiles.keys.sorted()
        Log.profiles.info("ProfileManager: added profile '\(trimmedName)' ('\(displayName)')")
    }

    /// - Throws: `ProfileError.cannotDeleteLastProfile`, `.cannotDeleteActiveProfile`, or `.profileNotFound`.
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
        }
        availableProfiles = configManager.config.profiles.keys.sorted()
        Log.profiles.info("ProfileManager: deleted profile '\(name)'")
    }

    func getActiveProfileBindings() -> Profile? {
        return configManager.config.profiles[configManager.config.activeProfile]
    }
}
