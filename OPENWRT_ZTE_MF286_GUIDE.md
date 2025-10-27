# OpenWrt Installation Guide for ZTE MF286 / MF286A

Comprehensive guide for installing OpenWrt on ZTE MF286 and MF286A LTE routers with integrated cellular modem.

**Based on:** https://eko.one.pl/forum/viewtopic.php?id=21845
**Device:** ZTE MF286 / MF286A 4G/LTE Router
**Target Audience:** Advanced users, router modders, cellular router enthusiasts
**Risk Level:** High - requires root access or serial console, can brick device

---

## ⚠️ Critical Warnings

**READ BEFORE PROCEEDING:**

- ⚠️ **DEVICE VARIANT CRITICAL**: MF286 and MF286A are DIFFERENT devices with different installation procedures
- ⚠️ **BRICK RISK**: Incorrect installation can permanently damage your router
- ⚠️ **WARRANTY VOID**: Installing OpenWrt voids manufacturer warranty
- ⚠️ **BACKUP MANDATORY**: Original firmware not publicly available - must backup before proceeding
- ⚠️ **CARRIER-SPECIFIC**: Stock firmware varies by carrier (T-Mobile, Orange, etc.)
- ⚠️ **NO OFFICIAL SUPPORT**: Community-driven effort, no manufacturer support

**Prerequisites:**
- Advanced Linux/OpenWrt knowledge
- Ability to identify device variant
- Understanding of MTD partitions and flash operations
- Backup capability (USB drive or network storage)

---

## Table of Contents

