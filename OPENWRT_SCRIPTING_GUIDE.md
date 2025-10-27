# OpenWrt Scripting Guide

Comprehensive guide for creating and managing custom scripts on OpenWrt routers, including automation, event handling, and system control.

**Based on:** https://eko.one.pl/?p=openwrt-skrypty
**Target Audience:** System administrators, developers, advanced OpenWrt users
**OpenWrt Versions:** Compatible with OpenWrt 15.05 through current releases

---

## Table of Contents

1. [Introduction](#introduction)
2. [Shell Scripting Basics](#shell-scripting-basics)
3. [Script Locations](#script-locations)
4. [Startup Scripts](#startup-scripts)
5. [Hotplug Scripts](#hotplug-scripts)
6. [Cron Jobs](#cron-jobs)
7. [Practical Script Examples](#practical-script-examples)
8. [UCI Integration](#uci-integration)
9. [Init Scripts](#init-scripts)
10. [Debugging Scripts](#debugging-scripts)
11. [Best Practices](#best-practices)

---

## Introduction

### What are OpenWrt Scripts?

OpenWrt scripts are shell scripts that automate tasks, respond to system events, and customize router behavior. They can:

- Toggle WiFi on/off with button presses
- Monitor internet connectivity and auto-restart connections
- Automatically mount USB drives and start services
- Schedule tasks (enable/disable features at specific times)
- Respond to hardware events (button presses, USB insertion)
- Control LEDs, network interfaces, and services

### Script Types

| Type | Purpose | Location | Execution |
|------|---------|----------|-----------|
| **Startup Scripts** | Run at boot | `/etc/rc.local` | Once at boot |
| **Init Scripts** | Service management | `/etc/init.d/` | Via service commands |
| **Hotplug Scripts** | Event handlers | `/etc/hotplug.d/` | On hardware events |
| **Cron Jobs** | Scheduled tasks | `/etc/crontabs/root` | At scheduled times |
| **Custom Scripts** | General automation | `/usr/bin/`, `/root/` | Manually or called by other scripts |

---

## Shell Scripting Basics

### Basic Script Structure

```bash
#!/bin/sh
# Description: This script does something useful

# Variables
VAR1="value"
VAR2=123

# Commands
echo "Script starting..."

# Conditional logic
if [ "$VAR1" = "value" ]; then
    echo "Condition met"
fi

# Exit with status
exit 0
```

### Important Notes for OpenWrt

1. **Use `/bin/sh`, not `/bin/bash`** - OpenWrt uses BusyBox ash, not bash
2. **Keep scripts simple** - Limited resources, avoid complex operations
3. **Always test** - Errors can make router inaccessible
4. **Make executable** - `chmod +x /path/to/script.sh`
5. **Use absolute paths** - Don't rely on `$PATH` in automated scripts

### Common OpenWrt Commands in Scripts

```bash
# UCI configuration
uci get network.lan.ipaddr
uci set wireless.radio0.disabled=1
uci commit wireless

# Network control
ifup wan
ifdown wan
wifi up
wifi down

# Service management
/etc/init.d/dnsmasq restart
/etc/init.d/firewall reload

# System info
cat /proc/uptime
cat /proc/meminfo
df -h

# LED control
echo 1 > /sys/class/leds/led-name/brightness
echo timer > /sys/class/leds/led-name/trigger
```

### BusyBox Limitations

OpenWrt uses BusyBox, a lightweight version of standard Linux utilities. Some features are limited:

**Not available or limited:**
- Bash-specific syntax (`[[`, `{1..10}`, `**` glob)
- Advanced `sed`/`awk` features
- Some `find` options

**Use instead:**
- POSIX shell syntax (`[`, `seq`, explicit loops)
- Simple `sed`/`awk` patterns
- BusyBox-compatible options

---

## Script Locations

### Directory Structure

```
/etc/
├── rc.local                    # Startup script (runs at boot)
├── rc.button/                  # Legacy button scripts
├── hotplug.d/                  # Hotplug event handlers
│   ├── button/                 # Button press events
│   │   └── 01-wifitoggle       # WiFi toggle script
│   ├── block/                  # Storage device events
│   │   └── 99-mount            # Auto-mount script
│   ├── iface/                  # Network interface events
│   ├── net/                    # Network events
│   └── usb/                    # USB device events
├── init.d/                     # Service init scripts
│   ├── network
│   ├── dnsmasq
│   └── custom_service
├── crontabs/
│   └── root                    # Cron jobs for root user
└── config/                     # UCI configuration files

/usr/bin/                       # Custom executable scripts
/root/                          # User scripts
```

### File Naming Conventions

**Hotplug scripts:** Use numeric prefixes to control execution order
- `01-first-script` runs before `99-last-script`
- Common prefixes: `10-`, `20-`, `90-`, `99-`

**Init scripts:** No extension, must be executable
- Named after the service (e.g., `transmission`, `minidlna`)

**Cron scripts:** Can be anywhere, referenced by full path

---

## Startup Scripts

### `/etc/rc.local`

This file runs **once during boot** after all system services start. Use it for:
- Starting custom services
- Initializing hardware
- One-time configuration tasks

**Important:** Must end with `exit 0`

### Basic Example

```bash
#!/bin/sh
# /etc/rc.local - Custom startup tasks

# Log startup time
echo "System started at $(date)" >> /tmp/startup.log

# Set LED to indicate boot complete
echo 1 > /sys/class/leds/green:status/brightness

# Start custom service
/etc/init.d/my_service start

# Must end with exit 0
exit 0
```

### Delayed Execution

Some services need time to initialize before starting dependent tasks:

```bash
#!/bin/sh
# /etc/rc.local

# Start transmission after 20 seconds (wait for USB mount)
(sleep 20; /etc/init.d/transmission start) &

# Start multiple delayed tasks
(
    sleep 30
    /usr/bin/my_script.sh
    /etc/init.d/minidlna start
) &

exit 0
```

**Explanation:**
- `(...)` creates a subshell
- `&` runs in background (doesn't block boot)
- `sleep 20` waits 20 seconds before executing commands

### Conditional Startup

```bash
#!/bin/sh
# /etc/rc.local

# Only start service if USB drive is mounted
if grep -q "/mnt/usb" /proc/mounts; then
    /etc/init.d/transmission start
fi

# Only enable WiFi during daytime hours
HOUR=$(date +%H)
if [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 23 ]; then
    wifi up
else
    wifi down
fi

exit 0
```

### Make rc.local Executable

```bash
chmod +x /etc/rc.local
```

### Test rc.local Without Rebooting

```bash
/etc/rc.local
```

---

## Hotplug Scripts

### What are Hotplug Scripts?

Hotplug scripts **respond to hardware events** in real-time:
- Button presses (WPS, reset, custom buttons)
- USB device insertion/removal
- Network interface up/down
- Storage device mount/unmount

### Hotplug Environment Variables

Scripts receive event information via environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `$ACTION` | Event type | `add`, `remove`, `pressed`, `released` |
| `$BUTTON` | Button name | `reset`, `wps`, `BTN_0` |
| `$DEVICENAME` | Device path | `sda1`, `sdb` |
| `$INTERFACE` | Network interface | `wlan0`, `eth0`, `br-lan` |
| `$SUBSYSTEM` | Event subsystem | `button`, `usb`, `block` |

### Button Hotplug Scripts

**Location:** `/etc/hotplug.d/button/`

#### WiFi Toggle Button

```bash
#!/bin/sh
# /etc/hotplug.d/button/01-wifitoggle
# Toggle WiFi on/off when WPS button is pressed

[ "$BUTTON" = "wps" ] || exit 0
[ "$ACTION" = "pressed" ] || exit 0

# Get current WiFi state
WIFI_STATUS=$(uci get wireless.radio0.disabled)

if [ "$WIFI_STATUS" = "1" ]; then
    # WiFi is disabled, enable it
    uci set wireless.radio0.disabled=0
    uci commit wireless
    wifi up
    logger -t wifi-toggle "WiFi enabled via button"
else
    # WiFi is enabled, disable it
    uci set wireless.radio0.disabled=1
    uci commit wireless
    wifi down
    logger -t wifi-toggle "WiFi disabled via button"
fi

exit 0
```

**Make it executable:**
```bash
chmod +x /etc/hotplug.d/button/01-wifitoggle
```

#### WAN Connection Toggle Button

```bash
#!/bin/sh
# /etc/hotplug.d/button/02-wan-toggle
# Toggle WAN connection with reset button (short press)

[ "$BUTTON" = "reset" ] || exit 0
[ "$ACTION" = "pressed" ] || exit 0

# Check if WAN is up
if ifstatus wan | grep -q '"up": true'; then
    # WAN is up, bring it down
    ifdown wan
    logger -t wan-toggle "WAN connection disabled via button"
    # Blink LED to indicate disconnection
    echo timer > /sys/class/leds/wan:green/trigger
else
    # WAN is down, bring it up
    ifup wan
    logger -t wan-toggle "WAN connection enabled via button"
    # Set LED to solid
    echo default-on > /sys/class/leds/wan:green/trigger
fi

exit 0
```

#### Reset Button with Timer (Factory Reset Prevention)

```bash
#!/bin/sh
# /etc/hotplug.d/button/03-safe-reset
# Require 10-second press for factory reset

[ "$BUTTON" = "reset" ] || exit 0

if [ "$ACTION" = "pressed" ]; then
    # Start timer
    echo $$ > /tmp/reset_timer.pid
    (
        sleep 10
        # If we reach here, button was held for 10 seconds
        logger -t safe-reset "Factory reset initiated"
        jffs2reset -y && reboot
    ) &
elif [ "$ACTION" = "released" ]; then
    # Cancel factory reset if released early
    if [ -f /tmp/reset_timer.pid ]; then
        kill $(cat /tmp/reset_timer.pid) 2>/dev/null
        rm /tmp/reset_timer.pid
        logger -t safe-reset "Factory reset cancelled (released too early)"
    fi
fi

exit 0
```

### Block Device Hotplug Scripts

**Location:** `/etc/hotplug.d/block/`

#### Auto-Mount USB Drive

```bash
#!/bin/sh
# /etc/hotplug.d/block/10-mount
# Automatically mount USB drives to /mnt/usb

[ "$ACTION" = "add" ] || exit 0
[ -n "$DEVICENAME" ] || exit 0

# Only handle partitions (sda1, sdb1), not whole disks (sda, sdb)
case "$DEVICENAME" in
    *[0-9]) ;;
    *) exit 0 ;;
esac

# Create mount point
MOUNT_POINT="/mnt/$DEVICENAME"
mkdir -p "$MOUNT_POINT"

# Attempt to mount
mount "/dev/$DEVICENAME" "$MOUNT_POINT"

if [ $? -eq 0 ]; then
    logger -t automount "Mounted /dev/$DEVICENAME to $MOUNT_POINT"
else
    logger -t automount "Failed to mount /dev/$DEVICENAME"
    rmdir "$MOUNT_POINT"
fi

exit 0
```

#### Auto-Start Service on USB Mount

```bash
#!/bin/sh
# /etc/hotplug.d/block/99-start-services
# Start transmission when USB drive is mounted

[ "$ACTION" = "add" ] || exit 0

# Wait for mount to complete
sleep 2

# Check if our USB partition is mounted
if grep -q "/mnt/usb" /proc/mounts; then
    # Start transmission with download directory on USB
    /etc/init.d/transmission start
    logger -t usb-services "Started transmission (USB mounted)"

    # Also start minidlna media server
    /etc/init.d/minidlna start
    logger -t usb-services "Started minidlna (USB mounted)"
fi

exit 0
```

#### Auto-Unmount and Stop Services

```bash
#!/bin/sh
# /etc/hotplug.d/block/99-stop-services
# Stop services and unmount when USB is removed

[ "$ACTION" = "remove" ] || exit 0
[ -n "$DEVICENAME" ] || exit 0

# Stop services that use USB storage
if [ -f /var/run/transmission.pid ]; then
    /etc/init.d/transmission stop
    logger -t usb-services "Stopped transmission (USB removed)"
fi

if [ -f /var/run/minidlna.pid ]; then
    /etc/init.d/minidlna stop
    logger -t usb-services "Stopped minidlna (USB removed)"
fi

# Unmount
MOUNT_POINT="/mnt/$DEVICENAME"
if grep -q "$MOUNT_POINT" /proc/mounts; then
    umount "$MOUNT_POINT"
    rmdir "$MOUNT_POINT"
    logger -t automount "Unmounted $MOUNT_POINT"
fi

exit 0
```

### Network Interface Hotplug Scripts

**Location:** `/etc/hotplug.d/iface/`

#### Update DNS on WAN Connect

```bash
#!/bin/sh
# /etc/hotplug.d/iface/99-update-dns
# Update external services when WAN IP changes

[ "$ACTION" = "ifup" ] || exit 0
[ "$INTERFACE" = "wan" ] || exit 0

# Wait for interface to fully initialize
sleep 5

# Get new WAN IP
WAN_IP=$(ifstatus wan | jsonfilter -e '@["ipv4-address"][0].address')

logger -t wan-update "WAN IP changed to $WAN_IP"

# Update Dynamic DNS
/usr/sbin/ddns-update.sh

exit 0
```

### USB Device Hotplug Scripts

**Location:** `/etc/hotplug.d/usb/`

#### Log USB Device Events

```bash
#!/bin/sh
# /etc/hotplug.d/usb/99-log-usb
# Log all USB device connections

if [ "$ACTION" = "add" ]; then
    logger -t usb-monitor "USB device connected: $DEVICENAME"
elif [ "$ACTION" = "remove" ]; then
    logger -t usb-monitor "USB device disconnected: $DEVICENAME"
fi

exit 0
```

---

## Cron Jobs

### What is Cron?

Cron executes commands at scheduled times. Use for:
- Periodic monitoring tasks
- Scheduled WiFi on/off
- Automated backups
- Log rotation
- Connection health checks

### Cron File Location

`/etc/crontabs/root`

### Cron Syntax

```
# ┌───────────── minute (0 - 59)
# │ ┌───────────── hour (0 - 23)
# │ │ ┌───────────── day of month (1 - 31)
# │ │ │ ┌───────────── month (1 - 12)
# │ │ │ │ ┌───────────── day of week (0 - 6, Sunday = 0)
# │ │ │ │ │
# * * * * * command to execute
```

### Common Cron Patterns

```bash
# Every minute
* * * * * /usr/bin/script.sh

# Every 5 minutes
*/5 * * * * /usr/bin/script.sh

# Every 10 minutes
*/10 * * * * /usr/bin/script.sh

# Every hour at minute 0
0 * * * * /usr/bin/script.sh

# Every day at 2:30 AM
30 2 * * * /usr/bin/script.sh

# Every Sunday at midnight
0 0 * * 0 /usr/bin/script.sh

# Weekdays at 6:00 AM
0 6 * * 1-5 /usr/bin/script.sh

# First day of every month at noon
0 12 1 * * /usr/bin/script.sh
```

### Scheduled WiFi Control

**Disable WiFi at night, enable in morning:**

```bash
# /etc/crontabs/root

# Disable WiFi at 23:00 (11 PM)
0 23 * * * wifi down

# Enable WiFi at 07:00 (7 AM)
0 7 * * * wifi up
```

**Using UCI (survives reboot):**

```bash
# /etc/crontabs/root

# Disable WiFi at 23:00
0 23 * * * uci set wireless.radio0.disabled=1; uci commit wireless; wifi down

# Enable WiFi at 07:00
0 7 * * * uci set wireless.radio0.disabled=0; uci commit wireless; wifi up
```

### Internet Connection Monitor

**Ping test and restart WAN if down:**

```bash
#!/bin/sh
# /usr/bin/wan-monitor.sh
# Check internet connectivity and restart WAN if unreachable

# Ping Google DNS
if ! ping -c 3 -W 5 8.8.8.8 > /dev/null 2>&1; then
    logger -t wan-monitor "Internet unreachable, restarting WAN"

    # Restart WAN interface
    ifdown wan
    sleep 5
    ifup wan

    # Log new IP after restart
    sleep 10
    NEW_IP=$(ifstatus wan | jsonfilter -e '@["ipv4-address"][0].address')
    logger -t wan-monitor "WAN restarted with IP: $NEW_IP"
else
    logger -t wan-monitor "Internet connection OK"
fi

exit 0
```

**Make executable:**
```bash
chmod +x /usr/bin/wan-monitor.sh
```

**Add to cron (check every 10 minutes):**
```bash
# /etc/crontabs/root
*/10 * * * * /usr/bin/wan-monitor.sh
```

### Automatic Reboot Schedule

```bash
# /etc/crontabs/root

# Reboot every night at 4:00 AM
0 4 * * * /sbin/reboot

# Reboot every Sunday at 3:00 AM
0 3 * * 0 /sbin/reboot
```

### Backup Configuration Daily

```bash
# /etc/crontabs/root

# Backup config to USB drive every day at 2:00 AM
0 2 * * * sysupgrade -b /mnt/usb/backup-$(date +\%Y\%m\%d).tar.gz
```

**Note:** Escape `%` with `\` in cron entries.

### Clear Logs Weekly

```bash
# /etc/crontabs/root

# Clear system logs every Sunday at midnight
0 0 * * 0 logread -f > /dev/null && echo > /var/log/messages
```

### Edit Cron Jobs

```bash
# Edit cron file
vi /etc/crontabs/root

# Restart cron service
/etc/init.d/cron restart

# Check if cron is running
/etc/init.d/cron status

# View cron logs
logread | grep cron
```

---

## Practical Script Examples

### 1. WiFi Toggle Script (Standalone)

```bash
#!/bin/sh
# /usr/bin/wifi-toggle.sh
# Toggle WiFi on/off manually or via button

WIFI_STATUS=$(uci get wireless.radio0.disabled)

if [ "$WIFI_STATUS" = "1" ]; then
    echo "Enabling WiFi..."
    uci set wireless.radio0.disabled=0
    uci commit wireless
    wifi up
    echo "WiFi enabled"
else
    echo "Disabling WiFi..."
    uci set wireless.radio0.disabled=1
    uci commit wireless
    wifi down
    echo "WiFi disabled"
fi
```

**Usage:**
```bash
/usr/bin/wifi-toggle.sh
```

### 2. WAN Connection Controller

```bash
#!/bin/sh
# /usr/bin/wan-control.sh <up|down|toggle|status>

case "$1" in
    up)
        echo "Bringing WAN up..."
        ifup wan
        ;;
    down)
        echo "Bringing WAN down..."
        ifdown wan
        ;;
    toggle)
        if ifstatus wan | grep -q '"up": true'; then
            echo "WAN is up, bringing down..."
            ifdown wan
        else
            echo "WAN is down, bringing up..."
            ifup wan
        fi
        ;;
    status)
        if ifstatus wan | grep -q '"up": true'; then
            echo "WAN is UP"
            ifstatus wan | jsonfilter -e '@["ipv4-address"][0].address'
        else
            echo "WAN is DOWN"
        fi
        ;;
    *)
        echo "Usage: $0 {up|down|toggle|status}"
        exit 1
        ;;
esac

exit 0
```

**Usage:**
```bash
/usr/bin/wan-control.sh status
/usr/bin/wan-control.sh toggle
```

### 3. Connected WiFi Clients Monitor

```bash
#!/bin/sh
# /usr/bin/wifi-clients.sh
# Show connected WiFi clients

echo "=== Connected WiFi Clients ==="
echo ""

# For mac80211 driver (most modern devices)
if [ -d /sys/kernel/debug/ieee80211 ]; then
    for iface in /sys/class/net/wlan*; do
        IFACE=$(basename $iface)
        echo "Interface: $IFACE"
        iw dev $IFACE station dump | grep -E "Station|signal|tx bitrate|rx bitrate" | sed 's/^/  /'
        echo ""
    done
fi

# Alternative: Parse association list
echo "=== Client List ==="
for iface in wlan0 wlan1; do
    if [ -d /sys/class/net/$iface ]; then
        echo "Interface: $iface"
        iwinfo $iface assoclist
        echo ""
    fi
done

exit 0
```

### 4. LED Controller

```bash
#!/bin/sh
# /usr/bin/led-control.sh <led-name> <on|off|blink>

LED_PATH="/sys/class/leds"
LED_NAME="$1"
ACTION="$2"

if [ ! -d "$LED_PATH/$LED_NAME" ]; then
    echo "Error: LED '$LED_NAME' not found"
    echo "Available LEDs:"
    ls -1 "$LED_PATH"
    exit 1
fi

case "$ACTION" in
    on)
        echo "default-on" > "$LED_PATH/$LED_NAME/trigger"
        echo 1 > "$LED_PATH/$LED_NAME/brightness"
        ;;
    off)
        echo "none" > "$LED_PATH/$LED_NAME/trigger"
        echo 0 > "$LED_PATH/$LED_NAME/brightness"
        ;;
    blink)
        echo "timer" > "$LED_PATH/$LED_NAME/trigger"
        echo 500 > "$LED_PATH/$LED_NAME/delay_on"
        echo 500 > "$LED_PATH/$LED_NAME/delay_off"
        ;;
    *)
        echo "Usage: $0 <led-name> {on|off|blink}"
        exit 1
        ;;
esac

echo "LED '$LED_NAME' set to '$ACTION'"
exit 0
```

**Usage:**
```bash
# List available LEDs
ls /sys/class/leds/

# Control LED
/usr/bin/led-control.sh green:status on
/usr/bin/led-control.sh red:wan blink
/usr/bin/led-control.sh blue:wlan off
```

### 5. System Status Report

```bash
#!/bin/sh
# /usr/bin/system-status.sh
# Generate system status report

echo "==================================="
echo "   OpenWrt System Status Report"
echo "==================================="
echo ""

echo "--- System Info ---"
echo "Hostname: $(uci get system.@system[0].hostname)"
echo "Uptime: $(uptime)"
echo "Date: $(date)"
echo ""

echo "--- Memory ---"
free -h
echo ""

echo "--- Disk Usage ---"
df -h
echo ""

echo "--- Network Interfaces ---"
ip -br addr
echo ""

echo "--- WAN Status ---"
if ifstatus wan | grep -q '"up": true'; then
    echo "Status: UP"
    echo "IP: $(ifstatus wan | jsonfilter -e '@["ipv4-address"][0].address')"
    echo "Gateway: $(ifstatus wan | jsonfilter -e '@["route"][0].nexthop')"
else
    echo "Status: DOWN"
fi
echo ""

echo "--- WiFi Status ---"
wifi status | jsonfilter -e '@.*.up'
echo ""

echo "--- Connected Clients ---"
cat /tmp/dhcp.leases | wc -l
echo ""

echo "==================================="

exit 0
```

### 6. Backup Script with Rotation

```bash
#!/bin/sh
# /usr/bin/backup-config.sh
# Backup configuration with 7-day rotation

BACKUP_DIR="/mnt/usb/backups"
BACKUP_FILE="$BACKUP_DIR/config-$(date +%Y%m%d-%H%M%S).tar.gz"
MAX_BACKUPS=7

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create backup
echo "Creating backup: $BACKUP_FILE"
sysupgrade -b "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Backup created successfully"

    # Rotate old backups (keep only last 7)
    ls -t "$BACKUP_DIR"/config-*.tar.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm
    echo "Old backups rotated (keeping last $MAX_BACKUPS)"
else
    echo "Backup failed!"
    exit 1
fi

exit 0
```

---

## UCI Integration

### Reading UCI Values in Scripts

```bash
#!/bin/sh

# Get single value
LAN_IP=$(uci get network.lan.ipaddr)
echo "LAN IP: $LAN_IP"

# Get WiFi SSID
SSID=$(uci get wireless.default_radio0.ssid)
echo "SSID: $SSID"

# Check if option exists
if uci -q get wireless.radio0.disabled >/dev/null; then
    WIFI_DISABLED=$(uci get wireless.radio0.disabled)
    echo "WiFi disabled: $WIFI_DISABLED"
else
    echo "WiFi disabled option not set"
fi
```

### Setting UCI Values in Scripts

```bash
#!/bin/sh

# Set values
uci set network.lan.ipaddr='192.168.10.1'
uci set wireless.default_radio0.ssid='NewSSID'
uci set wireless.default_radio0.key='NewPassword'

# Commit changes
uci commit network
uci commit wireless

# Apply changes
/etc/init.d/network restart
wifi
```

### Adding List Items

```bash
#!/bin/sh

# Add DNS server to DHCP options
uci add_list dhcp.lan.dhcp_option='6,8.8.8.8,8.8.4.4'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

### Deleting UCI Values

```bash
#!/bin/sh

# Delete specific option
uci delete wireless.default_radio0.key
uci commit wireless

# Delete entire section
uci delete wireless.guest_radio0
uci commit wireless
```

---

## Init Scripts

### What are Init Scripts?

Init scripts manage services: start, stop, restart, enable/disable at boot.

**Location:** `/etc/init.d/`

### Basic Init Script Template

```bash
#!/bin/sh /etc/rc.common
# /etc/init.d/myservice

START=99
STOP=10

USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/myprogram --config /etc/myconfig
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    # Optional cleanup
    killall myprogram
}

reload_service() {
    # Optional reload logic
    stop
    start
}
```

### Init Script Sections

- `START=99`: Boot priority (higher = later in boot sequence)
- `STOP=10`: Shutdown priority (lower = earlier in shutdown)
- `USE_PROCD=1`: Use procd process manager (recommended)
- `start_service()`: Start the service
- `stop_service()`: Stop the service (optional, procd handles it)
- `reload_service()`: Reload configuration (optional)

### Managing Init Scripts

```bash
# Enable service at boot
/etc/init.d/myservice enable

# Disable service at boot
/etc/init.d/myservice disable

# Start service
/etc/init.d/myservice start

# Stop service
/etc/init.d/myservice stop

# Restart service
/etc/init.d/myservice restart

# Reload configuration
/etc/init.d/myservice reload

# Check status
/etc/init.d/myservice status
```

### Example: Custom Monitoring Service

```bash
#!/bin/sh /etc/rc.common
# /etc/init.d/connection-monitor

START=99
STOP=10

USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/wan-monitor.sh
    procd_set_param respawn ${respawn_threshold:-3600} ${respawn_timeout:-5} ${respawn_retry:-5}
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}
```

**Make executable and enable:**
```bash
chmod +x /etc/init.d/connection-monitor
/etc/init.d/connection-monitor enable
/etc/init.d/connection-monitor start
```

---

## Debugging Scripts

### Enable Verbose Output

```bash
#!/bin/sh
set -x  # Enable debug output (shows each command)

# Your script here

set +x  # Disable debug output
```

### Logging to Syslog

```bash
#!/bin/sh

# Log messages with logger
logger -t my-script "Script started"
logger -t my-script -p user.error "Error occurred"
logger -t my-script -p user.info "Processing complete"

# View logs
logread | grep my-script
```

### Logging to File

```bash
#!/bin/sh

LOG_FILE="/tmp/my-script.log"

echo "$(date): Script started" >> "$LOG_FILE"
echo "$(date): Processing..." >> "$LOG_FILE"
echo "$(date): Script finished" >> "$LOG_FILE"

# View log
cat "$LOG_FILE"
```

### Test Scripts Without Rebooting

```bash
# Test hotplug script manually
ACTION=add DEVICENAME=sda1 /etc/hotplug.d/block/10-mount

# Test button script
ACTION=pressed BUTTON=wps /etc/hotplug.d/button/01-wifitoggle

# Test startup script
/etc/rc.local

# Test cron script
/usr/bin/wan-monitor.sh
```

### Common Debugging Commands

```bash
# Check if script is executable
ls -l /path/to/script.sh

# Check script syntax
sh -n /path/to/script.sh

# Run script with debug output
sh -x /path/to/script.sh

# View system logs
logread
logread -f  # Follow logs in real-time

# Check process list
ps | grep my-script

# Check cron execution
logread | grep crond
```

---

## Best Practices

### 1. Always Use Absolute Paths

**Bad:**
```bash
wifi down
```

**Good:**
```bash
/sbin/wifi down
```

### 2. Check Command Success

```bash
#!/bin/sh

if /sbin/wifi down; then
    logger "WiFi disabled successfully"
else
    logger -p user.error "Failed to disable WiFi"
    exit 1
fi
```

### 3. Use Lock Files for Single Instance

```bash
#!/bin/sh

LOCK_FILE="/var/run/my-script.lock"

if [ -f "$LOCK_FILE" ]; then
    logger "Script already running"
    exit 0
fi

# Create lock file
touch "$LOCK_FILE"

# Your script logic here

# Remove lock file
rm "$LOCK_FILE"
```

### 4. Validate Variables

```bash
#!/bin/sh

DEVICE="$1"

if [ -z "$DEVICE" ]; then
    echo "Error: No device specified"
    exit 1
fi

if [ ! -e "/dev/$DEVICE" ]; then
    echo "Error: Device /dev/$DEVICE does not exist"
    exit 1
fi
```

### 5. Use Functions for Readability

```bash
#!/bin/sh

check_internet() {
    ping -c 3 -W 5 8.8.8.8 > /dev/null 2>&1
    return $?
}

restart_wan() {
    ifdown wan
    sleep 5
    ifup wan
}

# Main logic
if ! check_internet; then
    logger "Internet down, restarting WAN"
    restart_wan
fi
```

### 6. Handle Errors Gracefully

```bash
#!/bin/sh

set -e  # Exit on any error

# Trap errors and cleanup
trap 'logger "Script failed at line $LINENO"' ERR
trap 'rm -f /tmp/*.tmp' EXIT

# Your script logic
```

### 7. Document Your Scripts

```bash
#!/bin/sh
# Script Name: wan-monitor.sh
# Description: Monitors internet connectivity and restarts WAN if down
# Author: Your Name
# Date: 2025-01-15
# Usage: /usr/bin/wan-monitor.sh
# Cron: */10 * * * * /usr/bin/wan-monitor.sh

# Configuration
PING_TARGET="8.8.8.8"
PING_COUNT=3
RETRY_DELAY=5

# Main logic
# ...
```

### 8. Test Before Deploying

```bash
# Test locally first
sh /tmp/test-script.sh

# Check syntax
sh -n /tmp/test-script.sh

# Run with debug
sh -x /tmp/test-script.sh

# Only deploy to /etc/ after testing
```

### 9. Use Exit Codes

```bash
#!/bin/sh

# Exit codes
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_INVALID_ARGS=2

if [ $# -ne 1 ]; then
    echo "Usage: $0 <device>"
    exit $EXIT_INVALID_ARGS
fi

# Process...

if [ $? -eq 0 ]; then
    exit $EXIT_SUCCESS
else
    exit $EXIT_ERROR
fi
```

### 10. Minimize Resource Usage

```bash
# Bad: Multiple process spawns
WAN_IP=$(cat /tmp/status.json | grep ipaddr | cut -d'"' -f4)

# Good: Single process
WAN_IP=$(jsonfilter -i /tmp/status.json -e '@.ipaddr')

# Bad: Unnecessary loops
for i in $(seq 1 100); do
    echo $i
done

# Good: Direct approach
seq 1 100
```

---

## Security Considerations

### 1. Avoid Hardcoded Passwords

**Bad:**
```bash
PASSWORD="mypassword123"
```

**Good:**
```bash
PASSWORD=$(uci get system.admin.password)
```

### 2. Sanitize User Input

```bash
#!/bin/sh

DEVICE="$1"

# Validate input
case "$DEVICE" in
    sda[1-9]|sdb[1-9])
        # Valid device
        ;;
    *)
        echo "Invalid device"
        exit 1
        ;;
esac
```

### 3. Use Proper Permissions

```bash
# Scripts with sensitive data
chmod 700 /usr/bin/sensitive-script.sh

# Public scripts
chmod 755 /usr/bin/public-script.sh

# Configuration files
chmod 600 /etc/config/sensitive
```

### 4. Avoid Shell Injection

**Bad:**
```bash
HOSTNAME="$1"
ping -c 1 $HOSTNAME  # Vulnerable to injection
```

**Good:**
```bash
HOSTNAME="$1"
# Validate hostname
if echo "$HOSTNAME" | grep -qE '^[a-zA-Z0-9.-]+$'; then
    ping -c 1 "$HOSTNAME"
else
    echo "Invalid hostname"
    exit 1
fi
```

---

## Quick Reference

### Common Script Templates

**Hotplug Button Script:**
```bash
#!/bin/sh
[ "$BUTTON" = "button-name" ] || exit 0
[ "$ACTION" = "pressed" ] || exit 0
# Your logic here
exit 0
```

**Hotplug Block Script:**
```bash
#!/bin/sh
[ "$ACTION" = "add" ] || exit 0
[ -n "$DEVICENAME" ] || exit 0
# Your logic here
exit 0
```

**Cron Job Script:**
```bash
#!/bin/sh
logger -t script-name "Started"
# Your logic here
logger -t script-name "Finished"
exit 0
```

**Init Script:**
```bash
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/program
    procd_close_instance
}
```

---

## Additional Resources

- **OpenWrt Scripting**: https://openwrt.org/docs/guide-developer/start
- **Hotplug**: https://openwrt.org/docs/guide-user/base-system/hotplug
- **Init Scripts**: https://openwrt.org/docs/techref/initscripts
- **BusyBox**: https://www.busybox.net/
- **Cron**: https://openwrt.org/docs/guide-user/base-system/cron

---

**Document Version:** 1.0
**Last Updated:** 2025-10-25
**Based on:** https://eko.one.pl/?p=openwrt-skrypty (Polish original)
**License:** CC BY-SA 4.0
