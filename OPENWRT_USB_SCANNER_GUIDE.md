# OpenWRT USB Scanner Guide: Network Scanner for Seniors

## Table of Contents
1. [Overview](#overview)
2. [Hardware Requirements](#hardware-requirements)
3. [Software Requirements](#software-requirements)
4. [Installation Steps](#installation-steps)
5. [Configuration](#configuration)
6. [Script Implementation](#script-implementation)
7. [Troubleshooting](#troubleshooting)
8. [Use Cases](#use-cases)

---

## Overview

This guide demonstrates how to transform an old USB scanner into a network-attached scanning solution using an OpenWRT router. The system is designed for elderly users or anyone who wants a simple, push-button scanning experience without needing a computer.

### Key Features
- **Simple Operation**: Press a number on a USB keypad to scan and categorize documents
- **Network Storage**: Automatically uploads scans to a network file server
- **Categorized Filing**: Different keys map to different document categories
- **Timestamped Files**: Automatic file naming with date/time stamps
- **No Computer Required**: Complete scanning workflow runs on the router

### Architecture
```
[Scanner] ---USB---> [OpenWRT Router] <---USB--- [Numeric Keypad]
                            |
                         Network
                            |
                     [Network Storage]
```

---

## Hardware Requirements

### Essential Components
1. **USB Scanner**
   - Must be supported by SANE (Scanner Access Now Easy)
   - Tested with: Canon CanoScan LIDE 30
   - Other SANE-compatible scanners should work

2. **OpenWRT Router**
   - USB port(s) for scanner and keyboard
   - Sufficient storage for packages (recommend 16MB+ free space)
   - Adequate RAM (recommend 128MB+ for xsane)
   - Tested devices: GL.iNet routers, TP-Link routers with USB

3. **USB Numeric Keypad**
   - Standard USB HID keyboard/numpad
   - 10-key layout recommended for document categories
   - Any USB keyboard will work

4. **Network Storage**
   - SMB/CIFS file share (NAS, Windows share, Samba server)
   - FTP server (alternative storage option)
   - Cloud storage (with appropriate tools)

---

## Software Requirements

### Required OpenWRT Packages

```bash
# USB HID support for keyboard
opkg install kmod-usb-hid

# Scanner support
opkg install sane-backends
opkg install sane-frontends
opkg install xsane

# Keypress detection daemon
opkg install triggerhappy

# Network file system support
opkg install kmod-fs-cifs
opkg install cifs-utils

# Additional utilities
opkg install bash
opkg install coreutils-date
```

### Optional Packages
```bash
# For image processing
opkg install imagemagick

# For FTP upload
opkg install curl

# For email notifications
opkg install msmtp
```

---

## Installation Steps

### Step 1: Update Package Lists
```bash
opkg update
```

### Step 2: Install USB HID Support
```bash
opkg install kmod-usb-hid
```

**Verify keyboard detection:**
```bash
# Plug in USB keyboard
dmesg | tail -20
# Should see: "USB HID core driver" and "input: USB Keyboard"

# Check input devices
ls -l /dev/input/
# Should show event0, event1, etc.
```

### Step 3: Install Scanner Packages
```bash
opkg install sane-backends sane-frontends xsane
```

**Test scanner detection:**
```bash
# List detected scanners
scanimage -L

# Expected output:
# device `plustek:libusb:001:002' is a Canon CanoScan N650U/N656U/LiDE30 flatbed scanner
```

### Step 4: Install Triggerhappy
```bash
opkg install triggerhappy

# Enable and start service
/etc/init.d/triggerhappy enable
/etc/init.d/triggerhappy start
```

### Step 5: Install Network Storage Support
```bash
opkg install kmod-fs-cifs cifs-utils
```

---

## Configuration

### 1. Create Mount Point for Network Storage

```bash
# Create mount directory
mkdir -p /mnt/homenas

# Test manual mount (replace with your NAS details)
mount -t cifs //192.168.1.100/scans /mnt/homenas \
  -o username=scanner,password=yourpass,iocharset=utf8

# Verify mount
df -h | grep homenas
```

**Add to `/etc/fstab` for automatic mounting:**
```bash
cat >> /etc/fstab << 'EOF'
//192.168.1.100/scans /mnt/homenas cifs username=scanner,password=yourpass,iocharset=utf8,_netdev 0 0
EOF
```

### 2. Create Scan Scripts Directory

```bash
mkdir -p /root/scan-scripts
cd /root/scan-scripts
```

### 3. Create Master Scan Script

Create `/root/scan-scripts/scan-document.sh`:

```bash
#!/bin/bash

# Configuration
CATEGORY="$1"
SCAN_DIR="/mnt/homenas/Scans"
TEMP_DIR="/tmp/scan"
LOCK_FILE="/tmp/scan.lock"

# Scanner settings
DPI=300
FORMAT="jpeg"
QUALITY=90

# Function to check if scan is already running
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        echo "Scan already in progress"
        exit 1
    fi
}

# Function to create lock
create_lock() {
    touch "$LOCK_FILE"
}

# Function to remove lock
remove_lock() {
    rm -f "$LOCK_FILE"
}

# Function to mount network share
mount_network() {
    if ! mountpoint -q /mnt/homenas; then
        mount /mnt/homenas
        sleep 2
    fi
}

# Function to generate filename
generate_filename() {
    local category="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    echo "${category}_${timestamp}.jpg"
}

# Function to perform scan
perform_scan() {
    local output_file="$1"

    mkdir -p "$TEMP_DIR"

    # Scan document
    scanimage \
        --format="$FORMAT" \
        --resolution="$DPI" \
        --mode=Color \
        > "$TEMP_DIR/temp.jpg"

    # Optional: Convert/optimize image
    # convert "$TEMP_DIR/temp.jpg" -quality "$QUALITY" "$output_file"

    # Move to final location
    mv "$TEMP_DIR/temp.jpg" "$output_file"
}

# Main script
main() {
    check_lock
    create_lock

    # Mount network share
    mount_network

    # Create category directory
    CATEGORY_DIR="$SCAN_DIR/$CATEGORY"
    mkdir -p "$CATEGORY_DIR"

    # Generate filename
    FILENAME=$(generate_filename "$CATEGORY")
    OUTPUT_FILE="$CATEGORY_DIR/$FILENAME"

    # Perform scan
    echo "Scanning to: $OUTPUT_FILE"
    perform_scan "$OUTPUT_FILE"

    # Cleanup
    rm -rf "$TEMP_DIR"
    remove_lock

    echo "Scan complete: $FILENAME"
}

# Run main function
main
```

Make it executable:
```bash
chmod +x /root/scan-scripts/scan-document.sh
```

### 4. Create Category-Specific Scripts

Create individual scripts for each category:

**Medical documents (Key 1):**
```bash
cat > /root/scan-scripts/scan-medical.sh << 'EOF'
#!/bin/bash
/root/scan-scripts/scan-document.sh "Medical"
EOF
chmod +x /root/scan-scripts/scan-medical.sh
```

**Insurance documents (Key 2):**
```bash
cat > /root/scan-scripts/scan-insurance.sh << 'EOF'
#!/bin/bash
/root/scan-scripts/scan-document.sh "Insurance"
EOF
chmod +x /root/scan-scripts/scan-insurance.sh
```

**Utilities/Bills (Key 3):**
```bash
cat > /root/scan-scripts/scan-utilities.sh << 'EOF'
#!/bin/bash
/root/scan-scripts/scan-document.sh "Utilities"
EOF
chmod +x /root/scan-scripts/scan-utilities.sh
```

**Banking (Key 4):**
```bash
cat > /root/scan-scripts/scan-banking.sh << 'EOF'
#!/bin/bash
/root/scan-scripts/scan-document.sh "Banking"
EOF
chmod +x /root/scan-scripts/scan-banking.sh
```

**Legal (Key 5):**
```bash
cat > /root/scan-scripts/scan-legal.sh << 'EOF'
#!/bin/bash
/root/scan-scripts/scan-document.sh "Legal"
EOF
chmod +x /root/scan-scripts/scan-legal.sh
```

**Receipts (Key 6):**
```bash
cat > /root/scan-scripts/scan-receipts.sh << 'EOF'
#!/bin/bash
/root/scan-scripts/scan-document.sh "Receipts"
EOF
chmod +x /root/scan-scripts/scan-receipts.sh
```

**Personal (Key 7):**
```bash
cat > /root/scan-scripts/scan-personal.sh << 'EOF'
#!/bin/bash
/root/scan-scripts/scan-document.sh "Personal"
EOF
chmod +x /root/scan-scripts/scan-personal.sh
```

**Miscellaneous (Enter key):**
```bash
cat > /root/scan-scripts/scan-misc.sh << 'EOF'
#!/bin/bash
/root/scan-scripts/scan-document.sh "Miscellaneous"
EOF
chmod +x /root/scan-scripts/scan-misc.sh
```

### 5. Configure Triggerhappy

Edit `/etc/triggerhappy/triggers.d/scanner.conf`:

```bash
cat > /etc/triggerhappy/triggers.d/scanner.conf << 'EOF'
# USB Numeric Keypad Scanner Controls

# Number keys for categories
KEY_KP1    1    /root/scan-scripts/scan-medical.sh
KEY_KP2    1    /root/scan-scripts/scan-insurance.sh
KEY_KP3    1    /root/scan-scripts/scan-utilities.sh
KEY_KP4    1    /root/scan-scripts/scan-banking.sh
KEY_KP5    1    /root/scan-scripts/scan-legal.sh
KEY_KP6    1    /root/scan-scripts/scan-receipts.sh
KEY_KP7    1    /root/scan-scripts/scan-personal.sh

# Enter key for miscellaneous
KEY_KPENTER    1    /root/scan-scripts/scan-misc.sh

# Alternative: regular number keys if not using numpad
KEY_1    1    /root/scan-scripts/scan-medical.sh
KEY_2    1    /root/scan-scripts/scan-insurance.sh
KEY_3    1    /root/scan-scripts/scan-utilities.sh
KEY_4    1    /root/scan-scripts/scan-banking.sh
KEY_5    1    /root/scan-scripts/scan-legal.sh
KEY_6    1    /root/scan-scripts/scan-receipts.sh
KEY_7    1    /root/scan-scripts/scan-personal.sh
KEY_ENTER    1    /root/scan-scripts/scan-misc.sh
EOF
```

**Restart triggerhappy:**
```bash
/etc/init.d/triggerhappy restart
```

### 6. Find Keyboard Event Codes (Optional)

If you need to find the correct key codes for your keyboard:

```bash
# Install evtest
opkg install evtest

# List input devices
evtest

# Select your keyboard device (usually /dev/input/event0)
# Press keys to see their codes

# Common key codes:
# KEY_KP1 to KEY_KP9 = Numpad 1-9
# KEY_KP0 = Numpad 0
# KEY_KPENTER = Numpad Enter
# KEY_1 to KEY_9 = Regular number keys
```

---

## Script Implementation

### Advanced Master Script with Features

Here's an enhanced version with LED feedback, error handling, and logging:

```bash
#!/bin/bash
# Enhanced scan-document.sh

# Configuration
CATEGORY="$1"
SCAN_DIR="/mnt/homenas/Scans"
TEMP_DIR="/tmp/scan"
LOCK_FILE="/tmp/scan.lock"
LOG_FILE="/var/log/scanner.log"

# Scanner settings
DPI=300
FORMAT="jpeg"
QUALITY=90
MODE="Color"  # Options: Color, Gray, Lineart

# Notification settings
BEEP_ENABLED=1
LED_ENABLED=1

# Functions
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

beep() {
    if [ "$BEEP_ENABLED" = "1" ]; then
        echo -e '\a'
    fi
}

led_on() {
    if [ "$LED_ENABLED" = "1" ] && [ -f /sys/class/leds/gl-connect:green/brightness ]; then
        echo 1 > /sys/class/leds/gl-connect:green/brightness
    fi
}

led_off() {
    if [ "$LED_ENABLED" = "1" ] && [ -f /sys/class/leds/gl-connect:green/brightness ]; then
        echo 0 > /sys/class/leds/gl-connect:green/brightness
    fi
}

blink_led() {
    for i in {1..3}; do
        led_on
        sleep 0.2
        led_off
        sleep 0.2
    done
}

check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        log_message "ERROR: Scan already in progress"
        beep
        return 1
    fi
    return 0
}

create_lock() {
    echo $$ > "$LOCK_FILE"
}

remove_lock() {
    rm -f "$LOCK_FILE"
}

check_scanner() {
    if ! scanimage -L | grep -q "device"; then
        log_message "ERROR: No scanner detected"
        blink_led
        return 1
    fi
    return 0
}

mount_network() {
    if ! mountpoint -q /mnt/homenas; then
        log_message "Mounting network storage..."
        mount /mnt/homenas
        sleep 2
        if ! mountpoint -q /mnt/homenas; then
            log_message "ERROR: Failed to mount network storage"
            blink_led
            return 1
        fi
    fi
    return 0
}

generate_filename() {
    local category="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    echo "${category}_${timestamp}.jpg"
}

perform_scan() {
    local output_file="$1"

    mkdir -p "$TEMP_DIR"

    log_message "Starting scan: $output_file"
    led_on

    # Perform scan
    if scanimage \
        --format="$FORMAT" \
        --resolution="$DPI" \
        --mode="$MODE" \
        > "$TEMP_DIR/temp.$FORMAT" 2>> "$LOG_FILE"; then

        # Move to final location
        mv "$TEMP_DIR/temp.$FORMAT" "$output_file"
        log_message "Scan successful: $output_file"
        led_off
        beep
        return 0
    else
        log_message "ERROR: Scan failed"
        led_off
        blink_led
        return 1
    fi
}

cleanup() {
    rm -rf "$TEMP_DIR"
    remove_lock
    led_off
}

# Main script
main() {
    # Trap to ensure cleanup on exit
    trap cleanup EXIT INT TERM

    log_message "=== Scan initiated for category: $CATEGORY ==="

    # Check if scan already running
    if ! check_lock; then
        exit 1
    fi

    create_lock

    # Check scanner
    if ! check_scanner; then
        exit 1
    fi

    # Mount network share
    if ! mount_network; then
        exit 1
    fi

    # Create category directory
    CATEGORY_DIR="$SCAN_DIR/$CATEGORY"
    mkdir -p "$CATEGORY_DIR"

    # Generate filename
    FILENAME=$(generate_filename "$CATEGORY")
    OUTPUT_FILE="$CATEGORY_DIR/$FILENAME"

    # Perform scan
    if perform_scan "$OUTPUT_FILE"; then
        log_message "=== Scan completed successfully: $FILENAME ==="
    else
        log_message "=== Scan failed ==="
        exit 1
    fi
}

# Run main function
main
```

### Test Script

Create a test script to verify everything works:

```bash
cat > /root/scan-scripts/test-scan.sh << 'EOF'
#!/bin/bash

echo "=== Scanner Test Script ==="

# Test 1: Check scanner detection
echo -n "1. Checking scanner detection... "
if scanimage -L | grep -q "device"; then
    echo "OK"
else
    echo "FAILED - No scanner detected"
    exit 1
fi

# Test 2: Check network mount
echo -n "2. Checking network mount... "
if mountpoint -q /mnt/homenas || mount /mnt/homenas 2>/dev/null; then
    echo "OK"
else
    echo "FAILED - Cannot mount network storage"
    exit 1
fi

# Test 3: Check write permissions
echo -n "3. Checking write permissions... "
if touch /mnt/homenas/test.txt 2>/dev/null; then
    rm /mnt/homenas/test.txt
    echo "OK"
else
    echo "FAILED - No write permission"
    exit 1
fi

# Test 4: Perform test scan
echo -n "4. Performing test scan... "
if scanimage --format=jpeg --resolution=150 > /tmp/test-scan.jpg 2>/dev/null; then
    if [ -s /tmp/test-scan.jpg ]; then
        rm /tmp/test-scan.jpg
        echo "OK"
    else
        echo "FAILED - Empty scan file"
        exit 1
    fi
else
    echo "FAILED - Scan error"
    exit 1
fi

echo ""
echo "=== All tests passed! ==="
echo "System is ready for use."
EOF

chmod +x /root/scan-scripts/test-scan.sh
```

---

## Troubleshooting

### Scanner Not Detected

**Check USB connection:**
```bash
lsusb
# Should show your scanner

dmesg | grep -i scanner
dmesg | grep -i usb
```

**Check SANE backends:**
```bash
scanimage -L

# If no devices found, check supported devices
less /etc/sane.d/dll.conf

# Enable your scanner backend (e.g., plustek)
echo "plustek" >> /etc/sane.d/dll.conf
```

**Check permissions:**
```bash
ls -l /dev/bus/usb/*/*
# Should show accessible USB devices
```

### Keyboard Not Working

**Check USB HID module:**
```bash
lsmod | grep hid
# Should show: usbhid, hid

# If not loaded
insmod usbhid
```

**Check input devices:**
```bash
ls -l /dev/input/
cat /dev/input/event0  # Press keys, should see output
```

**Check triggerhappy:**
```bash
/etc/init.d/triggerhappy status

# View logs
logread | grep triggerhappy

# Test manually
thd --dump /dev/input/event*
# Press keys, should see key codes
```

### Network Mount Issues

**Test mount manually:**
```bash
# Unmount if mounted
umount /mnt/homenas

# Mount with verbose output
mount -t cifs //192.168.1.100/scans /mnt/homenas \
  -o username=scanner,password=yourpass,iocharset=utf8,vers=3.0 -v
```

**Check network connectivity:**
```bash
ping 192.168.1.100

# Test SMB connection
smbclient //192.168.1.100/scans -U scanner
```

**Check logs:**
```bash
logread | grep cifs
dmesg | grep -i cifs
```

### Scanning Errors

**Test scanner manually:**
```bash
# List devices
scanimage -L

# Test scan to file
scanimage --format=jpeg > /tmp/test.jpg

# Check file
ls -lh /tmp/test.jpg
```

**Adjust scanner settings:**
```bash
# List all options for your scanner
scanimage -A

# Try different modes
scanimage --mode Gray > /tmp/test-gray.jpg
scanimage --resolution 150 > /tmp/test-150dpi.jpg
```

**Check permissions and space:**
```bash
df -h /tmp
df -h /mnt/homenas

ls -la /root/scan-scripts/
```

### LED/Beep Not Working

**Find LED paths:**
```bash
ls -l /sys/class/leds/

# Try different LEDs
echo 1 > /sys/class/leds/*/brightness
```

**Enable beep:**
```bash
# Install beep utility
opkg install beep

# Use in script instead of echo -e '\a'
beep -f 1000 -l 100
```

---

## Use Cases

### 1. Medical Document Management for Seniors

**Setup:**
- Key 1: Medical reports
- Key 2: Prescriptions
- Key 3: Insurance claims
- Key 4: Medical bills

**Benefits:**
- Elderly parents can scan documents without computer knowledge
- Automatic organization by category
- Family members can access scans remotely from NAS
- Timestamped files prevent confusion

### 2. Small Office Document Archival

**Setup:**
- Key 1: Invoices
- Key 2: Contracts
- Key 3: Correspondence
- Key 4: Receipts
- Key 5: Legal documents

**Benefits:**
- No dedicated scanning computer needed
- Immediate upload to company NAS
- Consistent file naming
- Easy integration with document management systems

### 3. Home Document Organization

**Setup:**
- Key 1: Bills/Utilities
- Key 2: Warranties
- Key 3: Receipts
- Key 4: Tax documents
- Key 5: Personal ID copies

**Benefits:**
- Digital backup of important documents
- Searchable file names
- Accessible from any device on network
- Space-saving alternative to filing cabinets

### 4. Library/Archive Digitization

**Setup:**
- Multiple keys for different collections
- Higher DPI settings for archival quality
- Direct upload to archive server

**Benefits:**
- Simple workflow for volunteers
- Consistent quality settings
- Automatic cataloging by collection
- Network-accessible archive

---

## Advanced Features

### Email Notifications

Add email notification to scan script:

```bash
# Install msmtp
opkg install msmtp msmtp-scripts

# Configure /etc/msmtprc
cat > /etc/msmtprc << 'EOF'
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        gmail
host           smtp.gmail.com
port           587
from           scanner@yourdomain.com
user           your-email@gmail.com
password       your-app-password

account default : gmail
EOF

chmod 600 /etc/msmtprc

# Add to scan script
send_notification() {
    local category="$1"
    local filename="$2"

    echo "Subject: Scan Complete: $category

A document has been scanned and saved:
Category: $category
Filename: $filename
Time: $(date)

Location: $SCAN_DIR/$category/$filename" | msmtp recipient@example.com
}

# Call in main function after successful scan
send_notification "$CATEGORY" "$FILENAME"
```

### OCR Processing

Add optical character recognition:

```bash
# Install tesseract
opkg install tesseract

# Add to scan script
perform_ocr() {
    local image_file="$1"
    local text_file="${image_file%.jpg}.txt"

    tesseract "$image_file" "${text_file%.txt}" -l eng

    if [ -f "$text_file" ]; then
        log_message "OCR completed: $text_file"
    fi
}

# Call after scan
perform_ocr "$OUTPUT_FILE"
```

### Web Interface

Create simple web interface using lighttpd and CGI:

```bash
# Install web server
opkg install lighttpd lighttpd-mod-cgi

# Create web directory
mkdir -p /www/scanner

# Create index page
cat > /www/scanner/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Network Scanner</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .button {
            padding: 20px 40px;
            margin: 10px;
            font-size: 18px;
            cursor: pointer;
        }
    </style>
</head>
<body>
    <h1>Network Scanner</h1>
    <form action="/cgi-bin/scan.sh" method="post">
        <button class="button" name="category" value="Medical">1 - Medical</button>
        <button class="button" name="category" value="Insurance">2 - Insurance</button>
        <button class="button" name="category" value="Utilities">3 - Utilities</button>
        <button class="button" name="category" value="Banking">4 - Banking</button>
        <button class="button" name="category" value="Legal">5 - Legal</button>
        <button class="button" name="category" value="Receipts">6 - Receipts</button>
        <button class="button" name="category" value="Personal">7 - Personal</button>
        <button class="button" name="category" value="Miscellaneous">Enter - Misc</button>
    </form>

    <h2>Recent Scans</h2>
    <iframe src="/cgi-bin/list-scans.sh" width="100%" height="400"></iframe>
</body>
</html>
EOF

# Create scan CGI script
cat > /www/cgi-bin/scan.sh << 'EOF'
#!/bin/sh
echo "Content-type: text/html"
echo ""

# Parse POST data
read POST_DATA
CATEGORY=$(echo "$POST_DATA" | sed 's/.*category=\([^&]*\).*/\1/')

echo "<html><body>"
echo "<h1>Scanning...</h1>"
echo "<p>Category: $CATEGORY</p>"

/root/scan-scripts/scan-document.sh "$CATEGORY" &

echo "<p>Scan initiated. Please wait...</p>"
echo "<p><a href='/scanner/'>Back to Scanner</a></p>"
echo "</body></html>"
EOF

chmod +x /www/cgi-bin/scan.sh
```

### Automatic Document Routing

Route scans to different destinations based on content detection:

```bash
# Install imagemagick for text detection
opkg install imagemagick tesseract

# Create routing script
cat > /root/scan-scripts/route-document.sh << 'EOF'
#!/bin/bash

IMAGE_FILE="$1"
CATEGORY="General"

# Extract text from image
TEXT=$(tesseract "$IMAGE_FILE" stdout 2>/dev/null)

# Simple keyword routing
if echo "$TEXT" | grep -qi "invoice\|bill"; then
    CATEGORY="Billing"
elif echo "$TEXT" | grep -qi "medical\|prescription\|doctor"; then
    CATEGORY="Medical"
elif echo "$TEXT" | grep -qi "contract\|agreement"; then
    CATEGORY="Legal"
fi

echo "$CATEGORY"
EOF

chmod +x /root/scan-scripts/route-document.sh
```

---

## Security Considerations

### Secure Network Credentials

Store SMB credentials securely:

```bash
# Create credentials file
cat > /root/.smbcredentials << 'EOF'
username=scanner
password=your_secure_password
domain=WORKGROUP
EOF

chmod 600 /root/.smbcredentials

# Update fstab entry
//192.168.1.100/scans /mnt/homenas cifs credentials=/root/.smbcredentials,iocharset=utf8,_netdev 0 0
```

### Restrict Access

Limit scanner access to specific users:

```bash
# Create scanner user
opkg install shadow-useradd
useradd -m -s /bin/sh scanner

# Set permissions
chown -R scanner:scanner /root/scan-scripts
chmod 750 /root/scan-scripts

# Run triggerhappy as scanner user
# Edit /etc/init.d/triggerhappy
# Add: --user scanner
```

### Enable HTTPS for Web Interface

```bash
# Generate SSL certificate
opkg install openssl-util

mkdir -p /etc/lighttpd/certs
openssl req -new -x509 -keyout /etc/lighttpd/certs/server.pem \
  -out /etc/lighttpd/certs/server.pem -days 365 -nodes

# Configure lighttpd for HTTPS
# Edit /etc/lighttpd/lighttpd.conf
server.port = 443
ssl.engine = "enable"
ssl.pemfile = "/etc/lighttpd/certs/server.pem"
```

---

## Performance Optimization

### Reduce Scan Time

```bash
# Lower DPI for faster scans (adjust in scan-document.sh)
DPI=150  # Instead of 300

# Use grayscale for text documents
MODE="Gray"  # Instead of Color

# Reduce JPEG quality
QUALITY=75  # Instead of 90
```

### Optimize Storage

```bash
# Compress scans after upload
compress_scan() {
    local file="$1"
    convert "$file" -quality 70 -resize 70% "$file"
}

# Add to scan script after successful upload
```

### Queue Multiple Scans

```bash
# Create scan queue directory
mkdir -p /tmp/scan-queue

# Modify lock check to queue instead of reject
if [ -f "$LOCK_FILE" ]; then
    # Add to queue
    echo "$CATEGORY" > "/tmp/scan-queue/$(date +%s).queue"
    exit 0
fi

# Add queue processor to main script
process_queue() {
    for queue_file in /tmp/scan-queue/*.queue; do
        if [ -f "$queue_file" ]; then
            category=$(cat "$queue_file")
            rm "$queue_file"
            /root/scan-scripts/scan-document.sh "$category"
        fi
    done
}
```

---

## Maintenance

### Log Rotation

```bash
# Create logrotate config
cat > /etc/logrotate.d/scanner << 'EOF'
/var/log/scanner.log {
    size 1M
    rotate 5
    compress
    missingok
    notifempty
}
EOF
```

### Backup Configuration

```bash
# Create backup script
cat > /root/backup-scanner-config.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/mnt/homenas/Scanner-Backups"
BACKUP_FILE="scanner-config-$(date +%Y%m%d).tar.gz"

mkdir -p "$BACKUP_DIR"

tar czf "$BACKUP_DIR/$BACKUP_FILE" \
    /root/scan-scripts/ \
    /etc/triggerhappy/triggers.d/scanner.conf \
    /etc/fstab \
    /root/.smbcredentials

echo "Backup completed: $BACKUP_FILE"
EOF

chmod +x /root/backup-scanner-config.sh

# Add to cron (weekly backup)
echo "0 2 * * 0 /root/backup-scanner-config.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

### Health Monitoring

```bash
# Create health check script
cat > /root/scanner-health-check.sh << 'EOF'
#!/bin/bash

LOG="/var/log/scanner-health.log"

check_scanner() {
    if scanimage -L | grep -q "device"; then
        echo "[$(date)] Scanner: OK" >> "$LOG"
        return 0
    else
        echo "[$(date)] Scanner: FAILED" >> "$LOG"
        return 1
    fi
}

check_network() {
    if mountpoint -q /mnt/homenas; then
        echo "[$(date)] Network: OK" >> "$LOG"
        return 0
    else
        echo "[$(date)] Network: FAILED - Attempting remount" >> "$LOG"
        mount /mnt/homenas
        return $?
    fi
}

check_disk_space() {
    local usage=$(df /tmp | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$usage" -lt 90 ]; then
        echo "[$(date)] Disk: OK ($usage%)" >> "$LOG"
        return 0
    else
        echo "[$(date)] Disk: WARNING ($usage% full)" >> "$LOG"
        return 1
    fi
}

# Run checks
check_scanner
check_network
check_disk_space
EOF

chmod +x /root/scanner-health-check.sh

# Add to cron (hourly checks)
echo "0 * * * * /root/scanner-health-check.sh" >> /etc/crontabs/root
```

---

## Conclusion

This guide provides a complete solution for turning a USB scanner into a network-attached, push-button scanning system using OpenWRT. The system is ideal for:

- Elderly users who need simple document scanning
- Small offices requiring quick document archival
- Home users wanting organized digital document storage
- Any scenario where simplified scanning workflow is beneficial

The modular script design allows easy customization for different use cases, storage backends, and document categories.

### Key Benefits
- ✅ No computer required for scanning
- ✅ Automatic categorization and organization
- ✅ Network storage integration
- ✅ Simple one-button operation
- ✅ Extensible with OCR, email, web interface
- ✅ Low cost using existing hardware

### Further Resources
- SANE Project: http://www.sane-project.org/
- OpenWRT Documentation: https://openwrt.org/docs/
- Triggerhappy: https://github.com/wertarbyte/triggerhappy
- Canon Scanner Support: https://www.canon.com/support

---

## Appendix: Supported Scanners

Common SANE-supported scanners that work well with OpenWRT:

### Canon
- CanoScan LiDE series (20, 25, 30, 35, 40, 50, 60, 70, 80, 90, 100, 110, 120, 200, 210, 220)
- CanoScan N series

### HP
- ScanJet 2400, 3400, 4400
- ScanJet G series
- Many HP All-in-One devices

### Epson
- Perfection V series
- GT series

### Other Brands
- Mustek BearPaw series
- Fujitsu ScanSnap (some models)
- Brother (selected models)

**To check if your scanner is supported:**
```bash
# Visit: http://www.sane-project.org/lists/sane-backends.html
# Or check on OpenWRT after installing sane-backends:
scanimage -L
```

---

*Document Version: 1.0*
*Last Updated: 2025*
*Based on: https://eko.one.pl/forum/viewtopic.php?id=23268*
