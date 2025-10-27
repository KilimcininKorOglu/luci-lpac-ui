# OpenWrt Installation Guide for ZTE MF286D

Comprehensive guide for installing OpenWrt on ZTE MF286D mobile router with integrated cellular modem management.

**Based on:** https://eko.one.pl/forum/viewtopic.php?id=21847
**Device:** ZTE MF286D 4G/LTE Mobile Router
**Target Audience:** Advanced users, router modders, cellular router enthusiasts
**Risk Level:** High - requires serial access, can brick device if done incorrectly

---

## ⚠️ Important Warnings

**READ BEFORE PROCEEDING:**

- ⚠️ **BRICK RISK**: Incorrect installation can permanently damage your router
- ⚠️ **WARRANTY VOID**: Installing OpenWrt voids manufacturer warranty
- ⚠️ **SERIAL ACCESS REQUIRED**: Must open device and solder/connect UART
- ⚠️ **TFTP SERVER NEEDED**: Requires network setup for firmware transfer
- ⚠️ **BACKUP CRITICAL**: Always backup original firmware before proceeding
- ⚠️ **NO OFFICIAL SUPPORT**: Community-driven effort, no manufacturer support

**Prerequisites:**
- Advanced Linux/OpenWrt knowledge
- Soldering skills (or UART adapter connection)
- TFTP server setup capability
- Understanding of U-Boot and NAND flash operations

---

## Table of Contents

