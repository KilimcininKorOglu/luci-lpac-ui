# OpenWRT GSM/CDMA Modem Compatibility and Configuration Guide

## Table of Contents
1. [Overview](#overview)
2. [General Installation](#general-installation)
3. [Modem Operation Modes](#modem-operation-modes)
4. [Huawei Modems](#huawei-modems)
5. [ZTE Modems](#zte-modems)
6. [CDMA Modems](#cdma-modems)
7. [Other Manufacturers](#other-manufacturers)
8. [Mode Switching](#mode-switching)
9. [NDIS Mode Configuration](#ndis-mode-configuration)
10. [Troubleshooting](#troubleshooting)
11. [AT Commands Reference](#at-commands-reference)

---

## Overview

This guide provides detailed compatibility information and configuration instructions for various USB GSM/CDMA modems on OpenWRT. Unlike the general 3G/4G guide, this document focuses on specific modem models, their quirks, and model-specific configuration requirements.

### Why This Guide?

Not all USB modems work the same way with OpenWRT. Different models require:
- **Different drivers** (serial, CDC-ACM, CDC-NCM, QMI, MBIM)
- **Mode switching** (from CD-ROM to modem mode)
- **Specific AT commands** for initialization
- **Special baud rates** or device paths
- **Firmware-specific workarounds**

This guide documents real-world solutions for specific modem models.

---

## General Installation

### Basic Requirements

All GSM modems require baseline USB support:

```bash
# Update package lists
opkg update

# Install basic USB support
opkg install kmod-usb-core
opkg install kmod-usb2 kmod-usb3
opkg install usbutils

# Install serial drivers (needed for most modems)
opkg install kmod-usb-serial
opkg install kmod-usb-serial-option
opkg install kmod-usb-serial-wwan

# Install mode switching
opkg install usb-modeswitch

# Install PPP support
opkg install ppp ppp-mod-pppoe
opkg install chat comgt

# Reboot
reboot
```

### Verification Steps

After installation:

```bash
# Check USB device is detected
lsusb

# Check for TTY devices
ls -l /dev/ttyUSB*

# Check kernel messages
dmesg | grep -i "usb\|tty\|modem"

# Test modem communication
echo "AT" > /dev/ttyUSB0
cat /dev/ttyUSB0
# Should respond: OK
```

---

## Modem Operation Modes

Modern USB modems can operate in several modes:

### 1. Serial/PPP Mode (Traditional)
- **Interface**: `/dev/ttyUSB*`
- **Protocol**: PPP over serial
- **Speed**: Limited to 20-30 Mbps
- **Compatibility**: Universal
- **OpenWRT Proto**: `3g`

### 2. NDIS Mode (Network Device)
- **Interface**: Network card (eth*, usb*)
- **Protocol**: RNDIS/CDC-NCM
- **Speed**: Full modem speed (no PPP overhead)
- **Compatibility**: Many Huawei and ZTE LTE modems
- **OpenWRT Proto**: `ncm`, `dhcp`

### 3. HiLink Mode (Huawei)
- **Interface**: Network card with built-in router
- **Protocol**: DHCP
- **Speed**: Full speed
- **Compatibility**: Huawei E3xxx series
- **OpenWRT Proto**: `dhcp`
- **Special**: Modem has its own IP (usually 192.168.8.1)

### 4. QMI/MBIM Mode
- **Interface**: `/dev/cdc-wdm*`
- **Protocol**: Modern control protocol
- **Speed**: Full speed
- **Compatibility**: Newer modems
- **OpenWRT Proto**: `qmi`, `mbim`

---

## Huawei Modems

### E3372 Series

**Two variants exist**: HiLink and Stick mode

#### E3372 HiLink Mode (Standard)

**Identification:**
```bash
lsusb
# Shows: ID 12d1:14db Huawei Technologies Co., Ltd.
```

**Installation:**
```bash
opkg install kmod-usb-net-cdc-ether
opkg install kmod-usb-net-rndis
```

**Configuration:**
```bash
# The modem appears as network card
uci set network.wwan=interface
uci set network.wwan.proto='dhcp'
uci set network.wwan.ifname='eth1'  # or usb0
uci commit network

# Add to WAN zone
uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

**Access modem web interface:**
- URL: `http://192.168.8.1`
- Default: admin/admin
- Configure APN, PIN in modem interface

#### E3372 Stick Mode (Non-HiLink)

**Identification:**
```bash
lsusb
# Shows: ID 12d1:1506 Huawei Technologies Co., Ltd.
```

**Special requirement**: Need to enable network interface via AT command

**Installation:**
```bash
opkg install kmod-usb-serial-option
opkg install kmod-usb-net-cdc-ncm
```

**Enable network interface:**
```bash
# Send AT command to enable NCM mode
echo -e "AT^NDISDUP=1,1,\"internet\"\r" > /dev/ttyUSB0

# Or permanently enable
echo -e "AT^SETPORT=\"FF;10,12,16\"\r" > /dev/ttyUSB0
```

**Configuration (NCM mode):**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='ncm'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pdptype='IP'
uci commit network
```

**Configuration (QMI mode alternative):**
```bash
# Some E3372 support QMI
opkg install kmod-usb-net-qmi-wwan uqmi

uci set network.wwan=interface
uci set network.wwan.proto='qmi'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci commit network
```

### E3131s-2

**HiLink model** - operates as network card

**Installation:**
```bash
opkg install kmod-usb-net-cdc-ether
```

**IP Conflict Resolution:**

The modem uses 192.168.8.1 by default. If your router also uses 192.168.x.x:

**Option 1: Change router IP**
```bash
uci set network.lan.ipaddr='192.168.1.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network
/etc/init.d/network restart
```

**Option 2: Change modem IP**
- Access modem at http://192.168.8.1
- Settings → LAN → Change to 192.168.9.1
- Save and reboot modem

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='dhcp'
uci set network.wwan.ifname='eth1'
uci commit network
```

### E3273

**Similar to E3131s-2** - HiLink mode

**Installation:**
```bash
opkg install kmod-usb-net-cdc-ether
opkg install kmod-usb-net-huawei-cdc-ncm
```

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='dhcp'
uci set network.wwan.ifname='eth1'
uci commit network
```

### E353

**HiLink mode** with similar configuration to E3131

**Installation:**
```bash
opkg install kmod-usb-net-cdc-ether
```

**Configuration:**
Same as E3131s-2 above.

### E173

**Classic 3G modem** - Serial/PPP mode

**Installation:**
```bash
opkg install kmod-usb-serial-option
opkg install comgt
```

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB0'
uci set network.wwan.service='umts'
uci set network.wwan.apn='internet'
uci set network.wwan.pincode='1234'
uci commit network
```

### E398

**LTE modem with QMI support**

**Installation:**
```bash
opkg install kmod-usb-net-qmi-wwan
opkg install uqmi
```

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='qmi'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pdptype='ipv4v6'
uci commit network
```

### General Huawei Notes

**Most Huawei modems work immediately after:**
```bash
opkg install kmod-usb-serial-option
```

**Common Huawei AT commands:**
```bash
# Get device info
echo "ATI" > /dev/ttyUSB0

# Get IMEI
echo "AT+GSN" > /dev/ttyUSB0

# Get signal strength
echo "AT+CSQ" > /dev/ttyUSB0

# Unlock SIM
echo "AT+CPIN=1234" > /dev/ttyUSB0

# Set network mode to LTE only
echo "AT^SYSCFGEX=\"03\",3FFFFFFF,1,2,7FFFFFFFFFFFFFFF,," > /dev/ttyUSB0
```

---

## ZTE Modems

### MF823

**Modern LTE modem** - QMI mode

**Installation:**
```bash
opkg install kmod-usb-net-qmi-wwan
opkg install uqmi
```

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='qmi'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci commit network
```

### MF831

**LTE modem** - Similar to MF823

**Installation:**
```bash
opkg install kmod-usb-net-qmi-wwan
opkg install uqmi
```

**Configuration:**
Same as MF823.

### MF195

**3G modem with USB mode switching**

**Installation:**
```bash
opkg install kmod-usb-serial-option
opkg install kmod-usb-acm
opkg install usb-modeswitch
```

**Mode Switch:**
```bash
# Check initial mode
lsusb
# ID 19d2:2000 ZTE WCDMA Technologies MSM (storage mode)

# Switch to modem mode
usb_modeswitch -v 19d2 -p 2000 -M '5553424312345678000000000000061b000000020000000000000000000000'

# After switch, should show:
# ID 19d2:0117 ZTE WCDMA Technologies MSM
```

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB2'
uci set network.wwan.service='umts'
uci set network.wwan.apn='internet'
uci commit network
```

### MF190

**Basic 3G modem**

**Installation:**
```bash
opkg install kmod-usb-serial-option
opkg install comgt
```

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB0'
uci set network.wwan.service='umts'
uci set network.wwan.apn='internet'
uci commit network
```

---

## CDMA Modems

### AnyDATA ADU635WA

**Dual-mode modem**: HSDPA and CDMA2000

**Mode Switching Required**: Device initialization string changes mode

**Installation:**
```bash
opkg install kmod-usb-serial-option
opkg install comgt
```

**For HSDPA Mode:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB0'
uci set network.wwan.service='umts'
uci set network.wwan.apn='internet'
uci set network.wwan.dialnumber='*99#'
uci set network.wwan.initstring='AT+CST=3'
uci commit network
```

**For CDMA Mode:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB0'
uci set network.wwan.service='cdma'
uci set network.wwan.dialnumber='#777'
uci set network.wwan.initstring='AT+CST=28'
uci set network.wwan.username='your_cdma_user'
uci set network.wwan.password='your_cdma_pass'
uci commit network
```

**Key AT Commands:**
- `AT+CST=3` - Switch to HSDPA mode
- `AT+CST=28` - Switch to CDMA mode
- `AT+CST?` - Query current mode

### AnyDATA ADU890-W

**Modern HSPA+/CDMA modem**

**Note**: PIN support is limited/non-functional on CDMA networks

**Installation:**
```bash
opkg install kmod-usb-serial-option
```

**HSPA+ Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB0'
uci set network.wwan.service='umts'
uci set network.wwan.apn='internet'
uci commit network
```

**CDMA Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB0'
uci set network.wwan.service='cdma'
uci set network.wwan.dialnumber='#777'
uci set network.wwan.username='cdma_username'
uci set network.wwan.password='cdma_password'
uci commit network
```

### DGT CT-680

**Designed for iPlus CDMA service** (Polish operator)

**Installation:**
```bash
opkg install kmod-usb-serial-option
```

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB0'
uci set network.wwan.service='cdma'
uci set network.wwan.dialnumber='#777'
uci set network.wwan.username='iplus'
uci set network.wwan.password='iplus'
uci commit network
```

---

## Other Manufacturers

### iPlus Commander 2

**Special requirement**: Non-standard baud rate

**Installation:**
```bash
opkg install kmod-usb-serial-option
```

**Configuration with custom baud rate:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB0'
uci set network.wwan.service='cdma'
uci set network.wwan.dialnumber='#777'
uci set network.wwan.username='iplus'
uci set network.wwan.password='iplus'
uci commit network
```

**Set baud rate manually:**
```bash
# Edit /etc/chatscripts/3g.chat
# Change baud rate line to:
stty 460800

# Or set via stty before connection
stty -F /dev/ttyUSB0 460800
```

### Nokia 21M-02

**Requires CDC-ACM driver**, not standard option driver

**Installation:**
```bash
opkg install kmod-usb-acm
# Do NOT install kmod-usb-serial-option (conflicts)
```

**Remove PPP option if present:**
```bash
opkg remove ppp-mod-pppoe  # If causing conflicts
```

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyACM0'  # Note: ACM not USB
uci set network.wwan.service='umts'
uci set network.wwan.apn='internet'
uci commit network
```

### Novatel Ovation MC990D

**Special requirement**: Virtual CD-ROM must be ejected

**Installation:**
```bash
opkg install kmod-usb-serial-option
opkg install sdparm  # For CD-ROM eject
```

**Eject virtual CD-ROM:**
```bash
# Find the sr device
ls -l /dev/sr*

# Eject it
sdparm --command=eject /dev/sr0

# Modem should now appear as /dev/ttyUSB*
```

**Or use usb-modeswitch:**
```bash
usb_modeswitch -v 1410 -p 5031 -u 2
```

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB0'
uci set network.wwan.service='cdma'
uci set network.wwan.dialnumber='#777'
uci commit network
```

### Sierra Wireless Modems

**General installation:**
```bash
opkg install kmod-usb-serial-option
opkg install kmod-usb-serial-sierrawireless
```

**Many Sierra modems support QMI:**
```bash
opkg install kmod-usb-net-qmi-wwan
opkg install uqmi

uci set network.wwan=interface
uci set network.wwan.proto='qmi'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci commit network
```

### Quectel Modems

**EC25, EC20, EP06** - All support QMI

**Installation:**
```bash
opkg install kmod-usb-net-qmi-wwan
opkg install kmod-usb-serial-option
opkg install uqmi
```

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='qmi'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pdptype='ipv4v6'
uci commit network
```

**GPS Support (if available):**
```bash
opkg install gpsd kmod-usb-serial

# GPS usually on /dev/ttyUSB1
gpsd /dev/ttyUSB1
```

---

## Mode Switching

Many USB modems initially appear as CD-ROM drives containing Windows drivers. They must be "switched" to modem mode.

### Using usb-modeswitch

**Installation:**
```bash
opkg install usb-modeswitch
```

**Find device ID:**
```bash
lsusb
# Example output:
# Bus 001 Device 005: ID 12d1:1f01 Huawei Technologies Co., Ltd.
```

**Manual mode switch:**
```bash
# Generic switch command
usb_modeswitch -v VENDOR_ID -p PRODUCT_ID -M 'MESSAGE_CONTENT'

# Example for Huawei
usb_modeswitch -v 12d1 -p 1f01 -M '55534243123456780000000000000611062000000000000000000000000000'
```

### Common Mode Switch Strings

**Huawei:**
```bash
usb_modeswitch -v 12d1 -p 1f01 -M '55534243123456780000000000000611062000000000000000000000000000'
```

**ZTE:**
```bash
usb_modeswitch -v 19d2 -p 2000 -M '5553424312345678000000000000061b000000020000000000000000000000'
```

**Sierra Wireless:**
```bash
usb_modeswitch -v 1199 -p 0fff -M '555342431234567800000000000006bd000000020000000000000000000000'
```

### Automatic Mode Switching

Create udev rule for automatic switching:

```bash
# Create file: /etc/hotplug.d/usb/20-usb_modeswitch
cat > /etc/hotplug.d/usb/20-usb_modeswitch << 'EOF'
#!/bin/sh

case "$PRODUCT" in
    "12d1/1f01/0")
        # Huawei modem in CD-ROM mode
        usb_modeswitch -v 12d1 -p 1f01 -M '55534243123456780000000000000611062000000000000000000000000000'
        ;;
    "19d2/2000/0")
        # ZTE modem in CD-ROM mode
        usb_modeswitch -v 19d2 -p 2000 -M '5553424312345678000000000000061b000000020000000000000000000000'
        ;;
esac
EOF

chmod +x /etc/hotplug.d/usb/20-usb_modeswitch
```

### Persistent Mode Configuration

Edit `/etc/usb-mode.json` for automatic switching:

```json
{
  "12d1:1f01": {
    "*": {
      "msg": [
        "55534243123456780000000000000611062000000000000000000000000000"
      ],
      "mode": "StandardEject"
    }
  }
}
```

---

## NDIS Mode Configuration

NDIS mode provides higher speeds than PPP (no 20-30 Mbps limitation).

### Huawei NDIS Support

**Installation:**
```bash
opkg install kmod-usb-net-huawei-cdc-ncm
opkg install kmod-usb-net-cdc-ncm
```

**Supported models:**
- E3131
- E3251
- E3272
- E3531
- E3372
- E392
- And many others

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='ncm'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci commit network
```

### ZTE NDIS Support

**Installation:**
```bash
opkg install kmod-usb-net-cdc-ncm
```

**Supported models:**
- MF823
- MF831
- MF910
- And others

**Configuration:**
Same as Huawei NCM above.

### Checking NDIS Capability

**Check if modem supports NDIS:**
```bash
# After plugging in modem
dmesg | grep -i "cdc\|ncm\|rndis"

# Should see messages like:
# cdc_ncm 1-1:1.1: CDC NCM: Device detected

# Check for network interface
ifconfig -a | grep -E "usb|eth"
```

---

## Troubleshooting

### Device Not Detected

**Check USB connection:**
```bash
lsusb
dmesg | tail -30
```

**If not showing:**
- Try different USB port
- Check USB hub power
- Verify USB drivers installed

### No /dev/ttyUSB* Devices

**Check serial drivers:**
```bash
lsmod | grep usb_serial
lsmod | grep option

# If not loaded
insmod kmod-usb-serial
insmod kmod-usb-serial-option
```

**Force driver binding:**
```bash
# Find vendor:product ID
lsusb
# Example: ID 12d1:1506

# Add to option driver
echo "12d1 1506" > /sys/bus/usb-serial/drivers/option1/new_id
```

### Wrong TTY Device

Different USB modems expose multiple serial ports for different functions:

```bash
ls -l /dev/ttyUSB*
# Output:
# /dev/ttyUSB0  # Usually AT command port
# /dev/ttyUSB1  # Usually NMEA/GPS port
# /dev/ttyUSB2  # Usually data port (PPP)
# /dev/ttyUSB3  # Usually debug/diagnostic port
```

**Test each port:**
```bash
# Test AT commands on each
for port in /dev/ttyUSB*; do
    echo "Testing $port"
    echo "ATI" > $port
    timeout 2 cat $port
done
```

**Update configuration with correct port:**
```bash
uci set network.wwan.device='/dev/ttyUSB2'  # Use data port
uci commit network
```

### Modem Responds but Won't Connect

**Check SIM and signal:**
```bash
# Test with comgt
gcom -d /dev/ttyUSB0 sig

# Or manually
echo "AT+CSQ" > /dev/ttyUSB0; cat /dev/ttyUSB0
# Response: +CSQ: 15,99
# First number is signal (0-31, higher is better)
```

**Check SIM PIN:**
```bash
echo "AT+CPIN?" > /dev/ttyUSB0; cat /dev/ttyUSB0
# Response: +CPIN: READY  (good)
# Response: +CPIN: SIM PIN  (needs PIN)
```

**Unlock SIM:**
```bash
echo "AT+CPIN=1234" > /dev/ttyUSB0
```

### PPP Connection Fails

**Enable debugging:**
```bash
uci set network.wwan.debug='1'
uci commit network
ifup wwan

# Watch logs
logread -f | grep ppp
```

**Common PPP errors:**

```
LCP: timeout sending Config-Requests
→ Wrong device or no response from modem

PAP authentication failed
→ Wrong username/password

No carrier
→ No signal or SIM issue
```

### HiLink Mode IP Conflict

**Symptom**: Cannot access modem or internet

**Solution 1**: Change router LAN IP
```bash
uci set network.lan.ipaddr='192.168.1.1'
uci commit network
/etc/init.d/network restart
```

**Solution 2**: Change modem IP
- Access modem web interface (usually 192.168.8.1)
- Change modem LAN IP to different subnet
- Restart modem

### AT Commands Not Working

**Check device is in AT mode:**
```bash
# Simple test
echo "AT" > /dev/ttyUSB0
timeout 1 cat /dev/ttyUSB0
# Should respond: OK
```

**If no response:**
- Wrong port (try other ttyUSB*)
- Modem in data mode (disconnect PPP first)
- Need proper line endings

**Proper AT command format:**
```bash
# Use echo -e with \r (carriage return)
echo -e "AT\r" > /dev/ttyUSB0

# Or use printf
printf "AT\r" > /dev/ttyUSB0
```

### Slow Speeds Despite LTE Connection

**Check if using PPP mode:**
```bash
uci show network.wwan.proto
```

If proto is `3g`, you're limited to ~30 Mbps.

**Solution**: Switch to QMI/MBIM/NCM mode if supported:
```bash
# Check if modem supports QMI
ls -l /dev/cdc-wdm*

# If available, use QMI
opkg install kmod-usb-net-qmi-wwan uqmi

uci set network.wwan.proto='qmi'
uci set network.wwan.device='/dev/cdc-wdm0'
uci commit network
ifup wwan
```

---

## AT Commands Reference

### Basic AT Commands

```bash
# Test modem response
AT
# Response: OK

# Get modem information
ATI
# Response: Manufacturer, model, firmware

# Get IMEI
AT+GSN
# Response: 15-digit IMEI number

# Get SIM card ID (ICCID)
AT+CCID
# Response: 19-20 digit SIM ID
```

### SIM Management

```bash
# Check PIN status
AT+CPIN?
# +CPIN: READY  (no PIN required or already unlocked)
# +CPIN: SIM PIN  (PIN required)

# Unlock SIM with PIN
AT+CPIN=1234

# Disable PIN requirement
AT+CLCK="SC",0,"1234"

# Enable PIN requirement
AT+CLCK="SC",1,"1234"

# Change PIN
AT+CPWD="SC","1234","5678"
```

### Network Information

```bash
# Get signal strength
AT+CSQ
# +CSQ: 18,99  (0-31, 99=unknown)

# Get network registration status
AT+CREG?
# +CREG: 0,1  (registered on home network)
# +CREG: 0,5  (registered roaming)

# Get operator name
AT+COPS?
# +COPS: 0,0,"T-Mobile",7

# Get network mode
AT^SYSINFO
# Returns: service, domain, roaming, mode, SIM state
```

### Mode Selection

**Huawei modems:**
```bash
# Auto mode
AT^SYSCFGEX="00",3FFFFFFF,1,2,7FFFFFFFFFFFFFFF,,

# LTE only
AT^SYSCFGEX="03",3FFFFFFF,1,2,7FFFFFFFFFFFFFFF,,

# 3G only
AT^SYSCFGEX="02",3FFFFFFF,1,2,7FFFFFFFFFFFFFFF,,

# 2G only
AT^SYSCFGEX="01",3FFFFFFF,1,2,7FFFFFFFFFFFFFFF,,
```

**ZTE modems:**
```bash
# Auto mode
AT+ZSNT=0,0,0

# LTE only
AT+ZSNT=1,0,0

# 3G only
AT+ZSNT=2,0,0
```

**Quectel modems:**
```bash
# Auto mode
AT+QCFG="nwscanmode",0

# LTE only
AT+QCFG="nwscanmode",3

# 3G only
AT+QCFG="nwscanmode",2
```

### Band Selection

**Huawei - Lock to LTE Band 3 (1800 MHz):**
```bash
AT^SYSCFGEX="03",800,1,2,800,,
```

**Quectel - Lock to LTE Band 7:**
```bash
AT+QCFG="band",0,40,1
```

### Connection Management

```bash
# Check connection status
AT+CGATT?
# +CGATT: 1  (attached to network)

# Set APN
AT+CGDCONT=1,"IP","internet"

# Activate PDP context
AT+CGACT=1,1

# Check IP address
AT+CGPADDR=1
# +CGPADDR: 1,"10.123.45.67"
```

### Diagnostic Commands

```bash
# Check antenna/RF status
AT^RFSWITCH?

# Get detailed signal info (Huawei)
AT^HCSQ?

# Get cell info
AT+COPS=?
# Lists all available networks (slow command)

# Get modem temperature
AT+CMTE?
```

---

## Configuration Templates

### Template 1: PPP/Serial Modem (Universal)

```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB0'
uci set network.wwan.service='umts'  # or 'cdma', 'evdo'
uci set network.wwan.apn='internet'
uci set network.wwan.pincode='1234'
uci set network.wwan.username=''
uci set network.wwan.password=''
uci set network.wwan.defaultroute='1'
uci set network.wwan.peerdns='1'
uci commit network

uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

### Template 2: QMI Modem (Huawei, ZTE, Quectel)

```bash
uci set network.wwan=interface
uci set network.wwan.proto='qmi'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pincode='1234'
uci set network.wwan.auth='none'
uci set network.wwan.pdptype='ipv4v6'
uci set network.wwan.autoconnect='1'
uci commit network

uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

### Template 3: NCM Modem (Modern Huawei/ZTE)

```bash
uci set network.wwan=interface
uci set network.wwan.proto='ncm'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pincode='1234'
uci set network.wwan.pdptype='IP'
uci set network.wwan.delay='15'
uci commit network

uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

### Template 4: HiLink Modem (Huawei E3xxx)

```bash
uci set network.wwan=interface
uci set network.wwan.proto='dhcp'
uci set network.wwan.ifname='eth1'  # or usb0
uci commit network

uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

### Template 5: CDMA Modem

```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB0'
uci set network.wwan.service='cdma'
uci set network.wwan.dialnumber='#777'
uci set network.wwan.username='your_username'
uci set network.wwan.password='your_password'
uci commit network

uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

---

## Useful Scripts

### Modem Detection and Setup Script

Create `/root/modem-detect.sh`:

```bash
#!/bin/bash

echo "=== OpenWRT Modem Detection Script ==="
echo ""

# Check USB devices
echo "USB Devices:"
lsusb

echo ""
echo "=== Checking for modem interfaces ==="

# Check for serial devices
if ls /dev/ttyUSB* >/dev/null 2>&1; then
    echo "✓ Serial devices found:"
    ls -l /dev/ttyUSB*

    echo ""
    echo "Testing AT commands on each port:"
    for port in /dev/ttyUSB*; do
        echo "  Testing $port..."
        (echo -e "ATI\r"; sleep 1) > $port &
        timeout 2 cat $port 2>/dev/null | head -5
    done
else
    echo "✗ No /dev/ttyUSB* devices found"
fi

# Check for QMI/MBIM devices
echo ""
if ls /dev/cdc-wdm* >/dev/null 2>&1; then
    echo "✓ QMI/MBIM devices found:"
    ls -l /dev/cdc-wdm*

    if command -v uqmi >/dev/null 2>&1; then
        echo ""
        echo "QMI Status:"
        uqmi -d /dev/cdc-wdm0 --get-device-operating-mode
    fi
else
    echo "✗ No /dev/cdc-wdm* devices found"
fi

# Check for network interfaces
echo ""
echo "=== Network Interfaces ==="
ifconfig -a | grep -E "usb|eth|wwan" | grep -v "127.0.0.1"

# Check kernel modules
echo ""
echo "=== Loaded Modem Drivers ==="
lsmod | grep -E "option|qmi|mbim|cdc|acm|sierra"

echo ""
echo "=== Recommendation ==="
if ls /dev/cdc-wdm* >/dev/null 2>&1; then
    echo "Use QMI or MBIM protocol for best performance"
    echo "Install: opkg install kmod-usb-net-qmi-wwan uqmi"
elif ls /dev/ttyUSB* >/dev/null 2>&1; then
    echo "Use 3G/PPP protocol (slower but compatible)"
    echo "Already installed"
else
    echo "No modem detected. Check USB connection and drivers."
fi
```

Make executable:
```bash
chmod +x /root/modem-detect.sh
```

---

## Conclusion

This guide documents real-world configurations for specific GSM/CDMA modem models. Key points:

### Best Practices
- ✅ Check modem compatibility before purchase
- ✅ Use fastest protocol available (QMI/MBIM > NCM > PPP)
- ✅ Test modem with detection script
- ✅ Keep mode-switch configurations for your model
- ✅ Document working AT commands for your modem

### Protocol Priority
1. **QMI/MBIM** - Best performance, modern modems
2. **NCM** - Good performance, Huawei/ZTE LTE
3. **HiLink** - Easy setup, some features limited
4. **PPP** - Universal compatibility, slower

### Common Issues
- **Wrong protocol** - Try QMI → MBIM → NCM → PPP
- **Mode switching** - Modem stuck in CD-ROM mode
- **Wrong TTY port** - Test all /dev/ttyUSB* ports
- **IP conflict** - HiLink modems vs. router LAN
- **Insufficient power** - Use powered USB hub

### Model-Specific Notes
- **Huawei E3xxx HiLink**: Change IP or use bridge mode
- **Huawei E3372 Stick**: Enable interface via AT command
- **ZTE MF195**: Requires mode switch
- **Nokia 21M-02**: Use CDC-ACM, not option driver
- **Novatel MC990D**: Eject virtual CD-ROM first
- **CDMA modems**: Often need username/password

---

*Document Version: 1.0*
*Last Updated: 2025*
*Based on: https://eko.one.pl/?p=openwrt-modemygsm*
