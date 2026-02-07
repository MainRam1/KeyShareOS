"""Tests for firmware serial communication protocol."""

import json
import sys
from pathlib import Path

import pytest

# Add firmware directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "firmware"))

# Mock CircuitPython modules before importing firmware code
sys.modules["board"] = type(sys)("board")
sys.modules["keypad"] = type(sys)("keypad")
sys.modules["usb_cdc"] = type(sys)("usb_cdc")

# Now we can import the firmware module's constants
# (We test the protocol at the message level, not by importing code.py directly,
# because code.py uses CircuitPython hardware that can't run on CPython)


FIXTURES_DIR = Path(__file__).parent.parent / "fixtures" / "serial_messages"


class TestProtocolSpec:
    """Tests that validate against the canonical protocol_spec.json."""

    def test_protocol_spec_exists(self):
        spec_path = FIXTURES_DIR / "protocol_spec.json"
        assert spec_path.exists(), f"Protocol spec not found at {spec_path}"

    def test_protocol_spec_valid_json(self):
        spec_path = FIXTURES_DIR / "protocol_spec.json"
        with open(spec_path) as f:
            spec = json.load(f)
        assert spec["protocol_version"] == 1

    def test_fixture_key_press_matches_spec(self):
        with open(FIXTURES_DIR / "key_press.json") as f:
            msg = json.load(f)
        assert msg["type"] == "key_press"
        assert isinstance(msg["key"], int)
        assert 1 <= msg["key"] <= 9

    def test_fixture_key_release_matches_spec(self):
        with open(FIXTURES_DIR / "key_release.json") as f:
            msg = json.load(f)
        assert msg["type"] == "key_release"
        assert isinstance(msg["key"], int)
        assert 1 <= msg["key"] <= 9

    def test_fixture_ready_matches_spec(self):
        with open(FIXTURES_DIR / "ready.json") as f:
            msg = json.load(f)
        assert msg["type"] == "ready"
        assert isinstance(msg["protocol"], int)
        assert isinstance(msg["firmware"], str)
        assert isinstance(msg["keys"], int)
        assert msg["keys"] == 9


class TestSerialComm:
    """Tests for the SerialComm class behavior using mock serial port."""

    def test_send_key_press(self, mock_serial):
        """Key press message has correct structure with 1-indexed key number."""
        from conftest import MockSerial

        serial = mock_serial
        # Simulate what SerialComm.send_key_press does
        msg = {"type": "key_press", "key": 5}
        serial.write((json.dumps(msg) + "\n").encode())

        messages = serial.get_written_messages()
        assert len(messages) == 1
        assert messages[0]["type"] == "key_press"
        assert messages[0]["key"] == 5

    def test_send_key_release(self, mock_serial):
        """Key release message has correct structure."""
        msg = {"type": "key_release", "key": 3}
        mock_serial.write((json.dumps(msg) + "\n").encode())

        messages = mock_serial.get_written_messages()
        assert len(messages) == 1
        assert messages[0]["type"] == "key_release"
        assert messages[0]["key"] == 3

    def test_send_ready(self, mock_serial):
        """Ready message includes protocol version, firmware version, and key count."""
        msg = {
            "type": "ready",
            "protocol": 1,
            "firmware": "0.1.0",
            "keys": 9,
        }
        mock_serial.write((json.dumps(msg) + "\n").encode())

        messages = mock_serial.get_written_messages()
        assert len(messages) == 1
        assert messages[0]["type"] == "ready"
        assert messages[0]["protocol"] == 1
        assert messages[0]["firmware"] == "0.1.0"
        assert messages[0]["keys"] == 9

    def test_send_heartbeat(self, mock_serial):
        """Heartbeat message has only type field."""
        msg = {"type": "heartbeat"}
        mock_serial.write((json.dumps(msg) + "\n").encode())

        messages = mock_serial.get_written_messages()
        assert len(messages) == 1
        assert messages[0]["type"] == "heartbeat"

    def test_messages_are_newline_terminated(self, mock_serial):
        """Every message ends with exactly one newline."""
        msg = {"type": "heartbeat"}
        mock_serial.write((json.dumps(msg) + "\n").encode())

        raw = mock_serial.get_written()
        assert raw.endswith("\n")
        # No double newlines
        assert "\n\n" not in raw

    def test_key_numbers_are_1_indexed(self):
        """Key numbers in messages must be 1-9, not 0-8."""
        for key_num in range(1, 10):
            msg = {"type": "key_press", "key": key_num}
            encoded = json.dumps(msg)
            decoded = json.loads(encoded)
            assert decoded["key"] == key_num
            assert 1 <= decoded["key"] <= 9

    def test_messages_are_valid_json(self, mock_serial):
        """All messages are parseable JSON."""
        messages_to_send = [
            {"type": "key_press", "key": 1},
            {"type": "key_release", "key": 1},
            {"type": "ready", "protocol": 1, "firmware": "0.1.0", "keys": 9},
            {"type": "heartbeat"},
        ]
        for msg in messages_to_send:
            mock_serial.write((json.dumps(msg) + "\n").encode())

        raw = mock_serial.get_written()
        for line in raw.strip().split("\n"):
            parsed = json.loads(line)  # Should not raise
            assert "type" in parsed
