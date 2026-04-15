# Setup Guide / 設置指南

# Waveshare Isolated Industrial Interface Board on RPi5 HAOS

# 微雪隔離型工業介面擴展板 — 樹莓派5 HAOS 安裝設定

---

## Hardware Used / 使用硬體

| Component / 元件 | Detail / 詳情 |
|-----------------|-------------|
| Single Board Computer | Raspberry Pi 5 |
| Operating System | Home Assistant OS (HAOS) 17.2 |
| Expansion Board | Waveshare Isolated RS232/RS485/CAN/CAN-FD HAT |
| Connection | 40-pin GPIO header (stacked on RPi5) |

## Interfaces Provided / 提供的介面

| Interface | Chip | Transceiver | Linux Device | Bus |
|-----------|------|-------------|-------------|-----|
| RS485 #1 | SC16IS752 (Ch.A) | SP485 | `/dev/ttySC0` | SPI1 |
| RS485 #2 | SC16IS752 (Ch.B) | SP485 | `/dev/ttySC1` | SPI1 |
| RS232 | — | SP3232EEN | `/dev/ttyAMA0` | UART0 |
| CAN FD | MCP2518FD | MCP2562FD | `can0` | SPI0 CE1 |
| CAN Classic | MCP2515 | SN65HVD230 | `can1` | SPI0 CE0 |

---

## Step 1: Install HAOS on RPi5 / 步驟1：安裝 HAOS

Follow the official Home Assistant installation guide for Raspberry Pi:

依照官方 Home Assistant 安裝指南安裝至樹莓派：

1. Download the RPi5 HAOS image from https://www.home-assistant.io/installation/raspberrypi
2. Flash to SD card using Raspberry Pi Imager or Balena Etcher
3. Insert SD card, connect Ethernet, power on RPi5
4. Access HA at `http://homeassistant.local:8123` (or by IP)
5. Complete onboarding

## Step 2: Install SSH Addon / 步驟2：安裝 SSH 附加元件

1. In HA, go to **Settings → Add-ons → Add-on Store** / 前往 **設定 → 附加元件 → 附加元件商店**
2. Search for **Advanced SSH & Web Terminal** / 搜尋 **Advanced SSH & Web Terminal**
3. Click **Install** / 點擊 **安裝**
4. After installation, go to **Configuration** tab / 安裝後前往 **設定** 頁籤
5. Set username (e.g., `root`) and password / 設定使用者名稱和密碼
6. Set SSH port to `22` / 設定 SSH 連接埠為 `22`

### Critical: Disable Protection Mode / 關鍵：關閉保護模式

7. Go to **Info** tab / 前往 **資訊** 頁籤
8. Toggle **Protection Mode** to **OFF** / 將 **保護模式** 切換為 **關閉**
9. Click **Start** / 點擊 **啟動**

> **Why?** Protection Mode restricts the addon container from accessing the host OS. With it ON, `ha` CLI commands return "unauthorized" and Docker is inaccessible.
>
> **為什麼？** 保護模式會限制附加元件容器存取主機作業系統。開啟時，`ha` CLI 指令會回傳「未授權」，Docker 也無法使用。

### Verify SSH Connection / 驗證 SSH 連線

```bash
ssh root@<RPi5_IP>
# Enter your password when prompted / 輸入密碼

# Verify host access / 驗證主機存取
ha os info
# Should show: Operating System: HAOS 17.2, Board: rpi5-64
```

## Step 3: Edit config.txt (Device Tree Overlays) / 步驟3：編輯 config.txt

### Why Docker is Needed / 為什麼需要 Docker

In HAOS, the SSH addon runs inside an Alpine Linux Docker container. This container cannot directly mount block devices because it lacks `CAP_SYS_ADMIN`. We need a privileged container.

在 HAOS 中，SSH 附加元件在 Alpine Linux Docker 容器內執行。此容器無法直接掛載區塊裝置，因為缺少 `CAP_SYS_ADMIN` 權限。需要使用特權容器。

### Mount and Edit / 掛載並編輯

```bash
# Launch a privileged Alpine container with access to the boot disk
# 啟動可存取開機磁碟的特權 Alpine 容器
docker run --rm -it --privileged \
  -v /dev/mmcblk0p1:/dev/mmcblk0p1 \
  alpine sh
```

Inside the container / 在容器內：

```bash
# Mount the boot partition / 掛載開機分區
mkdir -p /mnt/boot
mount /dev/mmcblk0p1 /mnt/boot

# Backup config.txt / 備份 config.txt
cp /mnt/boot/config.txt /mnt/boot/config.txt.bak

# View current config / 查看目前設定
cat /mnt/boot/config.txt
```

### Add Overlays / 加入 Overlay

Add the following lines **before** the `[cm4]` section in config.txt:

在 config.txt 的 `[cm4]` 段落**之前**加入以下內容：

```ini
# === Waveshare Isolated RS232/RS485/CAN/CAN-FD Board ===

# Enable SPI bus
dtparam=spi=on

# RS485 x2: SC16IS752 dual UART via SPI1
dtoverlay=spi1-3cs
dtoverlay=sc16is752-spi1,int_pin=25

# CAN Classic: MCP2515 on SPI0 CE0, 16MHz oscillator, INT=GPIO23
dtoverlay=mcp2515,spi0-0,oscillator=16000000,interrupt=23

# CAN FD: MCP2518FD on SPI0 CE1, INT=GPIO24
dtoverlay=mcp251xfd,spi0-1,interrupt=24

# RS232: Enable UART0 on RPi5 (GPIO 14/15)
dtoverlay=uart0-pi5
```

