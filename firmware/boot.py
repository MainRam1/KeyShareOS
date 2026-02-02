"""Macro Firmware — boot.py

USB configuration for the 9-key macropad.
Runs once before USB connection is established.

IMPORTANT: Changes to this file require a board reset to take effect.
"""

import usb_cdc

# Enable the data serial port for application communication.
# By default, only the console serial (REPL) is enabled.
# The data serial port appears as a second serial device on the host.
usb_cdc.enable(console=True, data=True)
