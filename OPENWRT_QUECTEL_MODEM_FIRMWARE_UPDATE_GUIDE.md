# OpenWRT Quectel Modem Firmware Update Guide

## Table of Contents
1. [Overview](#overview)
2. [Important Warnings](#important-warnings)
3. [Prerequisites](#prerequisites)
4. [Supported Modem Models](#supported-modem-models)
5. [Firmware Version Identification](#firmware-version-identification)
6. [Firmware Acquisition](#firmware-acquisition)
7. [Preparation](#preparation)
8. [Firmware Update Methods](#firmware-update-methods)
9. [Method 1: QFirehose (Recommended)](#method-1-qfirehose-recommended)
10. [Method 2: AT Commands (Delta Updates)](#method-2-at-commands-delta-updates)
11. [Method 3: EDL Mode (Advanced)](#method-3-edl-mode-advanced)
12. [Post-Update Verification](#post-update-verification)
13. [Troubleshooting](#troubleshooting)
14. [Recovery Procedures](#recovery-procedures)
15. [Best Practices](#best-practices)
16. [References](#references)

---

## Overview

This guide explains how to update firmware on Quectel LTE/5G modems integrated with OpenWRT routers. Firmware updates can improve modem stability, add features, fix bugs, and enhance network compatibility.

**Common Scenarios:**
- Improving network connectivity and stability
- Fixing modem bugs or issues
- Adding support for new cellular bands
- Updating security patches
- Enabling new features

**Applicable Devices:**
- Teltonika RUT950/RUT955 (with Quectel EC25)
- GL.iNet routers with Quectel modems
- Custom OpenWRT builds with embedded Quectel modems
- Routers with USB Quectel modems

**Supported Modem Types:**
- EC25 (LTE Cat 4)
- EC21 (LTE Cat 1)
- EP06 (LTE Cat 6)
- EM12 (LTE Cat 12)
- RM500Q (5G)
- And other Quectel cellular modules

---

## Important Warnings

### ⚠️ CRITICAL SAFETY INFORMATION

**READ BEFORE PROCEEDING:**

1. **⚠️ BRICK RISK - Soldered Modems**
   - If modem is soldered to motherboard (e.g., Teltonika RUT devices), firmware failure may result in **permanent device damage**
   - Recovery from failed flash on soldered modem requires specialized equipment (JTAG, EDL cables)
   - Consider risk vs. benefit before updating

2. **⚠️ NO DOWNGRADE**
   - Newer Quectel firmware versions **cannot be downgraded**
   - Once updated, you cannot revert to older firmware
   - Ensure compatibility before updating

3. **⚠️ FIRMWARE VARIANT CRITICAL**
   - Use **exact** firmware variant for your hardware
   - Example: EC25EFA vs EC25EFAR vs EC25EUXGA - each is different
   - Wrong variant = bricked modem
   - Verify your modem's exact model designation

4. **⚠️ STABLE POWER REQUIRED**
   - Use UPS or stable power source
   - Power loss during update = bricked modem
   - Ensure battery backup for portable devices

5. **⚠️ LOCAL UPDATE ONLY**
   - **Never** update remotely over WAN/cellular connection
   - Always perform updates via **local wired LAN connection**
   - Physical access to device required in case of failure

6. **⚠️ BACKUP EVERYTHING**
   - Full router configuration backup
   - Document current modem firmware version
   - Save modem configuration (if applicable)

**Proceed only if you:**
- ✓ Have correct firmware variant
- ✓ Accept risk of device damage
- ✓ Have stable power and local access
- ✓ Have backup router (if this is your primary internet)

---

## Prerequisites

### Hardware Requirements

**Router:**
- OpenWRT-compatible device with Quectel modem
- Sufficient RAM (128MB+ recommended)
- Available storage (100-200MB for firmware files)
- USB port or embedded modem

**Power:**
- Stable power source (UPS recommended)
- For portable devices: fully charged battery

**Network:**
- Local LAN connection (SSH access)
- Internet access for downloading tools (if not pre-staged)

### Software Requirements

**Packages needed:**
```bash
opkg update
opkg install sms-tool     # For AT commands
opkg install qfirehose    # For firmware flashing (if available)
opkg install sshfs        # For network file sharing (optional)
opkg install kmod-usb-storage  # For USB storage (optional)
```

**Note on qfirehose:**
- Removed from official OpenWRT repositories due to licensing restrictions
- May need to install from alternative sources or compile from source
- Alternative: Use AT command update method

### Storage for Firmware Files

**Options:**

1. **USB Storage:**
   - USB flash drive or external HDD
   - Minimum 256MB free space
   - Formatted as FAT32, ext4, or NTFS

2. **Network Share (SSHFS):**
   - Computer on LAN with firmware files
   - SSH server running
   - Network connectivity

3. **Router Internal Storage:**
   - If sufficient space available (rare on embedded devices)
   - Not recommended due to limited space

---

## Supported Modem Models

### Quectel LTE Modems

**EC25 Series (LTE Cat 4):**
- EC25-E (Europe)
- EC25-A (Americas)
- EC25-AU (Australia)
- EC25-J (Japan)
- Variants: EFA, EFAR, EUXGA, etc.

**EC21 Series (LTE Cat 1):**
- EC21-E (Europe)
- EC21-A (Americas)
- Lower power consumption

**EP06 Series (LTE Cat 6):**
- EP06-E (Europe)
- EP06-A (Americas)
- Faster speeds than EC25

**EM12 Series (LTE Cat 12):**
- EM12-G (Global)
- High-speed LTE

### Quectel 5G Modems

**RM500Q Series:**
- RM500Q-GL (Global)
- 5G NR support

**RG500Q Series:**
- Industrial 5G module

---

## Firmware Version Identification

### Check Current Firmware Version

**Method 1: Using AT commands via sms-tool**

```bash
# Install sms-tool if not present
opkg install sms-tool

# Query modem information
sms_tool -d /dev/ttyUSB2 at "ATI"
```

**Example output:**
```
Manufacturer: Quectel
Model: EC25
Revision: EC25EFAR02A08M4G
IMEI: 866425030123456
```

**Understanding revision format:**
- `EC25` - Model
- `EFA` - Hardware variant (CRITICAL - must match firmware)
- `R02` - Revision
- `A08` - Sub-version
- `M4G` - Build type

**Method 2: Using mmcli (if ModemManager installed)**

```bash
mmcli -m 0

# Look for "revision" field
```

**Method 3: Direct AT command**

```bash
# Using echo/cat
echo -e "ATI\r" > /dev/ttyUSB2
cat /dev/ttyUSB2
```

### Identify Required Firmware

**Determine your modem's exact variant:**

1. Check hardware label on modem (if accessible)
2. Use `ATI` command output
3. Check router manufacturer documentation
4. Contact manufacturer support

**Example variants:**
- EC25**EFA** - European variant A
- EC25**EFAR** - European variant A Revised
- EC25**EUXGA** - European UMTS/HSPA+ variant

**⚠️ CRITICAL:** Firmware must match variant **exactly**

---

## Firmware Acquisition

### Official Quectel Sources

**Primary method: Quectel Forum**

1. Register at Quectel forums: https://forums.quectel.com/
2. Request firmware in appropriate section
3. Provide:
   - Exact modem model and variant
   - Current firmware version
   - Reason for update
4. Wait for approval (typical: 1-14 days)
5. Download firmware package

**Direct contact:**
- Email: support@quectel.com
- Include device details and justification

### Community Sources

**⚠️ Use at your own risk**

**eko.one.pl archive (community builds):**
```
https://dl.eko.one.pl/test/quectel/
```

**Contains:**
- Various Quectel firmware versions
- Community-tested builds
- May not be latest versions

**Verification recommended:**
- Check MD5/SHA256 checksums
- Verify firmware variant matches your modem
- Test in non-critical environment first

### Firmware Package Contents

**Typical firmware archive contains:**

```
firmware/
├── firehose/
│   ├── prog_firehose_ddr.mbn
│   └── rawprogram_unsparse.xml
├── partition/
│   ├── NON-HLOS.bin
│   ├── modem.bin
│   └── [other partition files]
├── update/
│   ├── appsboot.mbn
│   ├── boot.img
│   ├── system.img
│   └── [other update files]
└── checksums.md5
```

**Important files:**
- **firehose/**: Low-level flash programmer
- **partition/**: Modem firmware images
- **checksums.md5**: MD5 verification file

---

## Preparation

### Step 1: Backup Current Configuration

**Full router backup:**

```bash
# Backup via LuCI web interface
# System → Backup/Flash Firmware → Generate Archive

# Or via command line
sysupgrade -b /tmp/backup-$(date +%Y%m%d).tar.gz

# Copy backup off router
scp /tmp/backup-*.tar.gz user@pc:/backup/
```

**Document current modem info:**

```bash
sms_tool -d /dev/ttyUSB2 at "ATI" > /tmp/modem_info_before.txt
sms_tool -d /dev/ttyUSB2 at "AT+CGMR" >> /tmp/modem_info_before.txt
sms_tool -d /dev/ttyUSB2 at "AT+QCFG=\"version\"" >> /tmp/modem_info_before.txt

# Copy to PC
scp /tmp/modem_info_before.txt user@pc:/backup/
```

### Step 2: Stop Services Using Modem

**Disable network interfaces:**

```bash
# Stop mobile WAN interface
ifdown wan
ifdown wwan

# Or stop specific mobile interface
ifdown mobile
```

**Stop services:**

```bash
# Stop cron (may have modem-related tasks)
/etc/init.d/cron stop

# Stop SMS daemon (if running)
killall smstools

# Stop ModemManager (if installed)
/etc/init.d/modemmanager stop

# Stop any custom modem scripts
```

**Verify no processes using modem:**

```bash
lsof | grep ttyUSB
# Should return empty

# Kill any processes if found
```

### Step 3: Prepare Firmware Files

**Option A: Using USB storage**

```bash
# Insert USB drive with firmware

# Check device name
ls /dev/sd*
# Example: /dev/sda1

# Mount USB drive
mkdir -p /tmp/firmware
mount /dev/sda1 /tmp/firmware

# Verify firmware files present
ls /tmp/firmware/
```

**Option B: Using network share (SSHFS)**

```bash
# Install sshfs
opkg install sshfs

# Create mount point
mkdir -p /tmp/firmware

# Mount remote directory
sshfs -o allow_other user@192.168.1.100:/path/to/firmware /tmp/firmware/

# Verify
ls /tmp/firmware/
```

**Option C: Download directly to router**

```bash
# Only if sufficient storage
df -h
# Check available space in /tmp

# Download firmware
wget -P /tmp/firmware/ https://example.com/firmware.zip

# Extract
opkg install unzip
cd /tmp/firmware
unzip firmware.zip
```

### Step 4: Verify Firmware Integrity

**Check MD5 checksums:**

```bash
cd /tmp/firmware

# Verify all files
md5sum -c checksums.md5

# Should show "OK" for all files
```

**If checksums fail:**
- Re-download firmware
- Check for corruption
- Do NOT proceed with update

---

## Firmware Update Methods

### Comparison of Methods

| Method | Difficulty | Speed | Risk | Use Case |
|--------|------------|-------|------|----------|
| QFirehose | Easy | Fast | Medium | Full firmware update |
| AT Commands | Medium | Medium | Low | Delta updates, minor versions |
| EDL Mode | Advanced | Fast | High | Recovery, advanced users |

---

## Method 1: QFirehose (Recommended)

### About QFirehose

QFirehose is a tool for flashing Qualcomm-based modems (including Quectel) using the Firehose protocol.

**Advantages:**
- Complete firmware replacement
- MD5 verification built-in
- Relatively safe (compared to manual methods)

**Limitations:**
- Removed from OpenWRT repos (licensing)
- May need manual installation

### Installation

**Check if available:**

```bash
opkg update
opkg install qfirehose
```

**If not available, compile from source:**

```bash
# Install build dependencies
opkg install git-http make gcc

# Clone repository
git clone https://github.com/forth32/qfirehose.git /tmp/qfirehose

# Compile
cd /tmp/qfirehose
make

# Install binary
cp qfirehose /usr/bin/
chmod +x /usr/bin/qfirehose
```

### Firmware Update Procedure

**1. Ensure modem is accessible:**

```bash
ls /dev/ttyUSB*
# Should show ttyUSB0, ttyUSB1, ttyUSB2, etc.
```

**2. Run QFirehose:**

```bash
# Basic usage
qfirehose -f /tmp/firmware/

# With verbose output
qfirehose -v -f /tmp/firmware/

# Specify device (if multiple modems)
qfirehose -d /dev/ttyUSB0 -f /tmp/firmware/
```

**3. Monitor output:**

```
QFirehose v1.4.1
Opening device: /dev/ttyUSB0
Entering download mode...
Sending programmer...
Verifying MD5: firehose/prog_firehose_ddr.mbn ... OK
Verifying MD5: partition/NON-HLOS.bin ... OK
Verifying MD5: partition/modem.bin ... OK
[... continues for all files ...]
Flashing partition: NON-HLOS
Progress: [##########] 100%
Flashing partition: modem
Progress: [##########] 100%
[... continues for all partitions ...]
Resetting modem...
Upgrade module successfully.
```

**4. Wait for completion:**

- Process takes 5-15 minutes
- Do NOT interrupt or power off
- Do NOT disconnect cables

**5. Verify success:**

```bash
# Check for success message
# Expected: "Upgrade module successfully."
```

### Handling Errors

**If timeout occurs:**

```bash
# Retry with longer timeout
qfirehose -t 60 -f /tmp/firmware/
```

**If MD5 verification fails:**

```bash
# Check firmware integrity
md5sum -c /tmp/firmware/checksums.md5

# Re-download firmware if corrupted
```

**If device not found:**

```bash
# Check USB enumeration
lsusb | grep Quectel

# Check tty devices
ls -l /dev/ttyUSB*

# Reload USB serial driver
rmmod option
insmod option
```

---

## Method 2: AT Commands (Delta Updates)

### About AT Command Updates

Some firmware updates can be applied incrementally using AT commands.

**Suitable for:**
- Minor version updates
- Delta/patch updates
- Updates provided as ".bin" or ".zip" files

**Not suitable for:**
- Major version changes
- Full firmware replacement

### Procedure

**1. Transfer firmware file to modem-accessible location:**

```bash
# Copy to /tmp
cp /tmp/firmware/update.bin /tmp/

# Or upload via AT command (for small files)
```

**2. Initiate update via AT commands:**

```bash
# Query update capability
sms_tool -d /dev/ttyUSB2 at "AT+QFOTA=\"query\""

# Set update path
sms_tool -d /dev/ttyUSB2 at "AT+QFOTA=\"update\",\"/tmp/update.bin\""

# Monitor update progress
while true; do
    sms_tool -d /dev/ttyUSB2 at "AT+QFOTA=\"status\""
    sleep 5
done
```

**3. Wait for completion:**

- Modem will reboot automatically
- Takes 5-10 minutes

**4. Verify new version:**

```bash
sms_tool -d /dev/ttyUSB2 at "ATI"
```

---

## Method 3: EDL Mode (Advanced)

### About EDL Mode

Emergency Download Mode (EDL) is a low-level recovery mode for Qualcomm modems.

**⚠️ ADVANCED USERS ONLY**

**When to use:**
- Modem is bricked
- Standard update methods fail
- Recovery from failed update

**Requirements:**
- EDL cable or ability to short test points
- QPST/QFIL software (Windows)
- Deep understanding of Qualcomm flash process

**Procedure:**
1. Enter EDL mode (varies by model - may require hardware modification)
2. Connect to PC running QFIL
3. Load programmer and firmware
4. Flash using Firehose protocol

**Not recommended unless:**
- You have experience with Qualcomm tools
- Modem is already non-functional
- You accept risk of permanent damage

---

## Post-Update Verification

### Check New Firmware Version

```bash
# Query modem info
sms_tool -d /dev/ttyUSB2 at "ATI"

# Expected output shows new version
# Example: EC25EFAR06A08M4G (updated from R02 to R06)
```

### Verify Modem Functionality

**1. Check modem registration:**

```bash
# Check network registration
sms_tool -d /dev/ttyUSB2 at "AT+CREG?"

# Expected: +CREG: 0,1 (registered, home network)
```

**2. Check signal strength:**

```bash
sms_tool -d /dev/ttyUSB2 at "AT+CSQ"

# Expected: +CSQ: 15-31,99 (good signal)
```

**3. Test data connection:**

```bash
# Bring up mobile interface
ifup wan

# Test connectivity
ping -I wwan0 8.8.8.8

# Check IP address
ip addr show wwan0
```

**4. Verify cellular bands:**

```bash
# Query supported bands
sms_tool -d /dev/ttyUSB2 at "AT+QCFG=\"band\""
```

### Document New Configuration

```bash
# Save post-update info
sms_tool -d /dev/ttyUSB2 at "ATI" > /tmp/modem_info_after.txt
sms_tool -d /dev/ttyUSB2 at "AT+QCFG=\"version\"" >> /tmp/modem_info_after.txt

# Compare before/after
diff /tmp/modem_info_before.txt /tmp/modem_info_after.txt
```

---

## Troubleshooting

### Modem Not Responding After Update

**Symptoms:**
- No /dev/ttyUSB* devices
- AT commands timeout
- Modem not enumerated

**Solutions:**

1. **Wait and reboot:**
   ```bash
   # Wait 5 minutes for modem to finish internal setup
   sleep 300

   # Reboot router
   reboot
   ```

2. **Force modem reset:**
   ```bash
   # Hardware reset (if modem has reset pin)
   echo 0 > /sys/class/gpio/gpioXX/value
   sleep 1
   echo 1 > /sys/class/gpio/gpioXX/value
   ```

3. **Check USB enumeration:**
   ```bash
   lsusb
   dmesg | grep -i quectel
   ```

4. **Reload USB drivers:**
   ```bash
   rmmod qmi_wwan option usb_wwan
   modprobe qmi_wwan
   modprobe option
   ```

### Update Failed / Timeout

**Symptoms:**
- QFirehose exits with error
- Timeout during flash
- Partial update

**Solutions:**

1. **Retry with increased timeout:**
   ```bash
   qfirehose -t 120 -f /tmp/firmware/
   ```

2. **Check power stability:**
   - Ensure stable power supply
   - Connect UPS if available

3. **Verify firmware files:**
   ```bash
   md5sum -c /tmp/firmware/checksums.md5
   ```

4. **Try different USB port:**
   - Some ports may have better connectivity

### Wrong Firmware Variant Flashed

**⚠️ CRITICAL SITUATION**

**Symptoms:**
- Modem not working after update
- Wrong bands or functionality
- Error messages

**Solutions:**

1. **Attempt reflash with correct firmware:**
   ```bash
   qfirehose -f /path/to/correct_firmware/
   ```

2. **Try EDL mode recovery:**
   - Requires specialized knowledge
   - See EDL section above

3. **Contact professional:**
   - May require hardware tools
   - Consider replacement if soldered

---

## Recovery Procedures

### Soft Recovery (Modem Responsive)

**If modem responds to AT commands:**

```bash
# Factory reset modem
sms_tool -d /dev/ttyUSB2 at "AT&F"
sms_tool -d /dev/ttyUSB2 at "AT+QPRTPARA=1"

# Reboot modem
sms_tool -d /dev/ttyUSB2 at "AT+CFUN=1,1"
```

### Hard Recovery (EDL Mode)

**⚠️ Last resort for bricked modems**

1. Enter EDL mode (hardware-dependent)
2. Use QFIL (Windows) to reflash
3. Load correct programmer and firmware
4. Flash using Firehose protocol

**Requires:**
- Windows PC
- QPST/QFIL tools
- EDL cable or test point shorting
- Correct firmware package

### Hardware Recovery

**For completely non-responsive modems:**

**USB modems:**
- Can be replaced
- Relatively easy recovery

**Soldered modems:**
- Requires professional tools (JTAG, etc.)
- May require board replacement
- Consider RMA with manufacturer

---

## Best Practices

### Before Update

1. **✓ Verify firmware variant matches exactly**
2. **✓ Read all warnings in this guide**
3. **✓ Backup router configuration**
4. **✓ Document current modem version**
5. **✓ Test firmware on non-critical device first (if possible)**
6. **✓ Ensure stable power (UPS recommended)**
7. **✓ Have local physical access**
8. **✓ Download firmware to USB/PC (not router storage)**

### During Update

1. **✓ Do NOT interrupt process**
2. **✓ Do NOT power off device**
3. **✓ Do NOT disconnect cables**
4. **✓ Monitor update progress**
5. **✓ Wait for completion message**

### After Update

1. **✓ Verify new firmware version**
2. **✓ Test all modem functions**
3. **✓ Document new version**
4. **✓ Monitor stability for 24-48 hours**
5. **✓ Keep old firmware files as backup**

### General Recommendations

1. **Only update if necessary:**
   - Fixing specific bug
   - Adding required feature
   - Security vulnerability
   - "If it ain't broke, don't fix it"

2. **Test in safe environment first:**
   - Non-production device
   - Backup router available

3. **Schedule during maintenance window:**
   - Low-traffic period
   - Have time to troubleshoot

4. **Keep backup connectivity:**
   - Secondary internet connection
   - Backup router ready

---

## References

### Official Documentation
- **Quectel Product Page:** https://www.quectel.com/
- **Quectel Forums:** https://forums.quectel.com/
- **Quectel Support:** support@quectel.com

### Community Resources
- **eko.one.pl Forum:** https://eko.one.pl/forum/viewtopic.php?pid=294381
- **eko.one.pl Firmware Archive:** https://dl.eko.one.pl/test/quectel/
- **OpenWRT Forum:** https://forum.openwrt.org/

### Tools
- **qfirehose:** Qualcomm Firehose flasher
- **sms-tool:** AT command interface
- **QPST/QFIL:** Qualcomm Product Support Tools (Windows)

### Teltonika Specific
- **Teltonika Wiki:** https://wiki.teltonika-networks.com/
- **RUT955 Firmware:** https://teltonika-networks.com/products/routers/rut955

---

## Summary

Updating Quectel modem firmware on OpenWRT requires careful preparation and execution:

**Key Points:**
- **⚠️ High risk** for soldered modems - proceed with extreme caution
- **⚠️ No downgrades** - firmware updates are one-way
- **⚠️ Exact variant match** required - wrong firmware = bricked modem
- **✓ QFirehose recommended** for full updates
- **✓ AT commands** for delta updates
- **✓ Local access required** - never update remotely

**Quick Reference:**

```bash
# Check current version
sms_tool -d /dev/ttyUSB2 at "ATI"

# Prepare
ifdown wan
/etc/init.d/cron stop

# Mount firmware
mount /dev/sda1 /tmp/firmware

# Update
qfirehose -f /tmp/firmware/

# Verify
sms_tool -d /dev/ttyUSB2 at "ATI"
ifup wan
```

**When in doubt:**
- Contact Quectel support
- Ask in community forums
- Test on spare device first
- Consider if update is truly necessary

Firmware updates can improve functionality but carry inherent risks. Proceed carefully and ensure you understand the process fully.

---

*This guide is based on the eko.one.pl forum discussion and Quectel firmware update documentation.*
