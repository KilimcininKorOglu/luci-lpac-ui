# OpenWRT APC UPS Monitoring with apcupsd Guide

## Table of Contents
1. [Overview](#overview)
2. [What is apcupsd](#what-is-apcupsd)
3. [Hardware Requirements](#hardware-requirements)
4. [Supported UPS Models](#supported-ups-models)
5. [Installation](#installation)
6. [Cable and Connection Types](#cable-and-connection-types)
7. [Configuration](#configuration)
8. [Service Management](#service-management)
9. [Monitoring and Status](#monitoring-and-status)
10. [Web Interface Setup](#web-interface-setup)
11. [Testing and Diagnostics](#testing-and-diagnostics)
12. [Advanced Configuration](#advanced-configuration)
13. [Automated Shutdown Scripts](#automated-shutdown-scripts)
14. [Network Monitoring (Master/Slave)](#network-monitoring-masterslave)
15. [Troubleshooting](#troubleshooting)
16. [Best Practices](#best-practices)
17. [References](#references)

---

## Overview

This guide explains how to monitor and manage APC (American Power Conversion) uninterruptible power supplies (UPS) on OpenWRT routers using apcupsd daemon. This enables automatic shutdown during power failures, battery monitoring, and status reporting.

**Key Features:**
- Real-time UPS monitoring
- Automatic graceful shutdown on battery depletion
- Battery status and runtime estimation
- Web-based monitoring interface
- Network monitoring (master/slave configuration)
- Event-driven actions and notifications
- Diagnostic testing tools

**Use Cases:**
- Protect router from power failures
- Automatic shutdown to prevent data corruption
- Monitor battery health and capacity
- Remote UPS monitoring
- Coordinate shutdown of multiple devices

**Based on:** APC Back-UPS ES 700 with OpenWRT 12.09 (applicable to newer versions)

---

## What is apcupsd

### About apcupsd

**apcupsd** (APC UPS Daemon) is a monitoring and control daemon for APC UPS devices. It provides:

- Real-time monitoring of UPS status
- Automatic shutdown when battery runs low
- Event notification system
- Network information server (NIS) for remote monitoring
- Web-based monitoring interface
- Logging and historical data

### How It Works

```
UPS Device ←→ Connection (USB/Serial) ←→ apcupsd daemon ←→ System
                                              ↓
                                        Event Scripts
                                              ↓
                                    Actions (shutdown, notify, etc.)
```

**Process Flow:**
1. UPS connects to router via USB or serial cable
2. apcupsd daemon communicates with UPS
3. Daemon monitors battery status, load, runtime
4. On power failure, events trigger scripts
5. If battery low, initiate graceful shutdown
6. System shuts down before battery depletes

### Components

- **apcupsd**: Main monitoring daemon
- **apcaccess**: Command-line status tool
- **apctest**: Diagnostic and testing utility
- **apcupsd-cgi**: Web interface for monitoring
- **Event scripts**: Located in `/etc/apcupsd/`

---

## Hardware Requirements

### Router Requirements

**Minimum specifications:**
- OpenWRT-compatible router
- USB port (for USB UPS) or serial port
- Sufficient storage for packages (~500KB)
- 16MB+ RAM recommended

**USB requirements:**
- USB 1.1/2.0/3.0 port
- USB HID (Human Interface Device) kernel support
- Power output sufficient for UPS communication (minimal)

**Serial requirements:**
- RS232 serial port (DB9) or
- USB-to-Serial adapter

### UPS Requirements

**Compatible UPS types:**
- APC Back-UPS series (ES, RS, CS, XS)
- APC Smart-UPS series
- APC Matrix-UPS
- Most APC UPS with USB or serial interface

**Connection interfaces:**
- USB connection (most modern models)
- Serial RS232 connection (older models)
- Network SNMP (advanced, not covered here)

### Cables

**USB Cable:**
- Standard USB Type-A to Type-B cable
- Included with most modern APC UPS units

**Serial Cables:**
- APC 940-0024C (Smart cable)
- APC 940-0020B/E (Simple signal cable)
- APC 940-0095A/B/C (various serial types)

---

## Supported UPS Models

### APC Back-UPS Series

**USB-equipped models:**
- Back-UPS ES (350-750VA)
- Back-UPS RS (500-1500VA)
- Back-UPS CS (350-650VA)
- Back-UPS XS (800-1500VA)
- Back-UPS Pro (280-1500VA)

**Serial-equipped models:**
- Older Back-UPS models with serial port
- Back-UPS Office series

### APC Smart-UPS Series

**Serial/USB models:**
- Smart-UPS (250-5000VA)
- Smart-UPS RT (rack-mount)
- Smart-UPS SC (SC 1000/1500)
- Smart-UPS SUA/SMT/SMX series

### Tested Configuration

**Reference setup (from eko.one.pl):**
- **UPS Model:** APC Back-UPS ES 700
- **Connection:** USB
- **OpenWRT Version:** 12.09 (Attitude Adjustment)
- **Status:** Fully functional

---

## Installation

### Step 1: Update Package Lists

```bash
opkg update
```

### Step 2: Install apcupsd Package

```bash
opkg install apcupsd
```

**Package includes:**
- apcupsd daemon
- apcaccess status tool
- Configuration files
- Event scripts
- Documentation

### Step 3: Install USB Support (for USB UPS)

```bash
# Install USB HID kernel module
opkg install kmod-usb-hid

# Also install USB core support (usually pre-installed)
opkg install kmod-usb-core
```

**Why kmod-usb-hid?**
- APC UPS devices use USB HID (Human Interface Device) protocol
- Same interface used by keyboards and mice
- Requires specific kernel driver

### Step 4: Verify USB Device Detection

```bash
# Check USB devices
cat /proc/bus/usb/devices

# Look for APC device
lsusb | grep APC
```

**Expected output:**
```
Bus 001 Device 002: ID 051d:0002 American Power Conversion Uninterruptible Power Supply
```

### Step 5: Install Web Interface (Optional)

```bash
# Install CGI web monitoring
opkg install apcupsd-cgi

# Install web server (if not already installed)
opkg install uhttpd

# Enable and start web server
/etc/init.d/uhttpd enable
/etc/init.d/uhttpd start
```

### Step 6: Verify Installation

```bash
# Check apcupsd version
apcupsd --version

# List installed files
opkg files apcupsd
```

---

## Cable and Connection Types

### USB Connection

**Most common and recommended:**

**Configuration:**
```bash
UPSCABLE usb
UPSTYPE usb
DEVICE
```

**Characteristics:**
- Simple plug-and-play
- No additional hardware needed
- Detected as HID device
- Full monitoring capabilities
- Supported by all modern APC UPS

**Verification:**
```bash
# Check if UPS detected as HID
dmesg | grep -i hid

# Example output:
# usb 1-1: new low-speed USB device number 2 using ehci-platform
# hid-generic 0003:051D:0002.0001: hiddev0,hidraw0: USB HID v1.10 Device [American Power Conversion Back-UPS ES 700] on usb-1-1/input0
```

### Serial RS232 Connection (Smart Cable 940-0024C)

**For APC Smart-UPS and older models:**

**Configuration:**
```bash
UPSCABLE 940-0024C
UPSTYPE apcsmart
DEVICE /dev/ttyS0
```

**Characteristics:**
- Requires hardware serial port
- Full "smart" protocol support
- Advanced features (battery calibration, sensitivity)
- Reliable communication

**Serial port locations:**
- Built-in serial: `/dev/ttyS0` (COM1)
- Second serial port: `/dev/ttyS1` (COM2)

### USB-to-Serial Adapter

**When router has no serial port:**

**Configuration:**
```bash
UPSCABLE 940-0024C
UPSTYPE apcsmart
DEVICE /dev/ttyUSB0
```

**Requirements:**
```bash
# Install USB serial driver
opkg install kmod-usb-serial
opkg install kmod-usb-serial-pl2303  # For Prolific adapters
# or
opkg install kmod-usb-serial-ftdi    # For FTDI adapters
```

**Characteristics:**
- Adds serial port via USB
- Requires compatible USB-serial driver
- Device appears as `/dev/ttyUSB0` or `/dev/ttyUSB1`

**Verify adapter:**
```bash
# Check USB serial device
ls -l /dev/ttyUSB*

# Check kernel messages
dmesg | grep ttyUSB
```

### Simple Signal Cable (940-0020B/E)

**For older Back-UPS models:**

**Configuration:**
```bash
UPSCABLE simple
UPSTYPE backups
DEVICE /dev/ttyS0
```

**Characteristics:**
- Limited monitoring capabilities
- Basic on/off battery status
- No battery percentage or runtime
- Simple signal lines only

### Cable Type Summary

| Cable Type | UPS Models | Connection | Protocol | Capabilities |
|------------|------------|------------|----------|--------------|
| USB | Modern Back-UPS, Smart-UPS | USB port | HID | Full |
| 940-0024C | Smart-UPS series | Serial RS232 | Smart | Full |
| 940-0020B/E | Older Back-UPS | Serial RS232 | Simple | Limited |
| USB-to-Serial | Smart-UPS via adapter | USB + adapter | Smart | Full |

---

## Configuration

### Main Configuration File

**Location:** `/etc/apcupsd/apcupsd.conf`

### Basic USB Configuration

Edit the configuration file:

```bash
vi /etc/apcupsd/apcupsd.conf
```

**Essential settings for USB UPS:**

```bash
## apcupsd.conf - USB UPS Configuration

# UPS name (appears in status messages)
UPSNAME BackUPS700

# Cable type
UPSCABLE usb

# UPS type
UPSTYPE usb

# Device (leave blank for USB auto-detection)
DEVICE

# Network Information Server (NIS) port
NISIP 0.0.0.0
NISPORT 3551

# Battery level at which shutdown occurs
BATTERYLEVEL 10

# Minutes of runtime remaining before shutdown
MINUTES 5

# Timeout for communications with UPS (seconds)
TIMEOUT 60

# Time to wait before declaring battery dead (seconds)
ANNOY 300
ANNOYDELAY 60

# Kill power on shutdown
KILLDELAY 0
```

### Basic Serial Configuration (Smart-UPS)

```bash
## apcupsd.conf - Serial Smart-UPS Configuration

UPSNAME SmartUPS1000
UPSCABLE 940-0024C
UPSTYPE apcsmart
DEVICE /dev/ttyS0

NISIP 0.0.0.0
NISPORT 3551

BATTERYLEVEL 10
MINUTES 5
TIMEOUT 60
```

### Configuration Parameters Explained

#### UPS Identity

```bash
# UPS name (for identification in multi-UPS setups)
UPSNAME BackUPS700
```

#### Cable and Device

```bash
# Cable type
UPSCABLE usb          # Options: usb, 940-0024C, simple, ether, etc.

# UPS type
UPSTYPE usb           # Options: usb, apcsmart, backups, etc.

# Device path
DEVICE                # Blank for USB, /dev/ttyS0 for serial
```

#### Network Information Server

```bash
# NIS IP address (0.0.0.0 = listen on all interfaces)
NISIP 0.0.0.0

# NIS port for status queries
NISPORT 3551
```

#### Shutdown Thresholds

```bash
# Battery level (%) to trigger shutdown
BATTERYLEVEL 10       # Shutdown at 10% battery

# Runtime (minutes) to trigger shutdown
MINUTES 5             # Shutdown at 5 minutes remaining

# Both conditions are OR logic: shutdown if either is met
```

#### Timing Parameters

```bash
# UPS communication timeout
TIMEOUT 60            # 60 seconds

# Time on battery before warning
ANNOY 300             # 5 minutes

# Delay between warning messages
ANNOYDELAY 60         # 1 minute

# Delay before UPS kills power after shutdown
KILLDELAY 0           # 0 = immediately (not recommended for network setups)
```

#### Power Failure Behavior

```bash
# Time to wait for power to return before shutdown
ONBATTERYDELAY 6      # Wait 6 seconds (avoids brief outages)

# How long UPS waits before killing power
KILLDELAY 60          # 60 seconds (allows system to shutdown)
```

### Apply Configuration

```bash
# After editing configuration file
/etc/init.d/apcupsd restart
```

---

## Service Management

### Enable Service at Boot

```bash
/etc/init.d/apcupsd enable
```

### Start Service

```bash
/etc/init.d/apcupsd start
```

### Stop Service

```bash
/etc/init.d/apcupsd stop
```

### Restart Service

```bash
/etc/init.d/apcupsd restart
```

### Check Service Status

```bash
# Using init script
/etc/init.d/apcupsd status

# Check if process is running
ps | grep apcupsd

# Check listening ports
netstat -tulpn | grep apcupsd
```

### View Logs

```bash
# System log
logread | grep apcupsd

# Dedicated apcupsd log (if configured)
cat /var/log/apcupsd.events
```

---

## Monitoring and Status

### Command-Line Monitoring (apcaccess)

**Basic status:**

```bash
apcaccess
```

**Example output:**

```
APC      : 001,036,0877
DATE     : 2023-10-15 14:23:45 +0000
HOSTNAME : OpenWrt
VERSION  : 3.14.10 (13 September 2011) unknown
UPSNAME  : BackUPS700
CABLE    : USB Cable
DRIVER   : USB UPS Driver
UPSMODE  : Stand Alone
STARTTIME: 2023-10-15 08:00:00 +0000
MODEL    : Back-UPS ES 700
STATUS   : ONLINE
LINEV    : 230.0 Volts
LOADPCT  : 15.0 Percent
BCHARGE  : 100.0 Percent
TIMELEFT : 45.0 Minutes
MBATTCHG : 10 Percent
MINTIMEL : 5 Minutes
MAXTIME  : 0 Seconds
SENSE    : Medium
LOTRANS  : 180.0 Volts
HITRANS  : 266.0 Volts
ALARMDEL : 30 Seconds
BATTV    : 13.5 Volts
LASTXFER : Automatic or explicit self test
NUMXFERS : 0
TONBATT  : 0 Seconds
CUMONBATT: 0 Seconds
XOFFBATT : N/A
STATFLAG : 0x07000008
SERIALNO : 5B1234X56789
BATTDATE : 2021-08-15
NOMINV   : 230 Volts
NOMBATTV : 12.0 Volts
NOMPOWER : 405 Watts
FIRMWARE : 841.L3 .D USB FW:L3
END APC  : 2023-10-15 14:23:47 +0000
```

### Key Status Fields

| Field | Description | Example |
|-------|-------------|---------|
| STATUS | Current UPS status | ONLINE, ONBATT, LOWBATT |
| LINEV | Input line voltage | 230.0 Volts |
| LOADPCT | Load percentage | 15.0 Percent |
| BCHARGE | Battery charge level | 100.0 Percent |
| TIMELEFT | Estimated runtime | 45.0 Minutes |
| BATTV | Battery voltage | 13.5 Volts |
| NUMXFERS | Number of transfers to battery | 0 |
| TONBATT | Time currently on battery | 0 Seconds |

### UPS Status Values

**STATUS field values:**
- `ONLINE` - Normal operation, AC power present
- `ONBATT` - Running on battery power
- `LOWBATT` - Battery critically low
- `COMMLOST` - Communication lost with UPS
- `SHUTTING DOWN` - Shutdown in progress

### Specific Value Queries

```bash
# Get specific value
apcaccess status STATUS

# Get battery charge
apcaccess status BCHARGE

# Get time remaining
apcaccess status TIMELEFT

# Get load percentage
apcaccess status LOADPCT
```

### Scripting with apcaccess

```bash
#!/bin/sh
# Check UPS status and send alert if on battery

STATUS=$(apcaccess status STATUS)

if echo "$STATUS" | grep -q "ONBATT"; then
    TIMELEFT=$(apcaccess status TIMELEFT | cut -d' ' -f1)
    BCHARGE=$(apcaccess status BCHARGE | cut -d' ' -f1)

    logger -t ups-monitor "UPS on battery! Charge: ${BCHARGE}%, Time: ${TIMELEFT} min"

    # Send notification (if mail configured)
    echo "UPS is running on battery. ${TIMELEFT} minutes remaining." | \
        mail -s "UPS Alert" admin@example.com
fi
```

---

## Web Interface Setup

### Installation

```bash
# Install web monitoring interface
opkg install apcupsd-cgi

# Install web server (if not already installed)
opkg install uhttpd

# Enable and start uhttpd
/etc/init.d/uhttpd enable
/etc/init.d/uhttpd start
```

### Configuration

**Default CGI location:** `/www/cgi-bin/`

**Web server configuration:** `/etc/config/uhttpd`

Verify CGI scripts are enabled:

```bash
uci show uhttpd | grep cgi
# Should show:
# uhttpd.main.cgi_prefix='/cgi-bin'
```

### Accessing Web Interface

**Single UPS monitoring:**
```
http://192.168.1.1/cgi-bin/apcupsd/upsstats.cgi
```

**Multi-UPS monitoring:**
```
http://192.168.1.1/cgi-bin/apcupsd/multimon.cgi
```

### Web Interface Features

**Displays:**
- Real-time UPS status (online/on battery/etc.)
- Battery charge percentage with visual indicator
- Estimated runtime remaining
- Load percentage and graph
- Input voltage
- UPS model and serial number
- Last transfer reason
- Historical events

**Refresh rate:** Automatic refresh every 30-60 seconds

### Custom Web Interface Configuration

Edit `/etc/apcupsd/hosts.conf` for multi-UPS monitoring:

```bash
# hosts.conf - Multi-UPS Configuration

# Format: MONITOR host:port "Description"

MONITOR localhost:3551 "Main Router UPS"
MONITOR 192.168.1.10:3551 "Server Room UPS"
MONITOR 192.168.1.20:3551 "Office UPS"
```

Access multimon.cgi to see all configured UPS devices.

---

## Testing and Diagnostics

### apctest Utility

**Start diagnostic tool:**

```bash
apctest
```

**Warning:** Stop apcupsd daemon before running apctest:

```bash
/etc/init.d/apcupsd stop
apctest
```

### apctest Main Menu

```
2023-10-15 14:30:00 apctest 3.14.10 (13 September 2011) unknown
Checking configuration ...
sharenet.type = Network & ShareUPS Disabled
cable.type = USB Cable
mode.type = USB UPS Driver
Setting up the port ...
Doing prep_device() ...

You are using a USB cable type, so I'm entering USB test mode
Hello, this is the apcupsd Cable Test program.
This part of apctest is for testing USB UPSes.

Please select the function you want to perform.

1)  Test kill UPS power
2)  Perform self-test
3)  Read last self-test result
4)  View/Change battery date
5)  View manufacturing date
6)  View/Change alarm behavior
7)  View/Change sensitivity
8)  View/Change low transfer voltage
9)  View/Change high transfer voltage
10) Perform battery calibration
11) Test alarm
12) View/Change self-test interval
 Q) Quit

Select function number:
```

### Common Tests

#### 1. Self-Test

**Purpose:** Verify UPS battery health

**Steps:**
1. Run `apctest`
2. Select option `2) Perform self-test`
3. UPS switches to battery briefly
4. Returns to online mode
5. Check results with option `3) Read last self-test result`

**Interpretation:**
- `PASSED` - Battery healthy
- `FAILED` - Battery needs replacement
- `IN PROGRESS` - Test currently running

#### 2. View Battery Date

**Purpose:** Track battery age and replacement schedule

**Steps:**
1. Select option `4) View/Change battery date`
2. View current date
3. Change if battery replaced

**Example:**
```
Current battery date: 2021-08-15
Enter new battery date (YYYY-MM-DD) or Q to quit: 2023-09-01
```

#### 3. Battery Calibration

**Purpose:** Recalibrate runtime estimates

**Steps:**
1. Select option `10) Perform battery calibration`
2. UPS runs on battery until depleted
3. Automatically recharges
4. Runtime estimates updated

**Warning:** Takes several hours, plan accordingly!

#### 4. Test Alarm

**Purpose:** Verify UPS alarm/beeper works

**Steps:**
1. Select option `11) Test alarm`
2. UPS beeper sounds
3. Verify you can hear it

#### 5. View/Change Sensitivity

**Purpose:** Adjust voltage sensitivity

**Steps:**
1. Select option `7) View/Change sensitivity`
2. Options: Low, Medium, High
3. Higher sensitivity = more frequent battery switching

**Recommended:** Medium (default)

### Manual Battery Test

```bash
# Simulate power failure
# 1. Stop apcupsd
/etc/init.d/apcupsd stop

# 2. Unplug UPS from AC power

# 3. Monitor voltage and runtime
watch -n 5 'apcaccess status | grep -E "BATTV|TIMELEFT|BCHARGE"'

# 4. Plug back in when satisfied

# 5. Restart apcupsd
/etc/init.d/apcupsd start
```

---

## Advanced Configuration

### Email Notifications

**Install mail client:**

```bash
opkg install msmtp msmtp-scripts
```

**Configure SMTP:** `/etc/msmtprc`

```bash
defaults
auth on
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt

account default
host smtp.gmail.com
port 587
from router@example.com
user router@example.com
password your_password
```

**Create notification script:** `/etc/apcupsd/apccontrol`

Look for the `ONBATTERY` section and add:

```bash
ONBATTERY)
    echo "UPS ${2} is running on battery power" | \
        mail -s "UPS Alert: On Battery" admin@example.com
    ;;
```

### Custom Event Scripts

**Event script locations:** `/etc/apcupsd/`

**Available events:**

| Event | Trigger |
|-------|---------|
| onbattery | Power failure, running on battery |
| offbattery | Power restored |
| failing | Battery charge below BATTERYLEVEL |
| timeout | Battery runtime below MINUTES |
| loadlimit | UPS load exceeded |
| commfailure | Communication lost with UPS |
| commok | Communication restored |
| emergency | Emergency shutdown |
| changeme | Battery needs replacement |
| doreboot | System rebooting |
| doshutdown | System shutting down |
| mainsback | Utility power restored |
| powerout | Power failure detected |

**Example custom script:** `/etc/apcupsd/onbattery`

```bash
#!/bin/sh
# Custom script when UPS goes on battery

LOGGER="logger -t apcupsd-event"

$LOGGER "Power failure detected!"

# Send notification
echo "UPS $(hostname) has lost power and is running on battery." | \
    mail -s "UPS Power Failure" admin@example.com

# Reduce system load
# Stop non-essential services
/etc/init.d/transmission stop
/etc/init.d/samba stop

exit 0
```

**Make executable:**
```bash
chmod +x /etc/apcupsd/onbattery
```

### Logging Configuration

**Enable detailed logging:**

Edit `/etc/apcupsd/apcupsd.conf`:

```bash
# Log all events
EVENTSFILE /var/log/apcupsd.events

# Maximum size of event file (KB)
EVENTSFILEMAX 100
```

**View event log:**
```bash
cat /var/log/apcupsd.events
```

**Sample event log:**
```
2023-10-15 08:00:00 +0000  apcupsd 3.14.10 startup succeeded
2023-10-15 10:23:15 +0000  Power failure.
2023-10-15 10:23:15 +0000  Running on UPS batteries.
2023-10-15 10:25:30 +0000  Mains returned. No longer on UPS batteries.
2023-10-15 10:25:30 +0000  Power is back. UPS running on mains.
```

---

## Automated Shutdown Scripts

### Graceful Shutdown Configuration

**Default behavior:** When battery reaches BATTERYLEVEL or MINUTES threshold, apcupsd initiates shutdown.

**Shutdown script:** `/etc/apcupsd/apccontrol`

### Customize Shutdown Behavior

**Pre-shutdown script:** `/etc/apcupsd/doshutdown`

```bash
#!/bin/sh
# Custom shutdown script

LOGGER="logger -t apcupsd-shutdown"

$LOGGER "UPS battery critical, initiating shutdown sequence"

# Stop services gracefully
$LOGGER "Stopping services..."
/etc/init.d/samba stop
/etc/init.d/transmission stop
/etc/init.d/minidlna stop

# Sync filesystem
sync
sleep 2
sync

# Send final notification
echo "Router $(hostname) is shutting down due to UPS battery depletion." | \
    mail -s "UPS Critical Shutdown" admin@example.com

# Allow apcupsd to continue shutdown
exit 0
```

### Cancel Shutdown on Power Restore

Edit `/etc/apcupsd/apccontrol`:

```bash
MAINSBACK)
    # Cancel pending shutdown if power restored
    if [ -f /etc/apcupsd/powerfail ]; then
        rm /etc/apcupsd/powerfail
        logger -t apcupsd "Power restored, shutdown cancelled"

        # Restart stopped services
        /etc/init.d/samba start
        /etc/init.d/transmission start
    fi
    ;;
```

---

## Network Monitoring (Master/Slave)

### Master Configuration

**On UPS-connected router (master):**

Edit `/etc/apcupsd/apcupsd.conf`:

```bash
# Enable NIS (Network Information Server)
NISIP 0.0.0.0           # Listen on all interfaces
NISPORT 3551

# Allow specific clients
# Edit /etc/apcupsd/apcupsd.conf or create /etc/apcupsd/apcupsd.conf.d/
```

**Firewall rule:**
```bash
# Allow NIS connections from LAN
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-APC-NIS'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest_port='3551'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall reload
```

### Slave Configuration

**On remote device monitoring UPS:**

Edit `/etc/apcupsd/apcupsd.conf`:

```bash
UPSNAME SlaveRouter
UPSCABLE ether           # Network cable type
UPSTYPE net              # Network UPS type
DEVICE 192.168.1.1:3551  # Master IP:port

# Slave will monitor master and shutdown if master shuts down
NISIP 0.0.0.0
NISPORT 3551

# Shutdown thresholds (can differ from master)
BATTERYLEVEL 15
MINUTES 3
```

**Restart apcupsd on slave:**
```bash
/etc/init.d/apcupsd restart
```

### Verify Network Monitoring

**On slave, check status:**
```bash
apcaccess
# Should show master's UPS data
```

---

## Troubleshooting

### UPS Not Detected

**Problem:** apcupsd cannot communicate with UPS.

**Solutions:**

1. **Check USB connection:**
   ```bash
   lsusb | grep -i apc
   # Should show APC device
   ```

2. **Verify USB HID module loaded:**
   ```bash
   lsmod | grep hid
   # Should show usbhid
   ```

3. **Install missing USB support:**
   ```bash
   opkg install kmod-usb-hid
   reboot
   ```

4. **Check dmesg for errors:**
   ```bash
   dmesg | grep -i usb
   dmesg | grep -i hid
   ```

### Communication Timeout Errors

**Problem:** `apcaccess` returns timeout or communication errors.

**Solutions:**

1. **Check configuration:**
   ```bash
   cat /etc/apcupsd/apcupsd.conf | grep -E "UPSCABLE|UPSTYPE|DEVICE"
   ```

2. **Verify correct cable type:**
   - USB UPS: `UPSCABLE usb`
   - Smart-UPS serial: `UPSCABLE 940-0024C`

3. **Increase timeout:**
   ```bash
   # In apcupsd.conf
   TIMEOUT 120
   ```

4. **Restart service:**
   ```bash
   /etc/init.d/apcupsd restart
   ```

### Web Interface Not Working

**Problem:** Cannot access multimon.cgi or upsstats.cgi.

**Solutions:**

1. **Verify apcupsd-cgi installed:**
   ```bash
   opkg list-installed | grep apcupsd-cgi
   ```

2. **Check uhttpd running:**
   ```bash
   /etc/init.d/uhttpd status
   /etc/init.d/uhttpd start
   ```

3. **Verify CGI enabled:**
   ```bash
   uci show uhttpd | grep cgi
   ```

4. **Check file permissions:**
   ```bash
   ls -la /www/cgi-bin/apcupsd/
   chmod +x /www/cgi-bin/apcupsd/*.cgi
   ```

### Incorrect Status Information

**Problem:** UPS shows wrong values or status.

**Solutions:**

1. **Run self-test:**
   ```bash
   /etc/init.d/apcupsd stop
   apctest
   # Select option 2: Perform self-test
   ```

2. **Calibrate battery:**
   ```bash
   # In apctest
   # Select option 10: Perform battery calibration
   ```

3. **Check battery age:**
   - Old batteries give inaccurate readings
   - Replace if over 3-5 years old

### Shutdown Not Triggering

**Problem:** System doesn't shutdown when battery low.

**Solutions:**

1. **Check thresholds:**
   ```bash
   grep -E "BATTERYLEVEL|MINUTES" /etc/apcupsd/apcupsd.conf
   ```

2. **Test manually:**
   ```bash
   # Temporarily lower thresholds for testing
   BATTERYLEVEL 50
   MINUTES 20

   # Simulate power failure (unplug UPS)
   ```

3. **Check event scripts:**
   ```bash
   ls -la /etc/apcupsd/doshutdown
   # Should be executable
   chmod +x /etc/apcupsd/doshutdown
   ```

4. **Review logs:**
   ```bash
   logread | grep apcupsd
   cat /var/log/apcupsd.events
   ```

---

## Best Practices

### 1. Regular Testing

```bash
# Monthly self-test
apctest
# Option 2: Perform self-test

# Check battery date
# Replace every 3-5 years
```

### 2. Conservative Shutdown Thresholds

```bash
# Don't wait too long
BATTERYLEVEL 20      # 20% (not 5%)
MINUTES 10           # 10 minutes (not 2)
```

### 3. Enable Logging

```bash
# Always log events
EVENTSFILE /var/log/apcupsd.events
EVENTSFILEMAX 500
```

### 4. Notifications

Set up email alerts for:
- Power failures
- Battery low
- UPS communication loss
- Self-test failures

### 5. Network Monitoring

Monitor UPS status from multiple locations:
- Web interface
- Remote apcaccess queries
- SNMP (if available)
- Custom monitoring scripts

### 6. Battery Maintenance

- Replace batteries every 3-5 years
- Run monthly self-tests
- Annual battery calibration
- Keep UPS in cool, dry location

### 7. Graceful Shutdown

Ensure shutdown scripts:
- Stop services properly
- Sync filesystems
- Save important data
- Log shutdown reason

---

## References

### Official Documentation
- **apcupsd Official Site:** http://www.apcupsd.org/
- **apcupsd Manual:** http://www.apcupsd.org/manual/
- **OpenWRT Packages:** https://openwrt.org/packages/

### Related Pages
- **eko.one.pl apcupsd Guide:** https://eko.one.pl/?p=openwrt-apcupsd
- **APC UPS Support:** https://www.apc.com/

### Tools and Utilities
- **apcupsd**: Main daemon
- **apcaccess**: Status tool
- **apctest**: Diagnostic utility
- **apcupsd-cgi**: Web interface

### Community Resources
- **apcupsd Users Mailing List:** http://www.apcupsd.org/support.html
- **OpenWRT Forum:** https://forum.openwrt.org/

---

## Summary

apcupsd provides comprehensive UPS monitoring for OpenWRT routers:

**Key Benefits:**
- Automatic shutdown on power failure
- Real-time battery monitoring
- Web-based status interface
- Network monitoring capabilities
- Event-driven automation

**Installation Steps:**
1. Install apcupsd and kmod-usb-hid packages
2. Configure cable type and UPS model
3. Set shutdown thresholds
4. Enable and start service
5. Verify with apcaccess

**Essential Configuration (USB):**
```bash
UPSCABLE usb
UPSTYPE usb
DEVICE
BATTERYLEVEL 15
MINUTES 5
```

**Monitoring:**
- Command-line: `apcaccess`
- Web interface: `http://router/cgi-bin/apcupsd/multimon.cgi`
- Logging: `/var/log/apcupsd.events`

**Best Practices:**
- Regular self-tests
- Conservative shutdown thresholds
- Email notifications
- Battery replacement every 3-5 years
- Graceful shutdown scripts

With proper configuration, apcupsd ensures your OpenWRT router shuts down safely during power outages, protecting data and preventing corruption.

---

*This guide is based on the eko.one.pl apcupsd documentation and official apcupsd reference materials.*
