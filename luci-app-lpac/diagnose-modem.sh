#!/bin/sh
# Modem Diagnostic Script for lpac on GL-XE300
# Run this on the router to diagnose modem communication issues

echo "╔══════════════════════════════════════════════════╗"
echo "║  lpac Modem Diagnostic Tool                     ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Check USB Devices
echo "${YELLOW}[1/8] Checking USB Devices...${NC}"
lsusb | grep -i "quectel\|qualcomm\|sierra\|telit\|simcom" || echo "  ${RED}✗${NC} No known modem found"
echo ""

# 2. Check Kernel Modules
echo "${YELLOW}[2/8] Checking Kernel Modules...${NC}"
MODULES="usb_wwan qmi_wwan cdc_wdm cdc_mbim option"
for mod in $MODULES; do
    if lsmod | grep -q "^$mod"; then
        echo "  ${GREEN}✓${NC} $mod loaded"
    else
        echo "  ${RED}✗${NC} $mod not loaded"
    fi
done
echo ""

# 3. Check Serial Devices
echo "${YELLOW}[3/8] Checking Serial Devices...${NC}"
if ls /dev/ttyUSB* >/dev/null 2>&1; then
    ls -l /dev/ttyUSB* | awk '{print "  "$1" "$NF}'
    echo "  ${GREEN}✓${NC} Serial devices found"
else
    echo "  ${RED}✗${NC} No /dev/ttyUSB* devices found"
fi
echo ""

# 4. Check MBIM/QMI Devices
echo "${YELLOW}[4/8] Checking MBIM/QMI Devices...${NC}"
if ls /dev/cdc-wdm* >/dev/null 2>&1; then
    ls -l /dev/cdc-wdm* | awk '{print "  "$1" "$NF}'
    echo "  ${GREEN}✓${NC} MBIM/QMI devices found"
else
    echo "  ${YELLOW}⚠${NC} No /dev/cdc-wdm* devices found (normal for serial-only modems)"
fi
echo ""

# 5. Test AT Commands on Each Port
echo "${YELLOW}[5/8] Testing AT Command Ports...${NC}"
for port in /dev/ttyUSB*; do
    [ ! -e "$port" ] && continue

    echo "  Testing $port..."

    # Try to send AT command with timeout
    (
        echo -e "AT\r" > "$port" &
        PID=$!
        sleep 1
        kill $PID 2>/dev/null

        # Try to read response
        response=$(timeout 1 cat "$port" 2>/dev/null)
        if echo "$response" | grep -q "OK"; then
            echo "    ${GREEN}✓${NC} AT port responding (likely the command port)"
        elif [ -n "$response" ]; then
            echo "    ${YELLOW}⚠${NC} Port responding but not to AT commands: $response"
        else
            echo "    ${RED}✗${NC} No response (may be data/diagnostic port)"
        fi
    )
done
echo ""

# 6. Check Modem Firmware
echo "${YELLOW}[6/8] Checking Modem Firmware (ATI)...${NC}"
for port in /dev/ttyUSB2 /dev/ttyUSB1 /dev/ttyUSB0; do
    [ ! -e "$port" ] && continue

    (
        # Send ATI command
        echo -e "ATI\r" > "$port" 2>/dev/null &
        sleep 0.5

        # Read response with timeout
        response=$(timeout 2 cat "$port" 2>/dev/null | head -20)

        if [ -n "$response" ]; then
            echo "  Port: $port"
            echo "$response" | head -10 | sed 's/^/    /'
            break
        fi
    )
done
echo ""

# 7. Check eUICC Support (AT+CSIM)
echo "${YELLOW}[7/8] Testing eUICC Support...${NC}"
for port in /dev/ttyUSB2 /dev/ttyUSB1 /dev/ttyUSB0; do
    [ ! -e "$port" ] && continue

    echo "  Testing $port with AT+CSIM..."
    (
        # Send simple APDU via AT+CSIM to test eUICC
        # This command selects the ISD-R (eUICC root)
        echo -e 'AT+CSIM=14,"00A4040400"\r' > "$port" 2>/dev/null &
        sleep 1

        response=$(timeout 2 cat "$port" 2>/dev/null)

        if echo "$response" | grep -q "+CSIM:"; then
            echo "    ${GREEN}✓${NC} eUICC responding on $port"
            echo "    Response: $(echo "$response" | grep "+CSIM:" | head -1)"
            break
        elif echo "$response" | grep -q "ERROR"; then
            echo "    ${RED}✗${NC} AT+CSIM not supported or eUICC not available"
        else
            echo "    ${YELLOW}⚠${NC} No response (port may not support AT+CSIM)"
        fi
    )
done
echo ""

# 8. Check lpac Installation
echo "${YELLOW}[8/8] Checking lpac Installation...${NC}"

if [ -x /usr/lib/lpac ]; then
    echo "  ${GREEN}✓${NC} lpac binary found: /usr/lib/lpac"
    VERSION=$(/usr/lib/lpac --version 2>&1 | head -1 || echo "unknown")
    echo "    Version: $VERSION"
else
    echo "  ${RED}✗${NC} lpac binary not found at /usr/lib/lpac"
fi

if [ -x /usr/bin/lpac_json ]; then
    echo "  ${GREEN}✓${NC} lpac_json wrapper found"
else
    echo "  ${RED}✗${NC} lpac_json wrapper not found"
fi

if [ -f /etc/config/lpac ]; then
    echo "  ${GREEN}✓${NC} UCI config found"
    echo "    Driver: $(uci get lpac.device.driver 2>/dev/null || echo 'not set')"
    echo "    AT Device: $(uci get lpac.device.at_device 2>/dev/null || echo 'not set')"
else
    echo "  ${YELLOW}⚠${NC} UCI config not found"
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  Diagnostic Complete                             ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Recommendations
echo "${YELLOW}Recommendations:${NC}"
echo ""

# Check if modem found
if ! lsusb | grep -qi "quectel\|qualcomm"; then
    echo "  ${RED}⚠ No Quectel/Qualcomm modem detected via USB${NC}"
    echo "    • Check if modem is properly inserted"
    echo "    • Check if modem has power"
    echo "    • Try: rmmod qmi_wwan && modprobe qmi_wwan"
    echo ""
fi

# Check if serial ports found
if ! ls /dev/ttyUSB* >/dev/null 2>&1; then
    echo "  ${RED}⚠ No serial ports detected${NC}"
    echo "    • Load USB serial modules: modprobe option"
    echo "    • Check dmesg for USB errors: dmesg | tail -50"
    echo ""
fi

# If lpac hangs
echo "  ${YELLOW}If lpac hangs:${NC}"
echo "    1. Verify AT port with: echo -e 'AT\r' > /dev/ttyUSB2 && cat /dev/ttyUSB2"
echo "    2. Check if eUICC responds to AT+CSIM (see test above)"
echo "    3. Try different USB ports (ttyUSB0, ttyUSB1, ttyUSB2, ttyUSB3)"
echo "    4. Some modems need QMI driver instead of AT driver"
echo "    5. Enable verbose logging: export LPAC_DEBUG=1"
echo ""

echo "  ${YELLOW}Common Issues:${NC}"
echo "    • EP06-E: Usually uses /dev/ttyUSB2 for AT commands"
echo "    • Some modems need 'at_csim' driver instead of 'at'"
echo "    • Modem may need initialization: AT+CFUN=1"
echo "    • Check if SIM card is inserted and detected"
echo ""
