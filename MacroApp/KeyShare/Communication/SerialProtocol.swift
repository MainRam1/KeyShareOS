import Foundation

/// Messages from the Pico.
enum DeviceMessage {
    case keyPress(key: Int)
    case keyRelease(key: Int)
    case ready(protocol: Int, firmware: String, keys: Int)
    case heartbeat
    case unknown(type: String)
}

/// Messages to the Pico.
enum HostMessage {
    case ack(profile: String)
    case profileChanged(name: String, displayName: String)
}

// MARK: - Errors

enum SerialProtocolError: Error, CustomStringConvertible {
    case invalidJSON(Data)
    case missingType
    case missingField(String, inType: String)

    var description: String {
        switch self {
        case .invalidJSON:
            return "Failed to parse JSON message"
        case .missingType:
            return "Message missing 'type' field"
        case .missingField(let field, let type):
            return "Message type '\(type)' missing field '\(field)'"
        }
    }
}

/// Single point for all serial JSON encoding/decoding.
enum SerialProtocol {

    static func parseDeviceMessage(from data: Data) -> Result<DeviceMessage, SerialProtocolError> {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(.invalidJSON(data))
        }

        guard let type = json["type"] as? String else {
            return .failure(.missingType)
        }

        switch type {
        case "key_press":
            guard let key = json["key"] as? Int else {
                return .failure(.missingField("key", inType: type))
            }
            return .success(.keyPress(key: key))

        case "key_release":
            guard let key = json["key"] as? Int else {
                return .failure(.missingField("key", inType: type))
            }
            return .success(.keyRelease(key: key))

        case "ready":
            guard let proto = json["protocol"] as? Int else {
                return .failure(.missingField("protocol", inType: type))
            }
            guard let firmware = json["firmware"] as? String else {
                return .failure(.missingField("firmware", inType: type))
            }
            guard let keys = json["keys"] as? Int else {
                return .failure(.missingField("keys", inType: type))
            }
            return .success(.ready(protocol: proto, firmware: firmware, keys: keys))

        case "heartbeat":
            return .success(.heartbeat)

        default:
            return .success(.unknown(type: type))
        }
    }

    static func encode(_ message: HostMessage) -> Data {
        let dict: [String: Any]

        switch message {
        case .ack(let profile):
            dict = ["type": "ack", "profile": profile]
        case .profileChanged(let name, let displayName):
            dict = ["type": "profile_changed", "name": name, "display_name": displayName]
        }

        // JSONSerialization is used here (not JSONEncoder) because we're working
        // with [String: Any] dictionaries matching the protocol spec, not Codable types.
        // Codable types for the config schema live in ConfigSchema.swift.
        var data = try! JSONSerialization.data(withJSONObject: dict)
        data.append(0x0A) // newline terminator
        return data
    }
}

/// Splits incoming serial bytes into newline-terminated lines.
final class LineBuffer {
    private var buffer = Data()

    func append(_ data: Data) -> [Data] {
        buffer.append(data)

        var lines: [Data] = []
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newlineIndex]
            if !line.isEmpty {
                lines.append(Data(line))
            }
            buffer = Data(buffer[buffer.index(after: newlineIndex)...])
        }

        // Prevent unbounded buffer growth from malformed data
        if buffer.count > Constants.serialReadBufferSize {
            buffer.removeAll()
        }

        return lines
    }

    func reset() {
        buffer.removeAll()
    }
}
