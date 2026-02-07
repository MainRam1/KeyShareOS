import Foundation
import IOKit
import IOKit.serial
import os

// MARK: - Errors

enum SerialError: Error, CustomStringConvertible {
    case openFailed(String, Int32)
    case exclusiveFailed
    case fcntlFailed
    case setAttrFailed
    case deviceNotFound

    var description: String {
        switch self {
        case .openFailed(let path, let err):
            return "Failed to open \(path): errno \(err)"
        case .exclusiveFailed:
            return "Failed to set exclusive access on serial port"
        case .fcntlFailed:
            return "Failed to configure serial port flags"
        case .setAttrFailed:
            return "Failed to set serial port attributes"
        case .deviceNotFound:
            return "No matching serial device found"
        }
    }
}

/// Handles IOKit discovery, POSIX serial I/O, hot-plug, and line-based JSON framing.
///
/// Threading model:
/// - IOKit notifications fire on `notificationQueue`
/// - Serial reads fire on `serialQueue` via DispatchSource
/// - External callbacks (delegate/closure) dispatch to caller's queue
final class SerialDeviceManager {

    var onDeviceMessage: ((DeviceMessage) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?

    private(set) var isConnected: Bool = false

    deinit {
        stopScanning()
    }

    let serialQueue = DispatchQueue(label: "com.macro.serial.io")
    let notificationQueue = DispatchQueue(label: "com.macro.serial.notify")

    var notifyPort: IONotificationPortRef?
    var addIterator: io_iterator_t = 0
    var removeIterator: io_iterator_t = 0

    var fileDescriptor: Int32 = -1
    var readSource: DispatchSourceRead?
    var originalAttrs = termios()
    var connectedDevicePath: String?

    let lineBuffer = LineBuffer()
    var hasCompletedHandshake = false

    // MARK: - Device Scanning

    func startScanning() {
        if let path = findCircuitPythonDevice() {
            connect(to: path)
        }
        setupNotifications()
    }

    func stopScanning() {
        disconnect()
        teardownNotifications()
    }

    // MARK: - Connection

    func connect(to path: String) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isConnected else { return }

            do {
                try self.openPort(at: path)
                self.connectedDevicePath = path
                self.isConnected = true
                self.startReading()

                Log.serial.info("Connected to \(path)")
                self.onConnectionStateChanged?(true)
            } catch {
                Log.serial.error("Failed to connect to \(path): \(error.localizedDescription)")
            }
        }
    }

    func disconnect() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            self.performDisconnect()
        }
    }

    /// Disconnect and then re-scan for devices. Fixes the IOKit race where
    /// deviceAddedCallback fires while isConnected is still true (disconnect
    /// hasn't run on serialQueue yet), causing the new device to be ignored.
    func disconnectAndRescan() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            self.performDisconnect()
        }
        serialQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, !self.isConnected else { return }
            if let newPath = self.findCircuitPythonDevice() {
                Log.serial.info("Re-scan found device after disconnect: \(newPath)")
                self.connect(to: newPath)
            }
        }
    }

    func performDisconnect() {
        if readSource != nil {
            // Cancel read source — fd close happens in cancel handler per Apple docs
            readSource?.cancel()
            readSource = nil
        } else if fileDescriptor != -1 {
            // No read source active — close fd directly
            tcsetattr(fileDescriptor, TCSANOW, &originalAttrs)
            close(fileDescriptor)
            fileDescriptor = -1
        }

        lineBuffer.reset()
        hasCompletedHandshake = false
        connectedDevicePath = nil

        if isConnected {
            isConnected = false
            Log.serial.info("Disconnected from device")
            onConnectionStateChanged?(false)
        }
    }

    // MARK: - POSIX Serial Port

    private func openPort(at path: String) throws {
        // O_NONBLOCK so open() doesn't wait for DCD (cu.* shouldn't, but safe)
        let fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd != -1 else {
            throw SerialError.openFailed(path, errno)
        }

        guard ioctl(fd, TIOCEXCL) != -1 else {
            close(fd)
            throw SerialError.exclusiveFailed
        }

        // Clear O_NONBLOCK now that we have the fd
        guard fcntl(fd, F_SETFL, 0) != -1 else {
            close(fd)
            throw SerialError.fcntlFailed
        }

        tcgetattr(fd, &originalAttrs)

        var options = termios()
        tcgetattr(fd, &options)
        cfmakeraw(&options)

        // USB CDC ignores baud rate but POSIX requires it
        cfsetspeed(&options, Constants.serialBaudRate)

        // VMIN=1, VTIME=0: block until at least 1 byte available
        // (DispatchSource handles the non-blocking waiting for us)
        withUnsafeMutablePointer(to: &options.c_cc) { ptr in
            let cc = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: cc_t.self)
            cc[Int(VMIN)] = 1
            cc[Int(VTIME)] = 0
        }

        guard tcsetattr(fd, TCSANOW, &options) != -1 else {
            close(fd)
            throw SerialError.setAttrFailed
        }

        fileDescriptor = fd
    }

}
