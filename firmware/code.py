"""Macro Firmware — code.py

Main firmware for the 9-key macropad on Raspberry Pi Pico.
Scans 9 Cherry MX switches, sends JSON key events over USB CDC serial,
and receives host messages (ack, profile_changed).

Architecture: State machine with dependency injection for testability.
"""

import board
import gc
import json
import keypad
import time
import usb_cdc

# --- Constants ---

FIRMWARE_VERSION = "0.1.0"
PROTOCOL_VERSION = 1
NUM_KEYS = 9
HEARTBEAT_INTERVAL_S = 5.0
READY_RETRY_INTERVAL_S = 3.0

# GPIO pin assignments — order determines key numbering (0-indexed internally).
# Key 1 = GP2, Key 2 = GP3, ..., Key 9 = GP10.
KEY_PINS = (
    board.GP2,   # Key 1
    board.GP3,   # Key 2
    board.GP4,   # Key 3
    board.GP5,   # Key 4
    board.GP6,   # Key 5
    board.GP7,   # Key 6
    board.GP8,   # Key 7
    board.GP9,   # Key 8
    board.GP10,  # Key 9
)


# --- State Machine ---

class FirmwareState:
    """Firmware operational states."""
    INITIALIZING = "initializing"
    WAITING_FOR_HOST = "waiting_for_host"
    RUNNING = "running"
    ERROR = "error"


# --- Serial Communication ---

class SerialComm:
    """Handles all serial communication with the host.

    Single exit point for outbound messages (json.dumps only called here).
    Accepts an injected serial port for testability.
    """

    def __init__(self, serial_port):
        self._port = serial_port
        self._read_buffer = bytearray()

    def send(self, message_dict):
        """Send a JSON message terminated by newline. Single serialization point."""
        if self._port is None:
            return
        try:
            self._port.write((json.dumps(message_dict) + "\n").encode())
        except OSError:
            pass  # Host disconnected — handled by state machine

    def send_key_press(self, key_number):
        """Send a key press event. key_number is 1-indexed (user-facing)."""
        self.send({"type": "key_press", "key": key_number})

    def send_key_release(self, key_number):
        """Send a key release event. key_number is 1-indexed (user-facing)."""
        self.send({"type": "key_release", "key": key_number})

    def send_ready(self):
        """Send device ready message on startup/reconnection."""
        self.send({
            "type": "ready",
            "protocol": PROTOCOL_VERSION,
            "firmware": FIRMWARE_VERSION,
            "keys": NUM_KEYS,
        })

    def send_heartbeat(self):
        """Send heartbeat to indicate device is alive."""
        self.send({"type": "heartbeat"})

    def read_message(self):
        """Non-blocking read of a single JSON message from host.

        Returns parsed dict if a complete message is available, None otherwise.
        Accumulates partial reads in an internal buffer.
        """
        if self._port is None or self._port.in_waiting == 0:
            return None

        # Read available bytes into buffer
        incoming = self._port.read(self._port.in_waiting)
        if incoming:
            self._read_buffer.extend(incoming)

        # Look for a complete line (newline-terminated JSON)
        newline_pos = self._read_buffer.find(b"\n")
        if newline_pos == -1:
            return None

        # Extract the line and remove it from buffer
        line = self._read_buffer[:newline_pos]
        self._read_buffer = self._read_buffer[newline_pos + 1:]

        try:
            return json.loads(line)
        except (ValueError, UnicodeError):
            return None  # Malformed JSON — discard


# --- Key Scanner ---

class KeyScanner:
    """Wraps keypad.Keys for the 9-key macropad.

    Uses internal pull-ups with value_when_pressed=False
    (Cherry MX switches pull to GND when pressed).
    """

    def __init__(self, pins):
        self._keys = keypad.Keys(
            pins=pins,
            value_when_pressed=False,
            pull=True,
            interval=0.020,  # 20ms debounce (Cherry MX bounces <5ms)
            max_events=64,
        )
        self._event = keypad.Event()

    @property
    def events(self):
        """Access the event queue."""
        return self._keys.events

    def get_event(self):
        """Get the next key event without allocating.

        Returns (key_number_1indexed, is_pressed) or None.
        """
        if self._keys.events.get_into(self._event):
            # Convert 0-indexed to 1-indexed (user-facing key numbers)
            return (self._event.key_number + 1, self._event.pressed)
        return None


# --- Main Firmware ---

class MacropadFirmware:
    """Main firmware state machine.

    Coordinates key scanning, serial communication, and heartbeat timing.
    All dependencies are injected for testability.
    """

    def __init__(self, key_scanner, serial_comm):
        self._state = FirmwareState.INITIALIZING
        self._scanner = key_scanner
        self._serial = serial_comm
        self._last_heartbeat = 0.0
        self._last_ready_time = 0.0
        self._host_connected = False

    def run(self):
        """Main loop. Each state has exactly one handler method."""
        self._state = FirmwareState.WAITING_FOR_HOST
        self._serial.send_ready()
        now = time.monotonic()
        self._last_heartbeat = now
        self._last_ready_time = now

        while True:
            if self._state == FirmwareState.WAITING_FOR_HOST:
                self._handle_waiting()
            elif self._state == FirmwareState.RUNNING:
                self._handle_running()
            elif self._state == FirmwareState.ERROR:
                self._handle_error()

            gc.collect()

    def _handle_waiting(self):
        """Wait for host acknowledgment before processing keys."""
        msg = self._serial.read_message()
        if msg and msg.get("type") == "ack":
            self._host_connected = True
            self._state = FirmwareState.RUNNING
            return

        # Re-send ready periodically so the host can ack even if it
        # missed the first one (e.g. app launched after device boot,
        # or reconnection after unplug/replug).
        now = time.monotonic()
        if now - self._last_ready_time >= READY_RETRY_INTERVAL_S:
            self._serial.send_ready()
            self._last_ready_time = now

        # Still send heartbeats while waiting
        self._check_heartbeat()

        # Drain key events to prevent queue overflow while waiting
        while self._scanner.get_event() is not None:
            pass

    def _handle_running(self):
        """Process key events and host messages."""
        # Process all pending key events
        event = self._scanner.get_event()
        while event is not None:
            key_number, is_pressed = event
            if is_pressed:
                self._serial.send_key_press(key_number)
            else:
                self._serial.send_key_release(key_number)
            event = self._scanner.get_event()

        # Check for host messages
        msg = self._serial.read_message()
        if msg is not None:
            self._handle_host_message(msg)

        # Send heartbeat
        self._check_heartbeat()

    def _handle_error(self):
        """Error recovery: attempt to re-establish communication."""
        time.sleep(1.0)
        self._serial.send_ready()
        self._state = FirmwareState.WAITING_FOR_HOST
        self._last_heartbeat = time.monotonic()

    def _handle_host_message(self, msg):
        """Process a message from the host."""
        msg_type = msg.get("type")
        if msg_type == "ack":
            self._host_connected = True
        elif msg_type == "profile_changed":
            pass  # Future: update display/LEDs

    def _check_heartbeat(self):
        """Send heartbeat if interval has elapsed."""
        now = time.monotonic()
        if now - self._last_heartbeat >= HEARTBEAT_INTERVAL_S:
            self._serial.send_heartbeat()
            self._last_heartbeat = now


# --- Entry Point ---

def main():
    """Initialize hardware and start firmware."""
    scanner = KeyScanner(KEY_PINS)
    serial = SerialComm(usb_cdc.data)
    firmware = MacropadFirmware(scanner, serial)
    firmware.run()


main()
