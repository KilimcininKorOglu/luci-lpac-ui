#!/bin/sh
# Fix modem port communication issues
# For Quectel EP06-E on OpenWrt 19.07.10

echo "╔══════════════════════════════════════════════════╗"
echo "║  Quectel EP06-E Port Fix Script                 ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Step 1: Fix permissions on all ports
echo "[1/7] Fixing device permissions..."
chmod 666 /dev/ttyUSB* 2>/dev/null
chmod 666 /dev/cdc-wdm* 2>/dev/null
echo "  ✓ Permissions updated"
echo ""

# Step 2: Check if any process is using the ports
echo "[2/7] Checking for port conflicts..."
for port in /dev/ttyUSB0 /dev/ttyUSB1 /dev/ttyUSB2 /dev/ttyUSB3 /dev/ttyUSB4; do
    [ ! -e "$port" ] && continue
    PROC=$(fuser "$port" 2>/dev/null)
    if [ -n "$PROC" ]; then
        echo "  ⚠ Port $port in use by PID: $PROC"
        echo "    Killing process..."
        fuser -k "$port" 2>/dev/null
        sleep 1
    fi
done
echo "  ✓ No conflicts"
echo ""

# Step 3: Test AT commands with proper timing
echo "[3/7] Testing AT commands (with proper delays)..."
test_at_port() {
    local port="$1"

    # Clear any pending data
    cat "$port" > /dev/null 2>&1 &
    CAT_PID=$!
    sleep 1
    kill $CAT_PID 2>/dev/null

    # Send AT command
    (
        echo -e "AT\r" > "$port" 2>/dev/null
        sleep 1

        # Read response (non-blocking with timeout)
        response=$(dd if="$port" bs=256 count=1 2>/dev/null | head -c 256)

        if echo "$response" | grep -q "OK"; then
            echo "  ✓ $port responding to AT commands"
            return 0
        elif echo "$response" | grep -q "ERROR"; then
            echo "  ⚠ $port returned ERROR"
            return 1
        else
            echo "  ✗ $port no response"
            return 1
        fi
    )
}

AT_PORT=""
for port in /dev/ttyUSB2 /dev/ttyUSB3 /dev/ttyUSB1 /dev/ttyUSB0 /dev/ttyUSB4; do
    [ ! -e "$port" ] && continue
    echo "  Testing $port..."
    if test_at_port "$port"; then
        AT_PORT="$port"
        break
    fi
done

if [ -z "$AT_PORT" ]; then
    echo ""
    echo "  ⚠ WARNING: No AT port found!"
    echo "    The modem may need initialization or be in a bad state"
    echo ""
    AT_PORT="/dev/ttyUSB2"  # Default fallback
fi

echo ""

# Step 4: Send modem reset/init commands
echo "[4/7] Initializing modem..."

init_modem() {
    local port="$1"
    echo "  Using port: $port"

    # Send basic initialization commands
    echo -e "ATE0\r" > "$port" 2>/dev/null  # Disable echo
    sleep 1

    echo -e "AT+CFUN?\r" > "$port" 2>/dev/null  # Check power mode
    sleep 1

    echo -e "AT+CFUN=1\r" > "$port" 2>/dev/null  # Full functionality
    sleep 2

    echo -e "AT\r" > "$port" 2>/dev/null  # Basic test
    sleep 1

    # Try to read response
    response=$(dd if="$port" bs=1024 count=1 2>/dev/null | head -c 1024)

    if echo "$response" | grep -q "OK"; then
        echo "  ✓ Modem initialized"
        return 0
    else
        echo "  ⚠ Modem may not have initialized properly"
        echo "    Response: ${response:-<no response>}"
        return 1
    fi
}

init_modem "$AT_PORT"
echo ""

# Step 5: Verify modem is responding
echo "[5/7] Verifying modem communication..."

# Clear buffer
cat "$AT_PORT" > /dev/null 2>&1 &
CAT_PID=$!
sleep 1
kill $CAT_PID 2>/dev/null

# Send ATI command
echo -e "ATI\r" > "$AT_PORT" 2>/dev/null
sleep 2

response=$(dd if="$AT_PORT" bs=2048 count=1 2>/dev/null | head -c 2048)

if [ -n "$response" ]; then
    echo "  ✓ Modem firmware info:"
    echo "$response" | grep -v "^$" | head -8 | sed 's/^/    /'
else
    echo "  ✗ No response from modem"
fi
echo ""

# Step 6: Test eUICC with AT+CSIM
echo "[6/7] Testing eUICC (AT+CSIM)..."

# Clear buffer
cat "$AT_PORT" > /dev/null 2>&1 &
CAT_PID=$!
sleep 1
kill $CAT_PID 2>/dev/null

# Send AT+CSIM command (select ISD-R)
echo -e 'AT+CSIM=14,"00A4040400"\r' > "$AT_PORT" 2>/dev/null
sleep 2

response=$(dd if="$AT_PORT" bs=1024 count=1 2>/dev/null | head -c 1024)

if echo "$response" | grep -q "+CSIM:"; then
    csim_response=$(echo "$response" | grep "+CSIM:" | head -1)
    echo "  ✓ eUICC responding!"
    echo "    $csim_response"

    if echo "$csim_response" | grep -q "9000"; then
        echo "    ✓ eUICC is accessible (status: 9000 = success)"
        EUICC_OK=1
    elif echo "$csim_response" | grep -q "6985"; then
        echo "    ⚠ eUICC locked or conditions not met (status: 6985)"
        EUICC_OK=0
    else
        echo "    ⚠ Unknown eUICC status"
        EUICC_OK=0
    fi
else
    echo "  ✗ No AT+CSIM response"
    echo "    The modem may need 'at_csim' driver or QMI driver instead"
    EUICC_OK=0
fi
echo ""

# Step 7: Configure lpac
echo "[7/7] Configuring lpac..."

if [ "$EUICC_OK" = "1" ]; then
    # AT driver works
    uci set lpac.device.driver='at'
    uci set lpac.device.at_device="$AT_PORT"
    uci commit lpac
    echo "  ✓ Configured for AT driver on $AT_PORT"
else
    # Try QMI driver
    if [ -e /dev/cdc-wdm0 ]; then
        echo "  ⚠ AT+CSIM not working, trying QMI driver..."
        uci set lpac.device.driver='qmi'
        uci set lpac.device.qmi_device='/dev/cdc-wdm0'
        uci commit lpac
        echo "  ✓ Configured for QMI driver on /dev/cdc-wdm0"
    else
        echo "  ⚠ Setting AT driver as default (may need manual configuration)"
        uci set lpac.device.driver='at'
        uci set lpac.device.at_device="$AT_PORT"
        uci commit lpac
    fi
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  Configuration Complete                          ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Test lpac
echo "Testing lpac..."
echo ""

if [ "$EUICC_OK" = "1" ]; then
    # Test with AT driver
    export LPAC_APDU=at
    export LPAC_APDU_AT_DEVICE="$AT_PORT"
    export LPAC_HTTP=curl

    echo "Running: lpac chip info"
    echo ""
    /usr/lib/lpac chip info 2>&1 | head -20
else
    echo "Skipping lpac test (eUICC not responding via AT commands)"
    echo ""
    echo "Try manually:"
    echo "  export LPAC_APDU=qmi"
    echo "  export LPAC_QMI_DEV=/dev/cdc-wdm0"
    echo "  /usr/lib/lpac chip info"
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo "Configuration saved to /etc/config/lpac"
echo ""
echo "Current settings:"
uci show lpac
echo ""