1. [Device Identification](#device-identification)
2. [Hardware Specifications](#hardware-specifications)
3. [Preparation](#preparation)
4. [Backup Original Firmware](#backup-original-firmware)
5. [Installation Methods](#installation-methods)
6. [Modem Configuration](#modem-configuration)
7. [Post-Installation Setup](#post-installation-setup)
8. [Known Issues](#known-issues)
9. [Recovery Procedures](#recovery-procedures)
10. [Troubleshooting](#troubleshooting)

---

## Device Identification

### Determining Your Device Variant

**CRITICAL:** MF286 and MF286A are different devices requiring different installation procedures!

#### Method 1: Check MTD Partitions

**Access stock firmware via web interface or serial console:**

```bash
# List MTD partitions
cat /proc/mtd
```

**MF286A identification:**
- If you see **16 partitions** → Device is MF286A
- If you see **different number** → Device is MF286

#### Method 2: Check Firmware Version

**Access router web interface:**
```
Settings → Device Information → Firmware Version
```

**MF286A firmware pattern:**
```
CR_TMOMF286V1.0.0B03
CR_TMOMF286AV1.0.0B04
```

If firmware version contains "MF286A" or shows MF286A pattern → Device is MF286A

#### Method 3: Physical Label

**Check label on bottom of device:**
- Model number explicitly states MF286 or MF286A
- Different carriers may use different variants

### Carrier Variants

**Common carrier versions:**
- **T-Mobile** - Both MF286 and MF286A
- **Orange** - Primarily MF286
- **Play** - Various versions
- **Generic unlocked** - Check firmware version

**Important:** Carrier firmware may differ significantly. Always backup before proceeding.

---

## Hardware Specifications

### ZTE MF286 / MF286A Common Specs

**System-on-Chip (SoC):**
- **CPU**: Qualcomm Atheros QCA9563
- **Frequency**: 775 MHz
- **Architecture**: MIPS 74Kc

**Memory:**
- **RAM**: 128 MB DDR2
- **NOR Flash**: 2 MB (bootloader and configuration)
- **NAND Flash**: 128 MB (main firmware storage)

**Wireless:**
- **2.4GHz**: 802.11b/g/n (2×2 MIMO)
- **5GHz**: 802.11a/n/ac (2×2 MIMO)
- **Chipset**: Qualcomm Atheros (integrated)

**Cellular Modem:**
- **Technology**: LTE Cat 4
- **Bands**: Varies by carrier/region
  - Typical: 1/3/7/8/20/28
- **Fallback**: 3G UMTS, 2G GSM
- **Interface**: QMI (Qualcomm MSM Interface)

**Connectivity:**
- **Ethernet**: 2× Gigabit LAN ports
- **WAN**: 1× Gigabit Ethernet (RJ-45)
- **USB**: 1× USB 2.0 port
- **SIM**: 1× Standard SIM slot
- **Antenna**: 2× external antenna connectors (LTE)

**Buttons:**
- WPS/WiFi button
- Reset button
- Power button

**LEDs:**
- Power, WiFi, Signal strength, LAN, etc.

**Power:**
- 12V/1.5A DC adapter

---

## Preparation

### 1. Identify Device Variant

**Follow [Device Identification](#device-identification) section above.**

### 2. Download Required Files

**OpenWrt Firmware:**
```
Community builds: dl.eko.one.pl/firmware/
Official builds: downloads.openwrt.org (if available)

Files needed:
- openwrt-ath79-generic-zte_mf286-initramfs-kernel.bin
- openwrt-ath79-generic-zte_mf286-squashfs-sysupgrade.bin

For MF286A (if different):
- Check community forums for specific images
```

**Backup Storage:**
```
- USB flash drive (4GB+ formatted as FAT32 or ext4)
- Or network storage accessible from router
```

### 3. Required Tools

**For software-based installation:**
- Web browser
- Network cable
- Computer with TFTP server capability

**For serial console method:**
- USB-to-UART adapter (FTDI FT232RL or similar)
  - **CRITICAL**: Must be 3.3V (NOT 5V - will damage router!)
  - Some 5V adapters can be modified with Zener diode
- Serial terminal software (PuTTY, minicom, screen)
- Soldering iron (if UART pads not accessible)

### 4. Setup TFTP Server (if using TFTP method)

**Linux:**
```bash
sudo apt install dnsmasq
sudo mkdir -p /srv/tftp
sudo chmod 777 /srv/tftp
cp openwrt-*-initramfs-kernel.bin /srv/tftp/

# Configure dnsmasq for TFTP
sudo tee /etc/dnsmasq.conf << EOF
interface=eth0
bind-interfaces
enable-tftp
tftp-root=/srv/tftp
EOF

sudo systemctl restart dnsmasq
```

**Windows:**
- Download Tftpd64 from https://pjo2.github.io/tftpd64/
- Run as administrator
- Set directory containing firmware
- Note your computer's IP address

---

## Backup Original Firmware

**CRITICAL:** Original firmware is NOT publicly available. You MUST backup before installing OpenWrt!

### Method 1: Backup via USB (Recommended)

#### Prerequisites
- USB flash drive (formatted FAT32 or ext4)
- Stock firmware web interface access or SSH

#### Enable USB Sharing (Stock Firmware)

**Via web interface:**
```
Settings → USB Settings → File Sharing → Enable
```

**Or via command line:**
```bash
# Access router via serial or SSH (if available)
# Check if USB is mounted
mount | grep usb

# If not mounted, mount manually
mkdir -p /mnt/usb
mount /dev/sda1 /mnt/usb
```

#### Backup All Partitions

**Via stock firmware command line:**
```bash
# Create backup directory
mkdir -p /mnt/usb/mf286_backup

# Backup all MTD partitions
for i in /dev/mtd*; do
    name=$(basename $i)
    echo "Backing up $name..."
    dd if=$i of=/mnt/usb/mf286_backup/$name bs=64k
    echo "$name complete"
done

# Sync to ensure all writes complete
sync

# List backups with sizes
ls -lh /mnt/usb/mf286_backup/
```

**Expected partitions (varies by variant):**
```
mtd0: u-boot (bootloader)
mtd1: u-boot-env (bootloader environment)
mtd2: factory (calibration data)
mtd3: crash (crash logs)
mtd4: cfg-param (configuration)
mtd5: oops (kernel oops)
mtd6: reserved0
mtd7: reserved1
mtd8: fota-flag
mtd9: kernel (kernel image)
mtd10: rootfs (root filesystem)
mtd11: rootfs_data (user data)
... (more partitions depending on variant)
```

#### Verify Backups

```bash
# Check file sizes (should be non-zero)
du -h /mnt/usb/mf286_backup/*

# Calculate checksums
md5sum /mnt/usb/mf286_backup/* > /mnt/usb/mf286_backup/checksums.md5

# Sync and unmount
sync
umount /mnt/usb
```

**Store backups safely:**
- Copy to computer immediately
- Keep multiple copies
- Label with device model, variant, carrier, and date

### Method 2: Backup via SSH (If Available)

**If SSH is enabled on stock firmware:**

```bash
# From your computer
ssh root@192.168.0.1

# Create backup directory
mkdir -p /tmp/backup

# Backup partitions
for i in /dev/mtd*; do
    dd if=$i of=/tmp/backup/$(basename $i) bs=64k
done

# Exit SSH
exit

# Copy backups to computer
scp -r root@192.168.0.1:/tmp/backup ./mf286_backup
```

### Method 3: Backup via Serial Console

**If other methods fail, use serial console:**

```bash
# Access via serial terminal
# Login as root

# Check available storage
df -h

# Mount USB if available
mount /dev/sda1 /mnt/usb

# Backup as in Method 1
```

---

## Installation Methods

### Overview of Methods

**Three main installation approaches:**

1. **Web-based exploit** - Easiest, no hardware modification
2. **TFTP recovery** - Moderate difficulty, requires TFTP server
3. **Serial console** - Most reliable, requires UART access

**Recommendation:**
- Try Method 1 (web exploit) first if available
- Fall back to Method 2 (TFTP) if exploit doesn't work
- Use Method 3 (serial) as last resort or for maximum control

### Method 1: Web-Based Exploit (URL Filtering Bypass)

**This method exploits busybox telnetd via URL filtering vulnerability.**

**Prerequisites:**
- Stock firmware web interface access
- Network connection to router

#### Step 1: Enable Telnet via Exploit

**Access router web interface:**
```
http://192.168.0.1
Login with admin credentials
```

**Navigate to URL filtering (path varies by firmware version):**
```
Security → URL Filter → Add Filter
```

**Exploit payload (example):**
```
URL to block: ;busybox telnetd;
```

**Or try alternate payloads:**
```
;/bin/busybox telnetd;
$(busybox telnetd)
`busybox telnetd`
```

**Apply and save settings**

#### Step 2: Access via Telnet

```bash
# From your computer
telnet 192.168.0.1

# Should get login prompt
# Try default credentials or root with no password
```

#### Step 3: Gain Root Access

**Once logged in via telnet:**
```bash
# Check current user
whoami
# If not root, try:
su -

# Or exploit to gain root
# (specific method depends on firmware version)
```

#### Step 4: Flash OpenWrt

**Transfer initramfs image:**
```bash
# On router (via telnet)
cd /tmp

# Download from TFTP server
tftp -g -r openwrt-ath79-generic-zte_mf286-initramfs-kernel.bin 192.168.1.100

# Or use wget if available
wget http://192.168.1.100/openwrt-ath79-generic-zte_mf286-initramfs-kernel.bin
```

**Flash to appropriate partition:**
```bash
# Identify kernel partition (usually mtd9)
cat /proc/mtd

# Flash initramfs (adjust mtd number if different)
mtd write /tmp/openwrt-*-initramfs-kernel.bin kernel

# Reboot
reboot
```

**Router will boot OpenWrt initramfs (temporary, in RAM)**

#### Step 5: Install Permanent Firmware

**After booting to initramfs:**
```bash
# Access via telnet or SSH (root, no password)
telnet 192.168.1.1
# or
ssh root@192.168.1.1

# Transfer sysupgrade image
# On your computer:
scp openwrt-*-sysupgrade.bin root@192.168.1.1:/tmp/

# On router:
cd /tmp
sysupgrade -n openwrt-*-sysupgrade.bin

# Router will flash and reboot to permanent OpenWrt
```

### Method 2: TFTP Recovery Mode

**This method uses built-in TFTP recovery mode.**

#### Step 1: Prepare TFTP Server

**Setup as described in [Preparation](#preparation) section.**

**Important:**
- TFTP server IP: 192.168.1.22 (specific to ZTE recovery)
- Firmware file must be named correctly (varies by model)

#### Step 2: Enter TFTP Recovery Mode

**Method A: Reset button during boot**
```
1. Power off router
2. Hold reset button
3. Power on router (keep holding reset)
4. Wait for specific LED pattern (usually flashing)
5. Release reset button
6. Router enters TFTP recovery mode
```

**Method B: Via web interface (if available)**
```
Some stock firmware versions have recovery option:
Settings → System → Backup/Restore → TFTP Recovery
```

#### Step 3: Upload Firmware via TFTP

**Router will automatically attempt to download firmware from:**
```
IP: 192.168.1.22
File: specific filename (check community forums for exact name)
```

**Configure your computer:**
```
IP: 192.168.1.22
Netmask: 255.255.255.0
Gateway: 192.168.1.1
```

**Place firmware in TFTP directory with correct name**

**Router will:**
1. Download firmware from TFTP server
2. Flash to memory
3. Reboot automatically

**If successful, router boots to OpenWrt**

### Method 3: Serial Console Installation

**Most reliable but requires hardware access.**

#### Step 1: UART Connection

**Locate UART pads on PCB:**
```
Usually near CPU or marked as:
GND  TX  RX  VCC
```

**Connect USB-UART adapter:**
```
Router  →  Adapter
GND     →  GND
TX      →  RX
RX      →  TX
VCC     →  NOT CONNECTED (router powered separately)
```

**CRITICAL:** Use 3.3V adapter only! 5V will damage router!

**For 5V FT232RL modification:**
```
Add 1.8V Zener diode between VCC and GND on adapter
This drops 5V to ~3.2V (safe for router)
```

**Serial settings:**
```
Baud rate: 115200
Data bits: 8
Parity: None
Stop bits: 1
Flow control: None
```

#### Step 2: Access Bootloader

```bash
# Connect serial terminal
screen /dev/ttyUSB0 115200
# or
minicom -D /dev/ttyUSB0 -b 115200

# Power on router
# Watch boot messages
# Press any key when prompted to interrupt boot
# Should get bootloader prompt (varies by bootloader)
```

#### Step 3: Load Initramfs via TFTP

**In bootloader:**
```bash
# Set environment variables
setenv ipaddr 192.168.1.1
setenv serverip 192.168.1.100

# Test connectivity
ping 192.168.1.100

# Load initramfs to RAM
tftpboot 0x81000000 openwrt-ath79-generic-zte_mf286-initramfs-kernel.bin

# Boot from RAM
bootm 0x81000000
```

**Router boots OpenWrt from RAM (temporary)**

#### Step 4: Flash Permanent Firmware

**From initramfs:**
```bash
# Transfer sysupgrade image
scp openwrt-*-sysupgrade.bin root@192.168.1.1:/tmp/

# Or use wget if router has internet
wget -O /tmp/sysupgrade.bin http://downloads.openwrt.org/...

# Flash to permanent storage
sysupgrade -n /tmp/openwrt-*-sysupgrade.bin

# Router flashes and reboots to permanent OpenWrt
```

---

## Modem Configuration

### QMI Interface Setup

**Basic configuration for cellular connectivity:**

Edit `/etc/config/network`:
```bash
config interface 'wan'
    option device '/dev/cdc-wdm0'
    option proto 'qmi'
    option apn 'internet'  # Adjust for your carrier
    option pdptype 'ipv4'
```

**Apply configuration:**
```bash
uci commit network
/etc/init.d/network restart
```

### Known APN Issue

**Problem:** "Modem refuses to connect over QMI to APN other than configured in stock firmware"

**Symptoms:**
- Modem connects with original carrier APN
- Fails to connect with different APN via QMI

**Workarounds:**

**Option 1: Reset modem to factory**
```bash
# Via AT commands
echo "AT&F" > /dev/ttyUSB2
echo "AT+CGDCONT=0" > /dev/ttyUSB2  # Clear all contexts
```

**Option 2: Use AT commands to set APN**
```bash
# Set APN via AT command
echo 'AT+CGDCONT=1,"IP","internet","",0,0' > /dev/ttyUSB2

# Then use QMI for connection
uqmi -d /dev/cdc-wdm0 --start-network --apn internet
```

**Option 3: Use different connection protocol**
```bash
# Try NCM instead of QMI
config interface 'wan'
    option proto 'ncm'
    option device '/dev/ttyUSB0'
    option apn 'internet'
```

### AT Command Access

**Find AT command port:**
```bash
ls -l /dev/ttyUSB*

# Typical layout:
# /dev/ttyUSB0 - GPS or AT
# /dev/ttyUSB1 - AT commands (most likely)
# /dev/ttyUSB2 - Diagnostics
```

**Test AT commands:**
```bash
# Simple test
echo "AT" > /dev/ttyUSB1 && cat /dev/ttyUSB1

# Get modem info
echo "AT+CGMI" > /dev/ttyUSB1  # Manufacturer
echo "AT+CGMM" > /dev/ttyUSB1  # Model
echo "AT+CGSN" > /dev/ttyUSB1  # IMEI
```

---

## Post-Installation Setup

### 1. Set Root Password

```bash
# Immediately after first boot
passwd
# Enter new password twice
```

### 2. Configure WiFi

```bash
# Enable WiFi radios
uci set wireless.radio0.disabled='0'
uci set wireless.radio1.disabled='0'

# Configure 2.4GHz
uci set wireless.default_radio0.ssid='MyNetwork'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='MyPassword123'

# Configure 5GHz
uci set wireless.default_radio1.ssid='MyNetwork-5G'
uci set wireless.default_radio1.encryption='psk2'
uci set wireless.default_radio1.key='MyPassword123'

uci commit wireless
wifi
```

### 3. Install LuCI (if not included)

```bash
opkg update
opkg install luci luci-ssl
/etc/init.d/uhttpd enable
/etc/init.d/uhttpd start
```

**Access web interface:** http://192.168.1.1

### 4. Install Modem Tools

```bash
opkg update
opkg install luci-app-3ginfo-lite
opkg install luci-app-modemband
opkg install luci-app-sms-tool sms-tool
```

### 5. Configure Firewall

```bash
uci set firewall.@zone[1].network='wan wan6'
uci commit firewall
/etc/init.d/firewall restart
```

---

## Known Issues

### 1. WiFi LED Not Working

**Problem:** WiFi LED doesn't respond to WiFi status changes

**Cause:** LED GPIO mapping may differ between stock firmware and OpenWrt

**Workaround:**
```bash
# Manual LED control via script
# Create /etc/hotplug.d/iface/99-wifi-led

#!/bin/sh
[ "$INTERFACE" = "wlan0" ] || exit 0

if [ "$ACTION" = "ifup" ]; then
    echo 1 > /sys/class/leds/wifi/brightness
elif [ "$ACTION" = "ifdown" ]; then
    echo 0 > /sys/class/leds/wifi/brightness
fi
```

**Or disable LED:**
```bash
echo 0 > /sys/class/leds/wifi/brightness
```

### 2. Modem APN Lock

**See [Modem Configuration](#modem-configuration) section for workarounds.**

### 3. GPIO5 Hardware Reset

**Problem:** GPIO5 acts as hardware reset, not just modem reset

**Behavior:**
- Triggering GPIO5 may reset entire router
- Not suitable for modem-only reset

**Workaround:**
- Avoid using GPIO5 for modem control
- Use AT commands for modem reset instead

**Modem reset via AT:**
```bash
echo "AT+CFUN=1,1" > /dev/ttyUSB1
```

### 4. USB Issues

**Some users report USB port not working properly in OpenWrt**

**Troubleshooting:**
```bash
# Check USB kernel modules
lsmod | grep usb

# Check USB devices
lsusb

# Install USB storage support
opkg install kmod-usb-storage kmod-fs-ext4
```

---

## Recovery Procedures

### Scenario 1: OpenWrt Boots But Not Working

**Solution: Reflash OpenWrt**

```bash
# Boot to OpenWrt (even if not working properly)
# Transfer sysupgrade image
scp openwrt-*-sysupgrade.bin root@192.168.1.1:/tmp/

# Reflash
sysupgrade -n /tmp/openwrt-*-sysupgrade.bin
```

### Scenario 2: Cannot Boot OpenWrt

**Solution: TFTP Recovery or Serial Console**

**Via TFTP:**
1. Enter TFTP recovery mode (reset button method)
2. Upload stock firmware or OpenWrt via TFTP
3. Router should flash and boot

**Via Serial Console:**
1. Access bootloader
2. Load initramfs via TFTP
3. Boot from RAM
4. Reflash firmware

### Scenario 3: Restore Original Firmware

**Prerequisites:**
- Backup of original firmware (from [Backup](#backup-original-firmware) section)
- Serial console access or TFTP recovery mode

**Via Serial Console:**
```bash
# In bootloader
setenv ipaddr 192.168.1.1
setenv serverip 192.168.1.100

# For each partition backup (example for kernel):
tftpboot 0x81000000 mtd9_backup
nand erase.part kernel
nand write 0x81000000 kernel ${filesize}

# Repeat for rootfs and other modified partitions
# Reboot
reset
```

**Important:** Only restore partitions that were modified. Do NOT restore u-boot unless absolutely necessary.

### Scenario 4: Complete Brick

**If bootloader is corrupted or serial console not responding:**

**Recovery options:**
1. **JTAG recovery** - Requires JTAG adapter and advanced knowledge
2. **SPI/NAND programmer** - De-solder flash chip, program externally
3. **Professional repair** - Send to specialist
4. **Mainboard replacement** - If available

**Prevention:**
- Never flash bootloader unless necessary
- Always backup before modifications
- Use stable power supply during flashing
- Double-check partition numbers before writing

---

## Troubleshooting

### Cannot Access Web Interface

**Check network connection:**
```bash
# Ping router
ping 192.168.1.1

# Check if uhttpd is running
ssh root@192.168.1.1
ps | grep uhttpd

# Restart web server
/etc/init.d/uhttpd restart
```

### Modem Not Detected

**Check QMI device:**
```bash
ls -l /dev/cdc-wdm*

# If missing, check USB
lsusb | grep -i qualcomm

# Install QMI tools
opkg update
opkg install kmod-usb-net-qmi-wwan uqmi
reboot
```

### WiFi Not Working

**Check radio status:**
```bash
wifi status

# Enable radios
uci set wireless.radio0.disabled='0'
uci set wireless.radio1.disabled='0'
uci commit wireless
wifi reload
```

### Serial Console Issues

**Common problems:**

1. **No output** - Check baud rate (try 9600, 115200)
2. **Garbled text** - Wrong baud rate or flow control
3. **Cannot login** - Password may be set, try from stock firmware backup
4. **TX/RX swapped** - Reverse connections

### TFTP Not Working

**Verify setup:**
```bash
# On computer
sudo netstat -an | grep :69  # TFTP port

# Test TFTP from another computer
tftp 192.168.1.22
> get test.txt
```

**Check firewall:**
```bash
# Temporarily disable firewall
sudo ufw disable
# Or allow TFTP
sudo ufw allow 69/udp
```

---

## Resources

### Official Documentation

- **OpenWrt Wiki:** https://openwrt.org/ (check for MF286 device page)
- **Forums:** https://forum.openwrt.org/

### Community Resources

- **Firmware Repository:** dl.eko.one.pl/firmware/
- **Backups:** dl.eko.one.pl/orig/zte_mf286/
- **Polish Forum:** https://eko.one.pl/forum/viewtopic.php?id=21845
  - Active community
  - Troubleshooting help
  - Firmware updates

### Related Guides

- **OPENWRT_ZTE_MF286D_GUIDE.md** - Similar device (MF286D variant)
- **OPENWRT_EASYCONFIG_GUIDE.md** - Simplified modem management
- **OPENWRT_FAILOVER_GUIDE.md** - Multi-WAN setup
- **OPENWRT_CONFIGURATION_GUIDE.md** - General configuration

---

## Important Notes

### Device Variants

**Always verify your exact device model:**
- MF286 vs MF286A - Different hardware
- Carrier-specific variants - Different firmware
- Regional differences - Different LTE bands

### Backup Importance

**Cannot be overstated:**
- Stock firmware not publicly available
- Recovery requires your backup
- Backup ALL partitions before modifying
- Store multiple copies in safe locations

### Community Support

**Active community at eko.one.pl forums:**
- Polish language primarily
- Helpful community members
- Firmware testing and development
- Troubleshooting assistance

---

## Disclaimer

**This guide is provided "as-is" without warranty.**

- Installing OpenWrt voids manufacturer warranty
- Incorrect installation can permanently damage device
- Author and contributors not responsible for bricked devices
- Backup original firmware before proceeding
- Advanced technical knowledge required
- Proceed at your own risk

**Recommended:**
- Read entire guide before starting
- Understand each step
- Have backup plan
- Ask for help in community forums if uncertain

---

**Document Version:** 1.0
**Last Updated:** 2025-10-25
**Based on:** https://eko.one.pl/forum/viewtopic.php?id=21845 (community forum thread)
**License:** CC BY-SA 4.0
**Difficulty Level:** Advanced
**Estimated Time:** 2-4 hours (first time)
**Success Rate:** High (if followed carefully with proper backups)
