# OpenWRT CUPS Advanced Print Server Guide

## Table of Contents
1. [Overview](#overview)
2. [System Requirements](#system-requirements)
3. [Installation](#installation)
4. [CUPS Configuration](#cups-configuration)
5. [Printer Detection and Setup](#printer-detection-and-setup)
6. [Web Interface Management](#web-interface-management)
7. [Client Configuration by Platform](#client-configuration-by-platform)
8. [Driver Configuration](#driver-configuration)
9. [AirPrint Setup](#airprint-setup)
10. [Google Cloud Print (Legacy)](#google-cloud-print-legacy)
11. [Advanced Configuration](#advanced-configuration)
12. [Troubleshooting](#troubleshooting)
13. [Performance Optimization](#performance-optimization)

---

## Overview

CUPS (Common Unix Printing System) is a comprehensive print server solution for OpenWRT that provides:

### Key Features

- ✅ **IPP Protocol**: Internet Printing Protocol support
- ✅ **Multi-Platform**: Linux, macOS, Windows, iOS, Android support
- ✅ **Print Queue Management**: Job control, pause, cancel, reorder
- ✅ **Printer Sharing**: Network-wide printer access
- ✅ **AirPrint Support**: Direct printing from iOS/macOS devices
- ✅ **Web Interface**: Browser-based administration
- ✅ **Driver Support**: PPD files for numerous printers
- ✅ **Job History**: Logging and accounting

### CUPS vs p910nd

| Feature | CUPS | p910nd |
|---------|------|--------|
| Package Size | 5-7 MB | ~50 KB |
| RAM Usage | 15-25 MB | 1-2 MB |
| Print Queue | ✅ Yes | ❌ No |
| Job Control | ✅ Full | ❌ None |
| Driver Support | ✅ Extensive | ❌ Limited |
| AirPrint | ✅ Yes | ❌ No |
| Web Interface | ✅ Yes | ❌ No |
| Protocols | IPP, LPD, SMB | Raw TCP |
| Complexity | High | Low |

**When to use CUPS:**
- Need print queue management
- Multiple users/computers
- iOS/macOS AirPrint support
- Advanced printer features
- Router has sufficient resources (128MB+ RAM, 16MB+ flash)

---

## System Requirements

### Hardware Requirements

**Minimum:**
- 64MB RAM (128MB recommended)
- 16MB Flash storage (or external USB storage)
- USB 2.0 port
- 400MHz+ CPU

**Recommended:**
- 128MB+ RAM for stable operation
- 32MB+ Flash or external storage
- USB 2.0 or 3.0 port
- 600MHz+ CPU for faster processing

### Storage Considerations

CUPS packages require approximately **6-7MB** of storage space:
- `cups` - 2-3MB
- `cups-client` - 1MB
- `cups-filters` - 2-3MB
- Dependencies - 1-2MB

**Solutions for limited flash:**
- **External root**: Move root filesystem to USB drive
- **Extroot**: Extend overlay to USB storage
- **USB installation**: Install CUPS packages to USB

### OpenWRT Version Requirements

- OpenWRT 19.07 (Chaos Calmer) or newer
- OpenWRT 21.02 recommended
- OpenWRT 22.03 or 23.05 (latest)

---

## Installation

### Step 1: Prepare System

```bash
# Update package lists
opkg update

# Install USB support (if not already installed)
opkg install kmod-usb-core kmod-usb2

# Check available storage
df -h
# Ensure at least 10MB free space
```

### Step 2: Remove Conflicting Packages

**IMPORTANT**: Remove p910nd and kmod-usb-printer if installed:

```bash
# Check for conflicts
opkg list-installed | grep -E "p910nd|kmod-usb-printer"

# Remove p910nd
opkg remove p910nd luci-app-p910nd

# Remove kmod-usb-printer (CUPS has its own printer support)
opkg remove kmod-usb-printer

# Reboot recommended
reboot
```

**Why remove these?**
- `kmod-usb-printer` conflicts with CUPS USB backend
- `p910nd` creates device lock conflicts
- CUPS includes its own USB printer support

### Step 3: Install CUPS Packages

```bash
# Install core CUPS packages
opkg install cups

# Install CUPS client utilities
opkg install cups-client

# Install CUPS filters (for driver support)
opkg install cups-filters

# Install Berkeley Printing Package (for lpr/lpq commands)
opkg install cups-bsd

# Install PPD compiler (optional, for custom drivers)
opkg install cups-ppdc

# Install PostScript/PDF filters (optional)
opkg install ghostscript

# Verify installation
opkg list-installed | grep cups
```

### Step 4: Install Web Interface (Optional)

```bash
# Install LuCI CUPS app
opkg install luci-app-cups

# Restart LuCI
/etc/init.d/uhttpd restart
```

### Step 5: Set Root Password

**IMPORTANT**: CUPS requires root password for administration:

```bash
# Set root password if not already set
passwd

# Verify password is set
grep root /etc/shadow
# Should show encrypted password, not empty field
```

---

## CUPS Configuration

### Basic Configuration File

Edit `/etc/cups/cupsd.conf`:

```bash
# Backup original configuration
cp /etc/cups/cupsd.conf /etc/cups/cupsd.conf.backup

# Edit configuration
vi /etc/cups/cupsd.conf
```

**Essential configuration:**

```apache
# Server settings
LogLevel warn
MaxLogSize 0
ErrorPolicy retry-job

# Listen on all interfaces
Listen 0.0.0.0:631
Listen /var/run/cups/cups.sock

# Browsing (printer discovery)
Browsing On
BrowseLocalProtocols dnssd

# Access control
<Location />
  Order allow,deny
  Allow @LOCAL
</Location>

<Location /admin>
  Order allow,deny
  Allow @LOCAL
</Location>

<Location /admin/conf>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow @LOCAL
</Location>

# Printer sharing
<Policy default>
  JobPrivateAccess default
  JobPrivateValues default
  SubscriptionPrivateAccess default
  SubscriptionPrivateValues default

  <Limit Create-Job Print-Job Print-URI Validate-Job>
    Order deny,allow
  </Limit>

  <Limit Send-Document Send-URI Hold-Job Release-Job Restart-Job Purge-Jobs>
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>

  <Limit Cancel-Job CUPS-Authenticate-Job>
    Require user @OWNER @SYSTEM
    Order deny,allow
  </Limit>

  <Limit All>
    Order deny,allow
  </Limit>
</Policy>
```

### Critical Configuration Changes

**1. Change SystemGroup to root:**

```apache
# Find line:
SystemGroup lpadmin

# Change to:
SystemGroup root
```

**2. Allow network access:**

```apache
# Replace:
Listen localhost:631

# With:
Listen 0.0.0.0:631
```

**3. Allow LAN access to admin pages:**

```apache
<Location /admin>
  Order allow,deny
  Allow from 192.168.1.0/24  # Your LAN subnet
</Location>

<Location /admin/conf>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow from 192.168.1.0/24
</Location>
```

### Simplified Configuration for OpenWRT

For embedded systems, use minimal configuration:

```apache
# /etc/cups/cupsd.conf - Minimal OpenWRT configuration

MaxLogSize 0
LogLevel warn
ErrorPolicy retry-job

Listen 0.0.0.0:631
Listen /var/run/cups/cups.sock

Browsing On
BrowseLocalProtocols dnssd

SystemGroup root
User root
Group root

<Location />
  Order allow,deny
  Allow all
</Location>

<Location /admin>
  Order allow,deny
  Allow all
</Location>

<Location /admin/conf>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow all
</Location>

<Policy default>
  <Limit All>
    Order deny,allow
  </Limit>
</Policy>
```

**Warning**: This configuration allows unrestricted network access. Use only on trusted networks.

### Start CUPS Service

```bash
# Enable CUPS daemon (start on boot)
/etc/init.d/cupsd enable

# Start CUPS daemon
/etc/init.d/cupsd start

# Check status
/etc/init.d/cupsd status

# Verify CUPS is running
ps | grep cupsd
# Should show: /usr/sbin/cupsd

# Check listening ports
netstat -antp | grep 631
# Should show: tcp 0 0.0.0.0:631 0.0.0.0:* LISTEN
```

---

## Printer Detection and Setup

### Detect USB Printers

**Method 1: CUPS USB Backend**

```bash
# List connected USB printers
/usr/lib/cups/backend/usb

# Example output:
# direct usb://Xerox/Phaser%203117?serial=ABCD1234 "Xerox Phaser 3117" "Xerox Phaser 3117 Laser Printer" "MFG:Xerox;CMD:PCL;MDL:Phaser 3117;CLS:PRINTER;DES:Xerox Phaser 3117;"
```

**Output format explained:**
```
direct usb://[Manufacturer]/[Model]?serial=[SerialNumber] "[Description]" "[Location]" "[Device ID]"
```

**Method 2: USB Device Detection**

```bash
# Check USB devices
lsusb

# Example output:
# Bus 001 Device 003: ID 0924:3ce9 Xerox Phaser 3117

# Check kernel messages
dmesg | grep -i usb
dmesg | grep -i printer
```

**Method 3: CUPS Discovery**

```bash
# List all available backends
lpinfo -v

# Output shows all detected printers:
# network ipp
# network ipps
# network http
# network https
# network socket
# direct usb://Xerox/Phaser%203117?serial=ABCD1234
# file cups-brf:/
```

### Add Printer via Command Line

```bash
# Basic syntax
lpadmin -p [PrinterName] -v [DeviceURI] -E -m [Driver/PPD]

# Example: Add USB printer with RAW driver
lpadmin -p Xerox_3117 \
  -v usb://Xerox/Phaser%203117?serial=ABCD1234 \
  -E \
  -m raw

# Enable printer
cupsenable Xerox_3117

# Accept jobs
cupsaccept Xerox_3117

# Set as default
lpadmin -d Xerox_3117

# Set printer description
lpadmin -p Xerox_3117 -D "Office Laser Printer"

# Set location
lpadmin -p Xerox_3117 -L "Main Office"

# Share printer on network
lpadmin -p Xerox_3117 -o printer-is-shared=true
```

### Using Specific PPD Driver

```bash
# List available drivers
lpinfo -m | grep -i xerox

# Example output:
# drv:///sample.drv/xerox.ppd Xerox Phaser 3117 PostScript
# everywhere IPP Everywhere

# Add printer with specific PPD
lpadmin -p Xerox_3117 \
  -v usb://Xerox/Phaser%203117?serial=ABCD1234 \
  -E \
  -m drv:///sample.drv/xerox.ppd

# Or use generic driver
lpadmin -p Xerox_3117 \
  -v usb://Xerox/Phaser%203117?serial=ABCD1234 \
  -E \
  -m drv:///sample.drv/generpcl.ppd
```

---

## Web Interface Management

### Accessing CUPS Web Interface

```
URL: http://192.168.1.1:631
(Replace with your router IP)
```

### Web Interface Sections

**1. Home Tab:**
- CUPS version information
- Server information
- Quick links

**2. Administration Tab:**
- Add Printer
- Manage Printers
- Manage Classes
- Server Settings
- View Error Log
- View Access Log
- View Page Log

**3. Printers Tab:**
- List of configured printers
- Printer status
- Quick actions (Print Test Page, Modify, Delete)

**4. Jobs Tab:**
- Active print jobs
- Completed jobs
- Job control (Cancel, Hold, Resume)

**5. Classes Tab:**
- Printer classes (groups)
- Class management

### Add Printer via Web Interface

**Step 1: Navigate to Administration**
- Click "Administration" tab
- Click "Add Printer"
- Login: username `root`, password (your root password)

**Step 2: Select Printer**
- Under "Local Printers", select your USB printer
- Example: `Xerox Phaser 3117 (Xerox Phaser 3117)`
- Click "Continue"

**Step 3: Printer Information**
- **Name**: `Xerox_3117` (no spaces, letters/numbers/underscores only)
- **Description**: `Office Laser Printer` (descriptive name)
- **Location**: `Main Office, Room 201` (physical location)
- **Share This Printer**: ✓ Check to enable network sharing
- Click "Continue"

**Step 4: Select Driver**
- **Option A - RAW (No Driver):**
  - Select "RAW" from manufacturer list
  - Select "Raw Queue (en)"
  - This sends data directly without processing
  - **Use when**: Drivers installed on client computers

- **Option B - Generic PCL:**
  - Select "Generic" manufacturer
  - Select "Generic PCL Laser Printer"
  - Works with most laser printers

- **Option C - IPP Everywhere:**
  - Select "IPP Everywhere"
  - Auto-configuration for modern printers
  - **Best for**: Driverless printing

- **Option D - Specific PPD:**
  - Select manufacturer (e.g., "Xerox")
  - Select specific model
  - **Use when**: Available for your printer

- Click "Add Printer"

**Step 5: Set Default Options**
- **Media Size**: A4 or Letter
- **Print Quality**: Normal/Draft/Best
- **Duplex**: None/Long Edge/Short Edge
- Click "Set Default Options"

**Step 6: Verify**
- Printer should appear in "Printers" tab
- Status should be "Idle"
- Click "Print Test Page" to verify

### Printer Management Actions

**Print Test Page:**
```bash
# Via web interface: Printers → [Printer Name] → Print Test Page

# Via command line:
echo "Test page" | lp -d Xerox_3117
```

**Modify Printer Settings:**
- Web: Printers → [Printer Name] → Administration → Modify Printer
- Change URI, driver, or options

**Delete Printer:**
```bash
# Via web interface: Printers → [Printer Name] → Administration → Delete Printer

# Via command line:
lpadmin -x Xerox_3117
```

**Pause/Resume Printer:**
```bash
# Via web interface: Printers → [Printer Name] → Maintenance → Pause/Resume

# Via command line:
cupsdisable Xerox_3117  # Pause
cupsenable Xerox_3117   # Resume
```

**Accept/Reject Jobs:**
```bash
# Via web interface: Printers → [Printer Name] → Maintenance → Accept/Reject Jobs

# Via command line:
cupsaccept Xerox_3117   # Accept jobs
cupsreject Xerox_3117   # Reject jobs
```

---

## Client Configuration by Platform

### Linux Clients

#### Method 1: Command Line

```bash
# Add printer
lpadmin -p NetworkPrinter \
  -v ipp://192.168.1.1:631/printers/Xerox_3117 \
  -E

# Or with ipp14 protocol (CUPS 1.4+)
lpadmin -p NetworkPrinter \
  -v ipp14://192.168.1.1:631/printers/Xerox_3117 \
  -E

# Set as default
lpadmin -d NetworkPrinter

# Test print
echo "Test from Linux" | lp
```

#### Method 2: GNOME (Ubuntu, Fedora)

1. **Open Settings:**
   - Settings → Printers
   - Or: System Settings → Printers

2. **Add Printer:**
   - Click "Add" or "+" button
   - Select "Network Printer"

3. **Find Printer:**
   - Wait for auto-discovery
   - Or manually enter: `ipp://192.168.1.1:631/printers/Xerox_3117`

4. **Select Driver:**
   - Choose from detected list
   - Or select "Generic PCL Printer"
   - Or use "IPP Everywhere"

5. **Name and Add:**
   - Give printer a name
   - Click "Add"

#### Method 3: KDE (Kubuntu, openSUSE)

1. **Open Printer Settings:**
   - System Settings → Printers

2. **Add Printer:**
   - Click "Add Printer"

3. **Select Type:**
   - Choose "CUPS server"
   - Or "IPP/Internet Printing Protocol"

4. **Enter Details:**
   - URI: `ipp://192.168.1.1:631/printers/Xerox_3117`
   - Click "Forward"

5. **Select Driver and Finish**

### macOS Clients

#### Method 1: System Preferences

1. **Open Printers & Scanners:**
   - System Preferences → Printers & Scanners
   - Or: System Settings → Printers & Scanners (macOS 13+)

2. **Add Printer:**
   - Click "+" button to add printer
   - Wait for auto-discovery (Bonjour/AirPrint)
   - Printer should appear automatically if AirPrint is configured

3. **Manual Entry:**
   - If not auto-discovered, click "IP" tab
   - **Address**: `192.168.1.1`
   - **Protocol**: "Internet Printing Protocol - IPP"
   - **Queue**: `/printers/Xerox_3117`
   - **Name**: `Office Printer`
   - **Use**: Select driver or "Generic PostScript Printer"

4. **Add Printer:**
   - Click "Add"
   - macOS may download additional software

### Windows Clients

#### Method 1: IPP Printer

1. **Open Devices and Printers:**
   - Control Panel → Devices and Printers
   - Or: Settings → Devices → Printers & scanners

2. **Add Printer:**
   - Click "Add a printer"
   - Click "The printer that I want isn't listed"

3. **Select Printer Option:**
   - Choose "Select a shared printer by name"
   - Enter: `http://192.168.1.1:631/printers/Xerox_3117`
   - Click "Next"

4. **Install Driver:**
   - Windows will attempt to find driver
   - Or select from list
   - Or "Have Disk" for downloaded driver

5. **Complete Setup:**
   - Name the printer
   - Set as default if desired
   - Click "Finish"

#### Method 2: Standard TCP/IP Port

1. **Add Local Printer:**
   - Devices and Printers → Add a printer
   - Select "Add a local printer"

2. **Create New Port:**
   - Select "Create a new port"
   - Port type: "Standard TCP/IP Port"
   - Click "Next"

3. **Enter IP Address:**
   - Hostname or IP: `192.168.1.1`
   - Port name: `192.168.1.1:631`
   - Uncheck "Query the printer"
   - Click "Next"

4. **Custom Settings:**
   - Device Type: "Custom"
   - Settings → Protocol: "LPR"
   - Queue name: `printers/Xerox_3117`
   - LPR Byte Counting: Enabled
   - Click "OK" and "Next"

5. **Install Driver and Finish**

### iOS/iPadOS Clients

**Requires AirPrint** (see AirPrint Setup section below)

**Printing:**
1. Open document/photo
2. Tap Share icon
3. Tap "Print"
4. Select printer (should auto-discover)
5. Adjust settings (copies, pages, etc.)
6. Tap "Print"

### Android Clients

#### Method 1: Mopria Print Service

1. **Install Mopria:**
   - Google Play Store → "Mopria Print Service"
   - Install and enable

2. **Print:**
   - Open document
   - Menu → Print
   - Select printer (auto-discovery)
   - Tap print icon

#### Method 2: CUPS Print App

1. **Install CupsPrint:**
   - Google Play Store → "CupsPrint"
   - Configure: IP `192.168.1.1`, Port `631`

2. **Print:**
   - Share document to CupsPrint
   - Select printer
   - Print

---

## Driver Configuration

### RAW Driver (No Processing)

**Use case**: Client computers have printer drivers installed

```bash
# Add printer with RAW driver
lpadmin -p Printer_RAW \
  -v usb://Manufacturer/Model \
  -E \
  -m raw

# Enable sharing
lpadmin -p Printer_RAW -o printer-is-shared=true
```

**Advantages:**
- No processing on router (faster, less CPU)
- Full driver features on client
- Works with any printer

**Disadvantages:**
- Requires driver on every client
- No server-side job processing
- Limited cross-platform compatibility

### Generic PCL Driver

**Use case**: Laser printers with PCL support

```bash
# Add printer with Generic PCL driver
lpadmin -p Printer_PCL \
  -v usb://Manufacturer/Model \
  -E \
  -m drv:///sample.drv/generpcl.ppd

# Or use foomatic driver
lpadmin -p Printer_PCL \
  -v usb://Manufacturer/Model \
  -E \
  -m drv:///cupsfilters.drv/laserjet.ppd
```

**Advantages:**
- Universal compatibility
- No client drivers needed
- Works on all platforms

**Disadvantages:**
- Basic features only
- May not support all printer capabilities

### IPP Everywhere (Driverless)

**Use case**: Modern printers with driverless printing support

```bash
# Add printer with IPP Everywhere
lpadmin -p Printer_IPP \
  -v usb://Manufacturer/Model \
  -E \
  -m everywhere

# CUPS will auto-configure
```

**Advantages:**
- Automatic configuration
- Full feature support
- Standard protocol

**Requirements:**
- Printer must support IPP Everywhere
- CUPS 2.2.4+

### PostScript Driver

**Use case**: PostScript printers (many laser printers)

```bash
# Add with PostScript driver
lpadmin -p Printer_PS \
  -v usb://Manufacturer/Model \
  -E \
  -m drv:///sample.drv/generic-ps.ppd
```

### Custom PPD Files

**Upload custom PPD:**

1. **Via Web Interface:**
   - Administration → Add Printer
   - Select printer → Continue
   - Choose "Browse..." next to "Or Provide a PPD File"
   - Upload PPD file

2. **Via Command Line:**
```bash
# Copy PPD to CUPS directory
cp custom-printer.ppd /usr/share/cups/model/

# Add printer using custom PPD
lpadmin -p Custom_Printer \
  -v usb://Manufacturer/Model \
  -E \
  -P /usr/share/cups/model/custom-printer.ppd
```

---

## AirPrint Setup

AirPrint allows iOS and macOS devices to print without drivers.

### Requirements

- CUPS configured and running
- Avahi daemon (Bonjour/mDNS)
- Properly configured PPD driver (not RAW)

### Step 1: Install Avahi

```bash
# Install Avahi daemon
opkg install avahi-daemon

# Install Avahi utilities
opkg install avahi-utils
```

### Step 2: Configure Avahi

Edit `/etc/avahi/avahi-daemon.conf`:

```ini
[server]
host-name=openwrt
domain-name=local
use-ipv4=yes
use-ipv6=no
enable-dbus=no
allow-interfaces=br-lan

[wide-area]
enable-wide-area=no

[publish]
publish-addresses=yes
publish-hinfo=yes
publish-workstation=no
publish-domain=yes

[reflector]
enable-reflector=no

[rlimits]
rlimit-core=0
rlimit-data=4194304
rlimit-fsize=0
rlimit-nofile=30
rlimit-stack=4194304
rlimit-nproc=3
```

### Step 3: Create AirPrint Service File

**Method 1: Manual Service File**

Create `/etc/avahi/services/airprint.service`:

```xml
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">AirPrint Xerox 3117 @ %h</name>
  <service>
    <type>_ipp._tcp</type>
    <subtype>_universal._sub._ipp._tcp</subtype>
    <port>631</port>
    <txt-record>txtver=1</txt-record>
    <txt-record>qtotal=1</txt-record>
    <txt-record>rp=printers/Xerox_3117</txt-record>
    <txt-record>ty=Xerox Phaser 3117</txt-record>
    <txt-record>adminurl=http://192.168.1.1:631/printers/Xerox_3117</txt-record>
    <txt-record>note=Office Printer</txt-record>
    <txt-record>priority=0</txt-record>
    <txt-record>product=(GPL Ghostscript)</txt-record>
    <txt-record>printer-state=3</txt-record>
    <txt-record>printer-type=0x801046</txt-record>
    <txt-record>Transparent=T</txt-record>
    <txt-record>Binary=T</txt-record>
    <txt-record>Fax=F</txt-record>
    <txt-record>Color=T</txt-record>
    <txt-record>Duplex=T</txt-record>
    <txt-record>Staple=F</txt-record>
    <txt-record>Copies=T</txt-record>
    <txt-record>Collate=F</txt-record>
    <txt-record>Punch=F</txt-record>
    <txt-record>Bind=F</txt-record>
    <txt-record>Sort=F</txt-record>
    <txt-record>Scan=F</txt-record>
    <txt-record>pdl=application/octet-stream,application/pdf,application/postscript,image/jpeg,image/png,image/urf</txt-record>
    <txt-record>URF=W8,SRGB24,CP1,RS600</txt-record>
  </service>
</service-group>
```

**Adjust parameters:**
- `<name>`: Printer name as shown on iOS devices
- `rp=printers/Xerox_3117`: CUPS queue name
- `ty=Xerox Phaser 3117`: Printer model
- `adminurl=http://192.168.1.1:631/printers/Xerox_3117`: Web admin URL
- `Color=T`: T for color, F for B&W
- `Duplex=T`: T if duplex supported, F otherwise

**Method 2: Automatic Generation Script**

```bash
cat > /root/generate-airprint.sh << 'EOF'
#!/bin/bash

CUPS_SERVER="192.168.1.1"
OUTPUT_DIR="/etc/avahi/services"

# Get list of printers
PRINTERS=$(lpstat -p | awk '{print $2}')

for PRINTER in $PRINTERS; do
    # Get printer info
    INFO=$(lpstat -l -p $PRINTER)
    DESC=$(echo "$INFO" | grep Description | cut -d: -f2 | xargs)

    # Create service file
    cat > "$OUTPUT_DIR/${PRINTER}.service" <<AIRPRINT
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">AirPrint ${DESC} @ %h</name>
  <service>
    <type>_ipp._tcp</type>
    <subtype>_universal._sub._ipp._tcp</subtype>
    <port>631</port>
    <txt-record>txtver=1</txt-record>
    <txt-record>qtotal=1</txt-record>
    <txt-record>rp=printers/${PRINTER}</txt-record>
    <txt-record>ty=${DESC}</txt-record>
    <txt-record>adminurl=http://${CUPS_SERVER}:631/printers/${PRINTER}</txt-record>
    <txt-record>note=Network Printer</txt-record>
    <txt-record>pdl=application/pdf,image/jpeg,image/urf</txt-record>
    <txt-record>URF=W8,SRGB24,CP1,RS600</txt-record>
  </service>
</service-group>
AIRPRINT

    echo "Created AirPrint service for: $PRINTER"
done
EOF

chmod +x /root/generate-airprint.sh
/root/generate-airprint.sh
```

### Step 4: Start Avahi

```bash
# Enable Avahi (start on boot)
/etc/init.d/avahi-daemon enable

# Start Avahi
/etc/init.d/avahi-daemon start

# Check status
/etc/init.d/avahi-daemon status

# Verify services
avahi-browse -a -t -r
# Should show _ipp._tcp services
```

### Step 5: Test AirPrint

**On iOS device:**
1. Open any document or photo
2. Tap Share icon
3. Tap "Print"
4. Printer should appear automatically
5. Select and print

**Troubleshooting:**
- Printer must have proper PPD (not RAW)
- Firewall must allow port 631 and mDNS (port 5353 UDP)
- Avahi must be running
- iOS device must be on same network

---

## Google Cloud Print (Legacy)

**⚠️ IMPORTANT**: Google Cloud Print was discontinued on December 31, 2020. This section is for historical reference only.

### Historical Setup (No Longer Works)

```bash
# Install dependencies (historical)
opkg install python python-pip

# Install Cloud Print client (historical)
pip install cloudprint

# Configure (historical)
cloudprint --register
```

### Alternatives to Google Cloud Print

**1. Native Mobile Printing:**
- Use AirPrint (iOS/macOS)
- Use Mopria (Android)

**2. Third-Party Services:**
- PrinterShare
- Print Central
- Printer Pro

**3. Email-to-Print:**
- Configure email forwarding to print automatically
- Use CUPS with custom script

---

## Advanced Configuration

### Temporary Directory Configuration

CUPS uses `/tmp` for temporary files. On OpenWRT with limited space:

```bash
# Check /tmp space
df -h /tmp

# If limited, use USB storage
mkdir -p /mnt/usb/cups-tmp

# Edit /etc/cups/cupsd.conf
# Add or modify:
TempDir /mnt/usb/cups-tmp

# Restart CUPS
/etc/init.d/cupsd restart
```

### Printer Firmware Upload

Some printers require firmware uploaded on each power-on (e.g., HP LaserJet 1020):

```bash
# Create hotplug script
cat > /etc/hotplug.d/usb/20-printer-firmware << 'EOF'
#!/bin/sh

# HP LaserJet 1020 example
if [ "$PRODUCT" = "3f0/4117/100" ]; then
    sleep 2
    /usr/lib/cups/backend/usb --firmware /lib/firmware/sihp1020.dl
    sleep 5
fi
EOF

chmod +x /etc/hotplug.d/usb/20-printer-firmware

# Place firmware in /lib/firmware/
mkdir -p /lib/firmware
# Copy printer firmware to /lib/firmware/
```

### Remove Default Printer Profiles

CUPS may include default printer configs. Remove if causing conflicts:

```bash
# List default printers
ls /etc/cups/ppd/

# Remove all PPDs (fresh start)
rm /etc/cups/ppd/*.ppd

# Remove printer configuration
rm /etc/cups/printers.conf

# Restart CUPS
/etc/init.d/cupsd restart

# Re-add printers via web interface
```

### Enable Detailed Logging

```bash
# Edit /etc/cups/cupsd.conf
# Change:
LogLevel warn

# To:
LogLevel debug

# Restart CUPS
/etc/init.d/cupsd restart

# View logs
logread | grep cups
# Or:
cat /var/log/cups/error_log
```

### Custom Print Queue Scripts

```bash
# Add custom backend script
cat > /usr/lib/cups/backend/custom-script << 'EOF'
#!/bin/sh

# Custom print processing
# Called by CUPS for each print job

# Arguments: job-id user title copies options [file]
JOB_ID=$1
USER=$2
TITLE=$3
COPIES=$4
OPTIONS=$5
FILE=$6

# Process print job
# Example: Save to file, send email notification, etc.

# Forward to actual printer
cat $FILE | /usr/lib/cups/backend/usb "$DEVICE_URI"
EOF

chmod +x /usr/lib/cups/backend/custom-script
```

### Multiple CUPS Instances

For advanced setups with multiple isolated print servers:

```bash
# Create second instance directory
mkdir -p /etc/cups2

# Copy configuration
cp -r /etc/cups/* /etc/cups2/

# Edit /etc/cups2/cupsd.conf
# Change port to 632
Listen 0.0.0.0:632

# Start second instance
cupsd -c /etc/cups2/cupsd.conf

# Manage via:
# http://192.168.1.1:632
```

---

## Troubleshooting

### CUPS Won't Start

**Check configuration:**
```bash
# Validate cupsd.conf
cupsd -t

# If errors, fix configuration file
vi /etc/cups/cupsd.conf

# Check for permission issues
ls -la /etc/cups/
chmod 755 /etc/cups
```

**Check storage space:**
```bash
df -h
# Ensure sufficient space for /tmp and /var
```

**Check dependencies:**
```bash
opkg list-installed | grep cups
# Ensure all packages installed
```

### Printer Not Detected

**Check USB:**
```bash
lsusb
dmesg | grep -i usb

# Test backend directly
/usr/lib/cups/backend/usb

# If no output, USB issue
```

**Verify no conflicts:**
```bash
# Ensure p910nd removed
ps | grep p910nd

# Ensure kmod-usb-printer removed
lsmod | grep usblp
```

### Web Interface Inaccessible

**Check CUPS is running:**
```bash
ps | grep cupsd
netstat -antp | grep 631
```

**Check configuration:**
```bash
# Ensure listening on correct interface
grep "Listen" /etc/cups/cupsd.conf
# Should show: Listen 0.0.0.0:631

# Check access control
grep -A 3 "Location" /etc/cups/cupsd.conf
```

**Check firewall:**
```bash
# Test from client
telnet 192.168.1.1 631
# Should connect

# If blocked, add firewall rule
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-CUPS'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='631'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart
```

### Cannot Login to Web Interface

**Set root password:**
```bash
passwd
# Enter new password twice
```

**Check SystemGroup:**
```bash
grep SystemGroup /etc/cups/cupsd.conf
# Should be: SystemGroup root
```

### Print Job Stays in Queue

**Check printer status:**
```bash
lpstat -p
# Should show "idle" or "processing"

# If disabled, enable:
cupsenable [PrinterName]
cupsaccept [PrinterName]
```

**Check job status:**
```bash
lpstat -o
# Shows queued jobs

# Cancel job:
cancel [job-id]

# Or cancel all:
cancel -a
```

**Check USB connection:**
```bash
# USB device should be present
ls -l /dev/usb/lp*

# Test backend
/usr/lib/cups/backend/usb
```

### AirPrint Not Working

**Check Avahi:**
```bash
/etc/init.d/avahi-daemon status

# Browse services
avahi-browse -a -t -r | grep -i ipp

# Should show _ipp._tcp services
```

**Check service files:**
```bash
ls -l /etc/avahi/services/
# Should contain .service files

# Validate XML syntax
cat /etc/avahi/services/airprint.service
```

**Check firewall:**
```bash
# Allow mDNS (port 5353 UDP)
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-mDNS'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='5353'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart
```

**Check printer driver:**
- AirPrint requires proper PPD (not RAW)
- Use Generic PCL, PostScript, or IPP Everywhere

### Slow Printing

**Check router resources:**
```bash
top
free
# High CPU/memory usage indicates overload
```

**Optimize:**
- Use RAW driver (no processing on router)
- Reduce print quality/DPI
- Use faster router hardware
- Disable unnecessary CUPS features

### Out of Memory

**Check memory:**
```bash
free
# If low, consider:
```

**Solutions:**
- Use p910nd instead (much lighter)
- Add swap space on USB
- Upgrade router RAM
- Reduce simultaneous print jobs

---

## Performance Optimization

### Memory Optimization

```bash
# Limit CUPS memory usage
# Edit /etc/cups/cupsd.conf

# Limit number of jobs
MaxJobs 5
MaxJobsPerPrinter 3
MaxJobsPerUser 2

# Reduce log size
MaxLogSize 1m

# Restart CUPS
/etc/init.d/cupsd restart
```

### Storage Optimization

```bash
# Move CUPS temp to USB
TempDir /mnt/usb/cups-tmp

# Move CUPS cache
CacheDir /mnt/usb/cups-cache

# Disable browsing if not needed
Browsing Off
```

### Network Optimization

```bash
# Reduce broadcast traffic
BrowseInterval 60
BrowseTimeout 300

# Limit protocols
BrowseLocalProtocols dnssd
```

---

## Conclusion

CUPS on OpenWRT provides enterprise-grade print server capabilities for home and small office environments.

### Summary

✅ **Installation:**
- Remove conflicting packages (p910nd, kmod-usb-printer)
- Install CUPS packages (~6-7MB)
- Configure cupsd.conf for network access
- Set root password

✅ **Configuration:**
- Use RAW for minimal processing
- Use specific PPD for features
- Enable sharing for network access
- Configure firewall rules

✅ **AirPrint:**
- Install Avahi daemon
- Create service files
- Use proper PPD (not RAW)
- Allow mDNS traffic

✅ **Client Setup:**
- Linux: IPP protocol
- macOS: Auto-discovery or manual IPP
- Windows: IPP URL or TCP/IP port
- iOS/Android: AirPrint/Mopria

✅ **Optimization:**
- Use RAW if sufficient
- Limit memory usage
- Use USB storage for temp files
- Monitor resource usage

### Decision Matrix

**Use CUPS when:**
- Need print queue management
- Multiple users/printers
- AirPrint support required
- Advanced features needed
- Sufficient resources (128MB+ RAM)

**Use p910nd when:**
- Simple printing sufficient
- Limited resources (<64MB RAM)
- No queue management needed
- Basic laser printer

### Resource Requirements Summary

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| RAM | 64MB | 128MB+ |
| Flash | 16MB | 32MB+ |
| CPU | 400MHz | 600MHz+ |
| Storage | 10MB | 20MB+ |

---

*Document Version: 1.0*
*Last Updated: 2025*
*Based on: https://eko.one.pl/?p=openwrt-cups*
*Compatible with: OpenWRT 19.07+*