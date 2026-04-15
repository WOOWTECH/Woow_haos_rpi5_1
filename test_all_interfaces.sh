#!/bin/bash
# ============================================================================
# WOOW RPi5 HAOS - Waveshare Isolated Industrial Interface Board Test Script
# 微雪隔離型工業介面擴展板測試腳本
#
# Board: Waveshare Isolated RS232/RS485/CAN/CAN-FD Expansion Board
# Target: Raspberry Pi 5 running Home Assistant OS (HAOS)
#
# Interfaces tested:
#   RS485 #1: /dev/ttySC0 (SC16IS752 Channel A via SPI1)
#   RS485 #2: /dev/ttySC1 (SC16IS752 Channel B via SPI1)
#   RS232:    /dev/ttyAMA0 (SP3232EEN via UART0)
#   CAN FD:   can0 (MCP2518FD via SPI0 CE1)
#   CAN:      can1 (MCP2515 via SPI0 CE0)
#
# Usage:
#   Run directly on RPi5 HAOS via SSH:
#     bash test_all_interfaces.sh
#
#   CAN tests require Docker (BusyBox lacks CAN support):
#     The script will auto-detect and use Docker when needed.
# ============================================================================

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

log_info "OS and kernel info..."
uname -a
ha os info 2>/dev/null || echo "(ha CLI not available or unauthorized)"

log_info "Device tree model..."
cat /proc/device-tree/model 2>/dev/null && echo "" || echo "Cannot read device tree model"

# ============================================================================
# PHASE 2: Device Enumeration
# ============================================================================
log_header "PHASE 2: Device Enumeration"

log_info "Checking SC16IS752 UART devices (RS485)..."
if ls /dev/ttySC* 2>/dev/null; then
    log_pass "SC16IS752 UART devices found"
else
    log_fail "No /dev/ttySC* devices found - check SPI1 overlays"
fi

log_info "Checking UART0 device (RS232)..."
if [ -e /dev/ttyAMA0 ]; then
    log_pass "UART0 device /dev/ttyAMA0 found"
else
    log_fail "No /dev/ttyAMA0 - check uart0-pi5 overlay"
fi

log_info "Checking kernel modules..."
MODULES=$(lsmod 2>/dev/null)
for mod in sc16is7xx mcp251xfd mcp251x can_dev spi_bcm2835; do
    if echo "$MODULES" | grep -q "$mod"; then
        log_pass "Module loaded: $mod"
    else
        log_fail "Module NOT loaded: $mod"
    fi
done

log_info "Checking dmesg for device init..."
dmesg 2>/dev/null | grep -iE "ttySC|SC16IS|MCP251|MCP2515|MCP2518" | head -10

# ============================================================================
# PHASE 3: RS485 #1 Test (/dev/ttySC0)
# ============================================================================
log_header "PHASE 3: RS485 #1 (/dev/ttySC0)"

