# Quectel RM500Q-GL eSIM Usage Guide

## Table of Contents
1. [Overview](#overview)
2. [Hardware Information](#hardware-information)
3. [Prerequisites](#prerequisites)
4. [Understanding eSIM on RM500Q](#understanding-esim-on-rm500q)
5. [Method 1: Basic APN Configuration](#method-1-basic-apn-configuration)
6. [Method 2: Quectel AT+QESIM Commands](#method-2-quectel-atqesim-commands)
7. [Method 3: Using lpac Open Source Tool](#method-3-using-lpac-open-source-tool)
8. [Method 4: Quectel LPAd (Proprietary)](#method-4-quectel-lpad-proprietary)
9. [Firmware Requirements](#firmware-requirements)
10. [Driver Configuration](#driver-configuration)
11. [Profile Management](#profile-management)
12. [Troubleshooting](#troubleshooting)
13. [Community Experiences](#community-experiences)
14. [Best Practices](#best-practices)
15. [References](#references)

---

## Overview

The **Quectel RM500Q-GL** is a 5G cellular modem that supports both physical SIM cards and eSIM (eUICC) profiles. This guide documents methods for activating and managing eSIM profiles on the RM500Q-GL module, compiled from community experiences and official recommendations.

**Key Points:**
- RM500Q-GL has built-in eUICC support
- Multiple methods available for eSIM management
- Firmware version affects eSIM functionality
- Works with both USB and PCIe interfaces
- Compatible with Linux systems (Ubuntu, Debian, etc.)

**Tested Platforms:**
- Ubuntu Server 5.15
- Ubuntu Desktop 22.04+
- Debian-based distributions
- Khadas VIM4 and compatible SBCs

---

## Hardware Information

### Quectel RM500Q-GL Specifications

**Form Factor:** M.2 (Type 3042/3052)

**Cellular Technology:**
- 5G NR Sub-6 GHz
- LTE Cat 20
- 3G WCDMA/HSPA+
- 2G GSM/GPRS/EDGE

**Regional Support:**
- Global bands (GL variant)
- North America
- Europe
- Asia Pacific

**Interfaces:**
- USB 3.1 / 3.0
- PCIe Gen3
- UART
- PCM (audio)
- SIM/eSIM

**eSIM Support:**
- Built-in eUICC chip
- SGP.22 compliant
- Multiple profile storage
- Remote SIM provisioning

### Module Variants

| Model | Region | eSIM Support |
|-------|--------|--------------|
| RM500Q-GL | Global | ✅ Yes |
| RM500Q-AE | Americas, Europe | ✅ Yes |
| RM500Q-NA | North America | ✅ Yes |
| RM520N-GL | Global (newer) | ✅ Yes |

---

## Prerequisites

### Hardware Requirements

**Essential:**
- Quectel RM500Q-GL module
- Compatible host device (PC, SBC, router)
- M.2 slot (USB or PCIe)
- Antenna(s) - minimum 2x cellular antennas

**Optional:**
- External antenna(s) for better signal
- SIM adapter (if testing physical SIM first)

### Software Requirements

**Operating System:**
```bash
# Tested on Ubuntu 20.04+
uname -a
# Linux 5.15+ kernel recommended
```

**Required Packages:**
```bash
sudo apt update
sudo apt install \
    modemmanager \
    libqmi-utils \
    minicom \
    screen \
    usbutils \
    pciutils \
    jq
```

**Optional Tools:**
```bash
# For advanced users
sudo apt install \
    python3 \
    python3-pip \
    git \
    cmake \
    build-essential
```

### Firmware Check

**Check current firmware version:**
```bash
# Using AT commands
echo -e "ATI\r" | sudo tee /dev/ttyUSB2
sleep 1
sudo cat /dev/ttyUSB2

# Or using mmcli
mmcli -m 0 --command='ATI'
```

**Recommended firmware:**
- RM500QGLAAR03A02M4G or newer
- RM520NGLAAR03A03M4G (for RM520N)
- Check Quectel website for latest firmware

### Network Prerequisites

**For eSIM activation:**
- Active internet connection (via Ethernet or WiFi)
- Access to SM-DP+ server
- Valid eSIM activation code
- Working DNS resolution

---

## Understanding eSIM on RM500Q

### eSIM vs Physical SIM

**Physical SIM:**
- Removable plastic card
- Pre-provisioned by carrier
- One carrier per card
- Manual swap required

**eSIM (eUICC):**
- Embedded chip in modem
- Remotely provisioned
- Multiple profiles storage
- Software switching between carriers

### eSIM Architecture on RM500Q

```
┌─────────────────────────────────────┐
│       Host System (Linux)           │
│  ┌───────────────────────────────┐  │
│  │  User Application / Tool      │  │
│  │  (lpac, AT commands, LPAd)   │  │
│  └───────────┬───────────────────┘  │
│              │                       │
│              │ USB/PCIe              │
│              ▼                       │
│  ┌───────────────────────────────┐  │
│  │    Modem Driver (QMI/AT)     │  │
│  └───────────┬───────────────────┘  │
└──────────────┼──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│     Quectel RM500Q-GL Module        │
│  ┌───────────────────────────────┐  │
│  │    Modem Firmware             │  │
│  │    (AT+QESIM support)         │  │
│  └───────────┬───────────────────┘  │
│              │                       │
│              ▼                       │
│  ┌───────────────────────────────┐  │
│  │    eUICC Chip (eSIM)          │  │
│  │  - Profile Storage            │  │
│  │  - SGP.22 Implementation      │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
               │
               │ HTTPS/TLS
               ▼
┌─────────────────────────────────────┐
│      SM-DP+ Server (Carrier)        │
│  - Profile Generation               │
│  - Authentication                    │
│  - Profile Download                  │
└─────────────────────────────────────┘
```

### eSIM Profile States

**Disabled:**
- Profile stored but not active
- No network connection
- Can be enabled anytime

**Enabled:**
- Profile active and operational
- Network registration possible
- Only ONE profile can be enabled at a time

**Deleted:**
- Profile removed from eUICC
- Cannot be recovered locally
- Must be re-downloaded if needed

---

## Method 1: Basic APN Configuration

### Overview

According to **Khadas official response**, using eSIM is "no different from using a normal SIM card" - you just need to configure the correct APN.

**When to use this method:**
- eSIM profile already activated/downloaded
- Profile is enabled
- Only need to configure data connection

### Prerequisites

- eSIM profile must already be downloaded and enabled
- Know your carrier's APN settings

### Step-by-Step Procedure

**1. Stop ModemManager (if running):**
```bash
sudo systemctl stop ModemManager
```

**2. Identify AT command port:**
```bash
# List USB devices
lsusb | grep Quectel

# List serial ports
ls -l /dev/ttyUSB*

# Typically:
# /dev/ttyUSB0 - DM (Diagnostic)
# /dev/ttyUSB1 - NMEA (GPS)
# /dev/ttyUSB2 - AT Commands (use this)
# /dev/ttyUSB3 - PPP
```

**3. Test modem communication:**
```bash
# Using echo
echo -e "AT\r" | sudo tee /dev/ttyUSB2
sleep 1
sudo cat /dev/ttyUSB2

# Expected: OK
```

**4. Check SIM/eSIM status:**
```bash
echo -e "AT+CPIN?\r" | sudo tee /dev/ttyUSB2
sleep 1
sudo cat /dev/ttyUSB2

# Expected: +CPIN: READY
```

**5. Configure APN:**
```bash
# Syntax: AT+CGDCONT=<cid>,"<PDP_type>","<APN>"

# Example for carrier APN "internet"
echo -e 'AT+CGDCONT=1,"IP","internet"\r' | sudo tee /dev/ttyUSB2

# Example for T-Mobile
echo -e 'AT+CGDCONT=1,"IP","fast.t-mobile.com"\r' | sudo tee /dev/ttyUSB2

# Example for AT&T
echo -e 'AT+CGDCONT=1,"IP","broadband"\r' | sudo tee /dev/ttyUSB2
```

**6. Verify APN configuration:**
```bash
echo -e "AT+CGDCONT?\r" | sudo tee /dev/ttyUSB2
sleep 1
sudo cat /dev/ttyUSB2

# Expected: +CGDCONT: 1,"IP","internet","0.0.0.0",0,0
```

**7. Register to network:**
```bash
# Enable automatic network selection
echo -e "AT+COPS=0\r" | sudo tee /dev/ttyUSB2

# Check registration
echo -e "AT+CREG?\r" | sudo tee /dev/ttyUSB2
sleep 1
sudo cat /dev/ttyUSB2

# Expected: +CREG: 0,1 (home) or +CREG: 0,5 (roaming)
```

**8. Activate data connection:**
```bash
# Activate PDP context
echo -e "AT+CGACT=1,1\r" | sudo tee /dev/ttyUSB2

# Get IP address
echo -e "AT+CGPADDR=1\r" | sudo tee /dev/ttyUSB2
sleep 1
sudo cat /dev/ttyUSB2

# Expected: +CGPADDR: 1,"10.x.x.x"
```

### Automated Script

```bash
#!/bin/bash
# esim-apn-configure.sh - Configure APN for active eSIM

DEVICE="/dev/ttyUSB2"
APN="${1:-internet}"

if [ -z "$1" ]; then
    echo "Usage: $0 <APN>"
    echo "Example: $0 fast.t-mobile.com"
    exit 1
fi

echo "=== eSIM APN Configuration ==="
echo "Device: $DEVICE"
echo "APN: $APN"
echo ""

# Function to send AT command
send_at() {
    echo -e "$1\r" | sudo tee "$DEVICE" > /dev/null
    sleep 1
    sudo timeout 2 cat "$DEVICE" 2>/dev/null
}

# 1. Check SIM status
echo "1. Checking eSIM status..."
result=$(send_at "AT+CPIN?")
if echo "$result" | grep -q "READY"; then
    echo "   ✓ eSIM is ready"
else
    echo "   ✗ eSIM not ready"
    echo "$result"
    exit 1
fi

# 2. Set APN
echo "2. Configuring APN..."
send_at "AT+CGDCONT=1,\"IP\",\"$APN\""

# 3. Verify
echo "3. Verifying APN configuration..."
result=$(send_at "AT+CGDCONT?")
echo "$result"

# 4. Register to network
echo "4. Registering to network..."
send_at "AT+COPS=0"

# 5. Check registration
echo "5. Checking network registration..."
result=$(send_at "AT+CREG?")
echo "$result"

# 6. Activate connection
echo "6. Activating data connection..."
send_at "AT+CGACT=1,1"

# 7. Get IP
echo "7. Getting IP address..."
result=$(send_at "AT+CGPADDR=1")
echo "$result"

echo ""
echo "=== Configuration Complete ==="
```

**Usage:**
```bash
chmod +x esim-apn-configure.sh
./esim-apn-configure.sh fast.t-mobile.com
```

---

## Method 2: Quectel AT+QESIM Commands

### Overview

Quectel modems with eSIM support provide **AT+QESIM** commands for direct eSIM profile management through AT command interface.

**Advantages:**
- Native modem support
- No external tools needed
- Direct firmware integration
- Reliable profile management

**Requirements:**
- Firmware with AT+QESIM support
- RM500QGLAAR03A02M4G or newer recommended

### AT+QESIM Command Set

#### Check Command Support

```bash
# Test if AT+QESIM is supported
echo -e "AT+QESIM=?\r" | sudo tee /dev/ttyUSB2
sleep 1
sudo cat /dev/ttyUSB2
```

#### Set Default SM-DP+ Server

**Syntax:**
```
AT+QESIM="def_svr_addr","<ACTIVATION_STRING>"
```

**Activation string format:**
```
LPA:1$<SM-DP+ ADDRESS>$<ACTIVATION CODE>
```

**Example:**
```bash
# Set default SM-DP+ server and download profile
echo -e 'AT+QESIM="def_svr_addr","LPA:1$wbg.prod.ondemandconnectivity.com$ABC123-DEF456"\r' | sudo tee /dev/ttyUSB2
```

**This command:**
1. Sets the SM-DP+ server address
2. Initiates profile download
3. Installs profile to eUICC

#### List eSIM Profiles

```bash
# List all profiles on eUICC
echo -e 'AT+QESIM="list"\r' | sudo tee /dev/ttyUSB2
sleep 2
sudo cat /dev/ttyUSB2
```

**Example output:**
```
+QESIM: "list",1,"89012345678901234567","Carrier Name","enabled"
+QESIM: "list",2,"89012345678901234568","Travel SIM","disabled"

OK
```

**Format:**
```
+QESIM: "list",<index>,"<ICCID>","<profile_name>","<state>"
```

#### Enable Profile

```bash
# Enable profile by ICCID
echo -e 'AT+QESIM="enable","89012345678901234567"\r' | sudo tee /dev/ttyUSB2

# Or by index
echo -e 'AT+QESIM="enable",1\r' | sudo tee /dev/ttyUSB2
```

**Note:** Only one profile can be enabled at a time. Enabling a new profile automatically disables the current one.

#### Disable Profile

```bash
# Disable profile by ICCID
echo -e 'AT+QESIM="disable","89012345678901234567"\r' | sudo tee /dev/ttyUSB2

# Or by index
echo -e 'AT+QESIM="disable",1\r' | sudo tee /dev/ttyUSB2
```

#### Delete Profile

```bash
# Delete profile by ICCID
echo -e 'AT+QESIM="delete","89012345678901234567"\r' | sudo tee /dev/ttyUSB2

# Or by index
echo -e 'AT+QESIM="delete",2\r' | sudo tee /dev/ttyUSB2
```

**⚠️ Warning:** Deletion is permanent. Profile must be re-downloaded if needed.

#### Get eUICC Information

```bash
# Get EID and eUICC info
echo -e 'AT+QESIM="euicc_info"\r' | sudo tee /dev/ttyUSB2
sleep 1
sudo cat /dev/ttyUSB2
```

### Complete Profile Management Script

```bash
#!/bin/bash
# qesim-manager.sh - Manage eSIM profiles using AT+QESIM

DEVICE="/dev/ttyUSB2"

# Function to send AT command
send_at() {
    echo -e "$1\r" | sudo tee "$DEVICE" > /dev/null
    sleep 2
    sudo timeout 3 cat "$DEVICE" 2>/dev/null
}

# List profiles
list_profiles() {
    echo "=== eSIM Profiles ==="
    send_at 'AT+QESIM="list"'
}

# Download profile
download_profile() {
    local activation_string="$1"

    if [ -z "$activation_string" ]; then
        echo "Usage: $0 download 'LPA:1\$smdp.example.com\$CODE'"
        exit 1
    fi

    echo "Downloading profile..."
    send_at "AT+QESIM=\"def_svr_addr\",\"$activation_string\""
}

# Enable profile
enable_profile() {
    local iccid="$1"

    if [ -z "$iccid" ]; then
        echo "Usage: $0 enable <ICCID>"
        exit 1
    fi

    echo "Enabling profile: $iccid"
    send_at "AT+QESIM=\"enable\",\"$iccid\""
}

# Disable profile
disable_profile() {
    local iccid="$1"

    if [ -z "$iccid" ]; then
        echo "Usage: $0 disable <ICCID>"
        exit 1
    fi

    echo "Disabling profile: $iccid"
    send_at "AT+QESIM=\"disable\",\"$iccid\""
}

# Delete profile
delete_profile() {
    local iccid="$1"

    if [ -z "$iccid" ]; then
        echo "Usage: $0 delete <ICCID>"
        exit 1
    fi

    read -p "Are you sure you want to delete profile $iccid? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Cancelled"
        exit 0
    fi

    echo "Deleting profile: $iccid"
    send_at "AT+QESIM=\"delete\",\"$iccid\""
}

# Get eUICC info
euicc_info() {
    echo "=== eUICC Information ==="
    send_at 'AT+QESIM="euicc_info"'
}

# Main
case "$1" in
    list)
        list_profiles
        ;;
    download)
        download_profile "$2"
        ;;
    enable)
        enable_profile "$2"
        ;;
    disable)
        disable_profile "$2"
        ;;
    delete)
        delete_profile "$2"
        ;;
    info)
        euicc_info
        ;;
    *)
        echo "Usage: $0 {list|download|enable|disable|delete|info} [args]"
        echo ""
        echo "Examples:"
        echo "  $0 list"
        echo "  $0 download 'LPA:1\$smdp.example.com\$CODE'"
        echo "  $0 enable 89012345678901234567"
        echo "  $0 disable 89012345678901234567"
        echo "  $0 delete 89012345678901234567"
        echo "  $0 info"
        exit 1
        ;;
esac
```

**Usage examples:**
```bash
chmod +x qesim-manager.sh

# List all profiles
./qesim-manager.sh list

# Download new profile
./qesim-manager.sh download 'LPA:1$smdp.example.com$ABC-123'

# Enable profile
./qesim-manager.sh enable 89012345678901234567

# Get eUICC info
./qesim-manager.sh info
```

---

## Method 3: Using lpac Open Source Tool

### Overview

**lpac** is an open-source Local Profile Assistant Client that provides cross-platform eSIM management. The community-recommended fork **lpac-quectel** is specifically adapted for Quectel modems including RM500Q.

**Advantages:**
- Open source and free
- Better AT command handling for Quectel
- JSON output for automation
- Active community support

**GitHub Repository:**
```
https://github.com/estkme-group/lpac
```

**Quectel-specific fork (mentioned in forum):**
```
https://github.com/[community-fork]/lpac-quectel
```

### Installation

**Method A: Pre-built Binary (if available)**

```bash
# Download latest release
mkdir -p ~/esim-tools
cd ~/esim-tools
wget https://github.com/estkme-group/lpac/releases/latest/download/lpac-linux-x86_64.zip

# Extract
unzip lpac-linux-x86_64.zip
cd lpac

# Test
./lpac --help
```

**Method B: Build from Source (with Quectel patches)**

```bash
# Install dependencies
sudo apt install \
    git \
    cmake \
    build-essential \
    libpcsclite-dev \
    libcurl4-openssl-dev \
    pkg-config

# Clone repository
cd ~/esim-tools
git clone https://github.com/estkme-group/lpac.git
cd lpac

# Apply Quectel patches (see ESIM_LPAC_QUECTEL_PATCHING_GUIDE.md)
# 1. Patch AT driver (drivers/at.c)
# 2. Reduce MSS in euicc/euicc.c

vim euicc/euicc.c
# Find: ctx->es10x_mss = [value];
# Change to: ctx->es10x_mss = 60;

# Build with AT APDU support
cmake . -DLPAC_WITH_APDU_AT=1
make

# Binary location
ls -lh output/lpac
```

### Configuration for RM500Q

**Set environment variables:**

```bash
# Use AT command driver
export LPAC_APDU=at

# Set AT command port (adjust if needed)
export AT_DEVICE=/dev/ttyUSB2

# Test configuration
output/lpac chip info
```

**Make persistent (add to ~/.bashrc):**

```bash
echo 'export LPAC_APDU=at' >> ~/.bashrc
echo 'export AT_DEVICE=/dev/ttyUSB2' >> ~/.bashrc
source ~/.bashrc
```

### Using lpac with RM500Q

**Stop ModemManager:**
```bash
sudo systemctl stop ModemManager
```

**Get eUICC information:**
```bash
./lpac chip info

# Pretty print with jq
./lpac chip info | jq
```

**List profiles:**
```bash
./lpac profile list | jq
```

**Download profile:**
```bash
# Extract from QR code: LPA:1$smdp.example.com$ACTIVATION-CODE

./lpac profile download -s smdp.example.com -m ACTIVATION-CODE

# With confirmation code (if required)
./lpac profile download -s smdp.example.com -m ACTIVATION-CODE -c CONFIRM-CODE
```

**Enable profile:**
```bash
./lpac profile enable <ICCID>
```

**Disable profile:**
```bash
./lpac profile disable <ICCID>
```

**Rename profile:**
```bash
./lpac profile nickname <ICCID> "Carrier Name"
```

**Delete profile:**
```bash
./lpac profile delete <ICCID>
```

### Known Issues

**From forum discussion:**
- Some users reported difficulty downloading fresh profiles
- May require specific firmware version
- Quectel-specific patches recommended for reliability

**Solutions:**
- Use patched version (see ESIM_LPAC_QUECTEL_PATCHING_GUIDE.md)
- Update to latest firmware
- Check AT command port permissions

---

## Method 4: Quectel LPAd (Proprietary)

### Overview

**Quectel LPAd** is a proprietary Local Profile Assistant daemon provided by Quectel for eSIM management.

**Status (from forum):**
- ⚠️ Limited community success
- Compilation errors reported
- QMI connectivity issues
- Works better in usbnet mode vs PCIe
- May require specific firmware

### Installation Attempt

**Prerequisites:**
```bash
sudo apt install \
    git \
    cmake \
    build-essential \
    libqmi-glib-dev \
    libglib2.0-dev
```

**Obtain LPAd:**
- Contact Quectel support for source code
- May require NDA or customer agreement
- Not publicly available on GitHub

**Build:**
```bash
# If source obtained
cd LPAd
mkdir build
cd build
cmake ..
make

# May encounter compilation errors
```

### Known Issues from Community

**Compilation problems:**
- Missing dependencies
- Version conflicts
- Platform-specific errors

**Runtime problems:**
- QMI connection failures
- Profile download timeouts
- Interface detection issues

**Recommendation:** Use Method 2 (AT+QESIM) or Method 3 (lpac) instead.

---

## Firmware Requirements

### Minimum Firmware Version

**For eSIM support:**
- RM500QGLAAR03A02M4G or newer
- RM520NGLAAR03A03M4G (for RM520N variant)

**Check current firmware:**
```bash
echo -e "ATI\r" | sudo tee /dev/ttyUSB2
sleep 1
sudo cat /dev/ttyUSB2
```

**Example output:**
```
Quectel
RM500Q-GL
Revision: RM500QGLAAR03A02M4G

OK
```

### Firmware Update Process

**⚠️ Warning:** Firmware updates can brick the modem if interrupted. Proceed with caution.

**Tools required:**
- QFlash tool (Windows) or qfirehose (Linux)
- Latest firmware package from Quectel
- Stable power supply

**Linux firmware update (qfirehose):**

```bash
# Install qfirehose
git clone https://github.com/xnano/qfirehose.git
cd qfirehose
make

# Put modem in emergency download mode
echo -e "AT+QPRTPARA=3\r" | sudo tee /dev/ttyUSB2

# Flash firmware (device will reboot to /dev/ttyUSB0)
sudo ./qfirehose -f /path/to/firmware/

# Wait for completion
# Modem will reboot automatically
```

**⚠️ Important notes:**
- Never interrupt during firmware update
- Ensure stable power supply
- No downgrade possible
- Backup configuration if possible

### Verify Firmware Features

**Check AT+QESIM support:**
```bash
echo -e "AT+QESIM=?\r" | sudo tee /dev/ttyUSB2
sleep 1
sudo cat /dev/ttyUSB2

# If supported, will show command syntax
# If not supported, will return ERROR
```

---

## Driver Configuration

### QMI Driver Requirements

**Install QMI utilities:**
```bash
sudo apt install libqmi-utils
```

**QMI-aware driver needed** (from forum):
- Modern Linux kernels (5.15+) include QMI drivers
- Some features require updated libqmi

**Check QMI device:**
```bash
# List QMI devices
ls -l /dev/cdc-wdm*

# Typically /dev/cdc-wdm0 for RM500Q
```

**Test QMI connection:**
```bash
sudo qmicli -d /dev/cdc-wdm0 --dms-get-model
sudo qmicli -d /dev/cdc-wdm0 --dms-get-revision
```

### USB vs PCIe Mode

**USB Mode (recommended for eSIM):**
- Better tool compatibility
- Easier debugging
- More reliable profile downloads

**PCIe Mode:**
- Faster data throughput
- May have tool compatibility issues
- Reported QMI problems in forum

**Check current mode:**
```bash
# USB devices
lsusb | grep Quectel

# PCIe devices
lspci | grep Quectel
```

### udev Rules

**Create persistent device names:**

```bash
# Create udev rule
sudo tee /etc/udev/rules.d/99-quectel-rm500q.rules > /dev/null <<EOF
# Quectel RM500Q-GL
SUBSYSTEM=="tty", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0800", SYMLINK+="modem-at", GROUP="dialout", MODE="0660"
SUBSYSTEM=="usb", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0800", GROUP="dialout", MODE="0660"
SUBSYSTEM=="usbmisc", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0800", GROUP="dialout", MODE="0660"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

**Now use persistent device:**
```bash
# /dev/modem-at links to /dev/ttyUSB2
export AT_DEVICE=/dev/modem-at
```

---

## Profile Management

### Complete Workflow

**1. Get activation code from carrier**
- QR code or activation string
- Format: `LPA:1$smdp.example.com$ACTIVATION-CODE`

**2. Download profile (choose method):**

**Using AT+QESIM:**
```bash
echo -e 'AT+QESIM="def_svr_addr","LPA:1$smdp.example.com$CODE"\r' | sudo tee /dev/ttyUSB2
```

**Using lpac:**
```bash
export LPAC_APDU=at AT_DEVICE=/dev/ttyUSB2
./lpac profile download -s smdp.example.com -m CODE
```

**3. List profiles:**
```bash
# AT+QESIM
echo -e 'AT+QESIM="list"\r' | sudo tee /dev/ttyUSB2

# lpac
./lpac profile list | jq
```

**4. Enable profile:**
```bash
# Note the ICCID from list output

# AT+QESIM
echo -e 'AT+QESIM="enable","<ICCID>"\r' | sudo tee /dev/ttyUSB2

# lpac
./lpac profile enable <ICCID>
```

**5. Configure APN and connect** (see Method 1)

### Multi-Profile Management

**Scenario: Switch between work and personal profiles**

```bash
#!/bin/bash
# profile-switcher.sh

DEVICE="/dev/ttyUSB2"

# Define profiles
WORK_ICCID="89012345678901234567"
WORK_APN="corporate.apn"

PERSONAL_ICCID="89012345678901234568"
PERSONAL_APN="internet"

switch_to_work() {
    echo "Switching to work profile..."

    # Disable personal
    echo -e "AT+QESIM=\"disable\",\"$PERSONAL_ICCID\"\r" | sudo tee "$DEVICE"
    sleep 2

    # Enable work
    echo -e "AT+QESIM=\"enable\",\"$WORK_ICCID\"\r" | sudo tee "$DEVICE"
    sleep 2

    # Set APN
    echo -e "AT+CGDCONT=1,\"IP\",\"$WORK_APN\"\r" | sudo tee "$DEVICE"

    echo "Switched to work profile"
}

switch_to_personal() {
    echo "Switching to personal profile..."

    # Disable work
    echo -e "AT+QESIM=\"disable\",\"$WORK_ICCID\"\r" | sudo tee "$DEVICE"
    sleep 2

    # Enable personal
    echo -e "AT+QESIM=\"enable\",\"$PERSONAL_ICCID\"\r" | sudo tee "$DEVICE"
    sleep 2

    # Set APN
    echo -e "AT+CGDCONT=1,\"IP\",\"$PERSONAL_APN\"\r" | sudo tee "$DEVICE"

    echo "Switched to personal profile"
}

case "$1" in
    work)
        switch_to_work
        ;;
    personal)
        switch_to_personal
        ;;
    *)
        echo "Usage: $0 {work|personal}"
        exit 1
        ;;
esac
```

---

## Troubleshooting

### Profile Download Fails

**Symptom:** Profile download times out or fails

**Solutions:**

1. **Check internet connectivity:**
   ```bash
   # Ensure host has internet via Ethernet/WiFi
   ping -c 4 8.8.8.8
   curl -v https://www.google.com
   ```

2. **Verify activation code:**
   - Check for typos
   - Ensure code not already used
   - Activation codes are typically one-time use

3. **Update firmware:**
   - Use RM500QGLAAR03A02M4G or newer
   - Check Quectel website for latest

4. **Try different method:**
   - If AT+QESIM fails, try lpac
   - If lpac fails, try AT+QESIM

5. **Check SM-DP+ server reachability:**
   ```bash
   # Test HTTPS connectivity to SM-DP+ server
   curl -v https://smdp.example.com
   ```

### AT+QESIM Command Not Supported

**Symptom:** `AT+QESIM=?` returns ERROR

**Solutions:**

1. **Check firmware version:**
   ```bash
   echo -e "ATI\r" | sudo tee /dev/ttyUSB2
   ```
   - Must be RM500QGLAAR03A02M4G or newer

2. **Update firmware** (see Firmware Requirements section)

3. **Use alternative method:**
   - Try lpac (Method 3)
   - Contact Quectel support for LPAd

### Profile Enable Fails

**Symptom:** Cannot enable profile

**Solutions:**

1. **Check profile state:**
   ```bash
   # List profiles
   echo -e 'AT+QESIM="list"\r' | sudo tee /dev/ttyUSB2

   # Profile must be in "disabled" state to enable
   ```

2. **Disable current profile first:**
   ```bash
   # Only one profile can be enabled at a time
   echo -e 'AT+QESIM="disable","<CURRENT_ICCID>"\r' | sudo tee /dev/ttyUSB2
   sleep 2
   echo -e 'AT+QESIM="enable","<NEW_ICCID>"\r' | sudo tee /dev/ttyUSB2
   ```

3. **Check eUICC status:**
   ```bash
   echo -e 'AT+QESIM="euicc_info"\r' | sudo tee /dev/ttyUSB2
   ```

### ModemManager Interference

**Symptom:** Commands fail intermittently or modem not responding

**Solution:**

```bash
# Stop ModemManager
sudo systemctl stop ModemManager

# Disable permanently (optional)
sudo systemctl disable ModemManager

# Or configure ModemManager to ignore RM500Q
# Create file: /etc/ModemManager/ModemManager.conf
[Service]
Environment="MM_FILTER_RULE_TTY_BLACKLIST=/dev/ttyUSB2"
```

### lpac Build Errors

**Symptom:** Compilation fails

**Solutions:**

1. **Install all dependencies:**
   ```bash
   sudo apt install \
       git \
       cmake \
       build-essential \
       libpcsclite-dev \
       libcurl4-openssl-dev \
       pkg-config
   ```

2. **Clean and rebuild:**
   ```bash
   cd lpac
   rm -rf CMakeCache.txt CMakeFiles/ build/
   cmake . -DLPAC_WITH_APDU_AT=1
   make clean
   make
   ```

3. **Check for errors in output**
   - Missing libraries
   - Incompatible versions
   - Install required packages

### No Network Connection After Enable

**Symptom:** Profile enabled but no network

**Solutions:**

1. **Configure APN:**
   ```bash
   echo -e 'AT+CGDCONT=1,"IP","<APN>"\r' | sudo tee /dev/ttyUSB2
   ```

2. **Check registration:**
   ```bash
   echo -e "AT+CREG?\r" | sudo tee /dev/ttyUSB2
   # Should show: +CREG: 0,1 or +CREG: 0,5
   ```

3. **Check signal:**
   ```bash
   echo -e "AT+CSQ\r" | sudo tee /dev/ttyUSB2
   # RSSI should be > 10
   ```

4. **Reboot modem:**
   ```bash
   echo -e "AT+CFUN=1,1\r" | sudo tee /dev/ttyUSB2
   # Wait 30 seconds for modem to reboot
   ```

### QMI Connection Issues (LPAd)

**Symptom:** LPAd cannot connect via QMI

**Solutions:**

1. **Verify QMI device:**
   ```bash
   ls -l /dev/cdc-wdm*
   sudo qmicli -d /dev/cdc-wdm0 --dms-get-model
   ```

2. **Use USB mode instead of PCIe:**
   - Better LPAd compatibility reported
   - Check forum discussion

3. **Update libqmi:**
   ```bash
   sudo apt update
   sudo apt install --upgrade libqmi-utils libqmi-glib5
   ```

4. **Use alternative method:**
   - AT+QESIM (Method 2) recommended
   - lpac (Method 3) as backup

---

## Community Experiences

### Forum Highlights

**l0git3k (Original Poster):**
- RM500Q-GL works on Ubuntu Server 5.15
- Sought eSIM activation guidance
- Documentation lacking for Quectel Connect Manager

**numbqq (Khadas Official):**
- Confirmed eSIM works like normal SIM
- Just need correct APN configuration
- Use AT+CGDCONT for setup

**steely-glint:**
- Recommended open-source lpac tool
- lpac-quectel fork available on GitHub
- Some challenges downloading fresh profiles

**Community Consensus:**
- AT+QESIM commands most reliable
- Firmware version important
- lpac works with proper patching
- LPAd has limited success

### Successful Configurations

**Working setup 1:**
- Hardware: RM500Q-GL
- Firmware: RM500QGLAAR03A02M4G
- Method: AT+QESIM commands
- Interface: USB
- OS: Ubuntu 22.04

**Working setup 2:**
- Hardware: RM520N-GL (newer variant)
- Firmware: RM520NGLAAR03A03M4G
- Method: lpac (patched)
- Interface: USB
- OS: Debian 11

**Recommended configuration:**
- Use AT+QESIM for profile management
- Use standard AT commands for APN/connection
- Keep ModemManager stopped during eSIM operations
- USB interface preferred over PCIe

---

## Best Practices

### General Recommendations

1. **Firmware first:**
   - Update to latest firmware before eSIM operations
   - Check Quectel website regularly

2. **Use USB interface:**
   - Better tool compatibility
   - Easier debugging
   - More community support

3. **Stop ModemManager:**
   - Always stop during eSIM operations
   - Prevents interference

4. **Backup activation codes:**
   - Store codes securely
   - Many are one-time use only

5. **Test with physical SIM first:**
   - Verify modem works
   - Confirm APN settings
   - Then proceed to eSIM

### Production Deployment

**For IoT/embedded systems:**

1. **Automate profile management:**
   - Use scripts for switching
   - Implement error handling
   - Log all operations

2. **Monitor profile state:**
   - Check enabled profile periodically
   - Alert on profile issues
   - Track usage per profile

3. **Secure credentials:**
   - Never hardcode activation codes
   - Use environment variables
   - Implement access controls

4. **Plan for failures:**
   - Keep backup profiles
   - Implement fallback mechanisms
   - Test recovery procedures

### Security Considerations

**Activation codes:**
- Treat as sensitive credentials
- Don't commit to version control
- Use secure distribution methods

**Profile management:**
- Limit access to AT command port
- Log profile changes
- Audit profile operations

**Network security:**
- Use proper APNs
- Enable VPN if required
- Monitor data usage

---

## References

### Official Resources

**Quectel:**
- Website: https://www.quectel.com/
- Product page: RM500Q-GL
- Support: Contact for documentation and firmware

**Khadas:**
- Forum discussion: https://forum.khadas.com/t/how-to-use-esim-with-the-rm-500q-gl/21975
- VIM4 documentation: https://docs.khadas.com/

### Open Source Tools

**lpac:**
- Main repository: https://github.com/estkme-group/lpac
- Releases: Check GitHub releases page
- Documentation: Project README

**qfirehose:**
- Repository: https://github.com/xnano/qfirehose
- For Linux firmware updates

### Related Guides

**From this project:**
- ESIM_LPAC_USB_MODEM_GUIDE.md - General lpac usage
- ESIM_LPAC_QUECTEL_PATCHING_GUIDE.md - Quectel-specific patches
- AT_COMMANDS_COMPREHENSIVE_GUIDE.md - AT command reference

### Community Resources

- Khadas Forum: https://forum.khadas.com/
- OpenWRT Forum: eSIM discussions
- Reddit: r/eSIM
- GitHub: Search "lpac quectel"

---

## Summary

The Quectel RM500Q-GL supports eSIM through multiple methods:

**Recommended Method: AT+QESIM Commands**
```bash
# Download profile
AT+QESIM="def_svr_addr","LPA:1$smdp.example.com$CODE"

# List profiles
AT+QESIM="list"

# Enable profile
AT+QESIM="enable","<ICCID>"

# Configure APN
AT+CGDCONT=1,"IP","<APN>"
```

**Alternative Method: lpac**
```bash
export LPAC_APDU=at AT_DEVICE=/dev/ttyUSB2
./lpac profile download -s smdp.example.com -m CODE
./lpac profile enable <ICCID>
```

**Key Requirements:**
- ✅ Firmware RM500QGLAAR03A02M4G or newer
- ✅ QMI-aware drivers (kernel 5.15+)
- ✅ Stop ModemManager during operations
- ✅ USB interface recommended

**Community Insights:**
- AT+QESIM most reliable
- lpac works with proper patching
- Proprietary LPAd has limited success
- Configuration similar to physical SIM once profile enabled

The RM500Q-GL provides robust eSIM support when properly configured with the right firmware and tools.

---

*This guide is compiled from Khadas forum discussion and community experiences with Quectel RM500Q-GL eSIM usage.*