You can use `vi` to edit, or use this `awk` one-liner to insert before `[cm4]`:

可以使用 `vi` 編輯，或使用以下 `awk` 指令在 `[cm4]` 前插入：

```bash
awk '/^\[cm4\]/{
  print "dtparam=spi=on"
  print "dtoverlay=spi1-3cs"
  print "dtoverlay=sc16is752-spi1,int_pin=25"
  print "dtoverlay=mcp2515,spi0-0,oscillator=16000000,interrupt=23"
  print "dtoverlay=mcp251xfd,spi0-1,interrupt=24"
  print "dtoverlay=uart0-pi5"
  print ""
} {print}' /mnt/boot/config.txt > /tmp/config_new.txt \
  && mv /tmp/config_new.txt /mnt/boot/config.txt
```

```bash
# Unmount and exit container / 卸載並離開容器
umount /mnt/boot
exit
```

## Step 4: Reboot / 步驟4：重新啟動

```bash
ha host reboot
```

Wait about 1-2 minutes for the RPi5 to fully boot, then SSH back in.

等待約1-2分鐘讓樹莓派5完全啟動，然後重新 SSH 登入。

## Step 5: Verify All Devices / 步驟5：驗證所有裝置

```bash
# RS485 devices (SC16IS752) / RS485 裝置
ls -la /dev/ttySC*
# Expected: /dev/ttySC0 and /dev/ttySC1

# RS232 device (UART0) / RS232 裝置
ls -la /dev/ttyAMA0
# Expected: /dev/ttyAMA0

# CAN interfaces / CAN 介面
# Note: BusyBox 'ip' may not show CAN types; use Docker for CAN commands
# 注意：BusyBox 的 'ip' 可能不顯示 CAN 類型；CAN 指令需使用 Docker

# Check kernel modules / 檢查核心模組
lsmod | grep -iE "sc16|mcp|can|spi"
# Expected: sc16is7xx_spi, sc16is7xx, mcp251xfd, mcp251x, can_dev, spi_bcm2835

# Check dmesg for device initialization / 檢查 dmesg 裝置初始化訊息
dmesg | grep -iE "sc16|mcp|can|ttySC|ttyAMA"
# Expected: "ttySC0 at I/O 0x0", "ttySC1 at I/O 0x1", "MCP2518FD", "MCP2515"
```

### Expected dmesg Output / 預期 dmesg 輸出

```
spi1.0: ttySC0 at I/O 0x0 (irq = 188, base_baud = 921600) is a SC16IS752
spi1.0: ttySC1 at I/O 0x1 (irq = 188, base_baud = 921600) is a SC16IS752
mcp251xfd spi0.1 can0: MCP2518FD rev0.0 successfully initialized.
mcp251x spi0.0 can1: MCP2515 successfully initialized.
```

## Step 6: Quick Verification Test / 步驟6：快速驗證測試

### RS485 Test / RS485 測試

```bash
# Configure and write to RS485 #1 / 設定並寫入 RS485 #1
stty -F /dev/ttySC0 9600 cs8 -cstopb -parenb raw
echo -ne '\x01\x03\x00\x00\x00\x01\x84\x0A' > /dev/ttySC0
echo "RS485 #1: Write OK"

# Configure and write to RS485 #2 / 設定並寫入 RS485 #2
stty -F /dev/ttySC1 9600 cs8 -cstopb -parenb raw
echo -ne '\x01\x03\x00\x00\x00\x01\x84\x0A' > /dev/ttySC1
echo "RS485 #2: Write OK"
```

### RS232 Test / RS232 測試

```bash
stty -F /dev/ttyAMA0 115200 cs8 -cstopb -parenb raw
echo "Hello RS232" > /dev/ttyAMA0
echo "RS232: Write OK"
```

### CAN Bus Test / CAN Bus 測試

```bash
docker run --rm --privileged --net=host alpine sh -c '
  apk add --no-cache iproute2 can-utils 2>/dev/null

  # CAN FD loopback test / CAN FD 回環測試
  ip link set can0 up type can bitrate 500000 loopback on
  cansend can0 123#DEADBEEF && echo "CAN FD (can0): Send OK"
  ip link set can0 down

  # CAN Classic loopback test / CAN 經典回環測試
  ip link set can1 up type can bitrate 500000 loopback on
  cansend can1 456#CAFEBABE && echo "CAN Classic (can1): Send OK"
  ip link set can1 down
'
```

---

## What's Next / 下一步

After verifying all 5 interfaces, you can:

確認五個介面皆正常後，可以：

1. **Configure HA Modbus integration** for RS485 devices / 為 RS485 裝置設定 HA Modbus 整合
2. **Add serial sensors** for RS232 devices / 為 RS232 裝置新增序列感測器
3. **Set up CAN bus monitoring** via custom components or MQTT bridge / 透過自訂元件或 MQTT 橋接設定 CAN bus 監控
4. **Run the full test suite**: `bash test_all_interfaces.sh` / 執行完整測試：`bash test_all_interfaces.sh`

See [TEST_RESULTS.md](TEST_RESULTS.md) for comprehensive test results.

詳細測試結果請參閱 [TEST_RESULTS.md](TEST_RESULTS.md)。
