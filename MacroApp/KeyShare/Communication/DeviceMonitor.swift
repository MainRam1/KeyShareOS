import Cocoa
import Foundation
import os

/// Disconnects serial on sleep, re-scans on wake after USB re-enumeration.
final class DeviceMonitor {

    /// USB CDC devices take ~2s to re-enumerate after system wake.
    private static let wakeRescanDelay: TimeInterval = 2.5

    private let serialManager: SerialDeviceManager
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var screensSleepObserver: NSObjectProtocol?
    private var screensWakeObserver: NSObjectProtocol?
    private var wasConnectedBeforeSleep: Bool = false

    init(serialManager: SerialDeviceManager) {
        self.serialManager = serialManager
    }

    deinit {
        stop()
    }

    func start() {
        guard sleepObserver == nil else { return } // Idempotent

        let center = NSWorkspace.shared.notificationCenter

        sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillSleep()
        }

        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDidWake()
        }

        screensSleepObserver = center.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreensSleep()
        }

        screensWakeObserver = center.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreensWake()
        }

        Log.serial.info("DeviceMonitor: started monitoring sleep/wake events")
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter

        if let observer = sleepObserver {
            center.removeObserver(observer)
            sleepObserver = nil
        }
        if let observer = wakeObserver {
            center.removeObserver(observer)
            wakeObserver = nil
        }
        if let observer = screensSleepObserver {
            center.removeObserver(observer)
            screensSleepObserver = nil
        }
        if let observer = screensWakeObserver {
            center.removeObserver(observer)
            screensWakeObserver = nil
        }

        Log.serial.info("DeviceMonitor: stopped monitoring sleep/wake events")
    }

    // MARK: - Sleep/Wake Handlers

    private func handleWillSleep() {
        wasConnectedBeforeSleep = serialManager.isConnected
        if wasConnectedBeforeSleep {
            Log.serial.info("DeviceMonitor: system sleeping — disconnecting serial device")
            serialManager.disconnect()
        }
    }

    private func handleDidWake() {
        Log.serial.info("DeviceMonitor: system woke — scheduling device re-scan in \(Self.wakeRescanDelay, format: .fixed(precision: 1))s")

        // Delay re-scan to allow USB bus to re-enumerate
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.wakeRescanDelay) { [weak self] in
            guard let self = self else { return }
            if self.wasConnectedBeforeSleep {
                Log.serial.info("DeviceMonitor: re-scanning for serial device after wake")
                self.serialManager.startScanning()
            }
        }
    }

    private func handleScreensSleep() {
        Log.serial.info("DeviceMonitor: screens did sleep")
        // Screens sleeping doesn't necessarily mean USB is lost.
        // No action needed — willSleepNotification handles full system sleep.
    }

    private func handleScreensWake() {
        Log.serial.info("DeviceMonitor: screens did wake")
        // If device wasn't connected before sleep but screens wake,
        // it might be worth a quick scan in case device was plugged in while sleeping.
        if !serialManager.isConnected {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.serialManager.startScanning()
            }
        }
    }
}
