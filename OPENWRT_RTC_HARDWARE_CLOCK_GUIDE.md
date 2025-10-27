# OpenWRT Real-Time Clock (RTC) Hardware Integration Guide

## Table of Contents
1. [Overview](#overview)
2. [Why Add RTC to OpenWRT](#why-add-rtc-to-openwrt)
3. [Hardware Requirements](#hardware-requirements)
4. [RTC Module Options](#rtc-module-options)
5. [I2C Bus Implementation Methods](#i2c-bus-implementation-methods)
6. [Method 1: GPIO I2C (Software I2C)](#method-1-gpio-i2c-software-i2c)
7. [Method 2: USB I2C Adapter](#method-2-usb-i2c-adapter)
8. [RTC Driver Installation](#rtc-driver-installation)
9. [Testing and Verification](#testing-and-verification)
10. [Time Synchronization](#time-synchronization)
11. [Persistent Configuration](#persistent-configuration)
12. [Troubleshooting](#troubleshooting)
13. [Advanced Configuration](#advanced-configuration)
14. [Best Practices](#best-practices)
15. [References](#references)

---

## Overview

Most OpenWRT routers lack a Real-Time Clock (RTC) - hardware that maintains accurate time even when powered off. This guide demonstrates how to add external RTC functionality using I2C-based RTC modules, providing persistent timekeeping independent of network connectivity.

**Key Features:**
- Accurate timekeeping without internet
- Battery-backed time retention
- I2C interface integration
- Multiple implementation methods
- Automatic time restoration on boot

**Common RTC Modules:**
- DS1307 (most common, 5V tolerant)
- DS3231 (more accurate, temperature compensated)
- PCF8563 (low power)
- MCP7940N (I2C battery switchover)

---

## Why Add RTC to OpenWRT

### Problems Without RTC

**On every reboot:**
1. System clock resets to Jan 1, 1970 (Unix epoch)
2. Log timestamps are incorrect
3. SSL/TLS certificates fail validation (due to incorrect date)
4. Scheduled tasks execute incorrectly
5. File timestamps are wrong

**NTP limitations:**
- Requires internet connection
- Delays during boot
- May fail on network issues
- Not suitable for offline operation

### Benefits of Hardware RTC

**Advantages:**
- **Immediate accurate time** on boot
- **No internet dependency**
- **Battery backup** maintains time during power loss
- **Low power consumption**
- **Precise timekeeping** (±1-2 minutes/month for DS1307, ±2 minutes/year for DS3231)
- **SSL/TLS compatibility** from boot

**Use Cases:**
- Offline routers or isolated networks
- Logging and monitoring systems
- Time-critical applications
- Scheduled automation
- Security cameras with accurate timestamps
- Industrial/embedded applications

---

## Hardware Requirements

### Router Requirements

**GPIO pins needed:**
- 2 GPIO pins for I2C (SDA and SCL) - if using GPIO method
- OR 1 USB port - if using USB I2C adapter

**Software requirements:**
- OpenWRT with kernel I2C support
- Available storage for kernel modules (~50-100KB)

**Check available GPIO pins:**
```bash
# List GPIO chips and pins
ls /sys/class/gpio/

# Check specific GPIO
cat /sys/kernel/debug/gpio
```

### RTC Module Hardware

**DS1307 RTC Module:**
- **Chip:** DS1307 Real-Time Clock IC
- **Interface:** I2C (address 0x68)
- **Voltage:** 3.3V or 5V (5V tolerant)
- **Battery:** CR2032 coin cell (backup power)
- **Accuracy:** ±1-2 minutes/month
- **Cost:** ~$1-3 USD

**DS3231 RTC Module (Recommended for accuracy):**
- **Chip:** DS3231 Precision RTC
- **Interface:** I2C (address 0x68)
- **Voltage:** 3.3V or 5V
- **Battery:** CR2032 coin cell
- **Accuracy:** ±2 minutes/year (temperature compensated)
- **Cost:** ~$3-5 USD

### Connection Components

**For GPIO I2C:**
- Jumper wires (female-female)
- Optional: Pull-up resistors (4.7kΩ) if not on module
- RTC module with CR2032 battery

**For USB I2C:**
- USB I2C adapter (i2c-tiny-usb compatible)
- Jumper wires
- RTC module with CR2032 battery

---

## RTC Module Options

### DS1307 vs DS3231 Comparison

| Feature | DS1307 | DS3231 |
|---------|--------|--------|
| Accuracy | ±1-2 min/month | ±2 min/year |
| Temperature Compensation | No | Yes |
| Voltage | 3.3V-5V | 3.3V-5V |
| Current Draw | ~1.5mA active, ~500nA backup | ~100μA active, ~2μA backup |
| Cost | Lower (~$1-3) | Higher (~$3-5) |
| Recommended Use | Basic timekeeping | Precision applications |

### I2C Address

**Default address:** 0x68 (for both DS1307 and DS3231)

**Verify I2C address:**
```bash
# Install i2c-tools
opkg install i2c-tools

# Scan I2C bus
i2cdetect -y 0

# Example output:
#      0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
# 00:          -- -- -- -- -- -- -- -- -- -- -- -- --
# ...
# 60: -- -- -- -- -- -- -- -- 68 -- -- -- -- -- -- --
```

---

## I2C Bus Implementation Methods

### Method Comparison

| Method | Pros | Cons | Difficulty |
|--------|------|------|------------|
| GPIO I2C | No additional hardware, flexible pins | Software-based, slower | Medium |
| USB I2C | Hardware I2C, faster, no GPIO needed | Requires USB adapter | Easy |

---

## Method 1: GPIO I2C (Software I2C)

### About GPIO I2C

GPIO I2C (also called bit-banging I2C) uses standard GPIO pins to implement I2C protocol in software.

**Advantages:**
- No additional hardware needed
- Works on any router with available GPIO
- Flexible pin selection

**Disadvantages:**
- Slower than hardware I2C
- Uses CPU resources
- Limited to ~100kHz speed

### Step 1: Identify GPIO Pins

**Check router GPIO availability:**

```bash
# View available GPIO
cat /sys/kernel/debug/gpio

# List GPIO exports
ls /sys/class/gpio/
```

**Common routers and GPIO pins:**
- TP-Link WR1043ND: GPIO 8, 7
- TP-Link Archer C7: GPIO 16, 17
- GL.iNet: Various, check documentation

**Choose two available pins:**
- **SDA** (Data line) - Example: GPIO 8
- **SCL** (Clock line) - Example: GPIO 7

### Step 2: Install GPIO I2C Module

```bash
opkg update
opkg install kmod-i2c-gpio-custom
```

### Step 3: Load GPIO I2C Module

```bash
# Load module with custom pin configuration
insmod i2c-gpio-custom bus0=0,8,7
```

**Parameters explained:**
- `bus0` - First I2C bus definition
- `0` - Bus number (i2c-0)
- `8` - GPIO pin for SDA (data)
- `7` - GPIO pin for SCL (clock)

**For different pins:**
```bash
# Example: Using GPIO 16 (SDA) and GPIO 17 (SCL)
insmod i2c-gpio-custom bus0=0,16,17
```

### Step 4: Verify I2C Bus Created

```bash
# Check I2C bus devices
ls /sys/bus/i2c/devices/

# Should show: i2c-0

# Verify GPIO I2C adapter
ls /sys/class/i2c-adapter/i2c-0/

# Check dmesg for confirmation
dmesg | grep i2c-gpio
# Expected: i2c-gpio i2c-gpio.0: using pins 8 (SDA) and 7 (SCL)
```

### Step 5: Physical Connections

**Wire the RTC module to router:**

| RTC Module Pin | Router Connection |
|----------------|-------------------|
| VCC | 3.3V power pin |
| SDA | GPIO 8 (or chosen SDA pin) |
| SCL | GPIO 7 (or chosen SCL pin) |
| GND | Ground |

**Important notes:**
- Ensure CR2032 battery is installed in RTC module
- Most RTC modules have built-in pull-up resistors
- If module lacks pull-ups, add 4.7kΩ resistors between SDA/SCL and VCC

**Connection diagram:**
```
Router                  RTC Module (DS1307/DS3231)
┌────────┐             ┌────────────┐
│ 3.3V   │────────────→│ VCC        │
│ GPIO 8 │←───────────→│ SDA        │
│ GPIO 7 │────────────→│ SCL        │
│ GND    │────────────→│ GND        │
└────────┘             └────────────┘
                        │ Battery    │
                        │ CR2032     │
                        └────────────┘
```

---

## Method 2: USB I2C Adapter

### About USB I2C

USB I2C adapter provides hardware I2C interface via USB port.

**Advantages:**
- No GPIO pins required
- Hardware I2C (faster, more reliable)
- Easy to connect/disconnect
- Standard USB interface

**Popular adapters:**
- i2c-tiny-usb based adapters
- CH341A USB to I2C/SPI adapter
- FTDI-based I2C adapters

### Step 1: Install USB I2C Module

```bash
opkg update
opkg install kmod-i2c-tiny-usb
```

### Step 2: Connect USB Adapter

**Plug USB I2C adapter into router's USB port**

### Step 3: Verify USB I2C Detection

```bash
# Check USB devices
lsusb

# Expected output (example):
# Bus 001 Device 002: ID 0403:c631 Future Technology Devices International

# Check dmesg
dmesg | grep i2c

# Should show i2c-tiny-usb device registration
```

### Step 4: Physical Connections

**Wire RTC module to USB adapter:**

| RTC Module Pin | USB Adapter Pin |
|----------------|-----------------|
| VCC | 3.3V or 5V |
| SDA | SDA |
| SCL | SCL |
| GND | GND |

**Connection diagram:**
```
USB I2C Adapter         RTC Module (DS1307/DS3231)
┌────────────┐         ┌────────────┐
│ VCC (3.3V) │────────→│ VCC        │
│ SDA        │←───────→│ SDA        │
│ SCL        │────────→│ SCL        │
│ GND        │────────→│ GND        │
└────────────┘         └────────────┘
      ↑                 │ Battery    │
      │                 │ CR2032     │
    USB                 └────────────┘
      ↓
┌────────────┐
│   Router   │
│  USB Port  │
└────────────┘
```

---

## RTC Driver Installation

### Step 1: Install RTC Kernel Module

**For DS1307:**
```bash
opkg update
opkg install kmod-rtc-ds1307
```

**For DS3231:**
```bash
opkg install kmod-rtc-ds3231
```

**For PCF8563:**
```bash
opkg install kmod-rtc-pcf8563
```

### Step 2: Load RTC Driver

**Load the module:**
```bash
# For DS1307/DS3231 (both use ds1307 driver)
insmod rtc-ds1307

# Verify module loaded
lsmod | grep rtc
```

### Step 3: Register RTC Device

**Tell the kernel about the RTC chip:**

```bash
# Register DS1307 at address 0x68 on bus i2c-0
echo ds1307 0x68 > /sys/bus/i2c/devices/i2c-0/new_device
```

**For DS3231:**
```bash
echo ds3231 0x68 > /sys/bus/i2c/devices/i2c-0/new_device
```

**For PCF8563:**
```bash
echo pcf8563 0x51 > /sys/bus/i2c/devices/i2c-0/new_device
```

### Step 4: Verify RTC Device Created

```bash
# Check for /dev/rtc0
ls -l /dev/rtc*

# Expected output:
# crw-r--r--    1 root     root      254,   0 Oct 15 14:30 /dev/rtc0

# Check sysfs
ls /sys/class/rtc/
# Should show: rtc0

# Check I2C device
ls /sys/bus/i2c/devices/
# Should show: 0-0068 (or similar)
```

---

## Testing and Verification

### Check RTC Status

**View RTC information via sysfs:**

```bash
# Navigate to RTC device directory
cd /sys/bus/i2c/devices/i2c-0/0-0068/rtc/rtc0/

# Read current date
cat date
# Output: 2023-10-15

# Read current time
cat time
# Output: 14:30:45

# Read RTC name
cat name
# Output: ds1307
```

### Using hwclock Command

**Install hwclock utility:**

```bash
# Usually included in busybox, but if needed:
opkg install hwclock
```

**Read hardware clock:**

```bash
hwclock -r
# Output: Sun Oct 15 14:30:45 2023  0.000000 seconds
```

**Show system time vs hardware time:**

```bash
date
# Output: Sun Oct 15 14:30:50 UTC 2023

hwclock -r
# Output: Sun Oct 15 14:30:45 2023
```

---

## Time Synchronization

### Set RTC from System Time

**After setting correct time via NTP or manually:**

```bash
# Set system time (example)
date -s "2023-10-15 14:30:00"

# Write system time to RTC
hwclock -w

# Verify
hwclock -r
```

### Set System Time from RTC

**On boot or when needed:**

```bash
# Read RTC and set system time
hwclock -s

# Verify system time
date
```

### Automatic NTP Sync and RTC Update

**Script to sync NTP and update RTC:**

```bash
cat > /usr/bin/sync-rtc.sh << 'EOF'
#!/bin/sh
# Sync time from NTP and update RTC

# Wait for network
sleep 10

# Sync with NTP
ntpd -n -q -p pool.ntp.org

# Write to RTC
if [ -e /dev/rtc0 ]; then
    hwclock -w
    logger -t rtc-sync "RTC updated from NTP"
fi
EOF

chmod +x /usr/bin/sync-rtc.sh
```

**Add to cron for daily sync:**

```bash
# Sync daily at 2 AM
echo "0 2 * * * /usr/bin/sync-rtc.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

---

## Persistent Configuration

### Auto-load I2C and RTC Modules

**Create module configuration:**

```bash
# Create file for automatic module loading
cat > /etc/modules.d/50-rtc << 'EOF'
# I2C GPIO support (adjust pins as needed)
i2c-gpio-custom bus0=0,8,7

# RTC driver
rtc-ds1307
EOF
```

**Alternative for USB I2C:**

```bash
cat > /etc/modules.d/50-rtc << 'EOF'
# USB I2C support
i2c-tiny-usb

# RTC driver
rtc-ds1307
EOF
```

### Auto-register RTC Device

**Method 1: Modify sysfixtime init script**

Edit `/etc/init.d/sysfixtime`:

```bash
#!/bin/sh /etc/rc.common

START=00

boot() {
    # Register RTC device
    if [ -d /sys/bus/i2c/devices/i2c-0 ]; then
        echo ds1307 0x68 > /sys/bus/i2c/devices/i2c-0/new_device 2>/dev/null
    fi

    # Wait for RTC device
    sleep 2

    # Restore time from RTC if available
    if [ -e /dev/rtc0 ]; then
        hwclock -s
        logger -t rtc "System time restored from RTC"
    else
        # Original sysfixtime behavior
        [ -e /tmp/TZ ] && cat /tmp/TZ > /etc/TZ
        [ -e /etc/timestamp ] && date -s @$(cat /etc/timestamp)
    fi
}
```

**Method 2: Create dedicated RTC init script**

```bash
cat > /etc/init.d/rtc << 'EOF'
#!/bin/sh /etc/rc.common

START=01
STOP=99

start() {
    # Wait for I2C bus
    sleep 1

    # Register RTC device
    if [ -d /sys/bus/i2c/devices/i2c-0 ]; then
        echo ds1307 0x68 > /sys/bus/i2c/devices/i2c-0/new_device 2>/dev/null
        logger -t rtc "RTC device registered"
    fi

    # Wait for device creation
    sleep 2

    # Set system time from RTC
    if [ -e /dev/rtc0 ]; then
        hwclock -s
        logger -t rtc "System time set from RTC: $(date)"
    else
        logger -t rtc "ERROR: /dev/rtc0 not found"
    fi
}

stop() {
    # Save system time to RTC before shutdown
    if [ -e /dev/rtc0 ]; then
        hwclock -w
        logger -t rtc "RTC updated before shutdown"
    fi
}
EOF

chmod +x /etc/init.d/rtc
/etc/init.d/rtc enable
```

### Save Time Before Shutdown/Reboot

**Ensure RTC is updated on shutdown:**

Add to `/etc/rc.local` (before `exit 0`):

```bash
# Save time to RTC on shutdown
trap 'hwclock -w' EXIT
```

---

## Troubleshooting

### RTC Device Not Created

**Problem:** `/dev/rtc0` doesn't exist.

**Solutions:**

1. **Check I2C bus exists:**
   ```bash
   ls /sys/bus/i2c/devices/
   # Should show i2c-0
   ```

2. **Verify module loaded:**
   ```bash
   lsmod | grep rtc
   lsmod | grep i2c
   ```

3. **Check dmesg for errors:**
   ```bash
   dmesg | grep -i rtc
   dmesg | grep -i i2c
   ```

4. **Verify RTC chip detected:**
   ```bash
   i2cdetect -y 0
   # Should show device at 0x68
   ```

5. **Try re-registering:**
   ```bash
   echo ds1307 0x68 > /sys/bus/i2c/devices/i2c-0/new_device
   ```

### I2C Bus Not Found

**Problem:** `i2c-0` doesn't exist in `/sys/bus/i2c/devices/`.

**Solutions:**

1. **Check module loaded:**
   ```bash
   lsmod | grep i2c-gpio
   ```

2. **Reload with correct pins:**
   ```bash
   rmmod i2c-gpio-custom
   insmod i2c-gpio-custom bus0=0,8,7
   ```

3. **Check GPIO pins available:**
   ```bash
   cat /sys/kernel/debug/gpio
   ```

### Wrong Time After Boot

**Problem:** Time is incorrect after reboot.

**Solutions:**

1. **Verify RTC has correct time:**
   ```bash
   hwclock -r
   ```

2. **Set RTC manually:**
   ```bash
   date -s "2023-10-15 14:30:00"
   hwclock -w
   ```

3. **Check battery:**
   - Replace CR2032 if voltage < 3V
   - Measure with multimeter

4. **Verify hwclock -s runs at boot:**
   ```bash
   logread | grep rtc
   ```

### I2C Communication Errors

**Problem:** `i2cdetect` shows `UU` instead of `68`.

**This is normal!** `UU` means device is in use by a driver.

**If shows `--` at 0x68:**
- Check wiring connections
- Verify module has power (3.3V)
- Check pull-up resistors
- Try different I2C speed (add delay parameter)

---

## Advanced Configuration

### Multiple RTC Devices

**If you have multiple I2C devices:**

```bash
# Register first RTC on i2c-0
echo ds1307 0x68 > /sys/bus/i2c/devices/i2c-0/new_device

# Register second RTC on i2c-1 (if available)
echo ds3231 0x68 > /sys/bus/i2c/devices/i2c-1/new_device
```

### Custom I2C Speed

**Adjust I2C clock speed (for reliability):**

```bash
# Slower speed for long wires or noise
insmod i2c-gpio-custom bus0=0,8,7,100
# Last parameter is delay in μs (lower = faster)
```

### RTC with Temperature Sensor (DS3231)

**Read temperature from DS3231:**

```bash
# Install i2c-tools
opkg install i2c-tools

# Read temperature register (0x11)
i2cget -y 0 0x68 0x11

# Convert to Celsius (example output: 0x19 = 25°C)
```

### Wakealarm Feature

**Some RTCs support wake-from-sleep:**

```bash
# Check if wakealarm supported
cat /sys/class/rtc/rtc0/wakealarm

# Set alarm (Unix timestamp)
echo $(date -d '+5 minutes' +%s) > /sys/class/rtc/rtc0/wakealarm
```

---

## Best Practices

### 1. Regular NTP Sync

```bash
# Daily sync from NTP to correct drift
echo "0 2 * * * ntpd -n -q && hwclock -w" >> /etc/crontabs/root
```

### 2. Battery Replacement

```bash
# Replace CR2032 every 3-5 years
# Monitor voltage if possible
# Set time after battery replacement
```

### 3. Backup Configuration

```bash
# Save current time before major changes
hwclock -r > /tmp/rtc_time_backup.txt
```

### 4. Logging

```bash
# Log RTC operations
logger -t rtc "Time restored from RTC: $(date)"
```

### 5. Use DS3231 for Critical Applications

```bash
# DS3231 is more accurate and temperature-compensated
# Recommended for time-critical systems
```

---

## References

### Official Documentation
- **DS1307 Datasheet:** https://datasheets.maximintegrated.com/en/ds/DS1307.pdf
- **DS3231 Datasheet:** https://datasheets.maximintegrated.com/en/ds/DS3231.pdf
- **Linux RTC Documentation:** https://www.kernel.org/doc/Documentation/rtc.txt

### Related Pages
- **eko.one.pl RTC Guide:** https://eko.one.pl/?p=openwrt-rtc
- **OpenWRT Hardware:** https://openwrt.org/docs/guide-user/hardware/

### Tools and Libraries
- **i2c-tools:** I2C bus utilities
- **hwclock:** Hardware clock management
- **kmod-i2c-gpio-custom:** GPIO I2C module

---

## Summary

Adding RTC to OpenWRT provides reliable timekeeping independent of network:

**Key Benefits:**
- Accurate time from boot
- No internet dependency
- Battery-backed time retention
- SSL/TLS compatibility

**Implementation Methods:**
1. **GPIO I2C** - Software I2C using GPIO pins
2. **USB I2C** - Hardware I2C via USB adapter

**Quick Setup (GPIO method):**
```bash
# Install packages
opkg install kmod-i2c-gpio-custom kmod-rtc-ds1307

# Load modules (adjust GPIO pins)
insmod i2c-gpio-custom bus0=0,8,7
insmod rtc-ds1307

# Register RTC
echo ds1307 0x68 > /sys/bus/i2c/devices/i2c-0/new_device

# Set time from RTC
hwclock -s

# Save time to RTC
hwclock -w
```

**Recommended RTC:**
- **DS1307** - Budget option, adequate accuracy
- **DS3231** - Best choice for precision (±2 min/year)

**Persistent Configuration:**
- Auto-load modules via `/etc/modules.d/`
- Auto-register device in init script
- Restore time on boot with `hwclock -s`

This solution ensures your OpenWRT router maintains accurate time regardless of network connectivity.

---

*This guide is based on the eko.one.pl RTC configuration tutorial and Linux RTC subsystem documentation.*
