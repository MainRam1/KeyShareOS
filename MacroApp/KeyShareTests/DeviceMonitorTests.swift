import XCTest
@testable import KeyShare

final class DeviceMonitorTests: XCTestCase {

    private var serialManager: SerialDeviceManager!

    override func setUp() {
        super.setUp()
        serialManager = SerialDeviceManager()
    }

    override func tearDown() {
        serialManager = nil
        super.tearDown()
    }

    func testCreation() {
        let monitor = DeviceMonitor(serialManager: serialManager)
        XCTAssertNotNil(monitor)
    }

    func testStartStopIdempotent() {
        let monitor = DeviceMonitor(serialManager: serialManager)
        monitor.start()
        monitor.start()
        monitor.stop()
        monitor.stop()
    }

    func testStartThenStop() {
        let monitor = DeviceMonitor(serialManager: serialManager)
        monitor.start()
        monitor.stop()
    }

    func testDeinitCleanup() {
        var monitor: DeviceMonitor? = DeviceMonitor(serialManager: serialManager)
        monitor?.start()
        monitor = nil
    }
}