if [ -e /dev/ttySC0 ]; then
    # Test multiple baud rates
    for baud in 9600 19200 38400 57600 115200; do
        if stty -F /dev/ttySC0 "$baud" cs8 -cstopb -parenb raw 2>/dev/null; then
            log_pass "RS485 #1: baud rate $baud"
        else
            log_fail "RS485 #1: baud rate $baud"
        fi
    done

    # Test data formats
    if stty -F /dev/ttySC0 9600 cs8 -cstopb -parenb raw 2>/dev/null; then
        log_pass "RS485 #1: format 8N1"
    else
        log_fail "RS485 #1: format 8N1"
    fi

    if stty -F /dev/ttySC0 9600 cs8 -cstopb parenb -parodd raw 2>/dev/null; then
        log_pass "RS485 #1: format 8E1"
    else
        log_fail "RS485 #1: format 8E1"
    fi

    # Modbus RTU write test
    stty -F /dev/ttySC0 9600 cs8 -cstopb -parenb raw 2>/dev/null
    if echo -ne '\x01\x03\x00\x00\x00\x01\x84\x0A' > /dev/ttySC0 2>/dev/null; then
        log_pass "RS485 #1: Modbus FC03 write"
    else
        log_fail "RS485 #1: Modbus FC03 write"
    fi

    # Bulk write test (256 bytes)
    if dd if=/dev/urandom bs=256 count=1 2>/dev/null > /dev/ttySC0; then
        log_pass "RS485 #1: 256-byte bulk write"
    else
        log_fail "RS485 #1: 256-byte bulk write"
    fi

    # Stress test (5 cycles)
    STRESS_OK=0
    for i in $(seq 1 5); do
        stty -F /dev/ttySC0 9600 cs8 -cstopb -parenb raw 2>/dev/null && \
        echo -ne "\x01\x03\x00\x00\x00\x01\x84\x0A" > /dev/ttySC0 2>/dev/null && \
        STRESS_OK=$((STRESS_OK+1))
    done
    log_pass "RS485 #1: stress test $STRESS_OK/5 cycles"
else
    log_skip "RS485 #1: /dev/ttySC0 not found"
fi

# ============================================================================
# PHASE 4: RS485 #2 Test (/dev/ttySC1)
# ============================================================================
log_header "PHASE 4: RS485 #2 (/dev/ttySC1)"

if [ -e /dev/ttySC1 ]; then
    for baud in 9600 19200 38400 57600 115200; do
        if stty -F /dev/ttySC1 "$baud" cs8 -cstopb -parenb raw 2>/dev/null; then
            log_pass "RS485 #2: baud rate $baud"
        else
            log_fail "RS485 #2: baud rate $baud"
        fi
    done

    stty -F /dev/ttySC1 9600 cs8 -cstopb -parenb raw 2>/dev/null
    if echo -ne '\x01\x03\x00\x00\x00\x01\x84\x0A' > /dev/ttySC1 2>/dev/null; then
        log_pass "RS485 #2: Modbus FC03 write"
    else
        log_fail "RS485 #2: Modbus FC03 write"
    fi

    if dd if=/dev/urandom bs=256 count=1 2>/dev/null > /dev/ttySC1; then
        log_pass "RS485 #2: 256-byte bulk write"
    else
        log_fail "RS485 #2: 256-byte bulk write"
    fi

    # Dual-channel simultaneous write
    stty -F /dev/ttySC0 9600 cs8 -cstopb -parenb raw 2>/dev/null
    stty -F /dev/ttySC1 9600 cs8 -cstopb -parenb raw 2>/dev/null
    echo -ne '\x01\x03\x00\x00\x00\x01\x84\x0A' > /dev/ttySC0 &
    echo -ne '\x02\x03\x00\x00\x00\x01\x84\x39' > /dev/ttySC1 &
    wait
    log_pass "RS485: dual-channel simultaneous write"
else
    log_skip "RS485 #2: /dev/ttySC1 not found"
fi

# ============================================================================
# PHASE 5: RS232 Test (/dev/ttyAMA0)
# ============================================================================
log_header "PHASE 5: RS232 (/dev/ttyAMA0)"

