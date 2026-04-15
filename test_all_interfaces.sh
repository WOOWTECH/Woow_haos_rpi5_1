#!/bin/bash
# ============================================================================
# WOOW RPi5 HAOS Interface Test Script
# Tests: RS485 x2, RS232 x1, CAN bus x2
# Target: Raspberry Pi 5 running Home Assistant OS
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
SKIP=0
RESULTS=()

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_pass()  { echo -e "${GREEN}[PASS]${NC} $*"; PASS=$((PASS+1)); RESULTS+=("PASS: $*"); }
log_fail()  { echo -e "${RED}[FAIL]${NC} $*"; FAIL=$((FAIL+1)); RESULTS+=("FAIL: $*"); }
log_skip()  { echo -e "${YELLOW}[SKIP]${NC} $*"; SKIP=$((SKIP+1)); RESULTS+=("SKIP: $*"); }
log_header(){ echo -e "\n${BLUE}============================================================${NC}"; echo -e "${BLUE} $*${NC}"; echo -e "${BLUE}============================================================${NC}"; }

# ============================================================================
# PHASE 1: System Discovery
# ============================================================================
log_header "PHASE 1: System Discovery"

log_info "Checking OS and kernel info..."
uname -a
cat /etc/os-release 2>/dev/null || echo "No /etc/os-release"

log_info "Checking device tree model..."
cat /proc/device-tree/model 2>/dev/null && echo "" || echo "Cannot read device tree model"

log_info "Checking kernel version..."
uname -r

# ============================================================================
# PHASE 2: Device Enumeration
# ============================================================================
log_header "PHASE 2: Device Enumeration"

log_info "Listing all serial/tty devices..."
ls -la /dev/ttyAMA* /dev/ttyS* /dev/ttyUSB* /dev/serial* 2>/dev/null || echo "No standard serial devices found"

log_info "Listing all CAN interfaces..."
ls -la /dev/can* 2>/dev/null || echo "No /dev/can* devices"
ip link show type can 2>/dev/null || echo "No CAN network interfaces found"

log_info "Checking SPI devices..."
ls -la /dev/spi* 2>/dev/null || echo "No SPI devices found"

log_info "Checking loaded kernel modules..."
lsmod 2>/dev/null | grep -iE "can|spi|serial|uart|rs485|mcp" || echo "No relevant modules loaded"

log_info "Checking device tree overlays..."
ls /proc/device-tree/soc/serial@* 2>/dev/null || echo "No serial nodes in device tree"
ls /proc/device-tree/soc/spi@* 2>/dev/null || echo "No SPI nodes in device tree"

log_info "Checking config.txt..."
if [ -f /mnt/boot/config.txt ]; then
    echo "--- config.txt contents ---"
    cat /mnt/boot/config.txt
    echo "--- end config.txt ---"
else
    echo "/mnt/boot/config.txt not found"
    # Try alternate locations
    for f in /boot/config.txt /boot/firmware/config.txt; do
        if [ -f "$f" ]; then
            echo "Found config at: $f"
            cat "$f"
        fi
    done
fi

log_info "Checking GPIO pins..."
cat /sys/kernel/debug/gpio 2>/dev/null | head -30 || echo "Cannot read GPIO debug info"

# ============================================================================
# PHASE 3: RS485 Test - Interface #1
# ============================================================================
log_header "PHASE 3: RS485 Interface #1 Test"

RS485_1=""
# Common RS485 device paths on RPi5 with HAT
for dev in /dev/ttyAMA1 /dev/ttyAMA2 /dev/ttyS0 /dev/ttyUSB0; do
    if [ -e "$dev" ]; then
        RS485_1="$dev"
        log_info "Found potential RS485 #1 device: $dev"
        break
    fi
done

if [ -n "$RS485_1" ]; then
    log_info "Testing RS485 #1 on $RS485_1"

    # Configure serial port
    if command -v stty &>/dev/null; then
        stty -F "$RS485_1" 9600 cs8 -cstopb -parenb raw 2>&1 && \
            log_pass "RS485 #1 ($RS485_1): stty configuration successful" || \
            log_fail "RS485 #1 ($RS485_1): stty configuration failed"
    else
        log_skip "RS485 #1: stty not available"
    fi

    # Try to write test data
    echo -ne '\x01\x03\x00\x00\x00\x01\x84\x0A' > "$RS485_1" 2>&1 && \
        log_pass "RS485 #1 ($RS485_1): write test successful" || \
        log_fail "RS485 #1 ($RS485_1): write test failed"

    # Check RS485 mode support
    if [ -d "/sys/class/tty/$(basename $RS485_1)/rs485" ] 2>/dev/null; then
        log_pass "RS485 #1: RS485 mode supported in kernel"
    else
        log_info "RS485 #1: No kernel RS485 mode directory (may use userspace control)"
    fi
else
    log_skip "RS485 #1: No device found"
fi

# ============================================================================
# PHASE 4: RS485 Test - Interface #2
# ============================================================================
log_header "PHASE 4: RS485 Interface #2 Test"

RS485_2=""
# Look for second RS485 device (skip the one already used)
for dev in /dev/ttyAMA1 /dev/ttyAMA2 /dev/ttyAMA3 /dev/ttyS1 /dev/ttyUSB1; do
    if [ -e "$dev" ] && [ "$dev" != "$RS485_1" ]; then
        RS485_2="$dev"
        log_info "Found potential RS485 #2 device: $dev"
        break
    fi
done