1. [Device Overview](#device-overview)
2. [Hardware Requirements](#hardware-requirements)
3. [Preparation](#preparation)
4. [Backup Original Firmware](#backup-original-firmware)
5. [OpenWrt Installation](#openwrt-installation)
6. [Modem Configuration](#modem-configuration)
7. [Post-Installation Setup](#post-installation-setup)
8. [Recovery Procedures](#recovery-procedures)
9. [Advanced Features](#advanced-features)
10. [Troubleshooting](#troubleshooting)

---

## Device Overview

### ZTE MF286D Specifications

**Hardware:**
- **SoC**: Qualcomm IPQ4019 (Quad-core ARM Cortex-A7 @ 716MHz)
- **RAM**: 256 MB DDR3
- **Flash**: 128 MB NAND (Winbond W25N01GV)
- **Wireless**:
  - 2.4GHz: 802.11b/g/n (2×2 MIMO)
  - 5GHz: 802.11a/n/ac (2×2 MIMO)
- **Cellular Modem**: Qualcomm SDX24 (Cat 6 LTE)
  - 4G LTE: Bands 1/3/7/8/20/28/32/38
  - 3G UMTS: Bands 1/8
  - 2G GSM: 900/1800 MHz
- **Ethernet**: 2× Gigabit LAN, 1× Gigabit WAN
- **USB**: 1× USB 2.0 port
- **SIM**: 1× Micro-SIM slot
- **Antenna**: 2× external antenna connectors (LTE), 2× internal WiFi
- **Power**: 12V/1.5A DC

**Stock Firmware:** ZTE proprietary Linux-based firmware

**OpenWrt Status:** Supported (community builds)

### Why Install OpenWrt?

**Benefits:**
- ✅ Full control over router configuration
- ✅ Advanced networking features (VPN, QoS, mwan3)
- ✅ Better modem control (band locking, AT commands)
- ✅ Regular security updates
- ✅ Custom packages and applications
- ✅ No vendor restrictions or limitations

**Limitations:**
- ❌ May lose some stock features (depends on build)
- ❌ No official vendor support
- ❌ Requires technical knowledge
- ❌ Risk of bricking device

---

## Hardware Requirements

### Essential Hardware

#### 1. USB-to-UART Adapter

**Recommended adapters:**
- ✅ **CP2102** - Reliable, low noise
- ✅ **PL2303** - Common, stable
- ❌ **CH340** - NOT RECOMMENDED (generates noise during startup)

**Specifications:**
- Voltage: 3.3V TTL (NOT 5V - will damage router!)
- Connections: TX, RX, GND (3-wire minimum)

**Purchase sources:**
- Amazon, eBay, AliExpress
- Electronics stores
- ~$2-10 USD

#### 2. Connection Hardware

**Option A: Direct soldering**
- Solder wire to UART pads on PCB
- Permanent connection
- Most reliable

**Option B: Test clips/probes**
- Connect without soldering
- Temporary connection
- Easier but less reliable

**Option C: Pogo pin adapter**
- Spring-loaded pins
- Reusable
- Good middle ground

#### 3. Computer with TFTP Server

**Requirements:**
- Linux, Windows, or macOS
- TFTP server software installed
- Ethernet connection to router
- Terminal emulator (PuTTY, minicom, screen)

#### 4. Network Cable

- Standard Ethernet cable (Cat 5e or better)
- Connect computer to router LAN port

### Optional Hardware

- **Multimeter** - Verify voltage levels
- **Anti-static wrist strap** - Prevent ESD damage
- **Good lighting and magnification** - For soldering small pads

---

## Preparation

### 1. Download Required Files

**OpenWrt Firmware:**
```
Source: dl.eko.one.pl/firmware/
Files needed:
- openwrt-XXX-zte_mf286d-initramfs-kernel.bin
- openwrt-XXX-zte_mf286d-squashfs-sysupgrade.bin
```

**Original Firmware (for backup/recovery):**
```
Source: dl.eko.one.pl/orig/zte_mf286d/
Files: Stock firmware images (multiple MTD partitions)
```

**Recommended Packages (post-installation):**
```
- luci-app-3ginfo-lite (modem information)
- luci-app-modemband (band management)
- luci-app-sms-tool (SMS support)
```

### 2. Setup TFTP Server

**Linux (using dnsmasq):**
```bash
# Install dnsmasq
sudo apt install dnsmasq

# Create TFTP directory
sudo mkdir -p /srv/tftp
sudo chmod 777 /srv/tftp

# Copy firmware
cp openwrt-*-initramfs-kernel.bin /srv/tftp/

# Configure dnsmasq
sudo tee /etc/dnsmasq.conf << EOF
interface=eth0
bind-interfaces
dhcp-range=192.168.1.100,192.168.1.200,12h
enable-tftp
tftp-root=/srv/tftp
EOF

# Start dnsmasq
sudo systemctl restart dnsmasq
```

**Windows (using Tftpd64):**
```
1. Download Tftpd64 from https://pjo2.github.io/tftpd64/
2. Run as administrator
3. Set Current Directory to folder with firmware
4. Set Server interfaces to your Ethernet adapter
5. Enable TFTP Server
6. Set IP to 192.168.1.100
```

**macOS (built-in TFTP):**
```bash
# Enable TFTP
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist

# Copy firmware to TFTP directory
sudo cp openwrt-*-initramfs-kernel.bin /private/tftpboot/

# Set permissions
sudo chmod 777 /private/tftpboot/*
```

### 3. Setup Serial Console

**Identify UART Pins:**

On ZTE MF286D PCB (near USB port):
```
GND  TX  RX  VCC (3.3V)
 •   •   •   •
```

**Connection:**
```
Router → USB Adapter
GND    → GND
TX     → RX
RX     → TX
VCC    → NOT CONNECTED (router powers itself)
```

**CRITICAL:** Do NOT connect VCC/3.3V pin - router has its own power supply!

**Serial Settings:**
- Baud rate: 115200
- Data bits: 8
- Parity: None
- Stop bits: 1
- Flow control: None

**Terminal Software:**

**Linux:**
```bash
# Using screen
screen /dev/ttyUSB0 115200

# Using minicom
minicom -D /dev/ttyUSB0 -b 115200
```

**Windows:**
```
PuTTY:
- Connection type: Serial
- COM port: (check Device Manager)
- Speed: 115200
```

**macOS:**
```bash
screen /dev/tty.usbserial-XXX 115200
```

### 4. Physical Access to Router

**Opening the device:**
1. Remove rubber feet to access screws
2. Unscrew case (usually 4 screws)
3. Carefully separate case halves
4. Locate UART pads on PCB

**UART Location:**
- Near USB port
- Usually labeled or marked with test points
- May require magnification to identify

---

## Backup Original Firmware

**CRITICAL:** Always backup before flashing OpenWrt!

### 1. Boot to Stock Firmware

Power on router normally, access via serial console

### 2. Enable USB Storage

**If using USB flash drive for backup:**

Via web interface:
```
Settings → USB → File Sharing → Enable SMB
```

Or via serial console:
```bash
# Mount USB drive
mount /dev/sda1 /mnt/usb
```

### 3. Backup All MTD Partitions

**Via serial console:**
```bash
# Create backup directory
mkdir -p /var/usb_disk/backup

# Backup all partitions (0-21)
for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21; do
    echo "Backing up mtd$i..."
    cat /dev/mtd$i > /var/usb_disk/backup/mtd$i
    echo "mtd$i complete"
done

# Verify backups
ls -lh /var/usb_disk/backup/
```

**Expected partitions:**
```
mtd0: sbl              (128 KB)
mtd1: mibib            (128 KB)
mtd2: bootconfig       (128 KB)
mtd3: qsee             (512 KB)
mtd4: devcfg           (128 KB)
mtd5: rpm              (128 KB)
mtd6: cdt              (128 KB)
mtd7: appsblenv        (128 KB)
mtd8: appsbl           (1 MB)
mtd9: ubi              (29 MB) ← IMPORTANT: This is modified by OpenWrt
mtd10: fota            (32 MB)
mtd11-21: Other partitions
```

**IMPORTANT:** `mtd9` (ubi) is the only partition modified during OpenWrt installation. All other partitions remain untouched.

### 4. Copy Backups to Computer

**Via USB:**
```bash
# Sync to ensure all writes complete
sync

# Unmount USB
umount /mnt/usb

# Remove USB drive and copy to computer
```

**Via network (if possible):**
```bash
# From router to computer
scp /var/usb_disk/backup/* user@192.168.1.100:/backup/
```

### 5. Verify Backups

**On computer:**
```bash
# Check file sizes
ls -lh backup/

# Verify mtd9 (most important)
file backup/mtd9
# Should show: UBI image

# Calculate checksums
md5sum backup/* > checksums.txt
```

**Store backups safely:**
- Keep multiple copies
- Store on different media
- Label with device serial number and date

---

## OpenWrt Installation

### Method 1: TFTP + U-Boot (Recommended)

This is the safest method using U-Boot bootloader.

#### Step 1: Enter U-Boot

1. Connect serial console
2. Connect Ethernet cable (computer to LAN port)
3. Configure computer network:
   ```
   IP: 192.168.1.100
   Netmask: 255.255.255.0
   Gateway: 192.168.1.1
   ```

4. Power on router
5. **Immediately** press key repeatedly (try space, Enter, or Escape)
6. U-Boot prompt should appear:
   ```
   IPQ40xx #
   ```

#### Step 2: Configure Network

```bash
# Set router IP
setenv ipaddr 192.168.1.1

# Set server IP (your computer)
setenv serverip 192.168.1.100

# Verify settings
printenv ipaddr
printenv serverip

# Test connectivity
ping 192.168.1.100
```

**If ping fails:**
- Check Ethernet cable
- Verify computer IP configuration
- Ensure TFTP server is running
- Try different LAN port

#### Step 3: Erase mtd9 Partition

**CRITICAL STEP:** Erasing mtd9 before loading initramfs prevents sysupgrade issues.

```bash
# Erase NAND partition 9 (29MB at offset 0x1800000)
nand erase 0x1800000 0x1d00000

# Wait for completion (may take 30-60 seconds)
```

**Explanation:**
- `0x1800000` = Start offset (24 MB)
- `0x1d00000` = Length (29 MB)
- This clears the rootfs partition

#### Step 4: Load Initramfs Image

```bash
# Load initramfs via TFTP to RAM
tftpboot 0x84000000 openwrt-ipq40xx-generic-zte_mf286d-initramfs-kernel.bin

# Verify loaded
# Should see: "Bytes transferred = XXXXX (XXXXX hex)"

# Boot from RAM
bootm 0x84000000
```

**Router will boot OpenWrt from RAM (temporary, not written to flash yet)**

#### Step 5: Transfer Sysupgrade Image

**From router console:**
```bash
# Wait for boot to complete (~2 minutes)
# Login as root (no password)

# Verify network interface
ip addr show

# Bring up LAN
ifconfig eth0 192.168.1.1 netmask 255.255.255.0 up
```

**From computer:**
```bash
# Copy sysupgrade image to router
scp openwrt-ipq40xx-generic-zte_mf286d-squashfs-sysupgrade.bin root@192.168.1.1:/tmp/

# Or use TFTP from router:
# cd /tmp
# tftp -g -r openwrt-XXX-sysupgrade.bin 192.168.1.100
```

#### Step 6: Install to Flash

```bash
# On router (in initramfs)

# Verify sysupgrade image exists
ls -lh /tmp/*sysupgrade.bin

# Perform sysupgrade
sysupgrade -n /tmp/openwrt-*-sysupgrade.bin

# Router will:
# 1. Write firmware to flash
# 2. Automatically reboot
# 3. Boot from flash (permanent installation)
```

**Wait 3-5 minutes for installation and reboot**

#### Step 7: First Boot

**After automatic reboot:**
```bash
# Router boots from flash
# Login via serial: root (no password)

# Or access via network:
# IP: 192.168.1.1
# Username: root
# Password: (none - set immediately!)
```

**Set root password immediately:**
```bash
passwd
```

**Access web interface:**
```
http://192.168.1.1
Login: root
Password: (whatever you just set)
```

### Method 2: Alternative Installation (If Method 1 Fails)

**If erase fails or sysupgrade has issues:**

```bash
# In U-Boot, after loading initramfs and booting:

# Attach UBI
ubiattach -m 9

# Remove old volumes
ubirmvol /dev/ubi0 -N ubi_rootfs
ubirmvol /dev/ubi0 -N ubi_rootfs_data

# Then perform sysupgrade as usual
sysupgrade -n /tmp/openwrt-*-sysupgrade.bin
```

**Note:** Newer installation procedures find the erase method (Method 1) more reliable.

---

## Modem Configuration

### Auto-APN Feature

**Discovery:** The ZTE MF286D modem retains APN configuration from factory firmware stored in `auto_apn.db` database (located in mtd8 partition).

**Benefit:** Minimal configuration needed for cellular connectivity.

### Minimal QMI Configuration

**For generic OpenWrt builds:**

Edit `/etc/config/network`:
```bash
config interface 'wan'
    option proto 'qmi'
    option device '/dev/cdc-wdm0'
    # No APN needed - uses auto-APN from database
```

**Apply configuration:**
```bash
uci commit network
/etc/init.d/network restart
```

**Modem will:**
1. Detect SIM card operator
2. Look up operator in auto_apn.db
3. Apply stored APN settings automatically
4. Connect to network

### Manual APN Configuration

**If auto-APN doesn't work:**

```bash
uci set network.wan.apn='internet'
uci set network.wan.pdptype='ipv4'
uci set network.wan.username=''
uci set network.wan.password=''
uci commit network
/etc/init.d/network restart
```

**Common APNs:**
- Generic: `internet`, `broadband`, `data`
- Check with your carrier for specific APN

### AT Command Access

**Via serial interface:**
```bash
# List serial devices
ls -l /dev/ttyUSB*

# Typically:
# /dev/ttyUSB0 - AT command port
# /dev/ttyUSB1 - Diagnostics
# /dev/ttyUSB2 - GPS (if available)

# Send AT commands
echo "AT" > /dev/ttyUSB0 && cat /dev/ttyUSB0

# Query modem info
echo "AT+CGMM" > /dev/ttyUSB0  # Model
echo "AT+CGSN" > /dev/ttyUSB0  # IMEI
echo "AT+CSQ" > /dev/ttyUSB0   # Signal quality
```

### Common AT Commands

**Network information:**
```bash
# Get operator
AT+COPS?

# Get signal quality
AT+CSQ

# Get cell info
AT+CREG?

# Get network mode
AT+ZNLOCKMODE?
```

**APN Configuration:**
```bash
# Set APN
AT+CGDCONT=1,"IP","internet","",0,0

# Query APN
AT+CGDCONT?
```

**Band Locking:**
```bash
# Lock to specific LTE band (example: Band 7 - 2600 MHz)
AT+ZNLOCKBAND=1,0,80000,0

# Unlock bands (auto selection)
AT+ZNLOCKBAND=0

# Query current band
AT+ZNLOCKBAND?
```

**Cell Locking:**
```bash
# Lock to specific cell (example)
AT+ZLOCKCELL=6350,307

# Unlock cell
AT+ZLOCKCELL=0

# Query locked cell
AT+ZLOCKCELL?
```

**Carrier Aggregation:**
```bash
# Query upload carrier aggregation
AT+ZULCA?

# Query download carrier aggregation
AT+ZDLCA?
```

---

## Post-Installation Setup

### 1. Install LuCI Web Interface (if not included)

```bash
# Update package lists
opkg update

# Install LuCI
opkg install luci luci-ssl

# Start web server
/etc/init.d/uhttpd enable
/etc/init.d/uhttpd start
```

**Access:** http://192.168.1.1

### 2. Install Modem Management Tools

**3ginfo-lite (modem information):**
```bash
opkg update
opkg install luci-app-3ginfo-lite
```

**modemband (band management):**
```bash
opkg install luci-app-modemband
```

**sms-tool (SMS support):**
```bash
opkg install luci-app-sms-tool sms-tool
```

**Access tools:** Network menu in LuCI

### 3. Configure WiFi

```bash
# Enable WiFi
uci set wireless.radio0.disabled='0'
uci set wireless.radio1.disabled='0'

# Set SSID and password (2.4GHz)
uci set wireless.default_radio0.ssid='MyNetwork'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='MySecurePassword123'

# Set SSID and password (5GHz)
uci set wireless.default_radio1.ssid='MyNetwork-5G'
uci set wireless.default_radio1.encryption='psk2'
uci set wireless.default_radio1.key='MySecurePassword123'

uci commit wireless
wifi
```

### 4. Configure Firewall

```bash
# Add WAN (cellular) to firewall
uci set firewall.@zone[1].network='wan wan6'
uci commit firewall
/etc/init.d/firewall restart
```

### 5. Update and Install Essential Packages

```bash
opkg update

# Useful packages
opkg install htop nano curl wget iperf3

# VPN support (optional)
opkg install openvpn-openssl wireguard-tools

# USB storage support (optional)
opkg install kmod-usb-storage kmod-fs-ext4 block-mount
```

---

## Recovery Procedures

### Scenario 1: OpenWrt Boot Failure (Router Still Accessible via U-Boot)

**Solution: Reinstall OpenWrt**

1. Enter U-Boot (power on, press key repeatedly)
2. Follow installation procedure from Step 2 onwards
3. Load initramfs via TFTP
4. Perform sysupgrade again

### Scenario 2: Restore Original Firmware

**Prerequisites:**
- Backup of mtd9 partition
- Access to U-Boot
- TFTP server with original firmware

**Procedure:**

1. Enter U-Boot
2. Configure network (same as installation)
3. Load original mtd9 backup via TFTP:
   ```bash
   tftpboot 0x84000000 mtd9.backup
   ```

4. Write to NAND:
   ```bash
   nand erase 0x1800000 0x1d00000
   nand write 0x84000000 0x1800000 0x1d00000
   ```

5. Reboot:
   ```bash
   reset
   ```

**Router should boot to original firmware**

### Scenario 3: Complete Brick (No U-Boot Access)

**This is serious and difficult to recover from.**

**Possible causes:**
- Corrupted bootloader
- Wrong voltage on UART (fried components)
- Power loss during critical write

**Recovery options:**

1. **JTAG recovery** (advanced, requires JTAG adapter)
2. **SPI programmer** (de-solder NAND chip, program directly)
3. **Professional repair service**
4. **Replace mainboard** (if available)

**Prevention is key:**
- Never interrupt power during flashing
- Always use 3.3V UART (not 5V)
- Keep backup of all partitions
- Test TFTP connectivity before starting

---

## Advanced Features

### Band Locking

**Via modemband package (web interface):**
```
Network → Modem Band → Select bands → Apply
```

**Via AT commands:**
```bash
# Lock to Band 7 (2600 MHz)
echo 'AT+ZNLOCKBAND=1,0,80000,0' > /dev/ttyUSB0

# Band values (hexadecimal):
# Band 1: 1
# Band 3: 4
# Band 7: 40
# Band 20: 80000
# Multiple bands: Add values (e.g., B3+B7 = 44)
```

### SMS via AT Commands

**Send SMS:**
```bash
# Set SMS text mode
echo 'AT+CMGF=1' > /dev/ttyUSB0

# Send SMS
echo 'AT+CMGS="+48123456789"' > /dev/ttyUSB0
sleep 1
echo -e 'Hello World\x1A' > /dev/ttyUSB0
```

**Read SMS:**
```bash
# List all SMS
echo 'AT+CMGL="ALL"' > /dev/ttyUSB0
cat /dev/ttyUSB0
```

### GPS (if supported by modem variant)

**Enable GPS:**
```bash
echo 'AT+CGPS=1' > /dev/ttyUSB0
```

**Read GPS data:**
```bash
echo 'AT+CGPSINFO' > /dev/ttyUSB0
cat /dev/ttyUSB0
```

### Multi-WAN with mwan3

```bash
# Install mwan3
opkg install mwan3

# Configure cellular as WAN1, Ethernet WAN as WAN2
# See OPENWRT_FAILOVER_GUIDE.md for complete setup
```

---

## Troubleshooting

### Modem Not Detected

**Check QMI device:**
```bash
ls -l /dev/cdc-wdm*
# Should show: /dev/cdc-wdm0
```

**If missing:**
```bash
# Check USB devices
lsusb | grep Qualcomm

# Check kernel messages
dmesg | grep -i qmi
dmesg | grep -i cdc

# Install QMI packages
opkg update
opkg install kmod-usb-net-qmi-wwan uqmi
reboot
```

### No Cellular Connection

**Verify interface status:**
```bash
uqmi -d /dev/cdc-wdm0 --get-data-status
```

**Check network registration:**
```bash
uqmi -d /dev/cdc-wdm0 --get-serving-system
```

**Manual connection:**
```bash
# Start network
uqmi -d /dev/cdc-wdm0 --start-network --apn internet

# Get IP
udhcpc -i wwan0
```

### WiFi Not Working

**Check radio status:**
```bash
wifi status
```

**Enable radios:**
```bash
uci set wireless.radio0.disabled='0'
uci set wireless.radio1.disabled='0'
uci commit wireless
wifi reload
```

**Check for errors:**
```bash
logread | grep -i wifi
```

### Serial Console Not Working

**Common issues:**

1. **Wrong baud rate:**
   - Try: 9600, 19200, 38400, 57600, 115200

2. **TX/RX swapped:**
   - Router TX → Adapter RX
   - Router RX → Adapter TX

3. **Wrong voltage:**
   - Must be 3.3V TTL
   - 5V will damage router

4. **Bad connection:**
   - Check solder joints
   - Verify continuity with multimeter

### TFTP Not Working

**Troubleshooting steps:**

1. **Ping test:**
   ```bash
   # From U-Boot
   ping 192.168.1.100
   ```

2. **Verify IPs:**
   ```bash
   # In U-Boot
   printenv ipaddr
   printenv serverip
   ```

3. **Firewall:**
   - Disable firewall on computer temporarily
   - Allow TFTP (port 69 UDP)

4. **TFTP server:**
   - Verify TFTP server is running
   - Check file permissions (world-readable)
   - Verify correct directory

---

## Resources

### Official Documentation

- **OpenWrt Wiki:** https://openwrt.org/toh/zte/mf286d
- **Device Page:** Detailed specifications and installation guide
- **Forum Support:** https://forum.openwrt.org/

### Community Resources

- **Firmware Repository:** dl.eko.one.pl/firmware/
- **Original Firmware Backups:** dl.eko.one.pl/orig/zte_mf286d/
- **Polish Forum Thread:** https://eko.one.pl/forum/viewtopic.php?id=21847
  - 150+ pages of community experiences
  - Troubleshooting solutions
  - Firmware updates

### Recommended Packages

**GitHub repositories:**
- `luci-app-3ginfo-lite` - Modem information display
- `luci-app-modemband` - LTE band management
- `luci-app-sms-tool` - SMS sending/receiving

### Related Guides

- **OPENWRT_EASYCONFIG_GUIDE.md** - Simplified modem management UI
- **OPENWRT_FAILOVER_GUIDE.md** - Multi-WAN setup
- **OPENWRT_CONFIGURATION_GUIDE.md** - General OpenWrt configuration

---

## Disclaimer

**This guide is provided "as-is" without warranty.**

- Installing OpenWrt voids manufacturer warranty
- Incorrect installation can permanently damage device
- Author and contributors not responsible for bricked devices
- Proceed at your own risk
- Advanced technical knowledge required
- When in doubt, ask for help in community forums

**Recommended:** Practice on spare/older device first

---

**Document Version:** 1.0
**Last Updated:** 2025-10-25
**Based on:** https://eko.one.pl/forum/viewtopic.php?id=21847 (150-page community forum thread)
**License:** CC BY-SA 4.0
**Difficulty Level:** Advanced
**Estimated Time:** 2-4 hours (first time)
