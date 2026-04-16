# Waveshare Isolated Industrial Interface Board on RPi5 HAOS

# 微雪隔離型工業介面擴展板 — 樹莓派5 HAOS 使用指南

> **Verified / 已驗證:** Raspberry Pi 5 + Home Assistant OS 17.2 + Waveshare Isolated RS232/RS485/CAN/CAN-FD Expansion Board
>
> **All 5 interfaces tested and PASS / 五個介面全部測試通過**

---

## Table of Contents / 目錄

- [Overview / 概述](#overview--概述)
- [Architecture / 系統架構](#architecture--系統架構)
- [Hardware / 硬體](#hardware--硬體)
- [Software Environment / 軟體環境](#software-environment--軟體環境)
- [Setup Guide / 設置指南](#setup-guide--設置指南)
- [Usage / 使用方式](#usage--使用方式)
- [Test Results / 測試結果](#test-results--測試結果)
- [HA Integration / HA 整合](#ha-integration--ha-整合)
- [Power Sequencer (RS232) / 電源時序器](#power-sequencer-rs232--電源時序器)
- [Troubleshooting / 故障排除](#troubleshooting--故障排除)
- [File Structure / 檔案結構](#file-structure--檔案結構)

---

## Overview / 概述

This project documents the complete setup and verification of a **Waveshare Isolated Industrial Interface Expansion Board** on a **Raspberry Pi 5** running **Home Assistant OS (HAOS)**. The board provides 5 industrial communication interfaces via GPIO/SPI:

本專案記錄了在 **樹莓派5 (Raspberry Pi 5)** 上執行 **Home Assistant OS (HAOS)** 時，完整設置和驗證 **微雪隔離型工業介面擴展板** 的過程。該擴展板透過 GPIO/SPI 提供 5 個工業通訊介面：

| # | Interface / 介面 | Chip / 晶片 | Device / 裝置 | Protocol / 協定 |
|---|-----------------|-------------|--------------|----------------|
| 1 | RS485 #1 | SC16IS752 + SP485 | `/dev/ttySC0` | Modbus RTU, serial |
| 2 | RS485 #2 | SC16IS752 + SP485 | `/dev/ttySC1` | Modbus RTU, serial |
| 3 | RS232 | SP3232EEN | `/dev/ttyAMA0` | Serial |
| 4 | CAN FD | MCP2518FD + MCP2562FD | `can0` | CAN FD (up to 5 Mbps) |
| 5 | CAN Classic | MCP2515 + SN65HVD230 | `can1` | CAN 2.0B (up to 1 Mbps) |

---

## Architecture / 系統架構

### System Block Diagram / 系統方塊圖

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Raspberry Pi 5 (RPi5)                            │
│                    Home Assistant OS 17.2                            │
│                    Kernel: 6.12.75-haos-raspi                       │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐    │
│  │  HA Core     │  │  HA Addons   │  │  Host OS (HAOS)        │    │
│  │              │  │              │  │                        │    │
│  │  Modbus      │  │  SSH & Web   │  │  Device Tree Overlays  │    │
│  │  Integration │  │  Terminal    │  │  Kernel Modules:       │    │
│  │              │  │  (Alpine)    │  │   - sc16is7xx_spi      │    │
│  │  Serial      │  │              │  │   - mcp251xfd          │    │
│  │  Integration │  │  Protection  │  │   - mcp251x            │    │
│  │              │  │  Mode: OFF   │  │   - can_dev            │    │
│  └──────┬───────┘  └──────┬───────┘  │   - spi_bcm2835        │    │
│         │                 │          └───────────┬────────────┘    │
│         │     Docker      │                      │                 │
│         └────────┬────────┘                      │                 │
│                  │                               │                 │
├──────────────────┼───────────────────────────────┼─────────────────┤
│          /dev/ttySC0,1  /dev/ttyAMA0        can0, can1             │
│                  │           │                   │                  │
│  ┌───────────────┴───────────┴───────────────────┴───────────────┐ │
│  │                     GPIO 40-Pin Header                        │ │
│  │  SPI0: GPIO 7-11  │  SPI1: GPIO 18-21  │  UART0: GPIO 14,15 │ │
│  └──────────┬─────────────────┬────────────────────┬─────────────┘ │
└─────────────┼─────────────────┼────────────────────┼───────────────┘
              │                 │                    │
┌─────────────┼─────────────────┼────────────────────┼───────────────┐
│             │    Waveshare Isolated Expansion Board │               │
│             │          (GPIO HAT, Isolated)         │               │
│             │                 │                    │               │
│  ┌──────────┴──────────┐  ┌──┴───────────┐  ┌─────┴──────────┐   │
│  │     SPI0 Bus        │  │   SPI1 Bus   │  │   UART0 Bus    │   │
│  │                     │  │              │  │                │   │
│  │ CE0       CE1       │  │ CE0          │  │                │   │
│  │ ┌──────┐ ┌────────┐ │  │ ┌──────────┐ │  │ ┌────────────┐ │   │
│  │ │MCP   │ │MCP     │ │  │ │SC16IS752 │ │  │ │SP3232EEN   │ │   │
│  │ │2515  │ │2518FD  │ │  │ │(Dual     │ │  │ │            │ │   │
│  │ │      │ │        │ │  │ │ UART)    │ │  │ │            │ │   │
│  │ └──┬───┘ └───┬────┘ │  │ └──┬───┬───┘ │  │ └─────┬──────┘ │   │
│  │    │         │      │  │    │   │     │  │       │        │   │
│  │ ┌──┴─────┐ ┌─┴────┐ │  │ ┌──┴─┐ ┌┴──┐ │  │       │        │   │
│  │ │SN65HVD│ │MCP   │ │  │ │SP  │ │SP │ │  │       │        │   │
│  │ │230    │ │2562FD│ │  │ │485 │ │485│ │  │       │        │   │
│  │ └──┬────┘ └──┬───┘ │  │ └─┬──┘ └┬──┘ │  │       │        │   │
│  └────┼─────────┼─────┘  └───┼─────┼────┘  └───────┼────────┘   │
│       │         │            │     │               │             │
│    ┌──┴──┐  ┌───┴───┐   ┌───┴──┐ ┌┴────┐    ┌─────┴─────┐      │
│    │CAN  │  │CAN FD │   │RS485 │ │RS485│    │  RS232    │      │
│    │can1 │  │can0   │   │ #1   │ │ #2  │    │ ttyAMA0   │      │
│    │     │  │       │   │ttySC0│ │ttySC1│   │           │      │
│    └──┬──┘  └───┬───┘   └──┬───┘ └──┬──┘    └─────┬─────┘      │
│  ═════╪═════════╪══════════╪════════╪═════════════╪══ Isolation │
│       │         │          │        │             │             │
│    ┌──┴──┐  ┌───┴───┐  ┌──┴────┐ ┌─┴─────┐  ┌───┴────┐        │
│    │CAN-H│  │CAN-H  │  │ A (+) │ │ A (+) │  │  TX    │        │
│    │CAN-L│  │CAN-L  │  │ B (-) │ │ B (-) │  │  RX    │        │
│    │ GND │  │ GND   │  │ GND   │ │ GND   │  │  GND   │        │
│    └─────┘  └───────┘  └───────┘ └───────┘  └────────┘        │
└─────────────────────────────────────────────────────────────────┘
  Terminal    Terminal     Terminal   Terminal   DB9 / Header
  Block #1   Block #2     Block #3   Block #4   Connector
```

### Data Flow / 資料流程

```
┌──────────────┐     ┌────────────────┐     ┌───────────────────┐
│  HA Core     │     │   HAOS Host    │     │  Waveshare Board  │
│              │     │                │     │                   │
│  Modbus RTU  │────>│  /dev/ttySC0   │────>│  SC16IS752 Ch.A   │──> RS485 Bus #1
│  Integration │     │  /dev/ttySC1   │────>│  SC16IS752 Ch.B   │──> RS485 Bus #2
│              │     │                │     │                   │
│  Serial      │────>│  /dev/ttyAMA0  │────>│  SP3232EEN        │──> RS232
│  Integration │     │                │     │                   │
│              │     │  can0 (socket) │────>│  MCP2518FD        │──> CAN FD Bus
│  Custom /    │────>│  can1 (socket) │────>│  MCP2515          │──> CAN Bus
│  CLI tools   │     │                │     │                   │
└──────────────┘     └────────────────┘     └───────────────────┘
```

### Setup Flow / 設置流程

```
  ┌─────────────────┐
  │ 1. Install HAOS  │
  │    on RPi5       │
  └────────┬────────┘
           │
  ┌────────▼────────┐
  │ 2. Install SSH   │
  │    Addon         │
  │    (Protection   │
  │     Mode: OFF)   │
  └────────┬────────┘
           │
  ┌────────▼─────────────────────────────┐
  │ 3. SSH into RPi5                      │
  │    ssh root@<IP>                      │
  │    password: <your_password>          │
  └────────┬─────────────────────────────┘
           │
  ┌────────▼─────────────────────────────┐
  │ 4. Mount boot partition               │
  │    docker run --privileged alpine     │
  │    mount /dev/mmcblk0p1 /mnt          │
  └────────┬─────────────────────────────┘
           │
  ┌────────▼─────────────────────────────┐
  │ 5. Edit config.txt                    │
  │    Add device tree overlays           │
  │    (see config_txt_example.txt)       │
  └────────┬─────────────────────────────┘
           │
  ┌────────▼────────┐
  │ 6. Reboot        │
  │    ha host reboot │
  └────────┬────────┘
           │
  ┌────────▼─────────────────────────────┐
  │ 7. Verify devices appear              │
  │    ls /dev/ttySC* /dev/ttyAMA0        │
  │    ip link show type can              │
  └────────┬─────────────────────────────┘
           │
  ┌────────▼─────────────────────────────┐
  │ 8. Configure HA integrations          │
  │    - Modbus for RS485                 │
  │    - Serial for RS232                 │
  │    - CLI/custom for CAN              │
  └──────────────────────────────────────┘
```

---

## Hardware / 硬體

### Expansion Board Specifications / 擴展板規格

| Item / 項目 | Specification / 規格 |
|-------------|---------------------|
| **Product / 產品** | Waveshare Isolated RS232/RS485/CAN/CAN-FD Expansion Board / 微雪隔離型工業介面擴展板 |
| **Compatible / 相容** | Raspberry Pi 4B / 5 |
| **Interface / 介面** | SPI + UART (via 40-pin GPIO) |
| **Power / 供電** | Type-C 5V **or** DC 7-36V terminal block / Type-C 5V 或 DC 7-36V 端子 |
| **Dimensions / 尺寸** | 154.6 x 83.7 x 59 mm |
| **Isolation / 隔離** | Yes, all channels / 是，全通道隔離 |
| **Mounting / 安裝** | DIN rail or wall mount / 導軌或壁掛 |

### Interface Detail / 介面詳情

| Interface / 介面 | Controller / 控制器 | Transceiver / 收發器 | Bus / 匯流排 | Speed / 速率 | Device / 裝置 |
|-----------------|--------------------|--------------------|-------------|-------------|--------------|
| CAN FD | MCP2518FD | MCP2562FD | SPI0 CE1 | 5 kbps - 8 Mbps | `can0` |
| CAN Classic | MCP2515 | SN65HVD230 | SPI0 CE0 | 5 kbps - 1 Mbps | `can1` |
| RS485 #1 | SC16IS752 (Ch.A) | SP485 | SPI1 CE0 | 300 - 921600 bps | `/dev/ttySC0` |
| RS485 #2 | SC16IS752 (Ch.B) | SP485 | SPI1 CE0 | 300 - 921600 bps | `/dev/ttySC1` |
| RS232 | - | SP3232EEN | UART0 | up to 921600 bps | `/dev/ttyAMA0` |

### GPIO Pin Mapping / GPIO 腳位對應

```
              RPi5 40-Pin GPIO Header
         ┌─────────────────────────────┐
         │  3V3  [1]  [2]  5V         │
         │  SDA  [3]  [4]  5V         │
         │  SCL  [5]  [6]  GND        │
         │       [7]  [8]  TX(RS232)──│── GPIO 14 → UART0 TX
         │  GND  [9]  [10] RX(RS232)──│── GPIO 15 → UART0 RX
         │       [11] [12] SPI1_CE0───│── GPIO 18 → SC16IS752 CS
         │       [13] [14] GND        │
         │       [15] [16] MCP2515_INT│── GPIO 23 → CAN Classic IRQ
         │  3V3  [17] [18] MCP2518_INT│── GPIO 24 → CAN FD IRQ
         │ MOSI0 [19] [20] GND        │
         │ MISO0 [21] [22] SC16IS_INT─│── GPIO 25 → RS485 IRQ
         │ SCLK0 [23] [24] SPI0_CE0───│── GPIO 8  → MCP2515 CS
         │  GND  [25] [26] SPI0_CE1───│── GPIO 7  → MCP2518FD CS
         │       [27] [28]            │
         │       [29] [30] GND        │
         │       [31] [32]            │
         │       [33] [34] GND        │
         │ MISO1 [35] [36]            │
         │       [37] [38] MOSI1      │
         │  GND  [39] [40] SCLK1      │
         └─────────────────────────────┘
```

| Function / 功能 | GPIO | Pin / 腳位 | Direction / 方向 |
|-----------------|------|-----------|-----------------|
| SC16IS752 INT (RS485 IRQ) | GPIO 25 | Pin 22 | Input / 輸入 |
| MCP2515 INT (CAN IRQ) | GPIO 23 | Pin 16 | Input / 輸入 |
| MCP2518FD INT (CAN FD IRQ) | GPIO 24 | Pin 18 | Input / 輸入 |
| UART0 TX (RS232) | GPIO 14 | Pin 8 | Output / 輸出 |
| UART0 RX (RS232) | GPIO 15 | Pin 10 | Input / 輸入 |
| SPI0 MOSI | GPIO 10 | Pin 19 | Output / 輸出 |
| SPI0 MISO | GPIO 9 | Pin 21 | Input / 輸入 |
| SPI0 SCLK | GPIO 11 | Pin 23 | Output / 輸出 |
| SPI0 CE0 (MCP2515) | GPIO 8 | Pin 24 | Output / 輸出 |
| SPI0 CE1 (MCP2518FD) | GPIO 7 | Pin 26 | Output / 輸出 |
| SPI1 MOSI | GPIO 20 | Pin 38 | Output / 輸出 |
| SPI1 MISO | GPIO 19 | Pin 35 | Input / 輸入 |
| SPI1 SCLK | GPIO 21 | Pin 40 | Output / 輸出 |
| SPI1 CE0 (SC16IS752) | GPIO 18 | Pin 12 | Output / 輸出 |

---

## Software Environment / 軟體環境

### System Stack / 系統軟體堆疊

| Layer / 層次 | Component / 元件 | Version / 版本 |
|-------------|-----------------|---------------|
| **Hardware** | Raspberry Pi 5 (rpi5-64) | - |
| **OS** | Home Assistant OS (HAOS) | 17.2 |
| **Kernel** | Linux | 6.12.75-haos-raspi |
| **Supervisor** | HA Supervisor | (managed by HAOS) |
| **Core** | Home Assistant Core | (latest via HAOS) |
| **SSH Addon** | Advanced SSH & Web Terminal | Alpine Linux-based |

### Kernel Modules / 核心模組

After config.txt overlays are applied and the system reboots, these modules load automatically:

設定好 config.txt overlay 並重啟後，以下核心模組會自動載入：

| Module / 模組 | Size / 大小 | Purpose / 用途 |
|--------------|------------|---------------|
| `sc16is7xx_spi` | 12288 | SC16IS752 SPI driver (RS485) |
| `sc16is7xx` | 28672 | SC16IS752 UART bridge core |
| `mcp251xfd` | 49152 | MCP2518FD CAN FD controller driver |
| `mcp251x` | 24576 | MCP2515 CAN classic controller driver |
| `can_dev` | 49152 | Linux CAN device framework |
| `spi_bcm2835` | 20480 | Broadcom SPI bus driver (RPi) |

### Device Tree Overlays / 裝置樹覆蓋層

The following overlays are added to `config.txt` (on the boot partition):

以下 overlay 需加入到開機分區的 `config.txt`：

```ini
# Enable SPI bus / 啟用 SPI 匯流排
dtparam=spi=on

# RS485 x2: SC16IS752 dual UART via SPI1
# RS485 雙通道：SC16IS752 透過 SPI1
dtoverlay=spi1-3cs
dtoverlay=sc16is752-spi1,int_pin=25

# CAN Classic: MCP2515 on SPI0 CE0, 16MHz oscillator, INT=GPIO23
# CAN 經典：MCP2515 接 SPI0 CE0，16MHz 振盪器，中斷=GPIO23
dtoverlay=mcp2515,spi0-0,oscillator=16000000,interrupt=23

# CAN FD: MCP2518FD on SPI0 CE1, INT=GPIO24
# CAN FD：MCP2518FD 接 SPI0 CE1，中斷=GPIO24
dtoverlay=mcp251xfd,spi0-1,interrupt=24

# RS232: Enable UART0 on RPi5 (GPIO 14/15)
# RS232：啟用 RPi5 的 UART0 (GPIO 14/15)
dtoverlay=uart0-pi5
```

---

## Setup Guide / 設置指南

### Prerequisites / 前置條件

- Raspberry Pi 5 with HAOS installed / 已安裝 HAOS 的樹莓派5
- Waveshare Isolated RS232/RS485/CAN/CAN-FD Expansion Board mounted on GPIO / 微雪擴展板已安裝在 GPIO 上
- Network access to the RPi5 / 可透過網路存取樹莓派5
- Advanced SSH & Web Terminal addon installed in HA / 已安裝 HA 的 Advanced SSH & Web Terminal 附加元件

### Step 1: Configure SSH Addon / 步驟1：設定 SSH 附加元件

1. Open HA at `http://<RPi5_IP>:8123` / 開啟 HA 網頁介面
2. Go to **Settings → Add-ons → Advanced SSH & Web Terminal** / 前往 **設定 → 附加元件**
3. Set username and password / 設定使用者名稱和密碼
4. **Disable Protection Mode** (critical for host access!) / **關閉保護模式** (存取主機必需！)
5. Start the addon / 啟動附加元件
6. Verify SSH: `ssh root@<RPi5_IP>` / 驗證 SSH 連線

> **Important / 重要:** Protection Mode must be OFF to access `ha` CLI commands and Docker.
>
> 保護模式必須關閉才能使用 `ha` CLI 指令和 Docker。

### Step 2: Edit config.txt / 步驟2：編輯 config.txt

In HAOS, the boot partition is not directly mounted. Use a privileged Docker container:

在 HAOS 中，開機分區未直接掛載，需使用特權 Docker 容器：

```bash
# Create a privileged container to access the boot partition
# 建立特權容器以存取開機分區
docker run --rm -it --privileged \
  -v /dev/mmcblk0p1:/dev/mmcblk0p1 \
  alpine sh

# Inside the container / 在容器內
mkdir -p /mnt/boot
mount /dev/mmcblk0p1 /mnt/boot

# Backup original config.txt / 備份原始 config.txt
cp /mnt/boot/config.txt /mnt/boot/config.txt.bak

# Edit config.txt / 編輯 config.txt
vi /mnt/boot/config.txt
```

Add the overlays from [config_txt_example.txt](config_txt_example.txt) **before** the `[cm4]` section.

將 [config_txt_example.txt](config_txt_example.txt) 中的 overlay 設定加入到 `[cm4]` 段落**之前**。

```bash
# Unmount and exit / 卸載並離開
umount /mnt/boot
exit
```

### Step 3: Reboot / 步驟3：重新啟動

```bash
ha host reboot
```

### Step 4: Verify Devices / 步驟4：驗證裝置

After reboot, SSH back in and check / 重啟後重新 SSH 登入並檢查：

```bash
# Check RS485 devices / 檢查 RS485 裝置
ls -la /dev/ttySC*
# Expected / 預期: /dev/ttySC0, /dev/ttySC1

# Check RS232 device / 檢查 RS232 裝置
ls -la /dev/ttyAMA0
# Expected / 預期: /dev/ttyAMA0

# Check CAN interfaces / 檢查 CAN 介面
ip link show type can
# Expected / 預期: can0, can1

# Check loaded modules / 檢查已載入模組
lsmod | grep -iE "sc16|mcp|can|spi"
```

Expected output / 預期輸出：
```
/dev/ttySC0   ← RS485 #1
/dev/ttySC1   ← RS485 #2
/dev/ttyAMA0  ← RS232
can0          ← CAN FD (MCP2518FD)
can1          ← CAN Classic (MCP2515)
```

---

## Usage / 使用方式

### RS485 (Modbus RTU)

```bash
# Configure serial port / 設定序列埠
stty -F /dev/ttySC0 9600 cs8 -cstopb -parenb raw

# Send Modbus RTU frame (FC03 Read Holding Registers)
# 發送 Modbus RTU 封包 (FC03 讀取保持暫存器)
echo -ne '\x01\x03\x00\x00\x00\x01\x84\x0A' > /dev/ttySC0

# Read response / 讀取回應
timeout 2 cat /dev/ttySC0 | xxd

# Supported baud rates / 支援的鮑率:
# 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200

# Supported data formats / 支援的資料格式:
# 8N1, 8E1, 8O1, 8N2, 7E1
```

### RS232

```bash
# Configure serial port / 設定序列埠
stty -F /dev/ttyAMA0 115200 cs8 -cstopb -parenb raw

# Send data / 發送資料
echo "Hello RS232" > /dev/ttyAMA0

# Supported baud rates / 支援的鮑率:
# 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600

# Supported data formats / 支援的資料格式:
# 8N1, 8E1, 8O1, 8N2, 7E1, 5N1, 6N1

# Flow control / 流量控制:
# Hardware (RTS/CTS), Software (XON/XOFF), None
```

### CAN Bus

> **Note / 注意:** HAOS uses BusyBox which lacks CAN support. Use Docker with `iproute2` and `can-utils`.
>
> HAOS 使用 BusyBox，不支援 CAN。需使用 Docker 搭配 `iproute2` 和 `can-utils`。

```bash
# Run CAN commands in a Docker container
# 在 Docker 容器中執行 CAN 指令
docker run --rm -it --privileged --net=host alpine sh -c '
  apk add --no-cache iproute2 can-utils

  # Bring up CAN FD interface / 啟動 CAN FD 介面
  ip link set can0 up type can bitrate 500000
  # Or with FD mode / 或使用 FD 模式
  # ip link set can0 up type can bitrate 500000 dbitrate 2000000 fd on

  # Bring up CAN Classic interface / 啟動 CAN 經典介面
  ip link set can1 up type can bitrate 500000

  # Send a CAN frame / 發送 CAN 封包
  cansend can0 123#DEADBEEF

  # Monitor CAN bus / 監控 CAN 匯流排
  candump can0 &

  # Loopback test / 回環測試
  ip link set can0 down
  ip link set can0 up type can bitrate 500000 loopback on
  cansend can0 7FF#0102030405060708

  # Check interface stats / 檢查介面統計
  ip -details -statistics link show can0

  # Bring down when done / 完成後關閉
  ip link set can0 down
  ip link set can1 down
'
```

#### CAN FD Specific / CAN FD 專用

```bash
# CAN FD with data bitrate 2 Mbps / CAN FD 資料位元率 2 Mbps
ip link set can0 up type can bitrate 500000 dbitrate 2000000 fd on

# CAN FD with data bitrate 5 Mbps / CAN FD 資料位元率 5 Mbps
ip link set can0 up type can bitrate 500000 dbitrate 5000000 fd on

# Send 64-byte CAN FD frame / 發送 64 位元組 CAN FD 封包
cansend can0 123##1.0102030405060708091011121314151617181920212223242526272829303132333435363738394041424344454647484950515253545556575859606162636465
```

---

## Test Results / 測試結果

All 5 interfaces have been comprehensively tested. See [TEST_RESULTS.md](TEST_RESULTS.md) for detailed per-interface results.

五個介面均已全面測試。詳細的各介面測試結果請參閱 [TEST_RESULTS.md](TEST_RESULTS.md)。

### Summary / 摘要

| Interface / 介面 | Tests / 測試數 | Result / 結果 |
|-----------------|---------------|--------------|
| RS485 #1 (`/dev/ttySC0`) | 18 | **ALL PASS / 全部通過** |
| RS485 #2 (`/dev/ttySC1`) | 19 | **ALL PASS / 全部通過** |
| RS232 (`/dev/ttyAMA0`) | 22 | **ALL PASS / 全部通過** |
| CAN FD (`can0`) | 12 | **ALL PASS / 全部通過** |
| CAN Classic (`can1`) | 14 | **ALL PASS / 全部通過** |
| **Total / 總計** | **85** | **ALL PASS / 全部通過** |

### Test Coverage / 測試涵蓋範圍

- **RS485:** 8 baud rates, 5 data formats, 3 Modbus functions (FC01/FC03/FC06), 256-byte bulk write, stress test (10x cycles), dual-channel concurrent write
- **RS232:** 11 baud rates (1200-921600), 7 data formats, 3 flow control modes, ASCII/binary/HTTP writes, 4KB bulk, stress test (20x cycles)
- **CAN FD:** 4 bitrates (125k-1M), 2 FD modes (500k/2M, 500k/5M), loopback verify, standard/extended/RTR/FD frames, 50-frame burst
- **CAN Classic:** 8 bitrates (10k-1M), loopback verify, standard/extended/RTR frames, min/max payloads, 50-frame burst

---

## HA Integration / HA 整合

### Modbus RTU (RS485) / Modbus RTU (RS485)

Add to `configuration.yaml`:

加入 `configuration.yaml`：

```yaml
modbus:
  - name: "RS485_Device_1"
    type: serial
    port: /dev/ttySC0
    baudrate: 9600
    bytesize: 8
    parity: N
    stopbits: 1
    method: rtu

  - name: "RS485_Device_2"
    type: serial
    port: /dev/ttySC1
    baudrate: 9600
    bytesize: 8
    parity: N
    stopbits: 1
    method: rtu
```

### Serial (RS232)

Use any serial-based integration or custom component:

使用任何序列通訊整合或自訂元件：

```yaml
# Example: Serial sensor integration
sensor:
  - platform: serial
    serial_port: /dev/ttyAMA0
    baudrate: 115200
```

### CAN Bus

CAN requires bringing interfaces up before HA can use them. Create an automation or startup script:

CAN 需要先啟動介面，HA 才能使用。可建立自動化或啟動腳本：

```bash
# Add to a startup automation or shell_command
docker run --rm --privileged --net=host alpine sh -c '
  apk add --no-cache iproute2 &&
  ip link set can0 up type can bitrate 500000 &&
  ip link set can1 up type can bitrate 500000
'
```

> **Note / 注意:** CAN bus integration in HA typically requires a custom component or MQTT bridge.
>
> HA 的 CAN bus 整合通常需要自訂元件或 MQTT 橋接。

---

## Power Sequencer (RS232) / 電源時序器

This section documents controlling an **8-channel Power Sequencer** via RS232 (USB-to-RS232 adapter) as plug/switch entities in HA.

本節說明如何透過 RS232（USB 轉 RS232 轉接器）控制 **8 通道電源時序器**，並在 HA 中顯示為插座/開關實體。

### Connection / 連線方式

```
  RPi5 (HAOS)                    Power Sequencer
  ┌──────────┐   USB-to-RS232    ┌──────────────┐
  │          │   (Exar XR21B1411)│              │
  │   USB ●──┼───────────────────┼── RS232 DB9  │
  │          │   /dev/ttyUSB0    │              │
  │          │                   │  8 Channels  │
  │  HA Core │   9600 8N1       │  Ch1 ── AC/DC│
  │          │   No flow ctrl    │  Ch2 ── AC/DC│
  │          │                   │  ...         │
  │          │                   │  Ch8 ── AC/DC│
  └──────────┘                   └──────────────┘
```

| Item / 項目 | Value / 值 |
|-------------|-----------|
| USB Adapter / USB 轉接器 | Exar XR21B1411 |
| Device Path / 裝置路徑 | `/dev/ttyUSB0` |
| Stable Path / 穩定路徑 | `/dev/serial/by-id/usb-Exar_Corp._XR21B1411_R6534754471-if00-port0` |
| Baud Rate / 鮑率 | 9600 |
| Data Format / 資料格式 | 8N1 (8 data bits, no parity, 1 stop bit) |
| Flow Control / 流量控制 | None / 無 |
| Cable / 線材 | Straight-through (parallel) / 直連線 |

### RS232 Protocol / RS232 協定

6-byte hex command format / 6 位元組十六進位指令格式：

```
┌──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
│  Byte 1  │  Byte 2  │  Byte 3  │  Byte 4  │  Byte 5  │  Byte 6  │
│  Header  │ Address  │ Reserved │ Channel  │  Action  │  Footer  │
│   0x55   │ 01 ~ FF  │   0x00   │ (below)  │ (below)  │   0xAA   │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
```

**Channel (Byte 4) / 通道：**

| Value / 值 | Meaning / 意義 |
|-----------|----------------|
| `00` | All channels / 所有通道 |
| `01`-`08` | Individual channel 1-8 / 個別通道 1-8 |
| `0D` | Sequential control / 順序控制 |
| `10` | Simultaneous all / 同步全部 |

**Action (Byte 5) / 動作：**

| Value / 值 | Meaning / 意義 |
|-----------|----------------|
| `F0` | Turn ON / 開啟 |
| `F1` | Turn OFF / 關閉 |
| `FA` | Read status / 讀取狀態 |
| `FB` | Read address / 讀取地址 |
| `F2` | Set address / 設定地址 |

**Examples / 範例：**

| Action / 動作 | Hex Command / 十六進位指令 |
|--------------|--------------------------|
| Ch1 ON / 通道1 開 | `55 01 00 01 F0 AA` |
| Ch3 OFF / 通道3 關 | `55 01 00 03 F1 AA` |
| All ON / 全部開 | `55 01 00 00 F0 AA` |
| Sequential ON / 順序開 | `55 01 00 0D F0 AA` |
| Simultaneous OFF / 同步全關 | `55 01 00 10 F1 AA` |

### HA Setup (No Custom Component Needed) / HA 設定（不需自訂元件）

This uses HA's native `shell_command` + `template switch` — no custom integration required.

使用 HA 原生的 `shell_command` + `template switch` — 不需要自訂整合。

#### Step 1: Deploy Helper Script / 步驟1：部署輔助腳本

Copy `power_sequencer/power_sequencer.py` to `/config/scripts/` inside HA:

將 `power_sequencer/power_sequencer.py` 複製到 HA 的 `/config/scripts/`：

```bash
# From SSH addon terminal / 從 SSH 附加元件終端
docker exec homeassistant mkdir -p /config/scripts

# Copy the script (pipe via SSH since SCP may not work in HAOS)
cat power_sequencer.py | docker exec -i homeassistant tee /config/scripts/power_sequencer.py > /dev/null
docker exec homeassistant chmod +x /config/scripts/power_sequencer.py
```

#### Step 2: Add to configuration.yaml / 步驟2：加入 configuration.yaml

Add the shell commands and template switches. See `power_sequencer/configuration.yaml` for the full config, or add:

加入 shell command 和 template switch。完整設定請參閱 `power_sequencer/configuration.yaml`，或加入：

```yaml
# Shell commands for each channel ON/OFF
shell_command:
  power_seq_ch1_on:  "python3 /config/scripts/power_sequencer.py /dev/ttyUSB0 1 1 on"
  power_seq_ch1_off: "python3 /config/scripts/power_sequencer.py /dev/ttyUSB0 1 1 off"
  power_seq_ch2_on:  "python3 /config/scripts/power_sequencer.py /dev/ttyUSB0 1 2 on"
  power_seq_ch2_off: "python3 /config/scripts/power_sequencer.py /dev/ttyUSB0 1 2 off"
  # ... ch3 through ch8 (same pattern)
  power_seq_all_on:  "python3 /config/scripts/power_sequencer.py /dev/ttyUSB0 1 0 on"
  power_seq_all_off: "python3 /config/scripts/power_sequencer.py /dev/ttyUSB0 1 0 off"

# Template switches (appear as plug entities in dashboard)
switch:
  - platform: template
    switches:
      power_sequencer_ch1:
        friendly_name: "Power Sequencer Ch1"
        unique_id: power_sequencer_ch1
        icon_template: "mdi:power-plug"
        turn_on:
          service: shell_command.power_seq_ch1_on
        turn_off:
          service: shell_command.power_seq_ch1_off
      # ... ch2 through ch8 (same pattern)
```

#### Step 3: Restart and Verify / 步驟3：重啟並驗證

```bash
# Validate configuration / 驗證設定
ha core check

# Restart HA Core / 重啟 HA Core
ha core restart

# After restart, 8 switch entities will appear:
# 重啟後會出現 8 個 switch 實體：
#   switch.power_sequencer_ch1
#   switch.power_sequencer_ch2
#   ...
#   switch.power_sequencer_ch8
```

### Dashboard / 儀表板

After restart, the 8 switches appear automatically in HA. You can:

重啟後，8 個開關會自動出現在 HA 中。你可以：

- Toggle them directly from the dashboard / 直接從儀表板切換
- Add them to any dashboard card / 加入任何儀表板卡片
- Use in automations and scripts / 在自動化和腳本中使用
- Group them logically / 依邏輯分組

Each switch shows as a **plug icon** (`mdi:power-plug`) with optimistic state tracking (state is tracked in HA since the device has no status feedback).

每個開關顯示為**插頭圖示** (`mdi:power-plug`)，使用樂觀狀態追蹤（因裝置無狀態回饋，狀態由 HA 追蹤）。

### Quick CLI Test / 快速 CLI 測試

```bash
# From SSH addon / 從 SSH 附加元件
# Turn on channel 1 / 開啟通道 1
docker exec homeassistant python3 /config/scripts/power_sequencer.py /dev/ttyUSB0 1 1 on

# Turn off channel 1 / 關閉通道 1
docker exec homeassistant python3 /config/scripts/power_sequencer.py /dev/ttyUSB0 1 1 off

# All channels on / 所有通道開
docker exec homeassistant python3 /config/scripts/power_sequencer.py /dev/ttyUSB0 1 0 on

# Sequential power on / 順序開啟
docker exec homeassistant python3 /config/scripts/power_sequencer.py /dev/ttyUSB0 1 13 on
```

---

## Troubleshooting / 故障排除

| Problem / 問題 | Cause / 原因 | Solution / 解決方案 |
|---------------|-------------|-------------------|
| No `/dev/ttySC*` devices / 沒有 ttySC 裝置 | Missing SPI1 overlays / 缺少 SPI1 overlay | Add `spi1-3cs` and `sc16is752-spi1` to config.txt, reboot / 加入 overlay 並重啟 |
| No `/dev/ttyAMA0` / 沒有 ttyAMA0 | UART0 not enabled on RPi5 / RPi5 未啟用 UART0 | Add `dtoverlay=uart0-pi5` to config.txt, reboot / 加入 overlay 並重啟 |
| No `can0`/`can1` interfaces / 沒有 CAN 介面 | Missing SPI/CAN overlays / 缺少 SPI/CAN overlay | Add MCP2515/MCP251xFD overlays, check `dtparam=spi=on` / 加入 overlay 並確認 SPI 已啟用 |
| `ip link set ... type can` fails / ip 指令失敗 | BusyBox `ip` lacks CAN support / BusyBox 不支援 CAN | Use Docker: `docker run --privileged --net=host alpine` with `iproute2` / 使用 Docker |
| `ha os info` returns "unauthorized" / 未授權 | Protection mode ON / 保護模式開啟 | Disable protection mode in SSH addon config / 關閉保護模式 |
| Cannot mount boot partition / 無法掛載開機分區 | Container lacks privileges / 容器缺少權限 | Use `docker run --privileged -v /dev/mmcblk0p1:/dev/mmcblk0p1 alpine` |
| CAN shows BUS-OFF / CAN 顯示 BUS-OFF | No termination or wiring error / 無終端電阻或接線錯誤 | Check 120Ω termination and CAN-H/CAN-L wiring / 檢查終端電阻和接線 |
| High CPU from `irq/188-spi1.0` | SC16IS752 IRQ handling / SC16IS752 中斷處理 | Known upstream issue; monitor with `top` / 已知上游問題 |
| Power Sequencer not responding / 電源時序器無反應 | Wrong serial port or address / 序列埠或地址錯誤 | Verify `/dev/ttyUSB0` exists; check machine address DIP switch / 確認裝置存在及地址開關 |
| Switch state stuck on "unknown" / 開關狀態顯示 unknown | Never toggled yet / 尚未操作過 | Toggle the switch once; state is optimistic (tracked in HA) / 操作一次即可，狀態由 HA 追蹤 |

---

## File Structure / 檔案結構

```
.
├── README.md                  ← This file / 本檔案 (bilingual docs / 雙語文件)
├── config_txt_example.txt     ← Verified config.txt overlays / 已驗證的 config.txt overlay
├── test_all_interfaces.sh     ← Automated test script / 自動化測試腳本
├── TEST_RESULTS.md            ← Detailed test results / 詳細測試結果
├── SETUP_GUIDE.md             ← Step-by-step setup guide / 逐步設置指南
└── power_sequencer/           ← Power Sequencer RS232 control / 電源時序器 RS232 控制
    ├── power_sequencer.py     ← Helper script (deploy to /config/scripts/) / 輔助腳本
    └── configuration.yaml     ← HA config snippet / HA 設定片段
```

---

## License / 授權

MIT

---

## References / 參考資料

- [Waveshare Isolated RS232/RS485/CAN/CAN-FD HAT Wiki](https://www.waveshare.com/wiki/Isolated_RS232_RS485_CAN_FD_HAT)
- [Home Assistant OS Documentation](https://developers.home-assistant.io/docs/operating-system/)
- [Raspberry Pi 5 Device Tree Overlays](https://github.com/raspberrypi/firmware/blob/master/boot/overlays/README)
- [SC16IS752 Datasheet](https://www.nxp.com/docs/en/data-sheet/SC16IS752_SC16IS762.pdf)
- [MCP2518FD Datasheet](https://ww1.microchip.com/downloads/en/DeviceDoc/MCP2517FD-External-CAN-FD-Controller-with-SPI-Interface-20005688B.pdf)
- [MCP2515 Datasheet](https://ww1.microchip.com/downloads/en/DeviceDoc/MCP2515-Stand-Alone-CAN-Controller-with-SPI-20001801J.pdf)
- [Linux SocketCAN Documentation](https://www.kernel.org/doc/html/latest/networking/can.html)
