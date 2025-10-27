# OpenWRT Button Configuration Guide

## Table of Contents
- [Overview](#overview)
- [What is Button Handling?](#what-is-button-handling)
- [Use Cases](#use-cases)
- [Prerequisites](#prerequisites)
- [Button Detection](#button-detection)
- [Hotplug System Overview](#hotplug-system-overview)
- [Configuration Methods](#configuration-methods)
- [Basic Script Method](#basic-script-method)
- [UCI Configuration Method](#uci-configuration-method)
- [Predefined Button Scripts](#predefined-button-scripts)
- [Advanced Button Functions](#advanced-button-functions)
- [Time-Based Actions](#time-based-actions)
- [Practical Examples](#practical-examples)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Real-World Scenarios](#real-world-scenarios)

## Overview

This comprehensive guide explains how to configure and customize physical button functionality on OpenWRT routers, enabling advanced automation, custom actions, and improved usability through GPIO-connected hardware buttons.

**What You'll Learn:**
- Detecting button names and identifiers
- Understanding the hotplug system
- Creating custom button handlers
- Configuring buttons via UCI
- Implementing time-based button actions
- Using predefined button scripts

**Key Benefits:**
- Customize router button behavior
- Add new functionality to existing buttons
- Create time-based actions (short press, long press)
- Automate common tasks
- Improve user experience

## What is Button Handling?

### Button Handling Basics

**Button handling** in OpenWRT allows you to define custom actions triggered by physical buttons on your router, such as WPS, reset, WiFi toggle, or custom GPIO buttons.

**How It Works:**
```
1. User presses physical button
2. GPIO pin state changes
3. Kernel detects button event
4. Hotplug system triggered
5. Button handler script executes
6. Custom action performed
```

**Components:**
- **Physical Button**: Hardware button connected to GPIO
- **GPIO Driver**: Kernel driver for button detection
- **Hotplug System**: Event dispatcher
- **Button Scripts**: Handler scripts in `/etc/hotplug.d/button/`
- **UCI Config**: Configuration in `/etc/config/system`

### Common Router Buttons

**Typical Router Buttons:**
- **Reset**: Factory reset, restart
- **WPS**: WiFi Protected Setup
- **WiFi/WLAN**: Toggle wireless on/off
- **Power**: Power on/off, sleep
- **Custom**: User-defined functions

**Button Actions:**
- **Pressed**: Button pushed down
- **Released**: Button released
- **Hold Duration**: Time button held (seconds)

## Use Cases

### 1. WiFi Toggle Button

**Scenario:** Quickly disable/enable WiFi without web interface

**Implementation:**
- Short press: Toggle WiFi on/off
- Visual feedback via LED

### 2. Safe USB Unmount

**Scenario:** Safely unmount USB drives before removal

**Implementation:**
- Press button to unmount all USB drives
- LED indicates safe to remove

### 3. Guest Network Toggle

**Scenario:** Enable guest WiFi when needed

**Implementation:**
- Short press: Enable guest network
- Long press: Disable guest network

### 4. VPN Toggle

**Scenario:** Quickly enable/disable VPN connection

**Implementation:**
- Press button to toggle VPN
- LED shows VPN status

### 5. Service Restart

**Scenario:** Restart specific services

**Implementation:**
- Short press: Restart network
- Long press: Restart router

## Prerequisites

### Hardware Requirements

**Router with Buttons:**
- Physical buttons (reset, WPS, custom)
- GPIO-connected buttons
- Button driver support in kernel

**Check Available Buttons:**
```bash
# List GPIO buttons
ls -l /sys/class/gpio/

# Check input devices
cat /proc/bus/input/devices

# View button events
cat /sys/class/input/event*/device/name
```

### Software Requirements

**OpenWRT Version:**
- Any version (8.09+)
- Barrier Breaker (14.07) or newer recommended

**Required Packages:**
```bash
# Usually pre-installed
# kmod-gpio-button-hotplug (check with opkg list-installed)

# Optional: for WPS functionality
opkg install hostapd-utils
```

### Knowledge Requirements

- SSH access to router
- Basic shell scripting
- Understanding of UCI configuration
- Familiarity with OpenWRT structure

## Button Detection

### Identify Button Names

**Create Detection Script:**

```bash
# Create hotplug directory if not exists
mkdir -p /etc/hotplug.d/button

# Create button detection script
cat > /etc/hotplug.d/button/99-button-detect <<'EOF'
#!/bin/sh
# Button detection script
logger -t button "BUTTON=$BUTTON ACTION=$ACTION SEEN=$SEEN"
EOF

# Make executable
chmod +x /etc/hotplug.d/button/99-button-detect
```

**Test Button Detection:**

```bash
# Monitor logs in real-time
logread -f | grep button

# Press buttons on router
# You should see output like:
# button: BUTTON=reset ACTION=pressed SEEN=0
# button: BUTTON=reset ACTION=released SEEN=2
# button: BUTTON=wps ACTION=pressed SEEN=0
# button: BUTTON=BTN_0 ACTION=pressed SEEN=0
```

**Common Button Names:**
- `reset` - Reset button
- `wps` - WPS button
- `rfkill` - WiFi toggle button
- `power` - Power button
- `BTN_0`, `BTN_1`, `BTN_2` - Generic buttons
- `wifi` - WiFi toggle
- `ses` - Secure Easy Setup (Linksys)

### Environment Variables

**Available Variables in Button Scripts:**

```bash
$BUTTON  # Button identifier (e.g., "reset", "wps", "BTN_0")
$ACTION  # Action type ("pressed" or "released")
$SEEN    # Seconds since last press (for hold detection)
```

**Example Usage:**
```bash
#!/bin/sh
echo "Button: $BUTTON" >> /tmp/button.log
echo "Action: $ACTION" >> /tmp/button.log
echo "Duration: $SEEN seconds" >> /tmp/button.log
```

### Button Event Flow

**Event Sequence:**
```
1. Button pressed
   → ACTION=pressed, SEEN=0

2. Button held
   → (no additional events while holding)

3. Button released
   → ACTION=released, SEEN=X (X = hold duration)
```

**Example Timeline:**
```
Time 0s:  User presses button
          → BUTTON=wps ACTION=pressed SEEN=0

Time 3s:  User releases button
          → BUTTON=wps ACTION=released SEEN=3
```

## Hotplug System Overview

### How Hotplug Works

**Hotplug Event Flow:**
```
Kernel Event
    ↓
/sbin/hotplug-call button
    ↓
Executes scripts in /etc/hotplug.d/button/
    ↓
Scripts run in numerical order (00-*, 01-*, etc.)
    ↓
Custom action performed
```

**Script Execution Order:**
```
/etc/hotplug.d/button/
├── 00-button (UCI config handler)
├── 10-custom
├── 20-wifi-toggle
└── 99-button-detect
```

Scripts execute in alphabetical/numerical order.

### Hotplug Script Location

**Button Scripts Directory:**
```bash
/etc/hotplug.d/button/
```

**Script Naming Convention:**
- `00-99`: Priority order (00 first, 99 last)
- Descriptive name: `00-button`, `10-wifi-toggle`
- Must be executable: `chmod +x script`

### Creating Hotplug Scripts

**Basic Script Template:**

```bash
#!/bin/sh
# /etc/hotplug.d/button/10-custom

# Check which button was pressed
if [ "$BUTTON" = "wps" ]; then
    # Check action type
    if [ "$ACTION" = "pressed" ]; then
        logger "WPS button pressed"
        # Perform action on press
    elif [ "$ACTION" = "released" ]; then
        logger "WPS button released after $SEEN seconds"
        # Perform action on release
    fi
fi
```

**Make Script Executable:**
```bash
chmod +x /etc/hotplug.d/button/10-custom
```

## Configuration Methods

### Method Comparison

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| Basic Script | Simple, direct control | Manual editing | Single actions |
| UCI Config | Structured, manageable | Requires UCI knowledge | Multiple buttons |
| Predefined Scripts | Ready-to-use | Less flexible | Standard functions |

## Basic Script Method

### Simple Button Script

**Create basic button handler:**

```bash
# Create script
cat > /etc/hotplug.d/button/00-button <<'EOF'
#!/bin/sh

# Handle button events
if [ "$ACTION" = "pressed" ]; then
    # Actions on button press
    case "$BUTTON" in
        BTN_0)
            logger "Button 0 pressed - Toggling WiFi"
            wifi toggle
            ;;
        BTN_1)
            logger "Button 1 pressed - Restarting network"
            /etc/init.d/network restart
            ;;
        wps)
            logger "WPS button pressed"
            # WPS action here
            ;;
        reset)
            # Handle reset button
            logger "Reset button pressed"
            ;;
    esac
fi

if [ "$ACTION" = "released" ]; then
    # Actions on button release
    case "$BUTTON" in
        reset)
            if [ "$SEEN" -gt 5 ]; then
                logger "Long press detected - Factory reset"
                firstboot -y && reboot
            else
                logger "Short press detected - Restart"
                reboot
            fi
            ;;
    esac
fi
EOF

chmod +x /etc/hotplug.d/button/00-button
```

### WiFi Toggle Example

**Complete WiFi toggle script:**

```bash
cat > /etc/hotplug.d/button/10-wifi-toggle <<'EOF'
#!/bin/sh

# Toggle WiFi on button press
if [ "$BUTTON" = "wps" ] && [ "$ACTION" = "pressed" ]; then
    # Check current WiFi status
    WIFI_STATUS=$(uci get wireless.radio0.disabled)

    if [ "$WIFI_STATUS" = "1" ]; then
        # WiFi is disabled, enable it
        logger "Enabling WiFi"
        uci set wireless.radio0.disabled=0
        uci set wireless.radio1.disabled=0 2>/dev/null
        uci commit wireless
        wifi up
    else
        # WiFi is enabled, disable it
        logger "Disabling WiFi"
        uci set wireless.radio0.disabled=1
        uci set wireless.radio1.disabled=1 2>/dev/null
        uci commit wireless
        wifi down
    fi
fi
EOF

chmod +x /etc/hotplug.d/button/10-wifi-toggle
```

### USB Unmount Example

**Safe USB unmount script:**

```bash
cat > /etc/hotplug.d/button/20-usb-unmount <<'EOF'
#!/bin/sh

# Unmount all USB drives on button press
if [ "$BUTTON" = "BTN_1" ] && [ "$ACTION" = "pressed" ]; then
    logger "Unmounting all USB drives"

    # Stop services using USB
    /etc/init.d/samba stop 2>/dev/null
    /etc/init.d/minidlna stop 2>/dev/null
    /etc/init.d/transmission stop 2>/dev/null

    # Unmount all /dev/sd* devices
    for device in $(mount | awk '/\/dev\/sd[a-z]/ { print $1 }'); do
        logger "Unmounting $device"
        umount "$device"
    done

    # Flash LED to indicate safe to remove
    echo 1 > /sys/class/leds/led_name/brightness
    sleep 1
    echo 0 > /sys/class/leds/led_name/brightness

    logger "USB drives unmounted - safe to remove"
fi
EOF

chmod +x /etc/hotplug.d/button/20-usb-unmount
```

## UCI Configuration Method

### Universal Button Handler

**Download UCI-based button handler:**

```bash
# Download universal handler (older versions)
wget -O /etc/hotplug.d/button/00-button \
http://dev.openwrt.org/export/21216/trunk/target/linux/atheros/base-files/etc/hotplug.d/button/00-button

# Make executable
chmod +x /etc/hotplug.d/button/00-button
```

**Or create manually:**

```bash
cat > /etc/hotplug.d/button/00-button <<'EOF'
#!/bin/sh

[ "$ACTION" = "released" ] || [ "$ACTION" = "pressed" ] || exit 0

. /lib/functions.sh

handle_button() {
    local button="$1"
    local action="$2"
    local handler="$3"
    local min="$4"
    local max="$5"

    [ "$button" = "$BUTTON" ] || return 0
    [ "$action" = "$ACTION" ] || return 0

    if [ -n "$min" ] || [ -n "$max" ]; then
        [ "$ACTION" = "released" ] || return 0
        [ -n "$min" ] && [ "$SEEN" -lt "$min" ] && return 0
        [ -n "$max" ] && [ "$SEEN" -gt "$max" ] && return 0
    fi

    logger "Executing button handler: $handler"
    eval "$handler"
}

config_load system
config_foreach handle_button button button action handler min max
EOF

chmod +x /etc/hotplug.d/button/00-button
```

### Configure Buttons via UCI

**Basic Button Configuration:**

```bash
# Add button configuration
uci add system button
uci set system.@button[-1].button='wps'
uci set system.@button[-1].action='pressed'
uci set system.@button[-1].handler='logger "WPS button pressed"'
uci commit system
```

**WiFi Toggle via UCI:**

```bash
uci add system button
uci set system.@button[-1].button='wps'
uci set system.@button[-1].action='pressed'
uci set system.@button[-1].handler='uci set wireless.radio0.disabled=$(uci get wireless.radio0.disabled | grep -q 1 && echo 0 || echo 1); uci commit wireless; wifi'
uci commit system
```

**Disable WiFi Example:**

```bash
uci add system button
uci set system.@button[-1].button='wps'
uci set system.@button[-1].action='pressed'
uci set system.@button[-1].handler='uci set wireless.@wifi-device[0].disabled=1 && wifi'
uci commit system
```

### Multiple Button Configurations

**Configure multiple buttons:**

```bash
# Button 1: WiFi toggle
uci add system button
uci set system.@button[-1].button='BTN_0'
uci set system.@button[-1].action='pressed'
uci set system.@button[-1].handler='wifi toggle'

# Button 2: Restart network
uci add system button
uci set system.@button[-1].button='BTN_1'
uci set system.@button[-1].action='pressed'
uci set system.@button[-1].handler='/etc/init.d/network restart'

# Button 3: Reboot (with time constraint)
uci add system button
uci set system.@button[-1].button='reset'
uci set system.@button[-1].action='released'
uci set system.@button[-1].handler='reboot'
uci set system.@button[-1].min='1'
uci set system.@button[-1].max='4'

# Button 4: Factory reset (long press)
uci add system button
uci set system.@button[-1].button='reset'
uci set system.@button[-1].action='released'
uci set system.@button[-1].handler='firstboot -y && reboot'
uci set system.@button[-1].min='5'

uci commit system
```

### UCI Configuration File

**Edit `/etc/config/system` directly:**

```bash
vi /etc/config/system
```

**Example configuration:**
```
config button
    option button 'wps'
    option action 'pressed'
    option handler 'wifi toggle'

config button
    option button 'reset'
    option action 'released'
    option handler 'reboot'
    option min '1'
    option max '4'

config button
    option button 'reset'
    option action 'released'
    option handler 'firstboot -y && reboot'
    option min '5'
```

## Predefined Button Scripts

### Barrier Breaker and Later

**Predefined Button Scripts Location:**
```
/etc/rc.button/
```

**Common Predefined Scripts:**

**Reset Button (`/etc/rc.button/reset`):**
```bash
#!/bin/sh

[ "${ACTION}" = "released" ] || exit 0

. /lib/functions.sh

logger "$BUTTON pressed for $SEEN seconds"

if [ "$SEEN" -lt 1 ]; then
    echo "REBOOT" > /dev/console
elif [ "$SEEN" -gt 5 ]; then
    echo "FACTORY RESET" > /dev/console
    firstboot && reboot &
fi
```

**Functionality:**
- Press < 1 second: Do nothing (bouncing protection)
- Press 1-5 seconds: Reboot
- Press > 5 seconds: Factory reset

**Power Button (`/etc/rc.button/power`):**
```bash
#!/bin/sh

[ "${ACTION}" = "released" ] || exit 0

logger "Power button - shutting down"
poweroff
```

**RF Kill Button (`/etc/rc.button/rfkill`):**
```bash
#!/bin/sh

[ "${ACTION}" = "pressed" ] || exit 0

. /lib/functions.sh

logger "RF kill button pressed"

wifi toggle
```

### Creating Custom Predefined Scripts

**Custom Script Example:**

```bash
# Create custom button script
cat > /etc/rc.button/custom <<'EOF'
#!/bin/sh

[ "${ACTION}" = "pressed" ] || exit 0

logger "Custom button action"

# Your custom action here
# Example: Toggle guest network
GUEST_STATUS=$(uci get wireless.guest_radio0.disabled)
if [ "$GUEST_STATUS" = "1" ]; then
    uci set wireless.guest_radio0.disabled=0
else
    uci set wireless.guest_radio0.disabled=1
fi
uci commit wireless
wifi
EOF

chmod +x /etc/rc.button/custom
```

### Symlinking Buttons

**Reuse Existing Scripts:**

```bash
# Make WPS button act as rfkill (WiFi toggle)
ln -s /etc/rc.button/rfkill /etc/rc.button/wps

# Make custom button act as reset
ln -s /etc/rc.button/reset /etc/rc.button/BTN_0
```

**Verify Symlinks:**
```bash
ls -la /etc/rc.button/
```

## Advanced Button Functions

### LED Feedback

**Provide visual feedback when button pressed:**

```bash
cat > /etc/hotplug.d/button/30-led-feedback <<'EOF'
#!/bin/sh

if [ "$BUTTON" = "wps" ] && [ "$ACTION" = "pressed" ]; then
    # Flash LED 3 times
    for i in 1 2 3; do
        echo 1 > /sys/class/leds/system/brightness
        sleep 0.2
        echo 0 > /sys/class/leds/system/brightness
        sleep 0.2
    done

    # Perform actual action
    wifi toggle
fi
EOF

chmod +x /etc/hotplug.d/button/30-led-feedback
```

**Find LED Names:**
```bash
ls /sys/class/leds/
```

### Button State Toggle

**Toggle between states:**

```bash
cat > /etc/hotplug.d/button/40-vpn-toggle <<'EOF'
#!/bin/sh

STATE_FILE="/tmp/vpn_state"

if [ "$BUTTON" = "BTN_1" ] && [ "$ACTION" = "pressed" ]; then
    # Check current state
    if [ -f "$STATE_FILE" ] && [ "$(cat $STATE_FILE)" = "enabled" ]; then
        # Disable VPN
        logger "Disabling VPN"
        /etc/init.d/openvpn stop
        echo "disabled" > "$STATE_FILE"
        # LED off
        echo 0 > /sys/class/leds/vpn/brightness
    else
        # Enable VPN
        logger "Enabling VPN"
        /etc/init.d/openvpn start
        echo "enabled" > "$STATE_FILE"
        # LED on
        echo 1 > /sys/class/leds/vpn/brightness
    fi
fi
EOF

chmod +x /etc/hotplug.d/button/40-vpn-toggle
```

### Multi-Function Button

**Different actions based on press duration:**

```bash
cat > /etc/hotplug.d/button/50-multi-function <<'EOF'
#!/bin/sh

if [ "$BUTTON" = "wps" ] && [ "$ACTION" = "released" ]; then
    if [ "$SEEN" -lt 2 ]; then
        # Short press: Toggle WiFi
        logger "Short press: Toggle WiFi"
        wifi toggle
    elif [ "$SEEN" -lt 5 ]; then
        # Medium press: Restart network
        logger "Medium press: Restart network"
        /etc/init.d/network restart
    else
        # Long press: Reboot
        logger "Long press: Reboot"
        reboot
    fi
fi
EOF

chmod +x /etc/hotplug.d/button/50-multi-function
```

## Time-Based Actions

### Hold Duration Detection

**Configure time-based actions via UCI:**

```bash
# Short press (0-2 seconds): WiFi toggle
uci add system button
uci set system.@button[-1].button='wps'
uci set system.@button[-1].action='released'
uci set system.@button[-1].handler='wifi toggle'
uci set system.@button[-1].min='0'
uci set system.@button[-1].max='2'

# Medium press (3-5 seconds): Restart network
uci add system button
uci set system.@button[-1].button='wps'
uci set system.@button[-1].action='released'
uci set system.@button[-1].handler='/etc/init.d/network restart'
uci set system.@button[-1].min='3'
uci set system.@button[-1].max='5'

# Long press (6+ seconds): Reboot
uci add system button
uci set system.@button[-1].button='wps'
uci set system.@button[-1].action='released'
uci set system.@button[-1].handler='reboot'
uci set system.@button[-1].min='6'

uci commit system
```

### USB Safe Unmount with Duration

**Unmount USB on 5-10 second hold:**

```bash
uci add system button
uci set system.@button[-1].button='BTN_1'
uci set system.@button[-1].action='released'
uci set system.@button[-1].handler='for i in $(mount | awk "/dev\/sd[a-z]/ { print \$1}"); do umount $i; done'
uci set system.@button[-1].min='5'
uci set system.@button[-1].max='10'
uci commit system
```

### Progressive Actions

**Different actions at different time intervals:**

```bash
cat > /etc/hotplug.d/button/60-progressive <<'EOF'
#!/bin/sh

if [ "$BUTTON" = "reset" ] && [ "$ACTION" = "released" ]; then
    case "$SEEN" in
        [0-1])
            # < 1 second: Ignore (debounce)
            ;;
        [2-3])
            # 2-3 seconds: Restart services
            logger "Restarting network services"
            /etc/init.d/network restart
            ;;
        [4-5])
            # 4-5 seconds: Reboot
            logger "Rebooting"
            reboot
            ;;
        *)
            # 6+ seconds: Factory reset
            if [ "$SEEN" -ge 6 ]; then
                logger "Factory reset"
                firstboot -y && reboot
            fi
            ;;
    esac
fi
EOF

chmod +x /etc/hotplug.d/button/60-progressive
```

## Practical Examples

### Example 1: Guest Network Toggle

**Enable/disable guest WiFi with button:**

```bash
cat > /etc/hotplug.d/button/guest-toggle <<'EOF'
#!/bin/sh

if [ "$BUTTON" = "wps" ] && [ "$ACTION" = "pressed" ]; then
    GUEST_STATUS=$(uci get wireless.guest_radio0.disabled 2>/dev/null)

    if [ "$GUEST_STATUS" = "1" ] || [ -z "$GUEST_STATUS" ]; then
        # Enable guest network
        logger "Enabling guest network"
        uci set wireless.guest_radio0.disabled=0
        uci commit wireless
        wifi
        # LED on
        echo 1 > /sys/class/leds/wlan/brightness
    else
        # Disable guest network
        logger "Disabling guest network"
        uci set wireless.guest_radio0.disabled=1
        uci commit wireless
        wifi
        # LED off
        echo 0 > /sys/class/leds/wlan/brightness
    fi
fi
EOF

chmod +x /etc/hotplug.d/button/guest-toggle
```

### Example 2: Bandwidth Limit Toggle

**Toggle SQM bandwidth limiting:**

```bash
cat > /etc/hotplug.d/button/sqm-toggle <<'EOF'
#!/bin/sh

if [ "$BUTTON" = "BTN_0" ] && [ "$ACTION" = "pressed" ]; then
    SQM_STATUS=$(uci get sqm.@queue[0].enabled)

    if [ "$SQM_STATUS" = "1" ]; then
        # Disable SQM (full speed)
        logger "Disabling SQM - Full speed mode"
        uci set sqm.@queue[0].enabled=0
        uci commit sqm
        /etc/init.d/sqm restart
    else
        # Enable SQM (limited speed)
        logger "Enabling SQM - Limited speed mode"
        uci set sqm.@queue[0].enabled=1
        uci commit sqm
        /etc/init.d/sqm restart
    fi
fi
EOF

chmod +x /etc/hotplug.d/button/sqm-toggle
```

### Example 3: Screenshot/Log Capture

**Capture network statistics on button press:**

```bash
cat > /etc/hotplug.d/button/stats-capture <<'EOF'
#!/bin/sh

if [ "$BUTTON" = "BTN_1" ] && [ "$ACTION" = "pressed" ]; then
    TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
    LOG_FILE="/tmp/stats-$TIMESTAMP.txt"

    logger "Capturing network statistics"

    {
        echo "=== Network Statistics $TIMESTAMP ==="
        echo ""
        echo "=== Interface Status ==="
        ifconfig
        echo ""
        echo "=== Routing Table ==="
        route -n
        echo ""
        echo "=== Active Connections ==="
        netstat -tuln
        echo ""
        echo "=== Wireless Status ==="
        iw dev
        echo ""
        echo "=== DHCP Leases ==="
        cat /tmp/dhcp.leases
    } > "$LOG_FILE"

    logger "Statistics saved to $LOG_FILE"

    # Optional: Copy to USB drive
    if [ -d "/mnt/usb" ]; then
        cp "$LOG_FILE" /mnt/usb/
        logger "Statistics copied to USB"
    fi
fi
EOF

chmod +x /etc/hotplug.d/button/stats-capture
```

### Example 4: Emergency Mode

**Enable emergency fallback configuration:**

```bash
cat > /etc/hotplug.d/button/emergency-mode <<'EOF'
#!/bin/sh

if [ "$BUTTON" = "reset" ] && [ "$ACTION" = "released" ] && [ "$SEEN" -ge 10 ]; then
    logger "EMERGENCY MODE ACTIVATED"

    # Disable WiFi encryption
    uci set wireless.@wifi-iface[0].encryption='none'

    # Set known IP
    uci set network.lan.ipaddr='192.168.1.1'

    # Enable DHCP
    uci set dhcp.lan.ignore='0'

    # Disable firewall
    /etc/init.d/firewall stop

    # Apply changes
    uci commit
    /etc/init.d/network restart
    wifi

    logger "Emergency mode: WiFi open, IP 192.168.1.1, Firewall disabled"
fi
EOF

chmod +x /etc/hotplug.d/button/emergency-mode
```

## Troubleshooting

### Button Not Responding

**Diagnosis:**

```bash
# Check if button detected
cat /proc/bus/input/devices | grep -A 5 Button

# Check GPIO
ls -l /sys/class/gpio/

# Monitor button events
logread -f | grep button

# Test hotplug manually
BUTTON=wps ACTION=pressed /sbin/hotplug-call button
```

**Solutions:**

```bash
# Reload GPIO modules
rmmod gpio-button-hotplug
insmod gpio-button-hotplug

# Check script permissions
chmod +x /etc/hotplug.d/button/*

# Verify script syntax
sh -n /etc/hotplug.d/button/00-button

# Reload UCI config
uci commit system
```

### Script Not Executing

**Diagnosis:**

```bash
# Check script exists
ls -la /etc/hotplug.d/button/

# Verify executable
file /etc/hotplug.d/button/00-button

# Test script manually
sh /etc/hotplug.d/button/00-button

# Check logs for errors
logread | grep -i error
```

**Solutions:**

```bash
# Fix permissions
chmod +x /etc/hotplug.d/button/00-button

# Fix shebang
# Ensure first line is: #!/bin/sh

# Check for syntax errors
sh -n /etc/hotplug.d/button/00-button

# Simplify script for testing
```

### UCI Configuration Not Working

**Diagnosis:**

```bash
# Verify UCI config
uci show system | grep button

# Check handler script exists
ls -l /etc/hotplug.d/button/00-button

# Test UCI handler manually
. /lib/functions.sh
config_load system
```

**Solutions:**

```bash
# Ensure UCI handler installed
# Download or create 00-button script

# Verify config syntax
uci show system

# Reload config
uci commit system
/etc/init.d/system reload
```

### Button Bouncing (Multiple Triggers)

**Problem:** Button triggers multiple times on single press

**Solution:**

```bash
# Add debounce delay
cat > /etc/hotplug.d/button/00-debounce <<'EOF'
#!/bin/sh

LOCK_FILE="/tmp/button_${BUTTON}.lock"

# Check if already processing
if [ -f "$LOCK_FILE" ]; then
    exit 0
fi

# Create lock
touch "$LOCK_FILE"

# Your button action here
if [ "$BUTTON" = "wps" ] && [ "$ACTION" = "pressed" ]; then
    wifi toggle
fi

# Remove lock after delay
( sleep 2; rm -f "$LOCK_FILE" ) &
EOF

chmod +x /etc/hotplug.d/button/00-debounce
```

## Best Practices

### Script Organization

**Recommended Structure:**

```
/etc/hotplug.d/button/
├── 00-button          # UCI handler (if used)
├── 10-wifi-toggle     # WiFi control
├── 20-usb-unmount     # USB management
├── 30-guest-network   # Guest network
├── 40-vpn-toggle      # VPN control
└── 99-button-detect   # Debug logging
```

### Naming Conventions

- Use descriptive names
- Number by priority (00-99)
- One function per script
- Comment your code

### Safety Considerations

**Important:**
- Always test in safe environment
- Avoid destructive commands without confirmation
- Use time constraints for critical actions (reset, factory restore)
- Provide LED feedback for user confirmation
- Log all button actions

### Performance

**Optimize Scripts:**
- Keep scripts short and fast
- Avoid heavy operations on "pressed" (user waiting)
- Use background processes for slow tasks
- Clean up temporary files

**Example:**
```bash
# Good: Fast response
if [ "$ACTION" = "pressed" ]; then
    wifi toggle &  # Background
fi

# Avoid: Slow response
if [ "$ACTION" = "pressed" ]; then
    apt-get update  # Takes too long
fi
```

### Documentation

**Document Your Buttons:**

```bash
# Create README
cat > /etc/hotplug.d/button/README <<'EOF'
Button Configuration:

WPS Button:
- Short press (< 2s): Toggle WiFi
- Medium press (3-5s): Restart network
- Long press (> 5s): Reboot

Reset Button:
- Short press (1-4s): Reboot
- Long press (> 5s): Factory reset

BTN_0:
- Press: Toggle guest network

BTN_1:
- Hold 5-10s: Safe unmount USB
EOF
```

## Real-World Scenarios

### Scenario 1: Home Router

**Setup:**
- WPS button: Toggle guest WiFi
- Reset button: Standard (reboot/factory reset)

```bash
# Guest WiFi toggle
cat > /etc/hotplug.d/button/guest <<'EOF'
#!/bin/sh
[ "$BUTTON" = "wps" ] && [ "$ACTION" = "pressed" ] || exit 0
uci set wireless.guest_radio0.disabled=$( \
    [ "$(uci get wireless.guest_radio0.disabled)" = "1" ] && echo 0 || echo 1)
uci commit wireless && wifi
EOF
chmod +x /etc/hotplug.d/button/guest
```

### Scenario 2: Small Office

**Setup:**
- WPS: Toggle VPN
- Custom button: Restart network services
- Reset: Standard

```bash
# VPN toggle
cat > /etc/hotplug.d/button/vpn <<'EOF'
#!/bin/sh
[ "$BUTTON" = "wps" ] && [ "$ACTION" = "pressed" ] || exit 0
/etc/init.d/openvpn status && /etc/init.d/openvpn stop || /etc/init.d/openvpn start
EOF
chmod +x /etc/hotplug.d/button/vpn
```

### Scenario 3: Media Server

**Setup:**
- Button: Safe unmount USB media drives
- Reset: Standard

```bash
# Safe unmount
cat > /etc/hotplug.d/button/media-unmount <<'EOF'
#!/bin/sh
[ "$BUTTON" = "BTN_0" ] && [ "$ACTION" = "released" ] && [ "$SEEN" -ge 3 ] || exit 0
/etc/init.d/minidlna stop
for d in $(mount | awk '/\/dev\/sd/ {print $1}'); do umount $d; done
logger "Media drives unmounted - safe to remove"
EOF
chmod +x /etc/hotplug.d/button/media-unmount
```

## Conclusion

Button configuration in OpenWRT provides powerful customization options, enabling advanced automation and improved usability through physical button controls.

**Key Takeaways:**

✅ **Detection:**
- Use hotplug logging to identify button names
- Environment variables: $BUTTON, $ACTION, $SEEN
- Test buttons with logread -f

🔧 **Configuration:**
- Basic scripts: Direct control in /etc/hotplug.d/button/
- UCI method: Structured configuration in /etc/config/system
- Predefined scripts: Ready-to-use in /etc/rc.button/

⏱️ **Time-Based:**
- Use $SEEN for hold duration detection
- Configure min/max times in UCI
- Implement progressive actions

📊 **Best Practices:**
- Number scripts by priority (00-99)
- Provide LED feedback
- Add debouncing for reliability
- Document button functions
- Test thoroughly

**Common Use Cases:**
- WiFi toggle
- Guest network control
- USB safe unmount
- VPN toggle
- Emergency fallback mode

For more information:
- OpenWRT Button Docs: https://openwrt.org/docs/guide-user/hardware/hardware.button
- Hotplug System: https://openwrt.org/docs/guide-user/base-system/hotplug
- UCI Configuration: https://openwrt.org/docs/guide-user/base-system/uci

---

**Document Version:** 1.0
**Last Updated:** Based on OpenWRT 8.09+
**Tested Platforms:** Various OpenWRT routers with GPIO buttons
