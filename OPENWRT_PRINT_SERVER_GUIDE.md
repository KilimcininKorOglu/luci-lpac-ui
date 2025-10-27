# OpenWRT Print Server Guide

## Table of Contents
1. [Overview](#overview)
2. [Print Server Options](#print-server-options)
3. [Hardware Requirements](#hardware-requirements)
4. [Installation](#installation)
5. [p910nd Configuration](#p910nd-configuration)
6. [CUPS Configuration](#cups-configuration)
7. [Client Configuration](#client-configuration)
8. [Printer-Specific Setup](#printer-specific-setup)
9. [Troubleshooting](#troubleshooting)
10. [Advanced Features](#advanced-features)
11. [Performance Considerations](#performance-considerations)

---

## Overview

OpenWRT can transform your router into a network print server, allowing USB printers to be shared across your network. This eliminates the need for a dedicated computer to be running for network printing.

### Benefits

- ✅ **24/7 Availability**: Print server always running (unlike desktop PC)
- ✅ **Low Power Consumption**: Router uses minimal electricity
- ✅ **Cost-Effective**: No dedicated print server hardware needed
- ✅ **Centralized Printing**: One printer accessible by all network devices
- ✅ **Simple Setup**: Basic configuration for most printers
- ✅ **Multiple Protocols**: Raw TCP, LPD, IPP support

### Use Cases

- **Home Networks**: Share single printer among family members
- **Small Office**: Centralized printing without dedicated server
- **Remote Locations**: Print server in unmanned locations
- **Legacy Printers**: Give old USB printers network capabilities

---

## Print Server Options

OpenWRT offers multiple print server solutions:

### Option 1: p910nd (Recommended for Most Users)

**Characteristics:**
- Lightweight daemon (~20KB)
- Raw TCP port printing (port 9100)
- No print queue management
- No data modification
- Direct pass-through to printer
- Minimal CPU and memory usage

**Best For:**
- Simple network printing needs
- Resource-constrained routers
- Basic laser and inkjet printers
- Direct printing without spooling

**Limitations:**
- No print queue
- No job management
- No printer status feedback
- Limited protocol support

### Option 2: CUPS (Advanced Features)

**Characteristics:**
- Full-featured print system
- IPP (Internet Printing Protocol)
- Print queue management
- Job control (pause, cancel, priority)
- Printer status monitoring
- Driver support for many printers

**Best For:**
- Complex printing requirements
- Multiple printers
- Print job management needed
- Routers with sufficient resources (128MB+ RAM)

**Limitations:**
- Large footprint (2-5MB packages)
- Higher memory usage (10-20MB RAM)
- More complex configuration

### Option 3: Samba Print Server

**Characteristics:**
- Windows-native printing (SMB protocol)
- Integrates with Windows Print Manager
- Works like Windows shared printer

**Best For:**
- Windows-only networks
- Users familiar with Windows printing
- When Samba already installed

**Limitations:**
- Requires Samba (large package)
- Higher resource usage
- Windows-centric

### Comparison Table

| Feature | p910nd | CUPS | Samba |
|---------|--------|------|-------|
| Package Size | 20KB | 2-5MB | 1-3MB |
| RAM Usage | 1-2MB | 10-20MB | 5-15MB |
| Print Queue | No | Yes | Yes |
| Job Control | No | Yes | Limited |
| Protocol | Raw TCP | IPP, LPD | SMB/CIFS |
| Complexity | Low | High | Medium |
| Windows Support | Good | Good | Excellent |
| Linux Support | Good | Excellent | Good |
| macOS Support | Good | Excellent | Good |

---

## Hardware Requirements

### Router Requirements

**Minimum:**
- USB port (USB 2.0 or higher)
- 32MB RAM minimum (64MB+ recommended)
- 4MB Flash minimum (8MB+ recommended)
- OpenWRT 19.07 or newer

**Recommended:**
- 64MB+ RAM for CUPS
- 128MB+ RAM for multiple printers
- USB 2.0 for better performance
- Fast CPU (400MHz+) for PostScript printers

### USB Printer Compatibility

**Well-Supported Printers:**
- Most HP LaserJet models
- Brother laser printers
- Canon PIXMA series
- Epson inkjet models
- Samsung laser printers

**Problematic Printers:**
- GDI printers (Windows-only drivers)
- Some all-in-one devices (scanner may not work)
- Printers requiring proprietary software
- Wireless printers (use WiFi instead)

**Check Compatibility:**
```bash
# After connecting printer, check if detected
lsusb
# Should show printer USB ID

dmesg | grep -i printer
# Should show printer kernel messages
```

---

## Installation

### Step 1: Install USB Support

```bash
# Update package list
opkg update

# Install base USB support
opkg install kmod-usb-core

# Install USB 2.0 support
opkg install kmod-usb2

# For USB 3.0 routers (optional)
opkg install kmod-usb3

# Install USB printer driver
opkg install kmod-usb-printer
```

**For older routers, may also need:**
```bash
# UHCI controller (older Intel chipsets)
opkg install kmod-usb-uhci

# OHCI controller (older non-Intel chipsets)
opkg install kmod-usb-ohci
```

### Step 2: Verify USB Printer Detection

```bash
# Connect printer to USB port

# Check USB devices
lsusb
# Example output:
# Bus 001 Device 002: ID 03f0:4117 Hewlett-Packard LaserJet 1018

# Check kernel messages
dmesg | grep -i usb
dmesg | grep -i printer

# Check for printer device
ls -l /dev/usb/lp*
# Should show: /dev/usb/lp0

# Or on some systems:
ls -l /dev/lp*
# Should show: /dev/lp0
```

### Step 3: Install Print Server Software

**For p910nd (recommended):**
```bash
opkg install p910nd

# Install LuCI web interface (optional)
opkg install luci-app-p910nd
```

**For CUPS:**
```bash
opkg install cups
opkg install cups-client
opkg install cups-filters

# Install LuCI web interface (optional)
opkg install luci-app-cups
```

---

## p910nd Configuration

### Understanding p910nd

p910nd provides **raw TCP printing** on port 9100 (plus offset):
- Port 9100: First printer (p910nd instance 0)
- Port 9101: Second printer (p910nd instance 1)
- Port 9102: Third printer (p910nd instance 2)

### Basic Configuration via UCI

```bash
# Enable p910nd for first printer
uci set p910nd.@p910nd[0].enabled='1'

# Set device path
uci set p910nd.@p910nd[0].device='/dev/usb/lp0'

# Set bidirectional mode (default: 1)
uci set p910nd.@p910nd[0].bidirectional='1'

# Set port (0 = port 9100)
uci set p910nd.@p910nd[0].port='0'

# Commit changes
uci commit p910nd
```

### Configuration File

Edit `/etc/config/p910nd`:

```bash
config p910nd
    option enabled '1'
    option device '/dev/usb/lp0'
    option port '0'
    option bidirectional '1'
    option bind '0.0.0.0'
```

**Options Explained:**

**enabled** (`0` or `1`):
- Enable or disable this printer instance
- Default: `0` (disabled)

**device** (path):
- Printer device path
- Common values: `/dev/usb/lp0`, `/dev/lp0`
- Check with `ls /dev/usb/lp*` or `ls /dev/lp*`

**port** (number):
- Port offset (actual port = 9100 + port number)
- `0` = port 9100
- `1` = port 9101
- Default: `0`

**bidirectional** (`0` or `1`):
- Enable bidirectional communication (status feedback)
- `1` = enabled (printer can send status)
- `0` = disabled (unidirectional, print only)
- Default: `1`
- **Note**: Some printers require `0` (disabled)

**bind** (IP address):
- Interface to bind to
- `0.0.0.0` = all interfaces
- `192.168.1.1` = LAN only
- Default: `0.0.0.0`

### Start p910nd Service

```bash
# Enable service (start on boot)
/etc/init.d/p910nd enable

# Start service now
/etc/init.d/p910nd start

# Check status
/etc/init.d/p910nd status

# Verify service is running
ps | grep p910nd
# Output: 12345 root      1234 S    /usr/sbin/p910nd -b -f /dev/usb/lp0 0

# Check listening port
netstat -antp | grep 9100
# Output: tcp        0      0 0.0.0.0:9100            0.0.0.0:*               LISTEN      12345/p910nd
```

### Multiple Printer Configuration

**For second printer:**

```bash
# Add second printer instance
uci add p910nd p910nd
uci set p910nd.@p910nd[1].enabled='1'
uci set p910nd.@p910nd[1].device='/dev/usb/lp1'
uci set p910nd.@p910nd[1].port='1'  # Port 9101
uci set p910nd.@p910nd[1].bidirectional='1'
uci commit p910nd

/etc/init.d/p910nd restart
```

### Firewall Configuration

```bash
# Allow printing from LAN (usually already allowed)
# Allow printing from WAN (if needed for remote printing)

uci add firewall rule
uci set firewall.@rule[-1].name='Allow-Print-Server'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='9100'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart
```

---

## CUPS Configuration

### Installation

```bash
# Install CUPS and dependencies
opkg install cups
opkg install cups-client
opkg install cups-filters
opkg install cups-ppdc

# Install printer drivers (optional, for specific printers)
opkg install ghostscript

# Install web interface
opkg install luci-app-cups
```

### Basic CUPS Configuration

**Edit `/etc/cups/cupsd.conf`:**

```bash
# Listen on all interfaces
Listen 0.0.0.0:631

# Allow access from LAN
<Location />
  Order allow,deny
  Allow from 192.168.1.0/24
</Location>

<Location /admin>
  Order allow,deny
  Allow from 192.168.1.0/24
</Location>

<Location /admin/conf>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow from 192.168.1.0/24
</Location>

# Enable browsing
Browsing On
BrowseLocalProtocols dnssd

# Share printers
<Policy default>
  <Limit All>
    Order deny,allow
  </Limit>
</Policy>
```

### Start CUPS Service

```bash
# Enable service
/etc/init.d/cupsd enable

# Start service
/etc/init.d/cupsd start

# Check status
/etc/init.d/cupsd status
```

### Add Printer via CUPS Web Interface

1. **Access CUPS web interface:**
   - URL: `http://192.168.1.1:631`
   - Navigate to: Administration → Add Printer

2. **Login:**
   - Username: `root`
   - Password: (your OpenWRT root password)

3. **Select Printer:**
   - Choose USB printer from detected list
   - Click "Continue"

4. **Set Printer Details:**
   - Name: `HP_LaserJet` (no spaces)
   - Description: `HP LaserJet 1020`
   - Location: `Office`
   - Check "Share This Printer"
   - Click "Continue"

5. **Select Driver:**
   - Choose appropriate driver from list
   - Or use "Generic" → "Generic PCL Laser Printer"
   - Click "Add Printer"

6. **Set Default Options:**
   - Paper size: A4 or Letter
   - Print quality
   - Click "Set Default Options"

### Add Printer via Command Line

```bash
# List available USB printers
lpinfo -v
# Output: usb://HP/LaserJet%201020

# List available drivers
lpinfo -m | grep -i hp

# Add printer
lpadmin -p HP_LaserJet \
  -v usb://HP/LaserJet%201020 \
  -E \
  -m drv:///sample.drv/generpcl.ppd \
  -L "Office" \
  -D "HP LaserJet 1020"

# Enable printer
cupsenable HP_LaserJet

# Accept jobs
cupsaccept HP_LaserJet

# Set as default
lpadmin -d HP_LaserJet

# Test print
echo "Test page" | lp
```

---

## Client Configuration

### Windows Client

#### Method 1: Standard TCP/IP Port (p910nd)

1. **Open Devices and Printers:**
   - Control Panel → Devices and Printers
   - Click "Add a printer"

2. **Add Local Printer:**
   - Select "Add a local printer"
   - Click "Next"

3. **Create New Port:**
   - Select "Create a new port"
   - Port type: "Standard TCP/IP Port"
   - Click "Next"

4. **Enter Printer Details:**
   - Hostname or IP: `192.168.1.1`
   - Port name: `192.168.1.1`
   - Uncheck "Query the printer and automatically select the driver"
   - Click "Next"

5. **Port Type:**
   - Device Type: "Custom"
   - Settings:
     - Protocol: "Raw"
     - Port Number: `9100`
   - Click "OK"

6. **Install Driver:**
   - Select printer manufacturer and model
   - Or use "Windows Update" to find driver
   - Or "Have Disk" for downloaded driver

7. **Name and Share:**
   - Printer name: `Network Printer`
   - Share if desired
   - Set as default if desired
   - Print test page

#### Method 2: IPP (CUPS)

1. **Add Network Printer:**
   - Control Panel → Devices and Printers
   - Click "Add a printer"
   - Select "Add a network, wireless or Bluetooth printer"

2. **Select Printer:**
   - Should auto-detect IPP printer
   - Or "The printer that I want isn't listed"

3. **Specify Printer:**
   - Select "Select a shared printer by name"
   - Enter: `http://192.168.1.1:631/printers/HP_LaserJet`
   - Click "Next"

4. **Install Driver:**
   - Select manufacturer and model
   - Complete installation

### Linux Client

#### Method 1: CUPS (p910nd or CUPS)

```bash
# For p910nd (raw TCP)
lpadmin -p Network_Printer \
  -v socket://192.168.1.1:9100 \
  -E \
  -m drv:///sample.drv/generpcl.ppd

# For CUPS (IPP)
lpadmin -p Network_Printer \
  -v ipp://192.168.1.1:631/printers/HP_LaserJet \
  -E

# Set as default
lpadmin -d Network_Printer

# Test print
echo "Test page" | lp
```

#### Method 2: GNOME/KDE GUI

**GNOME (Ubuntu, Fedora):**
1. Settings → Printers
2. Click "Add"
3. Select "Network Printer"
4. Enter: `socket://192.168.1.1:9100` (for p910nd)
   Or: `ipp://192.168.1.1:631/printers/HP_LaserJet` (for CUPS)
5. Select driver
6. Click "Add"

**KDE (Kubuntu, openSUSE):**
1. System Settings → Printers
2. Click "Add Printer"
3. Select "Manual URI"
4. Enter: `socket://192.168.1.1:9100`
5. Select driver
6. Click "OK"

### macOS Client

#### Method 1: System Preferences (p910nd)

1. **Open Printers & Scanners:**
   - System Preferences → Printers & Scanners
   - Click "+" to add printer

2. **Select IP Printer:**
   - Click "IP" tab
   - Address: `192.168.1.1`
   - Protocol: "HP Jetdirect - Socket"
   - Port: `9100`
   - Name: `Network Printer`

3. **Select Driver:**
   - Use: "Select Software"
   - Choose printer driver from list
   - Or "Generic PostScript Printer"

4. **Add Printer:**
   - Click "Add"

#### Method 2: IPP (CUPS)

1. **Open Printers & Scanners:**
   - System Preferences → Printers & Scanners
   - Click "+"

2. **Select IP Printer:**
   - Click "IP" tab
   - Address: `192.168.1.1`
   - Protocol: "Internet Printing Protocol - IPP"
   - Queue: `/printers/HP_LaserJet`

3. **Select Driver and Add**

### Android Client

**Install Print Service App:**
- "Let's Print" (for p910nd)
- "Mopria Print Service" (for IPP/CUPS)

**Configure:**
1. Settings → Connected devices → Connection preferences → Printing
2. Enable print service
3. Add printer with IP address and port

### iOS Client

**For CUPS (AirPrint compatible):**
- Printers should auto-discover
- Print from any app with share menu

**For p910nd:**
- Install "Printer Pro" app
- Configure manual printer with IP and port

---

## Printer-Specific Setup

### HP LaserJet 1020 (Requires Firmware Upload)

**Problem:** HP LaserJet 1020 needs firmware uploaded each time it's powered on.

**Solution:**

```bash
# Install firmware upload utility
opkg install hp-firmware

# Download firmware (from Windows driver or HP website)
# File needed: sihp1020.dl

# Create hotplug script
cat > /etc/hotplug.d/usb/20-hp1020 << 'EOF'
#!/bin/sh

# HP LaserJet 1020 firmware loader
if [ "$PRODUCT" = "3f0/4117/100" ]; then
    # Wait for device to settle
    sleep 2

    # Upload firmware
    cat /lib/firmware/sihp1020.dl > /dev/usb/lp0

    # Wait for firmware to load
    sleep 5
fi
EOF

chmod +x /etc/hotplug.d/usb/20-hp1020

# Place firmware file
mkdir -p /lib/firmware
# Copy sihp1020.dl to /lib/firmware/

# Test: Unplug and replug printer
```

### Brother Laser Printers

**Most Brother printers work out-of-box with p910nd.**

```bash
# Standard configuration
uci set p910nd.@p910nd[0].enabled='1'
uci set p910nd.@p910nd[0].device='/dev/usb/lp0'
uci set p910nd.@p910nd[0].bidirectional='0'  # Disable for Brother
uci commit p910nd
/etc/init.d/p910nd restart
```

### Canon PIXMA Printers

**PIXMA printers often work with CUPS and generic drivers.**

```bash
# Use CUPS with generic driver
lpadmin -p Canon_Printer \
  -v usb://Canon/PIXMA%20MG3600 \
  -E \
  -m everywhere

# Or use specific PPD if available
```

### Epson Inkjet Printers

**Epson printers usually require CUPS and specific drivers.**

```bash
# Install Epson driver package (if available)
opkg install cups-filters

# Use ESC/P-R generic driver
lpadmin -p Epson_Printer \
  -v usb://Epson/Stylus \
  -E \
  -m drv:///sample.drv/stcolor.ppd
```

### Samsung Laser Printers

**Samsung printers typically work with p910nd and SPL driver.**

**For CUPS:**
```bash
# Use Samsung SPL driver
lpadmin -p Samsung_Printer \
  -v usb://Samsung/ML-2010 \
  -E \
  -m drv:///sample.drv/generpcl.ppd
```

---

## Troubleshooting

### Printer Not Detected

**Check USB connection:**
```bash
# List USB devices
lsusb
# Should show printer

# If not shown, check USB modules
lsmod | grep usb

# Load modules manually
insmod usbcore
insmod ehci-hcd
insmod usb-printer
```

**Check device node:**
```bash
# Look for printer device
ls -l /dev/usb/lp*
ls -l /dev/lp*

# If missing, create manually
mknod /dev/usb/lp0 c 180 0
```

### p910nd Not Starting

**Check configuration:**
```bash
# Verify config
uci show p910nd

# Check device path exists
ls -l /dev/usb/lp0

# Check logs
logread | grep p910nd

# Try manual start
p910nd -b -f /dev/usb/lp0 0
```

### Print Job Hangs

**Issue:** Job sent but nothing prints, or prints partially.

**Solutions:**

1. **Disable bidirectional mode:**
```bash
uci set p910nd.@p910nd[0].bidirectional='0'
uci commit p910nd
/etc/init.d/p910nd restart
```

2. **Check printer status:**
```bash
# Send status query
echo -e "\033%-12345X@PJL INFO STATUS\r\n\033%-12345X" > /dev/usb/lp0
cat /dev/usb/lp0
```

3. **Reset printer:**
```bash
# Power cycle printer
# Or send reset command
echo -e "\033E" > /dev/usb/lp0
```

### Cannot Connect from Client

**Check firewall:**
```bash
# Verify port 9100 is open
netstat -antp | grep 9100

# Test from client
telnet 192.168.1.1 9100
# Should connect

# If connection refused, check firewall
uci show firewall | grep 9100
```

**Check binding:**
```bash
# Ensure p910nd listens on correct interface
uci set p910nd.@p910nd[0].bind='0.0.0.0'
uci commit p910nd
/etc/init.d/p910nd restart
```

### Garbled Output

**Issue:** Printer prints garbage characters or mixed text/binary.

**Causes and Solutions:**

1. **Wrong driver on client:**
   - Use correct printer driver
   - Or use generic PCL/PostScript driver

2. **Printer in wrong mode:**
```bash
# Send PCL reset
echo -e "\033E" > /dev/usb/lp0

# Send PostScript reset
echo -e "\004" > /dev/usb/lp0
```

3. **Character encoding issue:**
   - Ensure client sends raw data (no text conversion)
   - Use "print directly" option

### Slow Printing

**Check CPU usage:**
```bash
top
# If high CPU usage, router may be underpowered for CUPS
```

**Optimize:**
- Use p910nd instead of CUPS (lighter)
- Reduce print quality/resolution
- Use faster router hardware

### CUPS Web Interface Inaccessible

**Check CUPS is running:**
```bash
/etc/init.d/cupsd status

# Check listening port
netstat -antp | grep 631
```

**Fix configuration:**
```bash
# Edit /etc/cups/cupsd.conf
# Change:
Listen localhost:631
# To:
Listen 0.0.0.0:631

# Allow LAN access
<Location />
  Order allow,deny
  Allow from 192.168.1.0/24
</Location>

# Restart CUPS
/etc/init.d/cupsd restart
```

---

## Advanced Features

### Print Server with Authentication

**Using CUPS with authentication:**

```bash
# Create CUPS admin user
# Edit /etc/cups/cupsd.conf

<Location /admin>
  AuthType Basic
  Require user @SYSTEM
  Order allow,deny
  Allow from 192.168.1.0/24
</Location>

# Set password
passwd root
```

### Print Accounting and Logging

**Enable CUPS logging:**
```bash
# Edit /etc/cups/cupsd.conf
LogLevel info
AccessLogLevel all
PageLogFormat %p %j %u %T %P %C %{job-billing} %{job-originating-host-name} %{job-name} %{media} %{sides}

# View logs
tail -f /var/log/cups/access_log
tail -f /var/log/cups/page_log
```

### Multiple Print Servers

```bash
# First printer on port 9100
uci set p910nd.@p910nd[0].enabled='1'
uci set p910nd.@p910nd[0].device='/dev/usb/lp0'
uci set p910nd.@p910nd[0].port='0'

# Second printer on port 9101
uci add p910nd p910nd
uci set p910nd.@p910nd[1].enabled='1'
uci set p910nd.@p910nd[1].device='/dev/usb/lp1'
uci set p910nd.@p910nd[1].port='1'

uci commit p910nd
/etc/init.d/p910nd restart
```

### Automatic Printer Power Management

```bash
# USB power management (if supported)
cat > /etc/hotplug.d/usb/30-printer-power << 'EOF'
#!/bin/sh

if [ "$ACTION" = "add" ] && [ "$DEVICENAME" = "lp0" ]; then
    # Printer connected, ensure power
    echo on > /sys/bus/usb/devices/1-1/power/level
fi

if [ "$ACTION" = "remove" ]; then
    # Printer removed, save power
    echo auto > /sys/bus/usb/devices/1-1/power/level
fi
EOF

chmod +x /etc/hotplug.d/usb/30-printer-power
```

### Print Queue Monitoring Script

```bash
cat > /root/print-monitor.sh << 'EOF'
#!/bin/bash

LOG="/var/log/print-jobs.log"

while true; do
    # Check for CUPS jobs
    if command -v lpq >/dev/null 2>&1; then
        QUEUE=$(lpq)
        if echo "$QUEUE" | grep -q "no entries"; then
            echo "[$(date)] Queue empty" >> "$LOG"
        else
            echo "[$(date)] Jobs in queue: $QUEUE" >> "$LOG"
        fi
    fi

    # Check p910nd connections
    CONNS=$(netstat -an | grep :9100 | grep ESTABLISHED | wc -l)
    if [ $CONNS -gt 0 ]; then
        echo "[$(date)] Active print connections: $CONNS" >> "$LOG"
    fi

    sleep 60
done
EOF

chmod +x /root/print-monitor.sh

# Run in background
/root/print-monitor.sh &
```

---

## Performance Considerations

### Hardware Requirements by Printer Type

**Laser Printers:**
- Minimum: 32MB RAM, 400MHz CPU
- Recommended: 64MB RAM, 600MHz CPU
- Work well with p910nd

**Inkjet Printers:**
- Minimum: 64MB RAM, 400MHz CPU
- Recommended: 128MB RAM, 600MHz CPU
- May need CUPS for color management

**PostScript Printers:**
- Minimum: 128MB RAM, 600MHz CPU
- Recommended: 256MB RAM, 800MHz+ CPU
- Best with CUPS and ghostscript

### Optimization Tips

1. **Use p910nd for simple needs:**
   - Much lighter than CUPS
   - Direct pass-through (no processing)

2. **Limit print resolution:**
   - Lower DPI = faster processing
   - 300 DPI sufficient for text

3. **Use printer's internal RAM:**
   - Send small chunks
   - Let printer buffer

4. **Disable bidirectional if not needed:**
   - Reduces communication overhead

5. **Use wired network connection:**
   - More reliable than WiFi for large jobs

---

## Conclusion

OpenWRT provides flexible print server options suitable for various scenarios:

### Best Practices Summary

✅ **Installation:**
- Install necessary USB modules
- Choose appropriate print server (p910nd vs CUPS)
- Verify printer detection before configuration

✅ **Configuration:**
- Use p910nd for simple, lightweight printing
- Use CUPS for advanced features and complex needs
- Configure firewall for remote access if needed
- Test with sample print job

✅ **Client Setup:**
- Use raw TCP (port 9100) for p910nd
- Use IPP for CUPS
- Install correct printer drivers on clients
- Configure default printer settings

✅ **Troubleshooting:**
- Check USB detection first
- Verify device path (/dev/usb/lp0)
- Try disabling bidirectional mode
- Test with simple text file
- Check logs for errors

✅ **Optimization:**
- Match solution to hardware capabilities
- Use appropriate print resolution
- Consider printer-specific requirements
- Monitor resource usage

### Decision Guide

**Use p910nd if:**
- Simple printing needs
- Limited router resources (< 64MB RAM)
- Basic laser/inkjet printer
- No job management required

**Use CUPS if:**
- Advanced features needed
- Multiple printer support
- Job management required
- Sufficient router resources (128MB+ RAM)
- Complex printer drivers needed

**Use Samba if:**
- Windows-only network
- Samba already installed
- Familiar with Windows printing

### Printer Compatibility

**Generally Compatible:**
- HP LaserJet series (may need firmware)
- Brother laser printers
- Canon PIXMA series (with CUPS)
- Epson inkjet (with CUPS)
- Samsung laser printers

**May Require Special Setup:**
- All-in-one devices (scanner often unsupported)
- Printers requiring firmware upload
- GDI printers (limited support)
- Printers with proprietary protocols

### Resources

- OpenWRT Wiki: https://openwrt.org/docs/guide-user/services/print_server
- CUPS Documentation: https://www.cups.org/documentation.html
- p910nd Documentation: http://p910nd.sourceforge.net/

---

*Document Version: 1.0*
*Last Updated: 2025*
*Based on: https://eko.one.pl/?p=openwrt-printserwer*
*Compatible with: OpenWRT 19.07+*
