"""Tests for firmware key event generation."""

import json
from pathlib import Path

import pytest

from firmware_code import SerialComm, FirmwareState, NUM_KEYS, PROTOCOL_VERSION, FIRMWARE_VERSION


FIXTURES_DIR = Path(__file__).parent.parent / "fixtures" / "serial_messages"


class TestKeyPressEvents:
    """Tests for key press event JSON output."""

    def test_key_press_structure(self, mock_serial):
        """Key press message has type and 1-indexed key number."""
        comm = SerialComm(mock_serial)
        comm.send_key_press(1)

        messages = mock_serial.get_written_messages()
        assert len(messages) == 1
        assert messages[0]["type"] == "key_press"
        assert messages[0]["key"] == 1

    def test_key_release_structure(self, mock_serial):
        """Key release message has type and 1-indexed key number."""
        comm = SerialComm(mock_serial)
        comm.send_key_release(5)

        messages = mock_serial.get_written_messages()
        assert len(messages) == 1
        assert messages[0]["type"] == "key_release"
        assert messages[0]["key"] == 5

    def test_all_keys_produce_valid_events(self, mock_serial):
        """All 9 keys produce valid press/release events."""
        comm = SerialComm(mock_serial)
        for key in range(1, NUM_KEYS + 1):
            comm.send_key_press(key)
            comm.send_key_release(key)

        messages = mock_serial.get_written_messages()
        assert len(messages) == NUM_KEYS * 2

        for i, key in enumerate(range(1, NUM_KEYS + 1)):
            assert messages[i * 2]["type"] == "key_press"
            assert messages[i * 2]["key"] == key
            assert messages[i * 2 + 1]["type"] == "key_release"
            assert messages[i * 2 + 1]["key"] == key

    def test_key_numbers_are_1_indexed(self, mock_serial):
        """Key numbers in events are 1-9, not 0-8."""
        comm = SerialComm(mock_serial)
        comm.send_key_press(1)

        messages = mock_serial.get_written_messages()
        assert messages[0]["key"] == 1
        assert messages[0]["key"] >= 1

    def test_key_press_matches_fixture(self, mock_serial):
        """Key press event matches the canonical fixture."""
        with open(FIXTURES_DIR / "key_press.json") as f:
            fixture = json.load(f)

        comm = SerialComm(mock_serial)
        comm.send_key_press(fixture["key"])

        messages = mock_serial.get_written_messages()
        assert messages[0]["type"] == fixture["type"]
        assert messages[0]["key"] == fixture["key"]

    def test_key_release_matches_fixture(self, mock_serial):
        """Key release event matches the canonical fixture."""
        with open(FIXTURES_DIR / "key_release.json") as f:
            fixture = json.load(f)

        comm = SerialComm(mock_serial)
        comm.send_key_release(fixture["key"])

        messages = mock_serial.get_written_messages()
        assert messages[0]["type"] == fixture["type"]
        assert messages[0]["key"] == fixture["key"]

    def test_events_are_newline_terminated(self, mock_serial):
        """Each event is a single line terminated by newline."""
        comm = SerialComm(mock_serial)
        comm.send_key_press(3)

        raw = mock_serial.get_written()
        assert raw.endswith("\n")
        lines = raw.strip().split("\n")
        assert len(lines) == 1

    def test_events_are_valid_json(self, mock_serial):
        """All events are parseable JSON."""
        comm = SerialComm(mock_serial)
        comm.send_key_press(1)
        comm.send_key_release(1)

        raw = mock_serial.get_written()
        for line in raw.strip().split("\n"):
            parsed = json.loads(line)
            assert "type" in parsed

    def test_send_with_none_port_does_not_crash(self):
        """Sending with None port is silently ignored."""
        comm = SerialComm(None)
        comm.send_key_press(1)  # Should not raise


class TestReadyMessage:
    """Tests for the device ready message."""

    def test_ready_message_structure(self, mock_serial):
        """Ready message includes protocol, firmware, and key count."""
        comm = SerialComm(mock_serial)
        comm.send_ready()

        messages = mock_serial.get_written_messages()
        assert len(messages) == 1
        msg = messages[0]
        assert msg["type"] == "ready"
        assert msg["protocol"] == PROTOCOL_VERSION
        assert msg["firmware"] == FIRMWARE_VERSION
        assert msg["keys"] == NUM_KEYS

    def test_ready_matches_fixture(self, mock_serial):
        """Ready message matches the canonical fixture."""
        with open(FIXTURES_DIR / "ready.json") as f:
            fixture = json.load(f)

        comm = SerialComm(mock_serial)
        comm.send_ready()

        messages = mock_serial.get_written_messages()
        assert messages[0]["type"] == fixture["type"]
        assert messages[0]["protocol"] == fixture["protocol"]
        assert messages[0]["keys"] == fixture["keys"]


class TestReadMessage:
    """Tests for reading messages from the host."""

    def test_read_complete_message(self, mock_serial):
        """Complete JSON message is parsed correctly."""
        comm = SerialComm(mock_serial)
        mock_serial.inject_read('{"type": "ack", "profile": "general"}\n')

        msg = comm.read_message()
        assert msg is not None
        assert msg["type"] == "ack"
        assert msg["profile"] == "general"

    def test_read_no_data_returns_none(self, mock_serial):
        """No data available returns None."""
        comm = SerialComm(mock_serial)
        msg = comm.read_message()
        assert msg is None

    def test_read_partial_message_returns_none(self, mock_serial):
        """Incomplete message (no newline) returns None."""
        comm = SerialComm(mock_serial)
        mock_serial.inject_read('{"type": "ack"')

        msg = comm.read_message()
        assert msg is None

    def test_read_malformed_json_returns_none(self, mock_serial):
        """Malformed JSON is discarded and returns None."""
        comm = SerialComm(mock_serial)
        mock_serial.inject_read("not json at all\n")

        msg = comm.read_message()
        assert msg is None

    def test_read_with_none_port(self):
        """Reading from None port returns None without error."""
        comm = SerialComm(None)
        msg = comm.read_message()
        assert msg is None
