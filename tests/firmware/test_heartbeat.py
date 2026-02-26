"""Tests for firmware heartbeat timing."""

import sys
from unittest.mock import patch

import pytest

from firmware_code import SerialComm, MacropadFirmware, FirmwareState, HEARTBEAT_INTERVAL_S


class MockKeyScanner:
    """Mock key scanner that returns no events."""

    def get_event(self):
        return None


class TestHeartbeat:
    """Tests for heartbeat generation and timing."""

    def test_heartbeat_message_structure(self, mock_serial):
        """Heartbeat message has only type field."""
        comm = SerialComm(mock_serial)
        comm.send_heartbeat()

        messages = mock_serial.get_written_messages()
        assert len(messages) == 1
        assert messages[0] == {"type": "heartbeat"}

    def test_heartbeat_interval_constant(self):
        """Heartbeat interval is 5 seconds per spec."""
        assert HEARTBEAT_INTERVAL_S == 5.0

    @patch("firmware_code.time")
    def test_heartbeat_sent_after_interval(self, mock_time, mock_serial):
        """Heartbeat is sent when interval elapses."""
        mock_time.monotonic.return_value = 0.0

        comm = SerialComm(mock_serial)
        scanner = MockKeyScanner()
        firmware = MacropadFirmware(scanner, comm)

        # Initialize state
        firmware._state = FirmwareState.RUNNING
        firmware._host_connected = True
        firmware._last_heartbeat = 0.0

        # Time hasn't advanced enough — no heartbeat
        mock_time.monotonic.return_value = 4.0
        firmware._check_heartbeat()
        messages = mock_serial.get_written_messages()
        assert len(messages) == 0

        # Time advances past interval — heartbeat sent
        mock_time.monotonic.return_value = 5.0
        firmware._check_heartbeat()
        messages = mock_serial.get_written_messages()
        assert len(messages) == 1
        assert messages[0]["type"] == "heartbeat"

    @patch("firmware_code.time")
    def test_heartbeat_resets_timer(self, mock_time, mock_serial):
        """After sending heartbeat, timer resets for next interval."""
        mock_time.monotonic.return_value = 0.0

        comm = SerialComm(mock_serial)
        scanner = MockKeyScanner()
        firmware = MacropadFirmware(scanner, comm)

        firmware._state = FirmwareState.RUNNING
        firmware._host_connected = True
        firmware._last_heartbeat = 0.0

        # First heartbeat at 5s
        mock_time.monotonic.return_value = 5.0
        firmware._check_heartbeat()

        # At 9s (only 4s since last) — no heartbeat
        mock_time.monotonic.return_value = 9.0
        firmware._check_heartbeat()
        messages = mock_serial.get_written_messages()
        assert len(messages) == 1  # Still just the first one

        # At 10s (5s since last) — second heartbeat
        mock_time.monotonic.return_value = 10.0
        firmware._check_heartbeat()
        messages = mock_serial.get_written_messages()
        assert len(messages) == 2

    @patch("firmware_code.time")
    def test_heartbeat_sent_while_waiting_for_host(self, mock_time, mock_serial):
        """Heartbeats are sent even in WAITING_FOR_HOST state."""
        mock_time.monotonic.return_value = 0.0

        comm = SerialComm(mock_serial)
        scanner = MockKeyScanner()
        firmware = MacropadFirmware(scanner, comm)

        firmware._state = FirmwareState.WAITING_FOR_HOST
        firmware._last_heartbeat = 0.0

        mock_time.monotonic.return_value = 5.0
        firmware._check_heartbeat()

        messages = mock_serial.get_written_messages()
        assert len(messages) == 1
        assert messages[0]["type"] == "heartbeat"


class TestFirmwareState:
    """Tests for firmware state machine transitions."""

    def test_initial_state(self, mock_serial):
        """Firmware starts in INITIALIZING state."""
        comm = SerialComm(mock_serial)
        scanner = MockKeyScanner()
        firmware = MacropadFirmware(scanner, comm)
        assert firmware._state == FirmwareState.INITIALIZING

    @patch("firmware_code.time")
    def test_waiting_to_running_on_ack(self, mock_time, mock_serial):
        """Firmware transitions from WAITING to RUNNING on ack message."""
        mock_time.monotonic.return_value = 0.0

        comm = SerialComm(mock_serial)
        scanner = MockKeyScanner()
        firmware = MacropadFirmware(scanner, comm)

        firmware._state = FirmwareState.WAITING_FOR_HOST
        firmware._last_heartbeat = 0.0

        # Inject ack message
        mock_serial.inject_read('{"type": "ack", "profile": "general"}\n')

        firmware._handle_waiting()
        assert firmware._state == FirmwareState.RUNNING
        assert firmware._host_connected is True

    def test_firmware_state_values(self):
        """State enum has expected string values."""
        assert FirmwareState.INITIALIZING == "initializing"
        assert FirmwareState.WAITING_FOR_HOST == "waiting_for_host"
        assert FirmwareState.RUNNING == "running"
        assert FirmwareState.ERROR == "error"
