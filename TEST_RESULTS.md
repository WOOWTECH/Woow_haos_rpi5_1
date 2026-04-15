# RPi5 HAOS - Waveshare Industrial Interface Board Test Results

**Date:** 2026-04-15
**Target:** Raspberry Pi 5 running Home Assistant OS 17.2 (kernel 6.12.75-haos-raspi)
**IP:** 192.168.2.12
**Board:** Waveshare Isolated RS232/RS485/CAN/CAN-FD Expansion Board

## Summary: ALL 5 INTERFACES PASS

| # | Interface | Device | Chip | Result |
|---|-----------|--------|------|--------|
| 1 | RS485 #1 | `/dev/ttySC0` | SC16IS752 + SP485 | **PASS** |
| 2 | RS485 #2 | `/dev/ttySC1` | SC16IS752 + SP485 | **PASS** |
| 3 | RS232 | `/dev/ttyAMA0` | SP3232EEN | **PASS** |
| 4 | CAN FD | `can0` | MCP2518FD + MCP2562FD | **PASS** |
| 5 | CAN | `can1` | MCP2515 + SN65HVD230 | **PASS** |

---

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

## Kernel Modules Loaded

```
sc16is7xx_spi   12288  0       # RS485 SPI driver
sc16is7xx       28672  1       # RS485 UART bridge
mcp251xfd       49152  0       # CAN FD controller
mcp251x         24576  0       # CAN classic controller
can_dev         49152  2       # CAN device framework
spi_bcm2835     20480  0       # SPI bus driver
```

---

## Detailed Test Results

### RS485 #1 (`/dev/ttySC0` - SC16IS752 Channel A) — PASS

```
dmesg: spi1.0: ttySC0 at I/O 0x0 (irq = 188, base_baud = 921600) is a SC16IS752
```

| Test | Result |
|------|--------|
| **Baud rate 1200** | PASS |
| **Baud rate 2400** | PASS |
| **Baud rate 4800** | PASS |
| **Baud rate 9600** | PASS |
| **Baud rate 19200** | PASS |
| **Baud rate 38400** | PASS |
| **Baud rate 57600** | PASS |
| **Baud rate 115200** | PASS |
| **Data format 8N1** | PASS |
| **Data format 8E1 (even parity)** | PASS |
| **Data format 8O1 (odd parity)** | PASS |
| **Data format 8N2 (2 stop bits)** | PASS |
| **Data format 7E1** | PASS |
| **Modbus FC03 Read Holding Registers** | PASS |
| **Modbus FC06 Write Single Register** | PASS |
| **Modbus FC01 Read Coils** | PASS |
| **256-byte random bulk write** | PASS |
| **10x open/configure/write/close stress** | 10/10 PASS |

### RS485 #2 (`/dev/ttySC1` - SC16IS752 Channel B) — PASS

```
dmesg: spi1.0: ttySC1 at I/O 0x1 (irq = 188, base_baud = 921600) is a SC16IS752
```

| Test | Result |
|------|--------|
| **Baud rate 1200** | PASS |
| **Baud rate 2400** | PASS |
| **Baud rate 4800** | PASS |
| **Baud rate 9600** | PASS |
| **Baud rate 19200** | PASS |
| **Baud rate 38400** | PASS |
| **Baud rate 57600** | PASS |
| **Baud rate 115200** | PASS |
| **Data format 8N1** | PASS |
| **Data format 8E1 (even parity)** | PASS |
| **Data format 8O1 (odd parity)** | PASS |
| **Data format 8N2 (2 stop bits)** | PASS |
| **Data format 7E1** | PASS |
| **Modbus FC03 Read Holding Registers** | PASS |
| **Modbus FC06 Write Single Register** | PASS |
| **Modbus FC01 Read Coils** | PASS |
| **256-byte random bulk write** | PASS |
| **10x open/configure/write/close stress** | 10/10 PASS |
| **Simultaneous dual-channel write** | PASS |

### RS232 (`/dev/ttyAMA0` - SP3232EEN via UART0) — PASS

```
UART register: uart:PL011 AXI mmio:0x1F00030000 irq:125 tx:4177 rx:0
```

