import Foundation

extension ConfigManager {

    func exportProfile(name: String) throws -> Data {
        guard let profile = config.profiles[name] else {
            throw ConfigError.validationFailed("Profile '\(name)' not found for export.")
        }
        return try encodeProfile(profile)
    }

    private static let maxImportSize = 1_000_000
    private static let maxParamValueSize = 10_000
    private static let validKeyIDs: Set<String> = Set((1...Constants.numberOfKeys).map { String($0) })

    /// Decode and validate an imported profile. Does not add it to config.
    func decodeImportedProfile(from data: Data) throws -> Profile {
        guard data.count <= Self.maxImportSize else {
            throw ConfigError.validationFailed(
                "Import data too large (\(data.count) bytes). Maximum is \(Self.maxImportSize) bytes."
            )
        }

        let profile: Profile
        do {
            let decoder = JSONDecoder()
            profile = try decoder.decode(Profile.self, from: data)
        } catch let error as ConfigError {
            throw error
        } catch {
            throw ConfigError.decodingFailed(error)
        }

        guard !profile.displayName.isEmpty else {
            throw ConfigError.validationFailed("Imported profile has empty display name.")
        }

        // Validate key IDs are within expected range
        let invalidKeys = Set(profile.keys.keys).subtracting(Self.validKeyIDs)
        if !invalidKeys.isEmpty {
            throw ConfigError.validationFailed(
                "Invalid key IDs: \(invalidKeys.sorted().joined(separator: ", ")). Expected 1-\(Constants.numberOfKeys)."
            )
        }

        // Validate action types are registered
        let registeredActions = Set(ActionRegistry.shared.registeredTypes + ["none"])
        for (keyID, binding) in profile.keys {
            if !registeredActions.contains(binding.action) {
                throw ConfigError.validationFailed(
                    "Unknown action type '\(binding.action)' on key \(keyID)."
                )
            }
        }

        // Validate no individual param value exceeds size limit
        let encoder = JSONEncoder()
        for (keyID, binding) in profile.keys {
            for (paramName, paramValue) in binding.params {
                if let encoded = try? encoder.encode(paramValue), encoded.count > Self.maxParamValueSize {
                    throw ConfigError.validationFailed(
                        "Param '\(paramName)' on key \(keyID) exceeds \(Self.maxParamValueSize) byte limit."
                    )
                }
            }
        }

        return profile
    }

    func encodeProfile(_ profile: Profile) throws -> Data {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(profile)
        } catch {
            throw ConfigError.encodingFailed(error)
        }
    }
}
