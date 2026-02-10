import Foundation

enum ConfigError: Error, CustomStringConvertible {
    case fileReadFailed(URL, Error)
    case fileWriteFailed(URL, Error)
    case decodingFailed(Error)
    case encodingFailed(Error)
    case validationFailed(String)
    case directoryCreationFailed(URL, Error)

    var description: String {
        switch self {
        case .fileReadFailed(let url, let error):
            return "Failed to read config at \(url.path): \(error)"
        case .fileWriteFailed(let url, let error):
            return "Failed to write config to \(url.path): \(error)"
        case .decodingFailed(let error):
            return "Failed to decode config JSON: \(error)"
        case .encodingFailed(let error):
            return "Failed to encode config JSON: \(error)"
        case .validationFailed(let reason):
            return "Config validation failed: \(reason)"
        case .directoryCreationFailed(let url, let error):
            return "Failed to create directory \(url.path): \(error)"
        }
    }
}
