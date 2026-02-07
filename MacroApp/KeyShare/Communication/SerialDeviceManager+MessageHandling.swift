import Foundation
import os

extension SerialDeviceManager {

    func startReading() {
        guard fileDescriptor != -1 else { return }

        let source = DispatchSource.makeReadSource(
            fileDescriptor: fileDescriptor,
            queue: serialQueue
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.handleDataAvailable()
        }

        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor != -1 {
                tcsetattr(self.fileDescriptor, TCSANOW, &self.originalAttrs)
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source.resume()
        readSource = source
    }

    private func handleDataAvailable() {
        var buffer = [UInt8](repeating: 0, count: Constants.serialReadBufferSize)
        let bytesRead = read(fileDescriptor, &buffer, buffer.count)

        if bytesRead <= 0 {
            // Read error or EOF — device likely disconnected
            performDisconnect()
            return
        }

        let data = Data(buffer[0..<bytesRead])
        let lines = lineBuffer.append(data)

        for line in lines {
            let result = SerialProtocol.parseDeviceMessage(from: line)
            switch result {
            case .success(let message):
                handleDeviceMessage(message)
            case .failure(let error):
                Log.serial.error("Parse error: \(error.description)")
            }
        }
    }

    private func handleDeviceMessage(_ message: DeviceMessage) {
        switch message {
        case .ready(let proto, let firmware, let keys):
            Log.serial.info("Device ready — protocol: \(proto), firmware: \(firmware), keys: \(keys)")

            // Validate protocol version
            if proto < Constants.minimumProtocolVersion || proto > Constants.maximumProtocolVersion {
                Log.serial.warning("Protocol version \(proto) not supported (expected \(Constants.minimumProtocolVersion)-\(Constants.maximumProtocolVersion))")
            }

            // Send acknowledgment
            hasCompletedHandshake = true
            let ackData = SerialProtocol.encode(.ack(profile: "general"))
            writeAll(ackData)

        case .keyPress(let key):
            #if DEBUG
            Log.serial.debug("Key \(key) pressed")
            #endif

        case .keyRelease(let key):
            #if DEBUG
            Log.serial.debug("Key \(key) released")
            #endif

        case .heartbeat:
            // If we receive a heartbeat but haven't completed the handshake,
            // the device is in WAITING_FOR_HOST and re-sending ready messages.
            // Send a proactive ack to complete the handshake (fixes reconnection
            // deadlock when the app misses the initial ready message).
            if !hasCompletedHandshake && fileDescriptor != -1 {
                Log.serial.info("Heartbeat received before handshake — sending proactive ack")
                hasCompletedHandshake = true
                let ackData = SerialProtocol.encode(.ack(profile: "general"))
                writeAll(ackData)
            }

        case .unknown(let type):
            Log.serial.warning("Unknown message type: \(type)")
        }

        // Forward to external handler
        onDeviceMessage?(message)
    }

    /// Retries on short writes. Logs on failure (doesn't throw).
    func writeAll(_ data: Data) {
        guard fileDescriptor != -1 else { return }
        let bytes = [UInt8](data)
        var totalWritten = 0
        while totalWritten < bytes.count {
            let result = bytes.withUnsafeBufferPointer { buffer in
                Darwin.write(fileDescriptor, buffer.baseAddress! + totalWritten, bytes.count - totalWritten)
            }
            if result <= 0 {
                Log.serial.error("Write failed (errno \(errno)), wrote \(totalWritten) of \(bytes.count) bytes")
                return
            }
            totalWritten += result
        }
    }

    func send(_ message: HostMessage) {
        serialQueue.async { [weak self] in
            guard let self = self, self.fileDescriptor != -1 else { return }
            let data = SerialProtocol.encode(message)
            self.writeAll(data)
        }
    }
}