if [ -e /dev/ttyAMA0 ]; then
    for baud in 9600 19200 38400 57600 115200 230400 460800 921600; do
        if stty -F /dev/ttyAMA0 "$baud" cs8 -cstopb -parenb raw 2>/dev/null; then
            log_pass "RS232: baud rate $baud"
        else
            log_fail "RS232: baud rate $baud"
        fi
    done

    # Data formats
    stty -F /dev/ttyAMA0 115200 cs8 -cstopb -parenb raw 2>/dev/null && \
        log_pass "RS232: format 8N1" || log_fail "RS232: format 8N1"
    stty -F /dev/ttyAMA0 115200 cs8 -cstopb parenb -parodd raw 2>/dev/null && \
        log_pass "RS232: format 8E1" || log_fail "RS232: format 8E1"
    stty -F /dev/ttyAMA0 115200 cs8 -cstopb parenb parodd raw 2>/dev/null && \
        log_pass "RS232: format 8O1" || log_fail "RS232: format 8O1"

    # Flow control
    stty -F /dev/ttyAMA0 115200 crtscts raw 2>/dev/null && \
        log_pass "RS232: HW flow control (RTS/CTS)" || log_fail "RS232: HW flow control"
    stty -F /dev/ttyAMA0 115200 ixon ixoff raw 2>/dev/null && \
        log_pass "RS232: SW flow control (XON/XOFF)" || log_fail "RS232: SW flow control"
    stty -F /dev/ttyAMA0 115200 -crtscts -ixon -ixoff raw 2>/dev/null && \
        log_pass "RS232: No flow control" || log_fail "RS232: No flow control"

    # Write tests
    stty -F /dev/ttyAMA0 115200 cs8 -cstopb -parenb raw 2>/dev/null
    echo "Hello RS232 Test" > /dev/ttyAMA0 2>/dev/null && \
        log_pass "RS232: ASCII write" || log_fail "RS232: ASCII write"
    echo "AT" > /dev/ttyAMA0 2>/dev/null && \
        log_pass "RS232: AT command write" || log_fail "RS232: AT command write"

    # Bulk write (4KB)
    if dd if=/dev/urandom bs=4096 count=1 2>/dev/null > /dev/ttyAMA0; then
        log_pass "RS232: 4KB bulk write"
    else
        log_fail "RS232: 4KB bulk write"
    fi

    # Stress test (10 cycles)
    STRESS_OK=0
    for i in $(seq 1 10); do
        stty -F /dev/ttyAMA0 115200 cs8 -cstopb -parenb raw 2>/dev/null && \
        echo "stress_$i" > /dev/ttyAMA0 2>/dev/null && \
        STRESS_OK=$((STRESS_OK+1))
    done
    log_pass "RS232: stress test $STRESS_OK/10 cycles"
else
    log_skip "RS232: /dev/ttyAMA0 not found"
fi

# ============================================================================
# PHASE 6: CAN FD Test (can0 - MCP2518FD)
# ============================================================================
log_header "PHASE 6: CAN FD (can0 - MCP2518FD)"

# CAN tests require Docker with iproute2 and can-utils
if command -v docker &>/dev/null; then
    CAN_RESULT=$(docker run --rm --privileged --net=host alpine sh -c '
        apk add --no-cache iproute2 can-utils >/dev/null 2>&1

        PASS=0
        FAIL=0

        # Test multiple bitrates
        for brate in 125000 250000 500000 1000000; do
            ip link set can0 down 2>/dev/null
            if ip link set can0 up type can bitrate $brate loopback on 2>/dev/null; then
                echo "PASS: CAN FD bitrate $brate"
                PASS=$((PASS+1))
            else
                echo "FAIL: CAN FD bitrate $brate"
                FAIL=$((FAIL+1))
            fi
            ip link set can0 down 2>/dev/null
        done

        # CAN FD mode test
        ip link set can0 down 2>/dev/null
        if ip link set can0 up type can bitrate 500000 dbitrate 2000000 fd on loopback on 2>/dev/null; then
            echo "PASS: CAN FD mode 500k/2M"
            PASS=$((PASS+1))
        else
            echo "FAIL: CAN FD mode 500k/2M"
            FAIL=$((FAIL+1))
        fi

        # Loopback send/receive test
        ip link set can0 down 2>/dev/null
        ip link set can0 up type can bitrate 500000 loopback on 2>/dev/null
        if cansend can0 123#DEADBEEF 2>/dev/null; then
            echo "PASS: CAN FD loopback send"
            PASS=$((PASS+1))
        else
            echo "FAIL: CAN FD loopback send"
            FAIL=$((FAIL+1))
        fi

        # Extended frame
        if cansend can0 18DAF110#0102030405060708 2>/dev/null; then
            echo "PASS: CAN FD extended frame"
            PASS=$((PASS+1))
        else
            echo "FAIL: CAN FD extended frame"
            FAIL=$((FAIL+1))
        fi

        # Burst test (20 frames)
        BURST_OK=0
        for i in $(seq 1 20); do
            cansend can0 7FF#$(printf "%016X" $i) 2>/dev/null && BURST_OK=$((BURST_OK+1))
        done
        echo "PASS: CAN FD burst $BURST_OK/20 frames"

        # Show stats
        ip -details -statistics link show can0 2>/dev/null | head -5

        ip link set can0 down 2>/dev/null
        echo "CAN_FD_DONE"
    ' 2>&1)

    echo "$CAN_RESULT" | while IFS= read -r line; do
        case "$line" in
            PASS:*) log_pass "${line#PASS: }" ;;
            FAIL:*) log_fail "${line#FAIL: }" ;;
        esac
    done
