# eSIM Profile Management with lpac via USB Modem Guide

## Table of Contents
1. [Overview](#overview)
2. [What is lpac](#what-is-lpac)
3. [What is eSIM](#what-is-esim)
4. [Prerequisites](#prerequisites)
5. [System Requirements](#system-requirements)
6. [Installation](#installation)
7. [Building lpac with AT APDU Support](#building-lpac-with-at-apdu-support)
8. [Device Configuration](#device-configuration)
9. [Service Management](#service-management)
10. [lpac Operations](#lpac-operations)
11. [Profile Management](#profile-management)
12. [Quectel Modem Specific Configuration](#quectel-modem-specific-configuration)
13. [Troubleshooting](#troubleshooting)
14. [Advanced Usage](#advanced-usage)
15. [Best Practices](#best-practices)
16. [References](#references)

---

## Overview

This guide explains how to download and manage eSIM profiles on eSIM adapters or USB modems using **lpac** (Local Profile Assistant Client) without requiring a traditional smart card reader. By using AT+APDU commands over a USB modem's serial interface, you can manage eSIM profiles directly from Linux systems.

**Key Capabilities:**
- Download eSIM profiles via USB modem
- Manage multiple eSIM profiles
- Switch between profiles
- Delete profiles
- No smart card reader required

**Use Cases:**
- eSIM adapter management
- Cellular modem eSIM configuration
- Remote eSIM provisioning
- Multi-profile management for travel or testing

---

## What is lpac

### lpac - Local Profile Assistant Client

**lpac** is an open-source implementation of the Local Profile Assistant (LPA) for managing eSIM profiles.

**Official Repository:** https://github.com/estkme-group/lpac

**Features:**
- Download eSIM profiles from SM-DP+ servers
- List installed profiles
- Enable/disable profiles
- Delete profiles
- Set default profile
- Query profile information

**Communication Methods:**
- **PC/SC** - Smart card reader interface (traditional)
- **AT+APDU** - Serial AT commands (USB modem method)

**Standards Compliance:**
- GSMA SGP.22 (RSP Technical Specification)
- GlobalPlatform Secure Element Access Control

---

## What is eSIM

### eSIM - Embedded SIM

**eSIM** is a digital SIM that allows you to activate a cellular plan without using a physical SIM card.

**Key Differences from Physical SIM:**

| Feature | Physical SIM | eSIM |
|---------|--------------|------|
| Form Factor | Removable card | Embedded chip or adapter |
| Activation | Insert card | Download profile |
| Multiple Profiles | Swap cards | Switch digitally |
| Remote Provisioning | No | Yes (OTA) |

**eSIM Architecture:**
- **eUICC** - Embedded Universal Integrated Circuit Card (the chip)
- **SM-DP+** - Subscription Manager Data Preparation (profile server)
- **SM-DS** - Subscription Manager Discovery Service
- **LPA** - Local Profile Assistant (client software like lpac)

**Profile Download Process:**
```
User → LPA (lpac) → SM-DP+ Server → eSIM Profile → eUICC
```

---

## Prerequisites

### Knowledge Requirements

- Basic Linux command line
- Understanding of USB serial devices
- Familiarity with cellular modems
- Basic AT command knowledge

### Hardware Requirements

**eSIM-capable device (one of):**
- USB modem with embedded eSIM (e.g., certain Quectel models)
- eSIM adapter with USB interface
- eUICC chip accessible via USB modem

**Computer:**
- Linux system (Arch, Fedora, Debian, Ubuntu, etc.)
- Available USB port
- Internet connection (separate from modem)

**Network:**
- Active internet connection for profile downloads
- Can be WiFi, Ethernet, or different cellular connection

### Software Requirements

**Build tools:**
- GCC/G++ compiler
- CMake (3.0+)
- Make

**Libraries:**
- libcurl (with development headers)
- pcsclite (PC/SC Smart Card library)
- jq (JSON processor, optional but recommended)

---

## System Requirements

### Linux Distributions

**Tested distributions:**
- Arch Linux / EndeavorOS / Manjaro
- Fedora / Rocky Linux / AlmaLinux
- Debian / Ubuntu / Linux Mint
- OpenWRT (with custom build)

### Package Installation

#### Arch Linux / EndeavorOS / Manjaro

```bash
sudo pacman -S pcsclite pcsc-tools libcurl-compat cmake make gcc git jq
```

**Packages:**
- `pcsclite` - PC/SC smart card library
- `pcsc-tools` - PC/SC testing tools
- `libcurl-compat` - Compatible libcurl version
- `cmake` - Build system
- `make` - Build tool
- `gcc` - C compiler
- `git` - Version control (for cloning lpac)
- `jq` - JSON processor

#### Fedora / Rocky Linux / AlmaLinux

```bash
sudo dnf install libcurl libcurl-devel pcsc-lite-devel pcsc-lite-libs pcsc-lite pcsc-tools cmake make gcc git jq
```

**Packages:**
- `libcurl` - HTTP client library
- `libcurl-devel` - Development headers
- `pcsc-lite-devel` - PC/SC development files
- `pcsc-lite-libs` - PC/SC runtime libraries
- `pcsc-lite` - PC/SC daemon
- `pcsc-tools` - Testing utilities

#### Debian / Ubuntu / Linux Mint

```bash
sudo apt-get update
sudo apt-get install build-essential libpcsclite-dev libcurl4-openssl-dev cmake git jq zip
```

**Packages:**
- `build-essential` - GCC, Make, etc.
- `libpcsclite-dev` - PC/SC development files
- `libcurl4-openssl-dev` - libcurl with OpenSSL
- `cmake` - Build system
- `git` - Version control
- `jq` - JSON processor
- `zip` - Archive utility

---

## Installation

### Step 1: Clone lpac Repository

```bash
# Create workspace directory
mkdir -p ~/esim-tools
cd ~/esim-tools

# Clone lpac repository
git clone https://github.com/estkme-group/lpac.git
cd lpac

# Check latest release (optional)
git tag
git checkout <latest-version>  # e.g., v2.0.0
```

### Step 2: Verify Dependencies

```bash
# Check cmake
cmake --version

# Check compiler
gcc --version

# Check libcurl
pkg-config --modversion libcurl

# Check pcsclite
pkg-config --modversion libpcsclite
```

---

## Building lpac with AT APDU Support

### Standard Build Process

```bash
# Navigate to lpac source directory
cd ~/esim-tools/lpac

# Configure with AT APDU support enabled
cmake . -DLPAC_WITH_APDU_AT=1

# Build
make

# Verify build
ls -lh output/lpac
```

**Expected output:**
```
-rwxr-xr-x 1 user user 2.5M Oct 15 14:30 output/lpac
```

### Build Options

**Available CMake options:**

```bash
# Enable AT APDU support (required for USB modem)
-DLPAC_WITH_APDU_AT=1

# Enable PCSC support (for smart card readers)
-DLPAC_WITH_APDU_PCSC=1

# Build static binary
-DLPAC_DYNAMIC_LIBCURL=OFF

# Enable debug symbols
-DCMAKE_BUILD_TYPE=Debug
```

**Example - Build with both AT and PCSC support:**

```bash
cmake . -DLPAC_WITH_APDU_AT=1 -DLPAC_WITH_APDU_PCSC=1
make clean
make
```

### Installation (Optional)

```bash
# Install to system
sudo make install

# Or copy to user bin
mkdir -p ~/.local/bin
cp output/lpac ~/.local/bin/
export PATH=$PATH:~/.local/bin
```

---

## Device Configuration

### Identify USB Modem Serial Device

**Method 1: Using dmesg**

```bash
# Monitor kernel messages while plugging in modem
sudo dmesg -w
```

**Plug in USB modem and observe output:**

```
[12345.678] usb 1-2: new high-speed USB device number 5 using xhci_hcd
[12345.789] usb 1-2: New USB device found, idVendor=2c7c, idProduct=0125
[12345.790] usb 1-2: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[12345.791] usb 1-2: Product: Android
[12345.792] usb 1-2: Manufacturer: Android
[12345.793] option 1-2:1.0: GSM modem (1-port) converter detected
[12345.794] usb 1-2: GSM modem (1-port) converter now attached to ttyUSB0
[12345.795] option 1-2:1.1: GSM modem (1-port) converter detected
[12345.796] usb 1-2: GSM modem (1-port) converter now attached to ttyUSB1
[12345.797] option 1-2:1.2: GSM modem (1-port) converter detected
[12345.798] usb 1-2: GSM modem (1-port) converter now attached to ttyUSB2
[12345.799] option 1-2:1.3: GSM modem (1-port) converter detected
[12345.800] usb 1-2: GSM modem (1-port) converter now attached to ttyUSB3
```

**Common devices:**
- `/dev/ttyUSB2` - Often the AT command interface
- `/dev/ttyACM2` - Alternative on some systems

**Method 2: List USB serial devices**

```bash
# List all ttyUSB devices
ls -l /dev/ttyUSB*

# Or ttyACM devices
ls -l /dev/ttyACM*
```

**Method 3: Using lsusb**

```bash
# List USB devices
lsusb

# Example output:
# Bus 001 Device 005: ID 2c7c:0125 Quectel Wireless Solutions Co., Ltd. EC25 LTE modem
```

### Determine Correct Serial Port

**Quectel modems typically expose:**
- `/dev/ttyUSB0` - DM (Diagnostic)
- `/dev/ttyUSB1` - NMEA (GPS)
- `/dev/ttyUSB2` - AT Commands (use this for lpac)
- `/dev/ttyUSB3` - PPP/Data

**Test with AT commands:**

```bash
# Test each port
echo -e "AT\r" | sudo tee /dev/ttyUSB2

# Should respond:
# AT
# OK
```

### Check Device Permissions

```bash
# Check device ownership
ls -l /dev/ttyUSB2

# Example output:
# crw-rw---- 1 root uucp 188, 2 Oct 15 14:30 /dev/ttyUSB2
```

**Group ownership:**
- Usually `uucp`, `dialout`, or `tty`

### Add User to Device Group

**Find your groups:**
```bash
groups
```

**Add user to uucp group (Arch):**
```bash
sudo usermod -aG uucp $USER
```

**Add user to dialout group (Debian/Ubuntu):**
```bash
sudo usermod -aG dialout $USER
```

**Verify membership:**
```bash
groups

# Or force reload
newgrp uucp
```

**Log out and back in for changes to take effect**

### Set Device Permissions (Alternative)

**Temporary (until reboot):**
```bash
sudo chmod 666 /dev/ttyUSB2
```

**Persistent via udev rule:**

Create `/etc/udev/rules.d/99-esim-modem.rules`:

```bash
# Quectel modems
SUBSYSTEM=="tty", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0125", MODE="0666"

# Generic rule for all USB serial
SUBSYSTEM=="tty", KERNEL=="ttyUSB*", MODE="0666"
```

**Reload udev rules:**
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

---

## Service Management

### Stop Interfering Services

**ModemManager:**

ModemManager may interfere with direct AT command access.

```bash
# Check if ModemManager is running
systemctl status ModemManager

# Stop ModemManager
sudo systemctl stop ModemManager

# Disable on boot (optional)
sudo systemctl disable ModemManager

# Restart when done
sudo systemctl start ModemManager
```

**NetworkManager:**

Usually doesn't need to be stopped, but if issues persist:

```bash
sudo systemctl stop NetworkManager
# Perform lpac operations
sudo systemctl start NetworkManager
```

**Alternative: Blacklist specific device**

Create `/etc/udev/rules.d/77-mm-usb-device-blacklist.rules`:

```bash
# Blacklist specific Quectel modem from ModemManager
ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0125", ENV{ID_MM_DEVICE_IGNORE}="1"
```

Reload:
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo systemctl restart ModemManager
```

---

## lpac Operations

### Environment Variables

**Set up environment for AT APDU:**

```bash
export LPAC_APDU=at
export AT_DEVICE=/dev/ttyUSB2
```

**Persistent setup (add to `~/.bashrc` or `~/.bash_profile`):**

```bash
echo 'export LPAC_APDU=at' >> ~/.bashrc
echo 'export AT_DEVICE=/dev/ttyUSB2' >> ~/.bashrc
source ~/.bashrc
```

### Basic Commands

**Test connectivity:**

```bash
LPAC_APDU=at AT_DEVICE=/dev/ttyUSB2 output/lpac chip info
```

**With environment variables set:**

```bash
output/lpac chip info
```

**Pretty-print JSON output:**

```bash
output/lpac chip info | jq
```

**Example output:**

```json
{
  "eidValue": "89049032004008882600011234567890",
  "sasAccreditationNumber": ""
}
```

### Chip Information

**Get eUICC chip info:**

```bash
output/lpac chip info | jq
```

**Response fields:**
- `eidValue`: eUICC Identifier (EID) - unique chip ID
- `sasAccreditationNumber`: SAS accreditation (if applicable)

---

## Profile Management

### List Profiles

**Show all installed profiles:**

```bash
output/lpac profile list | jq
```

**Example output:**

```json
[
  {
    "iccid": "8901234567890123456",
    "isdpAid": "A0000005591010FFFFFFFF8900000100",
    "profileState": "enabled",
    "profileNickname": "My Carrier",
    "serviceProviderName": "Carrier Name",
    "profileName": "Profile 1",
    "profileClass": "operational"
  }
]
```

### Download Profile

**Basic download:**

```bash
output/lpac profile download -s "smdp.io" -m "ACTIVATION-CODE"
```

**Parameters:**
- `-s` or `--smdp`: SM-DP+ server address
- `-m` or `--matching-id`: Activation code / Matching ID

**Example with real activation code:**

```bash
output/lpac profile download -s "smdp.io" -m "K2-GH4JFI-D9JI"
```

**Example with full activation URL:**

```bash
# If you have QR code data like: LPA:1$smdp.example.com$ACTIVATION-CODE
output/lpac profile download -s "smdp.example.com" -m "ACTIVATION-CODE"
```

**With confirmation code (if required):**

```bash
output/lpac profile download -s "smdp.io" -m "ACTIVATION-CODE" -c "CONFIRMATION-CODE"
```

**Download process:**

1. lpac connects to SM-DP+ server via internet
2. Authenticates with activation code
3. Downloads encrypted profile
4. Installs profile on eUICC
5. Profile ready to enable

**Expected output:**

```
Downloading profile...
Profile downloaded successfully
ICCID: 8901234567890123456
```

### Enable Profile

**Enable specific profile:**

```bash
output/lpac profile enable -i "ICCID"
```

**Example:**

```bash
output/lpac profile enable -i "8901234567890123456"
```

**Note:** Only one profile can be enabled at a time (on most eUICC).

### Disable Profile

**Disable profile:**

```bash
output/lpac profile disable -i "ICCID"
```

**Example:**

```bash
output/lpac profile disable -i "8901234567890123456"
```

### Delete Profile

**Delete profile permanently:**

```bash
output/lpac profile delete -i "ICCID"
```

**Example:**

```bash
output/lpac profile delete -i "8901234567890123456"
```

**Warning:** This action is irreversible. Profile must be re-downloaded if needed.

### Set Profile Nickname

**Set custom nickname:**

```bash
output/lpac profile nickname -i "ICCID" -n "My Custom Name"
```

**Example:**

```bash
output/lpac profile nickname -i "8901234567890123456" -n "Travel SIM"
```

---

## Quectel Modem Specific Configuration

### Quectel eUICC Support

**Quectel modems with eSIM/eUICC:**
- EM05-G
- EM12-G
- RM500Q-GL
- And others (check Quectel documentation)

### Additional Patching Required

**Note from source:** "Quectel modems require additional patching before building."

**Potential patches may include:**
- Custom AT command sequences
- Modified APDU handling
- Timing adjustments

**Check lpac GitHub issues:**
- Search for "Quectel" in issues/discussions
- Look for patches or workarounds
- Community may have Quectel-specific forks

### Quectel AT Commands

**Check eUICC status (Quectel-specific):**

```bash
# Via AT commands
echo -e "AT+QSIMSTAT?\r" | sudo tee /dev/ttyUSB2
```

**Switch to embedded SIM:**

```bash
echo -e "AT+QDSIM=1,1\r" | sudo tee /dev/ttyUSB2
```

**Parameters:**
- First `1`: SIM slot (1=embedded eSIM, 2=physical SIM)
- Second `1`: Enable

---

## Troubleshooting

### lpac Cannot Access Device

**Problem:** Permission denied accessing `/dev/ttyUSB2`

**Solutions:**

1. **Check user groups:**
   ```bash
   groups
   # Should include uucp or dialout
   ```

2. **Add to group:**
   ```bash
   sudo usermod -aG uucp $USER
   # Log out and back in
   ```

3. **Temporary permission:**
   ```bash
   sudo chmod 666 /dev/ttyUSB2
   ```

### ModemManager Interference

**Problem:** Device busy or commands fail

**Solutions:**

```bash
# Stop ModemManager
sudo systemctl stop ModemManager

# Perform lpac operations
output/lpac chip info

# Restart ModemManager
sudo systemctl start ModemManager
```

### Profile Download Fails

**Problem:** "Failed to download profile" error

**Solutions:**

1. **Check internet connection:**
   ```bash
   ping -c 3 google.com
   ```

2. **Verify activation code:**
   - Check for typos
   - Ensure code is still valid
   - Some codes are single-use

3. **Verify SM-DP+ address:**
   - Correct server address
   - Check QR code data

4. **Check eUICC has space:**
   ```bash
   output/lpac profile list | jq
   # Some eUICC limited to 5-10 profiles
   ```

### No Response from eUICC

**Problem:** lpac hangs or timeout

**Solutions:**

1. **Verify correct serial port:**
   ```bash
   # Test with AT commands
   echo -e "AT\r" | sudo tee /dev/ttyUSB2
   ```

2. **Check modem is powered on:**
   ```bash
   lsusb | grep Quectel
   ```

3. **Try different serial port:**
   ```bash
   export AT_DEVICE=/dev/ttyUSB3
   output/lpac chip info
   ```

4. **Increase timeout (if lpac supports):**
   - Check lpac documentation for timeout options

### Build Errors

**Problem:** cmake or make fails

**Solutions:**

1. **Missing dependencies:**
   ```bash
   # Reinstall all dependencies
   sudo apt-get install build-essential libpcsclite-dev libcurl4-openssl-dev cmake
   ```

2. **CMake version too old:**
   ```bash
   cmake --version
   # Upgrade CMake if < 3.0
   ```

3. **Clean build:**
   ```bash
   make clean
   rm -rf CMakeCache.txt CMakeFiles/
   cmake . -DLPAC_WITH_APDU_AT=1
   make
   ```

---

## Advanced Usage

### Script Automation

**Automated profile management script:**

```bash
#!/bin/bash
# esim-manager.sh

export LPAC_APDU=at
export AT_DEVICE=/dev/ttyUSB2
LPAC=~/esim-tools/lpac/output/lpac

# Stop ModemManager
sudo systemctl stop ModemManager

# List profiles
echo "=== Current Profiles ==="
$LPAC profile list | jq

# Download new profile (if activation code provided)
if [ -n "$1" ]; then
    echo "=== Downloading Profile ==="
    $LPAC profile download -s "smdp.io" -m "$1"
fi

# Restart ModemManager
sudo systemctl start ModemManager
```

**Usage:**
```bash
chmod +x esim-manager.sh
./esim-manager.sh ACTIVATION-CODE
```

### Batch Profile Download

**Download multiple profiles:**

```bash
#!/bin/bash
export LPAC_APDU=at
export AT_DEVICE=/dev/ttyUSB2
LPAC=~/esim-tools/lpac/output/lpac

# Array of activation codes
CODES=(
    "CODE1-XXXX-XXXX"
    "CODE2-XXXX-XXXX"
    "CODE3-XXXX-XXXX"
)

for code in "${CODES[@]}"; do
    echo "Downloading: $code"
    $LPAC profile download -s "smdp.io" -m "$code"
    sleep 2
done
```

### Profile Switching

**Switch between profiles:**

```bash
#!/bin/bash
# switch-profile.sh

export LPAC_APDU=at
export AT_DEVICE=/dev/ttyUSB2
LPAC=~/esim-tools/lpac/output/lpac

TARGET_ICCID="$1"

if [ -z "$TARGET_ICCID" ]; then
    echo "Usage: $0 <ICCID>"
    exit 1
fi

# Disable all profiles
$LPAC profile list | jq -r '.[].iccid' | while read iccid; do
    echo "Disabling: $iccid"
    $LPAC profile disable -i "$iccid"
done

# Enable target profile
echo "Enabling: $TARGET_ICCID"
$LPAC profile enable -i "$TARGET_ICCID"

echo "Profile switched to: $TARGET_ICCID"
```

---

## Best Practices

### 1. Always Stop ModemManager

```bash
# Before lpac operations
sudo systemctl stop ModemManager

# After operations
sudo systemctl start ModemManager
```

### 2. Verify Device Before Operations

```bash
# Quick test
echo -e "AT\r" | sudo tee /dev/ttyUSB2
# Should see: AT\nOK
```

### 3. Keep Activation Codes Secure

```bash
# Don't share activation codes
# Store securely (password manager)
# Treat like passwords
```

### 4. Backup Profile List

```bash
# Save profile list
output/lpac profile list | jq > ~/esim-profiles-backup.json
```

### 5. Internet Connection Separate from Modem

- Use WiFi or Ethernet for profile downloads
- Don't rely on the modem's cellular connection during eSIM operations

### 6. Test on Non-Critical Profile First

- Download and test with a trial/test eSIM first
- Verify operations before using important profiles

---

## References

### Official Resources

**lpac GitHub:**
- Repository: https://github.com/estkme-group/lpac
- Issues: https://github.com/estkme-group/lpac/issues
- Documentation: https://github.com/estkme-group/lpac/wiki

**Original Guide:**
- Soprani.ca Wiki: https://wiki.soprani.ca/eSIM%20Adapter/lpac%20via%20USB%20modem

### Standards

**GSMA SGP.22:**
- RSP Technical Specification
- URL: https://www.gsma.com/esim/

**GlobalPlatform:**
- Secure Element specifications
- URL: https://globalplatform.org/

### Community

**OpenWRT Forum:**
- eSIM discussions
- URL: https://forum.openwrt.org/

**Quectel:**
- Modem documentation
- URL: https://www.quectel.com/

---

## Summary

lpac enables eSIM profile management via USB modem without smart card reader:

**Key Benefits:**
- No smart card reader required
- Works with eSIM adapters and USB modems
- Open-source and free
- Cross-platform (Linux)

**Basic Workflow:**

```bash
# 1. Setup
export LPAC_APDU=at
export AT_DEVICE=/dev/ttyUSB2

# 2. Stop ModemManager
sudo systemctl stop ModemManager

# 3. Check chip
output/lpac chip info | jq

# 4. Download profile
output/lpac profile download -s "smdp.io" -m "ACTIVATION-CODE"

# 5. List profiles
output/lpac profile list | jq

# 6. Enable profile
output/lpac profile enable -i "ICCID"

# 7. Restart ModemManager
sudo systemctl start ModemManager
```

**Requirements:**
- lpac built with `-DLPAC_WITH_APDU_AT=1`
- USB modem with eSIM/eUICC support
- Separate internet connection for downloads
- Linux system with proper permissions

**Quectel Note:**
- May require additional patches
- Check lpac GitHub for Quectel-specific issues

This solution provides a flexible, cost-effective way to manage eSIM profiles on compatible USB modems and adapters using open-source tools.

---

*This guide is based on the Soprani.ca wiki documentation and the lpac project specifications.*
