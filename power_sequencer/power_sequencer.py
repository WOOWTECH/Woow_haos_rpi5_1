#!/usr/bin/env python3
"""
Power Sequencer RS232 Control Script
用於 Home Assistant shell_command 控制 Power Sequencer

Usage:
  python3 power_sequencer.py <port> <address> <channel> <action>

Arguments:
  port     - Serial port path (e.g., /dev/ttyUSB0)
  address  - Machine address 1-255 (decimal)
  channel  - Channel number: 1-8, 0=all, 13=sequential, 16=simultaneous
  action   - on / off

Protocol: 6 bytes hex
  55 [addr] 00 [channel] [action] aa
  action: f0=ON, f1=OFF

Examples:
  python3 power_sequencer.py /dev/ttyUSB0 1 1 on    # Ch1 ON
  python3 power_sequencer.py /dev/ttyUSB0 1 3 off   # Ch3 OFF
  python3 power_sequencer.py /dev/ttyUSB0 1 0 on     # All ON
  python3 power_sequencer.py /dev/ttyUSB0 1 13 on    # Sequential ON
  python3 power_sequencer.py /dev/ttyUSB0 1 16 off   # Simultaneous All OFF
"""

import sys
import serial
import time


def send_command(port: str, address: int, channel: int, action: str) -> bool:
    action_byte = 0xF0 if action == "on" else 0xF1
    cmd = bytes([0x55, address, 0x00, channel, action_byte, 0xAA])

    try:
        ser = serial.Serial(
            port,
            baudrate=9600,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1,
            xonxoff=False,
            rtscts=False,
            dsrdtr=False,
        )
        ser.reset_input_buffer()
        ser.write(cmd)
        ser.flush()
        time.sleep(0.05)
        ser.close()
        return True
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return False


def main():
    if len(sys.argv) != 5:
        print(f"Usage: {sys.argv[0]} <port> <address> <channel> <action>")
        sys.exit(1)

    port = sys.argv[1]
    address = int(sys.argv[2])
    channel = int(sys.argv[3])
    action = sys.argv[4].lower()

    if action not in ("on", "off"):
        print("Action must be 'on' or 'off'", file=sys.stderr)
        sys.exit(1)

    if not (1 <= address <= 255):
        print("Address must be 1-255", file=sys.stderr)
        sys.exit(1)

    if channel not in list(range(0, 9)) + [13, 16]:
        print("Channel must be 0-8, 13 (sequential), or 16 (simultaneous)", file=sys.stderr)
        sys.exit(1)

    success = send_command(port, address, channel, action)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