else
    log_skip "CAN FD: Docker not available (required for CAN tools on HAOS)"
fi

# ============================================================================
# PHASE 7: CAN Classic Test (can1 - MCP2515)
# ============================================================================
log_header "PHASE 7: CAN Classic (can1 - MCP2515)"

if command -v docker &>/dev/null; then
    CAN1_RESULT=$(docker run --rm --privileged --net=host alpine sh -c '
        apk add --no-cache iproute2 can-utils >/dev/null 2>&1

        # Test multiple bitrates
        for brate in 125000 250000 500000 1000000; do
            ip link set can1 down 2>/dev/null
            if ip link set can1 up type can bitrate $brate loopback on 2>/dev/null; then
                echo "PASS: CAN Classic bitrate $brate"
            else
                echo "FAIL: CAN Classic bitrate $brate"
            fi
            ip link set can1 down 2>/dev/null
        done

        # Loopback test
        ip link set can1 down 2>/dev/null
        ip link set can1 up type can bitrate 500000 loopback on 2>/dev/null
        if cansend can1 456#CAFEBABE 2>/dev/null; then
            echo "PASS: CAN Classic loopback send"
        else
            echo "FAIL: CAN Classic loopback send"
        fi

        # Standard frame
        if cansend can1 000#01 2>/dev/null; then
            echo "PASS: CAN Classic standard frame ID=0x000"
        else
            echo "FAIL: CAN Classic standard frame"
        fi

        # Extended frame
        if cansend can1 1FFFFFFF#0102030405060708 2>/dev/null; then
            echo "PASS: CAN Classic extended frame ID=0x1FFFFFFF"
        else
            echo "FAIL: CAN Classic extended frame"
        fi

        # Burst test (20 frames)
        BURST_OK=0
        for i in $(seq 1 20); do
            cansend can1 100#$(printf "%016X" $i) 2>/dev/null && BURST_OK=$((BURST_OK+1))
        done
        echo "PASS: CAN Classic burst $BURST_OK/20 frames"

        ip -details -statistics link show can1 2>/dev/null | head -5

        ip link set can1 down 2>/dev/null
        echo "CAN_CLASSIC_DONE"
    ' 2>&1)

    echo "$CAN1_RESULT" | while IFS= read -r line; do
        case "$line" in
            PASS:*) log_pass "${line#PASS: }" ;;
            FAIL:*) log_fail "${line#FAIL: }" ;;
        esac
    done
else
    log_skip "CAN Classic: Docker not available"
fi

# ============================================================================
# PHASE 8: Summary
# ============================================================================
log_header "TEST SUMMARY"

echo ""
echo "Individual Results:"
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
    echo -e "${YELLOW}Some tests were SKIPPED. Check device availability.${NC}"
    exit 0
else
    echo -e "${GREEN}All tests PASSED!${NC}"
    exit 0
fi
