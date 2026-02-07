"""Shared fixtures for firmware tests."""

import importlib.util
import json
import sys
from io import BytesIO
from pathlib import Path
from unittest.mock import MagicMock

import pytest

# Mock CircuitPython modules before importing firmware code
_board = type(sys)("board")
_board.GP2 = "GP2"
_board.GP3 = "GP3"
_board.GP4 = "GP4"
_board.GP5 = "GP5"
_board.GP6 = "GP6"
_board.GP7 = "GP7"
_board.GP8 = "GP8"
_board.GP9 = "GP9"
_board.GP10 = "GP10"
sys.modules["board"] = _board
sys.modules["keypad"] = MagicMock()
sys.modules["usb_cdc"] = MagicMock()
sys.modules["gc"] = MagicMock()

# Load firmware/code.py as "firmware_code" to avoid shadowing stdlib `code`
_firmware_path = Path(__file__).parent.parent.parent / "firmware" / "code.py"
_spec = importlib.util.spec_from_file_location("firmware_code", _firmware_path)
firmware_code = importlib.util.module_from_spec(_spec)

# Prevent main() from running on import (it calls main() at module level)
_source = _firmware_path.read_text()
_source = _source.replace("\nmain()\n", "\n# main() skipped for testing\n")
exec(compile(_source, str(_firmware_path), "exec"), firmware_code.__dict__)

sys.modules["firmware_code"] = firmware_code


class MockSerial:
    """Mock for usb_cdc.data serial port."""

    def __init__(self):
        self._write_buffer = BytesIO()
        self._read_buffer = BytesIO()
        self.in_waiting = 0

    def write(self, data: bytes):
        self._write_buffer.write(data)

    def read(self, count: int) -> bytes:
        return self._read_buffer.read(count)

    def readline(self) -> bytes:
        return self._read_buffer.readline()

    def get_written(self) -> str:
        """Get all written data as a string."""
        self._write_buffer.seek(0)
        return self._write_buffer.read().decode()

    def get_written_messages(self) -> list:
        """Get all written data split into individual JSON messages."""
        raw = self.get_written()
        messages = []
        for line in raw.strip().split("\n"):
            if line:
                messages.append(json.loads(line))
        return messages

    def inject_read(self, data: str):
        """Inject data into the read buffer as if the host sent it."""
        pos = self._read_buffer.tell()
        self._read_buffer.seek(0, 2)  # Seek to end
        encoded = data.encode()
        self._read_buffer.write(encoded)
        self._read_buffer.seek(pos)
        self.in_waiting = len(encoded)


@pytest.fixture
def mock_serial():
    """Provide a fresh MockSerial instance."""
    return MockSerial()