if [ -n "$RS485_2" ]; then
    log_info "Testing RS485 #2 on $RS485_2"

    if command -v stty &>/dev/null; then
        stty -F "$RS485_2" 9600 cs8 -cstopb -parenb raw 2>&1 && \
            log_pass "RS485 #2 ($RS485_2): stty configuration successful" || \
            log_fail "RS485 #2 ($RS485_2): stty configuration failed"
    else
        log_skip "RS485 #2: stty not available"
    fi

    echo -ne '\x01\x03\x00\x00\x00\x01\x84\x0A' > "$RS485_2" 2>&1 && \
        log_pass "RS485 #2 ($RS485_2): write test successful" || \
        log_fail "RS485 #2 ($RS485_2): write test failed"
else
    log_skip "RS485 #2: No device found"
fi

# ============================================================================
# PHASE 5: RS232 Test
# ============================================================================
log_header "PHASE 5: RS232 Interface Test"

RS232=""
# RS232 typically on ttyAMA0 or a specific UART
for dev in /dev/ttyAMA0 /dev/ttyAMA4 /dev/ttyS0 /dev/ttyUSB0 /dev/ttyUSB1 /dev/ttyUSB2; do
    if [ -e "$dev" ] && [ "$dev" != "$RS485_1" ] && [ "$dev" != "$RS485_2" ]; then
        RS232="$dev"
        log_info "Found potential RS232 device: $dev"
        break
    fi
done

if [ -n "$RS232" ]; then
    log_info "Testing RS232 on $RS232"

    if command -v stty &>/dev/null; then
        stty -F "$RS232" 115200 cs8 -cstopb -parenb raw 2>&1 && \
            log_pass "RS232 ($RS232): stty configuration successful" || \
            log_fail "RS232 ($RS232): stty configuration failed"
    else
        log_skip "RS232: stty not available"
    fi

    # Loopback test (if TX/RX are connected)
    echo "RS232_LOOPBACK_TEST" > "$RS232" 2>&1 && \
        log_pass "RS232 ($RS232): write test successful" || \
        log_fail "RS232 ($RS232): write test failed"
else
    log_skip "RS232: No device found"
fi

# ============================================================================
# PHASE 6: CAN Bus Test - Interface #1
# ============================================================================
log_header "PHASE 6: CAN Bus Interface #1 Test"

CAN1_FOUND=false

# Check if can0 exists
if ip link show can0 &>/dev/null; then
    CAN1_FOUND=true
    log_info "CAN0 interface found"

    # Bring up CAN0 in loopback mode for self-test
    ip link set can0 down 2>/dev/null
    ip link set can0 up type can bitrate 500000 loopback on 2>&1 && \
        log_pass "CAN #1 (can0): interface brought up in loopback mode at 500kbps" || \
        log_fail "CAN #1 (can0): failed to bring up interface"

    # Check interface state
    ip -details link show can0 2>&1

    # Send test message
    if command -v cansend &>/dev/null; then
        cansend can0 123#DEADBEEF 2>&1 && \
            log_pass "CAN #1 (can0): cansend test message successful" || \
            log_fail "CAN #1 (can0): cansend failed"
    else
        log_skip "CAN #1: cansend not available (can-utils not installed)"
    fi

    # Dump (with timeout)
    if command -v candump &>/dev/null; then
        timeout 2 candump can0 2>&1 || true
    fi
else
    log_skip "CAN #1 (can0): interface not found"
fi

# ============================================================================
# PHASE 7: CAN Bus Test - Interface #2
# ============================================================================
log_header "PHASE 7: CAN Bus Interface #2 Test"

CAN2_FOUND=false

if ip link show can1 &>/dev/null; then
    CAN2_FOUND=true
    log_info "CAN1 interface found"

    ip link set can1 down 2>/dev/null
    ip link set can1 up type can bitrate 500000 loopback on 2>&1 && \
        log_pass "CAN #2 (can1): interface brought up in loopback mode at 500kbps" || \
        log_fail "CAN #2 (can1): failed to bring up interface"

    ip -details link show can1 2>&1

    if command -v cansend &>/dev/null; then
        cansend can1 456#CAFEBABE 2>&1 && \
            log_pass "CAN #2 (can1): cansend test message successful" || \
            log_fail "CAN #2 (can1): cansend failed"
    else
        log_skip "CAN #2: cansend not available"
    fi
else
    log_skip "CAN #2 (can1): interface not found"
fi

# ============================================================================
# PHASE 8: Summary
# ============================================================================
log_header "TEST SUMMARY"

echo ""
echo "Results:"
for r in "${RESULTS[@]}"; do
    case "$r" in
        PASS*) echo -e "  ${GREEN}$r${NC}" ;;
        FAIL*) echo -e "  ${RED}$r${NC}" ;;
        SKIP*) echo -e "  ${YELLOW}$r${NC}" ;;
    esac
done

echo ""
echo -e "Total: ${GREEN}$PASS PASS${NC} / ${RED}$FAIL FAIL${NC} / ${YELLOW}$SKIP SKIP${NC}"
echo ""

if [ $FAIL -gt 0 ]; then
    echo -e "${RED}Some tests FAILED. Review output above for details.${NC}"
    exit 1
elif [ $SKIP -gt 0 ]; then
    echo -e "${YELLOW}Some tests were SKIPPED (likely missing device/config).${NC}"
    echo -e "${YELLOW}Check config.txt overlays and hardware connections.${NC}"
    exit 0
else
    echo -e "${GREEN}All tests PASSED!${NC}"
    exit 0
fi
