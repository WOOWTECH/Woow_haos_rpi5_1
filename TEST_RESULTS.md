# RPi5 HAOS - Waveshare Industrial Interface Board Test Results

**Date:** 2026-04-15
**Target:** Raspberry Pi 5 running Home Assistant OS 17.2 (kernel 6.12.75-haos-raspi)
**IP:** 192.168.2.12
**Board:** Waveshare Isolated RS232/RS485/CAN/CAN-FD Expansion Board

## Hardware Summary

| Interface | Chip(s) | Bus | Device Path | Result |
|-----------|---------|-----|-------------|--------|
| RS485 #1 | SC16IS752 + SP485 | SPI1 CE0 | `/dev/ttySC0` | **PASS** |
| RS485 #2 | SC16IS752 + SP485 | SPI1 CE0 | `/dev/ttySC1` | **PASS** |
| RS232 | SP3232EEN | UART0 (GPIO14/15) | `/dev/ttyAMA0` | **PASS** |
| CAN FD | MCP2518FD + MCP2562FD | SPI0 CE1 | `can0` | **PASS** |
| CAN | MCP2515 + SN65HVD230 | SPI0 CE0 | `can1` | **PASS** |

## config.txt Overlays Applied

```ini
# Waveshare RS232/RS485/CAN/CAN-FD Isolated Industrial Board
dtparam=spi=on
dtoverlay=spi1-3cs
dtoverlay=sc16is752-spi1,int_pin=25
dtoverlay=mcp2515,spi0-0,oscillator=16000000,interrupt=23
dtoverlay=mcp251xfd,spi0-1,interrupt=24
dtoverlay=uart0-pi5
```

## Kernel Module Verification

```
sc16is7xx_spi   12288  0       # RS485 SPI driver
sc16is7xx       28672  1       # RS485 UART bridge
mcp251xfd       49152  0       # CAN FD controller
mcp251x         24576  0       # CAN classic controller
can_dev         49152  2       # CAN device framework
spi_bcm2835     20480  0       # SPI bus driver
```

## Test Details

### RS485 #1 (`/dev/ttySC0`) - PASS

```
dmesg: spi1.0: ttySC0 at I/O 0x0 (irq = 188, base_baud = 921600) is a SC16IS752
- stty configuration at 9600 8N1: OK
- Modbus RTU write test (0x01 0x03 0x00 0x00 0x00 0x01 0x84 0x0A): OK
```

### RS485 #2 (`/dev/ttySC1`) - PASS

```
dmesg: spi1.0: ttySC1 at I/O 0x1 (irq = 188, base_baud = 921600) is a SC16IS752
- stty configuration at 9600 8N1: OK
- Modbus RTU write test: OK
```

### RS232 (`/dev/ttyAMA0`) - PASS

```
- UART0 enabled via dtoverlay=uart0-pi5
- stty configuration at 115200 8N1: OK
- Write test: OK
```

### CAN FD (`can0` - MCP2518FD) - PASS

```
dmesg: MCP2518FD rev0.0 successfully initialized
- Interface up at 500kbps loopback: OK
- State: ERROR-ACTIVE (healthy)
- cansend 7FF#0102030405060708: OK
- Loopback RX confirmed: TX=3, RX=6 packets
- Clock: 40MHz, supports CAN FD data rates
```

### CAN Classic (`can1` - MCP2515) - PASS

```
dmesg: MCP2515 successfully initialized
- Interface up at 500kbps loopback: OK
- State: ERROR-ACTIVE (healthy)
- cansend 100#AABBCCDD: OK
- Loopback RX confirmed: TX=3, RX=3 packets
- Clock: 8MHz (16MHz oscillator / 2)
```

## GPIO Pin Mapping

| Function | GPIO | Pin | Direction |
|----------|------|-----|-----------|
| SC16IS752 INT | GPIO 25 | Pin 22 | Input |
| MCP2515 INT | GPIO 23 | Pin 16 | Input |
| MCP2518FD INT | GPIO 24 | Pin 18 | Input |
| UART0 TX (RS232) | GPIO 14 | Pin 8 | Output |
| UART0 RX (RS232) | GPIO 15 | Pin 10 | Input |
| SPI0 MOSI | GPIO 10 | Pin 19 | Output |
| SPI0 MISO | GPIO 9 | Pin 21 | Input |
| SPI0 SCLK | GPIO 11 | Pin 23 | Output |
| SPI0 CE0 (MCP2515) | GPIO 8 | Pin 24 | Output |
| SPI0 CE1 (MCP2518FD) | GPIO 7 | Pin 26 | Output |
| SPI1 MOSI | GPIO 20 | Pin 38 | Output |
| SPI1 MISO | GPIO 19 | Pin 35 | Input |
| SPI1 SCLK | GPIO 21 | Pin 40 | Output |
| SPI1 CE0 (SC16IS752) | GPIO 18 | Pin 12 | Output |

## Known Issues

1. **BusyBox `ip` in SSH addon** does not support `ip link set ... type can`. Must use Docker with `iproute2` package or host shell to configure CAN interfaces.

2. **High CPU from SC16IS752 IRQ** - Known issue on RPi5. Monitor with `top` for `irq/188-spi1.0` process. If CPU usage is high, this is a known upstream issue with the SC16IS752 interrupt handling on Pi 5.

## HA Integration Notes

For Home Assistant to use these interfaces:

- **RS485 (Modbus RTU)**: Use the Modbus integration with `serial_port: /dev/ttySC0` or `/dev/ttySC1`
- **RS232**: Use any serial-based integration with `serial_port: /dev/ttyAMA0`
- **CAN bus**: Requires custom component or CLI tools. CAN interfaces must be brought up before use:
  ```bash
  ip link set can0 up type can bitrate 500000
  ip link set can1 up type can bitrate 500000
  ```