| Test | Result |
|------|--------|
| **Baud rate 1200** | PASS |
| **Baud rate 2400** | PASS |
| **Baud rate 4800** | PASS |
| **Baud rate 9600** | PASS |
| **Baud rate 19200** | PASS |
| **Baud rate 38400** | PASS |
| **Baud rate 57600** | PASS |
| **Baud rate 115200** | PASS |
| **Baud rate 230400** | PASS |
| **Baud rate 460800** | PASS |
| **Baud rate 921600** | PASS |
| **Data format 8N1** | PASS |
| **Data format 8E1** | PASS |
| **Data format 8O1** | PASS |
| **Data format 8N2** | PASS |
| **Data format 7E1** | PASS |
| **Data format 5N1** | PASS |
| **Data format 6N1** | PASS |
| **HW flow control (RTS/CTS)** | PASS |
| **SW flow control (XON/XOFF)** | PASS |
| **No flow control** | PASS |
| **ASCII string write** | PASS |
| **AT command write** | PASS |
| **HTTP-style write** | PASS |
| **256-byte full range (0x00-0xFF)** | PASS |
| **4KB random bulk write** | PASS |
| **20x open/configure/write/close stress** | 20/20 PASS |

### CAN FD (`can0` - MCP2518FD + MCP2562FD) — PASS

```
dmesg: MCP2518FD rev0.0 successfully initialized
Clock: 40MHz, supports CAN FD data rates up to 5Mbps
```

| Test | Result |
|------|--------|
| **Bitrate 125 kbps** | PASS |
| **Bitrate 250 kbps** | PASS |
| **Bitrate 500 kbps** | PASS |
| **Bitrate 1000 kbps** | PASS |
| **CAN FD 500k/2M** | PASS |
| **CAN FD 500k/5M** | PASS |
| **Loopback TX/RX (0 errors)** | PASS |
| **Standard frame (11-bit ID)** | PASS |
| **Extended frame (29-bit ID)** | PASS |
| **RTR frame** | PASS |
| **CAN FD 64-byte frame** | PASS |
| **50-frame burst (1 Mbps)** | 50/50 PASS, 0 errors |
| **Final state** | ERROR-ACTIVE (healthy) |
| **Final stats** | TX=60, RX=120, 0 errors |

### CAN Classic (`can1` - MCP2515 + SN65HVD230) — PASS

```
dmesg: MCP2515 successfully initialized
Clock: 8MHz (16MHz oscillator / 2)
```

| Test | Result |
|------|--------|
| **Bitrate 10 kbps** | PASS |
| **Bitrate 20 kbps** | PASS |
| **Bitrate 50 kbps** | PASS |
| **Bitrate 100 kbps** | PASS |
| **Bitrate 125 kbps** | PASS |
| **Bitrate 250 kbps** | PASS |
| **Bitrate 500 kbps** | PASS |
| **Bitrate 1000 kbps (max)** | PASS |
| **Loopback TX/RX (0 errors)** | PASS |
| **Standard frame ID=0x000** | PASS |
| **Standard frame ID=0x7FF** | PASS |
| **8-byte payload** | PASS |
| **0-byte payload** | PASS |
| **Extended frame ID=0x00000001** | PASS |
| **Extended frame ID=0x1FFFFFFF** | PASS |
| **RTR frame** | PASS |
| **50-frame burst** | 50/50 PASS, 0 errors |
| **Final state** | ERROR-ACTIVE (healthy) |
| **Final stats** | TX=67, RX=67, 0 errors |

---

## Cross-Channel Tests

| Test | Result | Notes |
|------|--------|-------|
| RS485 ttySC0 -> ttySC1 | N/A | Not wired (separate connectors) |
| RS485 ttySC1 -> ttySC0 | N/A | Not wired (separate connectors) |
| RS232 TX -> RX loopback | N/A | No loopback connector |
| CAN can0 -> can1 | N/A | Separate CAN buses (not wired) |
| CAN can1 -> can0 | N/A | Separate CAN buses (not wired) |

> Cross-channel tests require physical wiring between connectors. All individual channel loopback tests pass via controller-level loopback mode.

---

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

1. **BusyBox `ip` in SSH addon** does not support `ip link set ... type can`. Must use Docker with `iproute2` and `can-utils` packages to configure CAN interfaces.

2. **High CPU from SC16IS752 IRQ** - Known upstream issue on RPi5. Monitor with `top` for `irq/188-spi1.0` process.

## HA Integration Notes

- **RS485 (Modbus RTU)**: Use the Modbus integration with `serial_port: /dev/ttySC0` or `/dev/ttySC1`
- **RS232**: Use any serial-based integration with `serial_port: /dev/ttyAMA0`
- **CAN bus**: Requires custom component or CLI tools. CAN interfaces must be brought up before use:
  ```bash
  ip link set can0 up type can bitrate 500000
  ip link set can1 up type can bitrate 500000
  ```
