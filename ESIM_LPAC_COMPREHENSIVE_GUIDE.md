# lpac - Local Profile Assistant Client Comprehensive Guide

## Table of Contents
1. [Overview](#overview)
2. [What is lpac](#what-is-lpac)
3. [How lpac Works](#how-lpac-works)
4. [Hardware Requirements](#hardware-requirements)
5. [Compatible Devices](#compatible-devices)
6. [Linux Setup](#linux-setup)
7. [Windows Setup](#windows-setup)
8. [macOS Setup](#macos-setup)
9. [Core Commands](#core-commands)
10. [Profile Management](#profile-management)
11. [Advanced Operations](#advanced-operations)
12. [Troubleshooting](#troubleshooting)
13. [Common Issues and Solutions](#common-issues-and-solutions)
14. [Best Practices](#best-practices)
15. [Security Considerations](#security-considerations)
16. [Integration Examples](#integration-examples)
17. [References](#references)

---

## Overview

**lpac** (Local Profile Assistant Client) is a command-line utility for managing eSIM profiles on compatible devices through smart card readers or direct modem interfaces. It provides complete control over eSIM profile lifecycle including download, installation, activation, deactivation, and deletion.

**Key Features:**
- Command-line interface for automated eSIM management
- Works with JMP eSIM Adapters and other eUICC devices
- Supports multiple profile management
- Cross-platform compatibility (Linux, Windows, macOS)
- Open-source implementation of SGP.22 specification
- No proprietary software required

**Use Cases:**
- IoT device provisioning
- Travel router eSIM management
- Multi-profile mobile devices
- Automated carrier switching
- Development and testing environments

---

## What is lpac

### Technical Definition

**lpac** is an open-source implementation of the **SGP.22 (RSP) specification** for Remote SIM Provisioning. It acts as a **Local Profile Assistant (LPA)** that communicates with eUICC (embedded Universal Integrated Circuit Card) to manage eSIM profiles.

### Components

**lpac consists of:**
- **ES10x Interface** - eUICC communication protocol
- **APDU Driver** - Low-level communication with smart card
- **Profile Manager** - High-level profile operations
- **Network Client** - SM-DP+ server communication

### Architecture

```
┌─────────────────────────────────────────┐
│           User / Application            │
└──────────────────┬──────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────┐
│         lpac (Command Line Tool)        │
│  ┌─────────────────────────────────┐   │
│  │     Profile Management Logic     │   │
│  └────────────┬────────────────────┘   │
│               │                          │
│  ┌────────────▼────────────────────┐   │
│  │     ES10x Protocol Handler       │   │
│  └────────────┬────────────────────┘   │
│               │                          │
│  ┌────────────▼────────────────────┐   │
│  │        APDU Driver Layer         │   │
│  │  (PC/SC, AT, HTTP, QMI, etc.)   │   │
│  └────────────┬────────────────────┘   │
└───────────────┼─────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────┐
│     eUICC / eSIM Chip (Smart Card)     │
└─────────────────────────────────────────┘
```

### Standards Compliance

**lpac implements:**
- **SGP.22 v3.0** - RSP Architecture for Consumer Devices
- **SGP.02** - Remote Provisioning Architecture for M2M
- **GlobalPlatform Card Specification** - Secure Element management
- **ETSI TS 102 221** - Smart card interface

---

## How lpac Works

### Profile Download Process

**Step-by-step workflow:**

1. **User initiates download:**
   ```bash
   lpac profile download -s smdp.example.com -m ACTIVATION-CODE
   ```

2. **lpac connects to SM-DP+ server:**
   - Establishes TLS connection
   - Authenticates using activation code
   - Retrieves profile metadata

3. **eUICC authentication:**
   - lpac queries eUICC for challenge
   - SM-DP+ server validates eUICC certificate
   - Mutual authentication established

4. **Profile download:**
   - Encrypted profile package downloaded from SM-DP+
   - Profile transmitted in segments (APDU commands)
   - eUICC decrypts and installs profile

5. **Installation verification:**
   - Profile ICCID registered
   - Profile state set (enabled/disabled)
   - Confirmation sent to SM-DP+ server

### Communication Flow

```
User
  │
  │  lpac profile download -s [SM-DP+] -m [CODE]
  ▼
lpac (Local Profile Assistant)
  │
  │  ES10x Commands (APDU)
  ▼
eUICC Chip
  │
  │  HTTPS/TLS
  ▼
SM-DP+ Server (Subscription Manager Data Preparation)
  │
  │  Profile Package
  ▼
eUICC Chip (Decrypts and Installs)
```

### APDU Communication

**Application Protocol Data Unit (APDU):**

lpac sends commands to eUICC using APDU format:
```
Command APDU: [CLA] [INS] [P1] [P2] [Lc] [Data] [Le]
Response APDU: [Data] [SW1] [SW2]
```

**Example ES10x command sequence:**
```bash
# Get EID (eUICC Identifier)
APDU: 80 E2 91 00 [...]
Response: [EID Data] 90 00

# Download profile
APDU: 80 E2 BD 00 [Profile Data]
Response: 90 00 (Success)
```

---

## Hardware Requirements

### Smart Card Readers

**Compatible reader types:**

1. **USB Smart Card Readers**
   - PC/SC compatible readers
   - ISO 7816 compliant
   - USB 2.0 or higher

2. **Internal Card Readers**
   - Built-in laptop readers
   - SD card readers (if adapter used)

3. **Cellular Modems**
   - Quectel series (EC25, EM12, RM500Q)
   - Sierra Wireless modems
   - Other AT command compatible modems

### Recommended Readers

**Popular USB readers:**

| Model | Interface | Notes |
|-------|-----------|-------|
| Generic USB CCID | USB | Most common, widely available |
| Identiv SCR3500 | USB | Professional grade |
| Gemalto IDBridge CT30 | USB | High reliability |
| ACR39U | USB | Budget-friendly |

**Adapter-specific:**
- **JMP eSIM Adapter** - Designed specifically for lpac
- Standard SIM card adapters (Mini → Standard, Nano → Standard)

### eSIM Chips / eUICC Devices

**Compatible eUICC:**
- JMP eSIM Adapter (recommended)
- eUICC-enabled cellular modems
- Standalone eUICC chips (development boards)
- eSIM-capable smartphones (with root access)

---

## Compatible Devices

### Tested Hardware

**Smart Card Readers:**
✅ Generic USB CCID readers (most common)
✅ Built-in laptop smart card readers
✅ ACR39U USB reader
✅ Identiv SCR3500

**Cellular Modems:**
✅ Quectel EC25
✅ Quectel EM12
✅ Quectel RM500Q
✅ Sierra Wireless EM7455
⚠️ Others - may require patching

**eSIM Adapters:**
✅ JMP eSIM Adapter (primary target)
✅ Various eUICC development boards

### Platform Support

**Operating Systems:**
- ✅ Linux (all major distributions)
- ✅ Windows 10/11
- ✅ macOS
- ✅ OpenWRT (embedded routers)
- ✅ FreeBSD (experimental)

**Architectures:**
- x86_64 (Intel/AMD)
- ARM64 (Raspberry Pi, etc.)
- ARMv7 (older ARM devices)

---

## Linux Setup

### Prerequisites

**Required packages:**

```bash
# Debian/Ubuntu
sudo apt update
sudo apt install pcscd libpcsclite-dev libccid

# Fedora/RHEL
sudo dnf install pcsc-lite pcsc-lite-ccid

# Arch Linux
sudo pacman -S pcsclite ccid

# Alpine Linux
apk add pcsc-lite pcsc-lite-libs ccid
```

**Check if pcscd pre-installed:**

Some distributions (Fedora Silverblue, etc.) have pcscd pre-installed:

```bash
# Check if pcscd is installed
which pcscd

# Check if service is running
systemctl status pcscd
```

### Enable pcscd Service

**Start and enable:**

```bash
# Enable socket activation (recommended)
sudo systemctl enable --now pcscd.socket

# Or start service directly
sudo systemctl enable --now pcscd.service

# Verify status
systemctl status pcscd
```

**Socket activation benefits:**
- Starts automatically when smart card reader accessed
- Lower resource usage when idle
- Faster initial connection

### Download lpac

**Official release:**

```bash
# Create directory
mkdir -p ~/esim-tools
cd ~/esim-tools

# Download latest release
wget https://github.com/estkme-group/lpac/releases/latest/download/lpac-linux-x86_64.zip

# Extract
unzip lpac-linux-x86_64.zip

# Navigate to directory
cd lpac

# Make executable (if needed)
chmod +x lpac

# Verify
./lpac --help
```

**Alternative: Build from source:**

```bash
# Install build dependencies
sudo apt install git cmake build-essential libpcsclite-dev libcurl4-openssl-dev

# Clone repository
git clone https://github.com/estkme-group/lpac.git
cd lpac

# Build
cmake .
make

# Binary location
ls -lh output/lpac
```

### Install lpac System-Wide (Optional)

```bash
# Copy to /usr/local/bin
sudo cp lpac /usr/local/bin/

# Verify
lpac --help
```

### Verify Installation

**Test smart card reader:**

```bash
# Check if reader detected
pcsc_scan

# Expected output:
# Reader 0: [Reader Name]
# Card state: Card inserted
```

**Test lpac:**

```bash
# Get eUICC information
./lpac chip info

# Expected output:
# {
#   "eidValue": "...",
#   "euiccInfo2": {...}
# }
```

---

## Windows Setup

### Prerequisites

**Required software:**

1. **Smart card reader driver**
   - Windows usually installs automatically
   - If needed, download from manufacturer

2. **lpac binary**
   - Download Windows release from GitHub

### Driver Installation

**Check if driver needed:**

1. Insert smart card reader
2. Open Device Manager (devmgmt.msc)
3. Look under "Smart card readers"
4. If showing "Unknown device", install driver

**Install driver:**

```powershell
# Download manufacturer driver
# Or use Windows Update

# Verify in Device Manager
Get-PnpDevice -Class SmartCardReader
```

### Download lpac

**Download and extract:**

```powershell
# Create directory
mkdir C:\esim-tools
cd C:\esim-tools

# Download from GitHub releases page
# Extract lpac-windows-x86_64.zip

# Test
.\lpac.exe --help
```

### Add to PATH (Optional)

**For system-wide access:**

```powershell
# Add to PATH
$env:Path += ";C:\esim-tools\lpac"

# Verify
lpac --help
```

### Verify Installation

**Test reader:**

```powershell
# Run lpac
.\lpac.exe chip info
```

---

## macOS Setup

### Prerequisites

**Install Homebrew (if not installed):**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Install dependencies:**

```bash
# Install pcsc-lite
brew install pcsc-lite
```

### Download lpac

**Get release:**

```bash
# Create directory
mkdir -p ~/esim-tools
cd ~/esim-tools

# Download macOS release
curl -L -o lpac-macos-x86_64.zip https://github.com/estkme-group/lpac/releases/latest/download/lpac-macos-x86_64.zip

# Extract
unzip lpac-macos-x86_64.zip

# Make executable
chmod +x lpac

# Test
./lpac --help
```

### Verify Installation

```bash
# Test smart card reader
./lpac chip info
```

---

## Core Commands

### Basic Syntax

```bash
lpac [COMMAND] [OPTIONS]
```

### Get eUICC Information

**chip info command:**

```bash
# Get EID and eUICC details
./lpac chip info

# Pretty print JSON output
./lpac chip info | jq
```

**Example output:**

```json
{
  "eidValue": "89049032004008882600012340000001",
  "euiccInfo2": {
    "profileVersion": "3.0.0",
    "euiccFirmwareVer": "1.2.3",
    "extCardResource": {...},
    "uiccCapability": [...],
    "globalplatformVersion": "2.3.1"
  }
}
```

### List Profiles

**profile list command:**

```bash
# List all profiles on eUICC
./lpac profile list

# With JSON formatting
./lpac profile list | jq
```

**Example output:**

```json
[
  {
    "iccid": "8901240112345678901",
    "isdpAid": "...",
    "profileState": "enabled",
    "profileNickname": "My Carrier",
    "serviceProviderName": "Example Carrier",
    "profileName": "Consumer Profile",
    "profileClass": "operational"
  },
  {
    "iccid": "8901240198765432109",
    "profileState": "disabled",
    "profileNickname": "Travel SIM",
    "serviceProviderName": "Travel Provider"
  }
]
```

**⚠️ Important:** Default profile (test profile) should NOT be deleted

### Download Profile

**profile download command:**

```bash
# Basic download
./lpac profile download -s [SM-DP+ ADDRESS] -m [ACTIVATION CODE]

# Example
./lpac profile download -s smdp.example.com -m ABC123-DEF456-GHI789
```

**Extract activation info:**

**From QR code:**
- Scan QR code with phone camera or QR app
- Format: `LPA:1$[SM-DP+ ADDRESS]$[ACTIVATION CODE]`

**From activation string:**
```
LPA:1$smdp.example.com$ABC123-DEF456-GHI789
```

**Extract components:**
- SM-DP+ Address: `smdp.example.com`
- Activation Code: `ABC123-DEF456-GHI789`

**Complete download example:**

```bash
# Download profile
./lpac profile download -s smdp.example.com -m ABC123-DEF456-GHI789

# Expected output:
# Downloading profile...
# Profile downloaded successfully
# ICCID: 8901240112345678901

# Verify
./lpac profile list | grep "8901240112345678901"
```

### Enable Profile

**profile enable command:**

```bash
# Enable profile by ICCID
./lpac profile enable [ICCID]

# Example
./lpac profile enable 8901240112345678901
```

**⚠️ Important:** Only ONE profile can be active simultaneously

**Example workflow:**

```bash
# List profiles
./lpac profile list

# Enable specific profile
./lpac profile enable 8901240112345678901

# Verify (check profileState)
./lpac profile list | jq '.[] | select(.iccid=="8901240112345678901")'
```

### Disable Profile

**profile disable command:**

```bash
# Disable profile by ICCID
./lpac profile disable [ICCID]

# Example
./lpac profile disable 8901240112345678901
```

**Use case:** Switching between profiles

```bash
# Disable current
./lpac profile disable 8901240112345678901

# Enable another
./lpac profile enable 8901240198765432109
```

### Rename Profile

**profile nickname command:**

```bash
# Set custom nickname
./lpac profile nickname [ICCID] "Custom Name"

# Example
./lpac profile nickname 8901240112345678901 "Work SIM"

# Verify
./lpac profile list | jq '.[] | select(.iccid=="8901240112345678901") | .profileNickname'
```

**Nickname best practices:**
- Use descriptive names ("Work", "Travel", "IoT Device")
- Avoid special characters
- Keep under 32 characters

### Delete Profile

**profile delete command:**

```bash
# Delete profile by ICCID
./lpac profile delete [ICCID]

# Example
./lpac profile delete 8901240112345678901
```

**⚠️ Warning:**
- Deletion is PERMANENT
- Cannot be undone
- Profile must be re-downloaded if needed
- NEVER delete default/test profile

**Safe deletion workflow:**

```bash
# 1. List profiles
./lpac profile list

# 2. Disable profile first
./lpac profile disable 8901240112345678901

# 3. Confirm ICCID
echo "Deleting ICCID: 8901240112345678901"

# 4. Delete
./lpac profile delete 8901240112345678901

# 5. Verify removal
./lpac profile list
```

---

## Profile Management

### Complete Profile Lifecycle

**1. Download new profile:**

```bash
# Extract from QR code
# LPA:1$smdp.carrier.com$ACTIVATION-CODE

# Download
./lpac profile download -s smdp.carrier.com -m ACTIVATION-CODE

# Note returned ICCID
# ICCID: 8901240112345678901
```

**2. Rename for identification:**

```bash
./lpac profile nickname 8901240112345678901 "Carrier Name"
```

**3. Enable profile:**

```bash
./lpac profile enable 8901240112345678901
```

**4. Verify activation:**

```bash
# Check profile state
./lpac profile list | jq '.[] | select(.iccid=="8901240112345678901")'

# Should show: "profileState": "enabled"
```

**5. Switch profiles:**

```bash
# Disable current
./lpac profile disable 8901240112345678901

# Enable different profile
./lpac profile enable 8901240198765432109
```

**6. Delete when no longer needed:**

```bash
./lpac profile disable 8901240112345678901
./lpac profile delete 8901240112345678901
```

### Multi-Profile Management Script

**Automated profile switching:**

```bash
#!/bin/bash
# profile-switch.sh - Easy profile switching

LPAC="./lpac"

# Function to list profiles
list_profiles() {
    echo "=== Available Profiles ==="
    $LPAC profile list | jq -r '.[] | "\(.iccid) - \(.profileNickname // .serviceProviderName) [\(.profileState)]"'
}

# Function to switch profile
switch_profile() {
    local target_iccid="$1"

    # Get currently enabled profile
    current=$($LPAC profile list | jq -r '.[] | select(.profileState=="enabled") | .iccid')

    if [ "$current" == "$target_iccid" ]; then
        echo "Profile already active"
        return 0
    fi

    # Disable current
    if [ -n "$current" ]; then
        echo "Disabling current profile: $current"
        $LPAC profile disable "$current"
    fi

    # Enable target
    echo "Enabling profile: $target_iccid"
    $LPAC profile enable "$target_iccid"

    echo "Profile switched successfully"
}

# Main
case "$1" in
    list)
        list_profiles
        ;;
    switch)
        if [ -z "$2" ]; then
            echo "Usage: $0 switch [ICCID]"
            exit 1
        fi
        switch_profile "$2"
        ;;
    *)
        echo "Usage: $0 {list|switch [ICCID]}"
        exit 1
        ;;
esac
```

**Usage:**

```bash
chmod +x profile-switch.sh

# List profiles
./profile-switch.sh list

# Switch to specific profile
./profile-switch.sh switch 8901240112345678901
```

---

## Advanced Operations

### Environment Variables

**APDU driver configuration:**

```bash
# Use AT commands (for USB modems)
export LPAC_APDU=at
export AT_DEVICE=/dev/ttyUSB2

# Use PC/SC (for smart card readers)
export LPAC_APDU=pcsc

# Use HTTP interface
export LPAC_APDU=http
export LPAC_HTTP=http://192.168.1.1:8080
```

### Notification Management

**profile notification list:**

```bash
# List pending notifications
./lpac notification list
```

**profile notification process:**

```bash
# Process pending notifications
./lpac notification process [SEQUENCE_NUMBER]
```

**profile notification remove:**

```bash
# Remove notification
./lpac notification remove [SEQUENCE_NUMBER]
```

### Discovery Service

**profile discovery:**

```bash
# Discover available profiles
./lpac profile discovery --sm-ds [SM-DS ADDRESS]
```

### Confirmation Code

**Some profiles require confirmation code:**

```bash
# Download with confirmation code
./lpac profile download -s smdp.carrier.com -m ACTIVATION-CODE -c CONFIRM-CODE
```

### Debug Mode

**Enable verbose output:**

```bash
# Set debug level
export LPAC_DEBUG=1

# Run command with debug
./lpac chip info
```

### JSON Output Processing

**Using jq for filtering:**

```bash
# Get only enabled profiles
./lpac profile list | jq '.[] | select(.profileState=="enabled")'

# Extract all ICCIDs
./lpac profile list | jq -r '.[].iccid'

# Get nicknames
./lpac profile list | jq -r '.[] | "\(.profileNickname // "No nickname") (\(.iccid))"'

# Count profiles
./lpac profile list | jq 'length'
```

---

## Troubleshooting

### Common Errors

#### Error: SCardEstablishContext Failed

**Symptom:**
```
Error: SCardEstablishContext failed
```

**Cause:** pcscd service not running

**Solution:**

```bash
# Install ccid driver
sudo apt install libccid

# Enable and start pcscd
sudo systemctl enable --now pcscd.socket

# Verify
systemctl status pcscd
```

#### Error: APDU Driver Initialization Failed

**Symptom:**
```
Error: Failed to initialize APDU driver
```

**Cause:** Smart card reader not detected or driver issue

**Solution:**

```bash
# Check reader detection
pcsc_scan

# Restart pcscd
sudo systemctl restart pcscd

# Check permissions
groups $USER
# Should include 'scard' or similar group

# Add user to group if needed
sudo usermod -aG scard $USER
# Log out and log back in
```

#### Error: Card Not Present

**Symptom:**
```
Error: Card not present or not responding
```

**Solutions:**

1. **Check physical connection:**
   ```bash
   # Reseat card in reader
   # Wait 5 seconds
   # Try again
   ```

2. **Check reader status:**
   ```bash
   pcsc_scan
   # Should show "Card inserted"
   ```

3. **Test with different reader:**
   - Try USB port change
   - Test with known working reader

#### Error: Profile Download Failed

**Symptom:**
```
Error: Profile download failed
Error code: [various]
```

**Solutions:**

1. **Check activation code:**
   ```bash
   # Verify code is correct
   # Check for typos
   # Ensure code not already used
   ```

2. **Check network connectivity:**
   ```bash
   # Test SM-DP+ connectivity
   ping smdp.carrier.com

   # Test HTTPS
   curl -v https://smdp.carrier.com
   ```

3. **Check eUICC space:**
   ```bash
   # List profiles
   ./lpac profile list | jq 'length'

   # eUICC has limited profile slots
   # Delete unused profiles if full
   ```

#### Error: Profile Enable Failed

**Symptom:**
```
Error: Failed to enable profile
```

**Solutions:**

1. **Disable other profiles first:**
   ```bash
   # Only one profile can be active
   # Disable current profile
   ./lpac profile disable [CURRENT_ICCID]

   # Then enable target
   ./lpac profile enable [TARGET_ICCID]
   ```

2. **Check profile state:**
   ```bash
   # Profile must exist and be in disabled state
   ./lpac profile list | jq '.[] | select(.iccid=="[ICCID]")'
   ```

### Permission Issues

**Linux permission errors:**

```bash
# Check current permissions
ls -l /var/run/pcscd/

# Add user to pcscd group
sudo usermod -aG pcscd $USER

# Or use scard group
sudo usermod -aG scard $USER

# Log out and back in
```

### Smart Card Reader Not Detected

**Diagnosis:**

```bash
# Check USB connection
lsusb | grep -i "smart\|card\|reader"

# Check kernel messages
dmesg | grep -i "usb\|card"

# Check pcscd logs
journalctl -u pcscd -n 50
```

**Solutions:**

1. **Install CCID driver:**
   ```bash
   sudo apt install libccid
   ```

2. **Restart pcscd:**
   ```bash
   sudo systemctl restart pcscd
   ```

3. **Try different USB port:**
   - USB 2.0 port preferred
   - Avoid USB hubs

---

## Common Issues and Solutions

### Issue: Profile Won't Delete

**Problem:** Default test profile cannot be deleted

**Solution:** Default profile is required for eUICC operation - do not delete

### Issue: Slow Profile Download

**Problem:** Download takes very long

**Solutions:**

1. **Network issue:**
   ```bash
   # Test connection speed
   curl -o /dev/null https://smdp.carrier.com/test
   ```

2. **Buffer size (Quectel modems):**
   - See Quectel patching guide
   - Reduce MSS value

### Issue: JSON Output Not Pretty

**Problem:** lpac output is single-line JSON

**Solution:**

```bash
# Install jq
sudo apt install jq

# Pipe output through jq
./lpac profile list | jq

# Or use python
./lpac profile list | python -m json.tool
```

### Issue: Cannot Build from Source

**Problem:** Compilation errors

**Solution:**

```bash
# Install all dependencies
sudo apt install \
    git \
    cmake \
    build-essential \
    libpcsclite-dev \
    libcurl4-openssl-dev \
    pkg-config

# Clean and rebuild
rm -rf CMakeCache.txt CMakeFiles/
cmake .
make clean
make
```

---

## Best Practices

### Profile Management

**Naming conventions:**
```bash
# Use descriptive nicknames
./lpac profile nickname [ICCID] "Work-Verizon"
./lpac profile nickname [ICCID] "Travel-EU-Vodafone"
./lpac profile nickname [ICCID] "IoT-Device-1"
```

**Profile organization:**
- Keep maximum 5-10 profiles
- Delete unused profiles regularly
- Document ICCIDs externally
- Backup activation codes

### Automation

**Script wrapper example:**

```bash
#!/bin/bash
# lpac-wrapper.sh

LPAC_PATH="/usr/local/bin/lpac"
LOG_FILE="/var/log/lpac.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

case "$1" in
    list)
        log "Listing profiles"
        $LPAC_PATH profile list | jq
        ;;
    enable)
        log "Enabling profile: $2"
        $LPAC_PATH profile enable "$2"
        ;;
    disable)
        log "Disabling profile: $2"
        $LPAC_PATH profile disable "$2"
        ;;
    *)
        echo "Usage: $0 {list|enable|disable} [ICCID]"
        exit 1
        ;;
esac
```

### Monitoring

**Check eUICC health:**

```bash
#!/bin/bash
# euicc-health-check.sh

echo "=== eUICC Health Check ==="

# Test connectivity
if ./lpac chip info > /dev/null 2>&1; then
    echo "✓ eUICC responding"
else
    echo "✗ eUICC not responding"
    exit 1
fi

# Check profile count
count=$(./lpac profile list | jq 'length')
echo "✓ Profiles installed: $count"

# Check for enabled profile
enabled=$(./lpac profile list | jq -r '.[] | select(.profileState=="enabled") | .profileNickname')
if [ -n "$enabled" ]; then
    echo "✓ Active profile: $enabled"
else
    echo "⚠ No active profile"
fi

echo "Health check complete"
```

---

## Security Considerations

### Activation Code Protection

**⚠️ Activation codes are sensitive:**
- One-time use only
- Treat like passwords
- Don't share publicly
- Don't commit to version control

**Secure handling:**

```bash
# Use environment variable
export ACTIVATION_CODE="ABC123-DEF456-GHI789"
./lpac profile download -s smdp.carrier.com -m "$ACTIVATION_CODE"
unset ACTIVATION_CODE

# Or read from encrypted file
gpg -d activation-codes.txt.gpg | grep "carrier-name" | ./lpac profile download -s smdp.carrier.com -m $(cat)
```

### Profile Access Control

**Limit access to lpac:**

```bash
# Set appropriate permissions
sudo chown root:pcscd /usr/local/bin/lpac
sudo chmod 750 /usr/local/bin/lpac

# Only allow specific users
sudo usermod -aG pcscd username
```

### Audit Logging

**Log all profile operations:**

```bash
# Enable audit logging
alias lpac='tee -a ~/.lpac_audit.log | /usr/local/bin/lpac'

# Review logs
tail -f ~/.lpac_audit.log
```

### Network Security

**Use secure connections:**
- All SM-DP+ connections use TLS
- Verify certificate validity
- Use VPN if needed for corporate networks

---

## Integration Examples

### Systemd Service

**Auto-enable profile on boot:**

```ini
# /etc/systemd/system/esim-auto-enable.service
[Unit]
Description=Auto-enable eSIM profile
After=pcscd.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/lpac profile enable 8901240112345678901
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

**Enable service:**

```bash
sudo systemctl daemon-reload
sudo systemctl enable esim-auto-enable.service
```

### Monitoring with Prometheus

**Export metrics:**

```bash
#!/bin/bash
# lpac-exporter.sh

while true; do
    # Get profile count
    count=$(./lpac profile list 2>/dev/null | jq 'length')

    # Get enabled profile
    enabled=$(./lpac profile list 2>/dev/null | jq -r '.[] | select(.profileState=="enabled") | .iccid' | wc -l)

    # Export metrics
    echo "# HELP esim_profile_count Total number of eSIM profiles"
    echo "# TYPE esim_profile_count gauge"
    echo "esim_profile_count $count"

    echo "# HELP esim_profile_enabled Number of enabled profiles"
    echo "# TYPE esim_profile_enabled gauge"
    echo "esim_profile_enabled $enabled"

    sleep 60
done
```

### REST API Wrapper

**Simple HTTP API:**

```python
#!/usr/bin/env python3
# lpac-api.py
from flask import Flask, jsonify
import subprocess
import json

app = Flask(__name__)
LPAC_PATH = "/usr/local/bin/lpac"

@app.route('/profiles')
def list_profiles():
    result = subprocess.run([LPAC_PATH, 'profile', 'list'],
                          capture_output=True, text=True)
    return jsonify(json.loads(result.stdout))

@app.route('/profile/enable/<iccid>')
def enable_profile(iccid):
    result = subprocess.run([LPAC_PATH, 'profile', 'enable', iccid],
                          capture_output=True, text=True)
    return jsonify({'status': 'success' if result.returncode == 0 else 'error'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

---

## References

### Official Resources

**lpac Repository:**
- Main: https://github.com/estkme-group/lpac
- Releases: https://github.com/estkme-group/lpac/releases
- Issues: https://github.com/estkme-group/lpac/issues

**Original Documentation:**
- Soprani.ca Wiki: https://wiki.soprani.ca/eSIM%20Adapter/lpac

### Standards

**GSMA Specifications:**
- SGP.22 - RSP Architecture for Consumer Devices
- SGP.02 - RSP Architecture for M2M eUICC

**Related Standards:**
- ETSI TS 102 221 - Smart card specifications
- ISO/IEC 7816 - Smart card physical interface
- GlobalPlatform Card Specification

### Hardware

**eSIM Adapters:**
- JMP eSIM Adapter: https://soprani.ca/

**Smart Card Readers:**
- PC/SC Workgroup: https://www.pcscworkgroup.com/

### Community

- lpac GitHub Discussions
- OpenWRT Forum (eSIM topics)
- Reddit: r/eSIM

---

## Summary

**lpac** is a powerful command-line tool for eSIM profile management:

**Key Capabilities:**
- ✅ List, download, enable, disable, delete profiles
- ✅ Works with smart card readers and modems
- ✅ Cross-platform support
- ✅ Open-source and free
- ✅ No proprietary software needed

**Quick Start Commands:**

```bash
# Setup (Linux)
sudo apt install pcscd libccid
sudo systemctl enable --now pcscd.socket
wget https://github.com/estkme-group/lpac/releases/latest/download/lpac-linux-x86_64.zip
unzip lpac-linux-x86_64.zip

# Basic operations
./lpac chip info                                    # Get eUICC info
./lpac profile list                                 # List profiles
./lpac profile download -s [SM-DP+] -m [CODE]      # Download profile
./lpac profile enable [ICCID]                       # Enable profile
./lpac profile nickname [ICCID] "Name"             # Rename profile
```

**Common Issues:**
- Install `pcscd` and `libccid` if SCardEstablishContext errors
- Enable `pcscd.socket` for automatic service activation
- Only one profile can be enabled at a time
- Never delete the default test profile

**For Production Use:**
- Use wrapper scripts for automation
- Implement logging and monitoring
- Secure activation codes properly
- Test profile switching before deployment

lpac provides reliable, scriptable eSIM management for IoT, travel routers, and development environments.

---

*This guide is based on the Soprani.ca wiki documentation and lpac project development.*
