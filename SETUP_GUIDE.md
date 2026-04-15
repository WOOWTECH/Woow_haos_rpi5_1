# RPi5 HAOS - RS485 x2 / RS232 x1 / CAN Bus x2 Testing Guide

## Overview

Testing 5 communication interfaces on a Raspberry Pi 5 running Home Assistant OS (HAOS):
- **RS485 #1** - UART1 (`/dev/ttyAMA1`) on GPIO 0/1
- **RS485 #2** - UART2 (`/dev/ttyAMA2`) on GPIO 4/5
- **RS232 #1** - UART3 (`/dev/ttyAMA3`) on GPIO 8/9
- **CAN Bus #1** - MCP2515 via SPI0 CE0 (`can0`)
- **CAN Bus #2** - MCP2515 via SPI0 CE1 (`can1`)

## Prerequisites

### 1. Enable SSH on HAOS

The Advanced SSH & Web Terminal addon must be configured:

1. Open HA web UI at `http://192.168.2.12:8123`
2. Go to **Settings > Add-ons > Advanced SSH & Web Terminal**
3. In the **Configuration** tab:
   - Set a password or paste your SSH public key into `authorized_keys`
   - Ensure port is set to `22`
4. Click **Save**, then go to **Info** tab and click **Start**
5. Verify: `ssh root@192.168.2.12`

### 2. Edit config.txt

SSH into the RPi5 host shell and edit the boot config:

```bash
# SSH into HAOS (port 22 for addon, port 22222 for debug)
ssh root@192.168.2.12

# If you see the "ha >" prompt, type 'login' to get to host shell

# Edit config.txt
vi /mnt/boot/config.txt
```

Add the required overlays (see `config_txt_example.txt` for full example):

```ini
[all]
enable_uart=1
dtoverlay=uart1-pi5
dtoverlay=uart2-pi5
dtoverlay=uart3-pi5
dtparam=spi=on
dtoverlay=mcp2515-can0,oscillator=12000000,interrupt=25,spimaxfrequency=2000000
dtoverlay=mcp2515-can1,oscillator=12000000,interrupt=24,spimaxfrequency=2000000
```

Reboot after editing:
```bash
reboot
```

### 3. Verify Devices After Reboot

```bash
# Check serial devices exist
ls -la /dev/ttyAMA*

# Check CAN interfaces
ip link show type can

# Check loaded modules
lsmod | grep -iE "can|mcp|spi"

# Check device tree
cat /proc/device-tree/model
```

## Testing

### Quick Test (All Interfaces)

```bash
# Copy test script to the RPi5 and run
scp test_all_interfaces.sh root@192.168.2.12:/root/
ssh root@192.168.2.12 "chmod +x /root/test_all_interfaces.sh && /root/test_all_interfaces.sh"
```

### Manual RS485 Testing

```bash
# Configure RS485 port
stty -F /dev/ttyAMA1 9600 cs8 -cstopb -parenb raw

# Send Modbus RTU request (read holding register)
echo -ne '\x01\x03\x00\x00\x00\x01\x84\x0A' > /dev/ttyAMA1

# Read response (with timeout)
timeout 2 cat /dev/ttyAMA1 | xxd
```

Loopback test (connect TX to RX):
```bash
# Terminal 1: Listen
cat /dev/ttyAMA1 &

# Terminal 2: Send
echo "RS485_TEST" > /dev/ttyAMA1
```

### Manual RS232 Testing

```bash
# Configure RS232 port
stty -F /dev/ttyAMA3 115200 cs8 -cstopb -parenb raw

# Loopback test (connect TX pin to RX pin)
echo "RS232_LOOPBACK_TEST" > /dev/ttyAMA3 &
timeout 2 cat /dev/ttyAMA3
```

### Manual CAN Bus Testing

```bash
# Bring up CAN0 in loopback mode (no external hardware needed)
ip link set can0 up type can bitrate 500000 loopback on

# Terminal 1: Listen for CAN messages
candump can0 &

# Terminal 2: Send a CAN message
cansend can0 123#DEADBEEF

# Should see the message echoed back in loopback mode

# Bring down when done
ip link set can0 down
```

For CAN bus with actual external device:
```bash
# Normal mode (not loopback)
ip link set can0 up type can bitrate 500000

# Monitor bus traffic
candump can0

# Send message
cansend can0 7DF#0201050000000000
```

## Troubleshooting

### No /dev/ttyAMA* devices
- Check `config.txt` has the correct `dtoverlay=uartX-pi5` entries
- Reboot after editing config.txt
- Check `dmesg | grep -i uart` for errors

### No CAN interfaces
- Check SPI is enabled: `dtparam=spi=on` in config.txt
- Check `dmesg | grep -i can` and `dmesg | grep -i mcp`
- Verify MCP2515 wiring: MOSI/MISO/SCK/CS/INT pins
- Check crystal frequency matches the `oscillator` parameter

### CAN bus ERROR-PASSIVE or BUS-OFF
- Check CAN-H / CAN-L wiring
- Ensure 120 ohm termination resistors at both ends
- Verify bitrate matches all devices on the bus

### Permission denied on serial ports
- HAOS runs as root in the SSH addon, so this shouldn't happen
- If using the Terminal addon (not Advanced SSH), it may lack hardware access

### stty/cansend not found
- HAOS is a minimal OS; some tools may need to be installed
- The Advanced SSH addon includes more utilities
- For CAN: `apk add can-utils` (Alpine-based containers)

## Hardware Pin Reference (RPi5)

| Interface | UART | TX Pin | RX Pin | Notes |
|-----------|------|--------|--------|-------|
| RS485 #1  | UART1 | GPIO 0 | GPIO 1 | Via SP3485/MAX485 transceiver |
| RS485 #2  | UART2 | GPIO 4 | GPIO 5 | Via SP3485/MAX485 transceiver |
| RS232     | UART3 | GPIO 8 | GPIO 9 | Via MAX3232 transceiver |

| Interface | Controller | SPI | CS Pin | INT Pin | Notes |
|-----------|-----------|-----|--------|---------|-------|
| CAN #1    | MCP2515   | SPI0 | CE0 | GPIO 25 | Check crystal freq |
| CAN #2    | MCP2515   | SPI0 | CE1 | GPIO 24 | Check crystal freq |

> **Warning**: RPi5 GPIO operates at 3.3V. Never connect 5V signals directly to GPIO pins.
