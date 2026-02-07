import XCTest
@testable import KeyShare

class SerialProtocolTests: XCTestCase {

    // MARK: - Parsing

    func testParseKeyPress() {
        let json = #"{"type": "key_press", "key": 3}"#
        let data = json.data(using: .utf8)!
        let result = SerialProtocol.parseDeviceMessage(from: data)

        switch result {
        case .success(.keyPress(let key)):
            XCTAssertEqual(key, 3)
        default:
            XCTFail("Expected key_press, got \(result)")
        }
    }

    func testParseKeyRelease() {
        let json = #"{"type": "key_release", "key": 7}"#
        let data = json.data(using: .utf8)!
        let result = SerialProtocol.parseDeviceMessage(from: data)

        switch result {
        case .success(.keyRelease(let key)):
            XCTAssertEqual(key, 7)
        default:
            XCTFail("Expected key_release, got \(result)")
        }
    }

    func testParseReady() {
        let json = #"{"type": "ready", "protocol": 1, "firmware": "0.1.0", "keys": 9}"#
        let data = json.data(using: .utf8)!
        let result = SerialProtocol.parseDeviceMessage(from: data)

        switch result {
        case .success(.ready(let proto, let firmware, let keys)):
            XCTAssertEqual(proto, 1)
            XCTAssertEqual(firmware, "0.1.0")
            XCTAssertEqual(keys, 9)
        default:
            XCTFail("Expected ready, got \(result)")
        }
    }

    func testParseHeartbeat() {
        let json = #"{"type": "heartbeat"}"#
        let data = json.data(using: .utf8)!
        let result = SerialProtocol.parseDeviceMessage(from: data)

        switch result {
        case .success(.heartbeat):
            break
        default:
            XCTFail("Expected heartbeat, got \(result)")
        }
    }

    func testParseUnknownType() {
        let json = #"{"type": "future_message"}"#
        let data = json.data(using: .utf8)!
        let result = SerialProtocol.parseDeviceMessage(from: data)

        switch result {
        case .success(.unknown(let type)):
            XCTAssertEqual(type, "future_message")
        default:
            XCTFail("Expected unknown, got \(result)")
        }
    }

    func testParseMissingType() {
        let json = #"{"key": 3}"#
        let data = json.data(using: .utf8)!
        let result = SerialProtocol.parseDeviceMessage(from: data)

        switch result {
        case .failure(.missingType):
            break
        default:
            XCTFail("Expected missingType error, got \(result)")
        }
    }

    func testParseMissingKeyField() {
        let json = #"{"type": "key_press"}"#
        let data = json.data(using: .utf8)!
        let result = SerialProtocol.parseDeviceMessage(from: data)

        switch result {
        case .failure(.missingField("key", inType: "key_press")):
            break
        default:
            XCTFail("Expected missingField error, got \(result)")
        }
    }

    func testParseGarbage() {
        let data = "not json at all".data(using: .utf8)!
        let result = SerialProtocol.parseDeviceMessage(from: data)

        switch result {
        case .failure(.invalidJSON):
            break
        default:
            XCTFail("Expected invalidJSON error, got \(result)")
        }
    }

    // MARK: - Encoding

    func testEncodeAck() {
        let data = SerialProtocol.encode(.ack(profile: "general"))
        let string = String(data: data, encoding: .utf8)!

        XCTAssertTrue(string.hasSuffix("\n"))

        let jsonData = string.trimmingCharacters(in: .newlines).data(using: .utf8)!
        let json = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "ack")
        XCTAssertEqual(json["profile"] as? String, "general")
    }

    func testEncodeProfileChanged() {
        let data = SerialProtocol.encode(.profileChanged(name: "coding", displayName: "Coding"))
        let string = String(data: data, encoding: .utf8)!

        XCTAssertTrue(string.hasSuffix("\n"))

        let jsonData = string.trimmingCharacters(in: .newlines).data(using: .utf8)!
        let json = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "profile_changed")
        XCTAssertEqual(json["name"] as? String, "coding")
        XCTAssertEqual(json["display_name"] as? String, "Coding")
    }

    // MARK: - Line Buffer

    func testSingleLine() {
        let buffer = LineBuffer()
        let lines = buffer.append("hello\n".data(using: .utf8)!)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(String(data: lines[0], encoding: .utf8), "hello")
    }

    func testMultipleLines() {
        let buffer = LineBuffer()
        let lines = buffer.append("line1\nline2\nline3\n".data(using: .utf8)!)
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(String(data: lines[0], encoding: .utf8), "line1")
        XCTAssertEqual(String(data: lines[1], encoding: .utf8), "line2")
        XCTAssertEqual(String(data: lines[2], encoding: .utf8), "line3")
    }

    func testPartialLine() {
        let buffer = LineBuffer()

        let lines1 = buffer.append("hel".data(using: .utf8)!)
        XCTAssertEqual(lines1.count, 0)

        let lines2 = buffer.append("lo\n".data(using: .utf8)!)
        XCTAssertEqual(lines2.count, 1)
        XCTAssertEqual(String(data: lines2[0], encoding: .utf8), "hello")
    }

    func testEmptyLinesSkipped() {
        let buffer = LineBuffer()
        let lines = buffer.append("\n\n".data(using: .utf8)!)
        XCTAssertEqual(lines.count, 0)
    }

    func testBufferReset() {
        let buffer = LineBuffer()
        _ = buffer.append("partial".data(using: .utf8)!)
        buffer.reset()
        let lines = buffer.append("new\n".data(using: .utf8)!)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(String(data: lines[0], encoding: .utf8), "new")
    }
}
