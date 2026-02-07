import Foundation
import IOKit
import IOKit.serial
import os

extension SerialDeviceManager {

    private func usbInterfaceNumber(for service: io_service_t) -> Int? {
        return IORegistryEntrySearchCFProperty(
            service, kIOServicePlane,
            "bInterfaceNumber" as CFString, nil,
            IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
        ) as? Int
    }

    private func matchCircuitPythonPort(_ service: io_service_t) -> (path: String, iface: Int)? {
        guard let vendorID = IORegistryEntrySearchCFProperty(
            service, kIOServicePlane,
            "idVendor" as CFString, nil,
            IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
        ) as? Int, vendorID == Constants.picoVendorID else {
            return nil
        }

        guard let path = IORegistryEntryCreateCFProperty(
            service,
            kIOCalloutDeviceKey as CFString,
            kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? String else {
            return nil
        }

        let iface = usbInterfaceNumber(for: service) ?? 0
        return (path, iface)
    }

    /// CircuitPython exposes two CDC ports: console (interface 0) and data (interface 2).
    /// We pick the highest bInterfaceNumber to get the data port deterministically.
    func findCircuitPythonDevice() -> String? {
        guard let matching = IOServiceMatching(kIOSerialBSDServiceValue) else {
            return nil
        }

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault, matching, &iterator
        ) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var bestPath: String?
        var bestIface: Int = -1

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            if let match = matchCircuitPythonPort(service), match.iface > bestIface {
                bestPath = match.path
                bestIface = match.iface
            }
        }

        if let path = bestPath {
            Log.serial.info("Found CircuitPython data port: \(path) (interface \(bestIface))")
            return path
        }

        return nil
    }

    func setupNotifications() {
        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort = notifyPort else { return }

        IONotificationPortSetDispatchQueue(notifyPort, notificationQueue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // Device added
        if let matching = IOServiceMatching(kIOSerialBSDServiceValue) {
            IOServiceAddMatchingNotification(
                notifyPort,
                kIOFirstMatchNotification,
                matching as CFDictionary,
                SerialDeviceManager.deviceAddedCallback,
                selfPtr,
                &addIterator
            )
            // Drain to arm the notification and catch already-present devices
            drainIterator(addIterator, checkConnection: true)
        }

        // Device removed
        if let matching = IOServiceMatching(kIOSerialBSDServiceValue) {
            IOServiceAddMatchingNotification(
                notifyPort,
                kIOTerminatedNotification,
                matching as CFDictionary,
                SerialDeviceManager.deviceRemovedCallback,
                selfPtr,
                &removeIterator
            )
            drainIterator(removeIterator, checkConnection: false)
        }
    }

    func teardownNotifications() {
        if addIterator != 0 {
            IOObjectRelease(addIterator)
            addIterator = 0
        }
        if removeIterator != 0 {
            IOObjectRelease(removeIterator)
            removeIterator = 0
        }
        if let port = notifyPort {
            IONotificationPortDestroy(port)
            notifyPort = nil
        }
    }

    /// Must drain after registration and in every callback to re-arm the notification.
    /// isConnected guard is deferred to connect(to:) on serialQueue to avoid
    /// a data race with the notification queue.
    func drainIterator(_ iterator: io_iterator_t, checkConnection: Bool) {
        var bestPath: String?
        var bestIface: Int = -1

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            if checkConnection {
                if let match = matchCircuitPythonPort(service), match.iface > bestIface {
                    bestPath = match.path
                    bestIface = match.iface
                }
            }
        }

        if let path = bestPath {
            connect(to: path)
        }
    }

    // C-compatible callbacks for IOKit
    static let deviceAddedCallback: IOServiceMatchingCallback = { refCon, iterator in
        guard let refCon = refCon else { return }
        let manager = Unmanaged<SerialDeviceManager>.fromOpaque(refCon).takeUnretainedValue()
        manager.drainIterator(iterator, checkConnection: true)
    }

    static let deviceRemovedCallback: IOServiceMatchingCallback = { refCon, iterator in
        guard let refCon = refCon else { return }
        let manager = Unmanaged<SerialDeviceManager>.fromOpaque(refCon).takeUnretainedValue()
        // Drain to re-arm notification
        var service = IOIteratorNext(iterator)
        while service != 0 {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        // Dispatch shared-state access onto serialQueue to avoid data race
        manager.serialQueue.async {
            if manager.isConnected {
                manager.handleDeviceRemoved()
            }
        }
    }

    func handleDeviceRemoved() {
        // Must be called on serialQueue
        if let path = connectedDevicePath {
            if !FileManager.default.fileExists(atPath: path) {
                Log.serial.info("Device removed: \(path)")
                disconnectAndRescan()
            }
        }
    }
}
