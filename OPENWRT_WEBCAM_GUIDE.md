# OpenWRT USB Webcam Integration Guide

## Table of Contents
1. [Overview](#overview)
2. [Use Cases](#use-cases)
3. [Hardware Requirements](#hardware-requirements)
4. [Driver Installation](#driver-installation)
5. [Camera Detection and Verification](#camera-detection-and-verification)
6. [Method 1: Motion (Motion Detection & Recording)](#method-1-motion-motion-detection--recording)
7. [Method 2: mjpg-streamer (Live Streaming)](#method-2-mjpg-streamer-live-streaming)
8. [Method 3: fswebcam (Snapshot/Timelapse)](#method-3-fswebcam-snapshottimelapse)
9. [Advanced Configuration](#advanced-configuration)
10. [Network Access and Security](#network-access-and-security)
11. [Storage Solutions](#storage-solutions)
12. [Performance Optimization](#performance-optimization)
13. [Troubleshooting](#troubleshooting)
14. [Supported Camera Models](#supported-camera-models)
15. [Best Practices](#best-practices)
16. [References](#references)

---

## Overview

This guide demonstrates how to transform an OpenWRT router with USB ports into a network-connected webcam system. By leveraging USB webcam support and various streaming software, you can create a low-cost IP camera solution for home monitoring, security, or timelapse photography.

**Key Features:**
- Live video streaming over network
- Motion detection and recording
- Snapshot capture and timelapse
- Remote access capability
- Minimal hardware requirements
- Low power consumption

**Software Options:**
1. **Motion** - Motion detection, recording, and streaming
2. **mjpg-streamer** - Lightweight MJPEG streaming
3. **fswebcam** - Simple snapshot capture

---

## Use Cases

### Home Security and Monitoring

- Baby monitor
- Pet monitoring
- Home security camera
- Entrance monitoring
- Garage/driveway surveillance

### Timelapse Photography

- Plant growth monitoring
- Construction projects
- Weather observation
- 3D printer monitoring
- Outdoor scenery

### Remote Monitoring

- Server room monitoring
- Equipment status checking
- Environmental monitoring
- Wildlife observation

### Advantages Over Commercial IP Cameras

- **Cost-effective:** Repurpose existing router and webcam
- **Customizable:** Full control over features and behavior
- **No cloud dependency:** Local storage and streaming
- **Privacy:** Data stays on your network
- **Educational:** Learn Linux, networking, and video streaming

---

## Hardware Requirements

### Router Requirements

**Minimum specifications:**
- OpenWRT-compatible router
- USB 2.0 or USB 3.0 port
- 64MB+ RAM (128MB+ recommended)
- 8MB+ flash storage (or external storage)
- CPU: 400MHz+ recommended

**Recommended routers:**
- TP-Link WR1043ND
- TP-Link Archer C7
- Linksys WRT series
- Netgear WNDR3800
- GL.iNet routers

### USB Webcam Requirements

**Supported interfaces:**
- USB 1.1/2.0/3.0 webcams
- UVC (USB Video Class) compatible cameras
- GSPCA-supported cameras

**Recommended specifications:**
- 640x480 (VGA) or higher resolution
- MJPEG hardware compression (reduces CPU load)
- USB powered (no external power needed)

**Tested cameras:**
- Logitech C270/C920
- Microsoft LifeCam
- Generic UVC webcams
- Various GSPCA-compatible models

### Optional Hardware

**USB Storage:**
- USB flash drive or external HDD
- For storing recordings/snapshots
- Minimum 8GB recommended

**USB Hub:**
- If router has only one USB port
- Powered hub recommended for multiple devices

---

## Driver Installation

### Step 1: Update Package Lists

```bash
opkg update
```

### Step 2: Install USB Core Support

```bash
# USB core modules
opkg install kmod-usb-core

# USB 2.0 support (EHCI)
opkg install kmod-usb2

# USB 3.0 support (XHCI) - if applicable
opkg install kmod-usb3

# Video core support
opkg install kmod-video-core
```

### Step 3: Install UVC Driver (Universal)

**For UVC-compatible cameras (most modern webcams):**

```bash
opkg install kmod-video-uvc
```

**UVC advantages:**
- Standardized driver
- Wide camera support
- Automatic detection
- No vendor-specific drivers needed

### Step 4: Install GSPCA Drivers (Alternative)

**For GSPCA-based cameras:**

```bash
# Install GSPCA core
opkg install kmod-video-gspca-core

# Install specific chip driver
opkg install kmod-video-gspca-zc3xx    # Example: ZC3xx chipset
```

**Common GSPCA drivers:**
- `kmod-video-gspca-conex` - Conexant cameras
- `kmod-video-gspca-etoms` - Etoms cameras
- `kmod-video-gspca-mars` - Mars cameras
- `kmod-video-gspca-ov519` - OmniVision OV519
- `kmod-video-gspca-ov534` - OmniVision OV534
- `kmod-video-gspca-pac7311` - PixArt PAC7311
- `kmod-video-gspca-spca500` - SPCA500 series
- `kmod-video-gspca-spca501` - SPCA501 series
- `kmod-video-gspca-spca505` - SPCA505 series
- `kmod-video-gspca-spca508` - SPCA508 series
- `kmod-video-gspca-sunplus` - Sunplus cameras
- `kmod-video-gspca-zc3xx` - ZC3xx chipset

**If unsure which driver to use:**

```bash
# Install all GSPCA drivers
opkg install kmod-video-gspca-*

# Note: This requires significant storage space
```

### Step 5: Verify Installation

```bash
# Check loaded modules
lsmod | grep video

# Expected output:
# videobuf2_core
# videobuf2_memops
# videobuf2_vmalloc
# videodev
# gspca_main (if GSPCA)
# uvcvideo (if UVC)

# Reboot if modules not loaded
reboot
```

---

## Camera Detection and Verification

### Check USB Device Detection

```bash
# List USB devices
lsusb

# Expected output example:
# Bus 001 Device 002: ID 046d:0825 Logitech, Inc. Webcam C270
```

### Check Video Device

```bash
# List video devices
ls -al /dev/video*

# Expected output:
# crw-r--r--    1 root     root       81,   0 Oct 15 14:00 /dev/video0
```

**Device permissions:**
- Character device (`c`)
- Major number: 81
- Minor number: 0 (for /dev/video0)

### Check dmesg for Camera Detection

```bash
dmesg | grep -i video
dmesg | grep -i camera
dmesg | grep -i usb

# Look for messages like:
# uvcvideo: Found UVC 1.00 device <Camera Name> (046d:0825)
# uvcvideo 1-1:1.0: Entity type for entity Processing 2 was not initialized!
# uvcvideo 1-1:1.0: Entity type for entity Camera 1 was not initialized!
# input: UVC Camera (046d:0825) as /devices/platform/...
```

### Test Camera Capabilities

```bash
# Install v4l-utils for advanced testing
opkg install v4l-utils

# List camera capabilities
v4l2-ctl --list-devices

# Show camera formats
v4l2-ctl --list-formats-ext

# Get current settings
v4l2-ctl --all
```

---

## Method 1: Motion (Motion Detection & Recording)

### About Motion

Motion is a feature-rich software for motion detection, video recording, and live streaming.

**Features:**
- Motion detection
- Video recording
- Live streaming (MJPEG)
- Snapshot capture
- Event scripts
- Web control interface

### Installation

```bash
opkg update
opkg install motion
```

### Basic Configuration

**Configuration file:** `/etc/motion.conf`

**Essential settings:**

```bash
# Edit configuration
vi /etc/motion.conf

# Key settings to modify:

# Daemon mode
daemon on

# Video device
videodevice /dev/video0

# Image resolution
width 640
height 480

# Frame rate
framerate 15

# Disable auto brightness (if causing issues)
auto_brightness off

# Live stream settings
stream_port 8081
stream_localhost off
stream_maxrate 15
stream_auth_method 0

# Motion detection
threshold 1500
minimum_motion_frames 1

# Output settings
output_pictures off    # Set to 'on' to save snapshots
output_debug_pictures off

# Target directory for files
target_dir /tmp

# Text overlay
text_right %Y-%m-%d %T
text_changes off
```

### Enable Live Streaming

```bash
# In /etc/motion.conf
stream_localhost off
stream_port 8081
stream_maxrate 15
stream_quality 85
stream_motion off
```

**Access stream:**
```
http://192.168.1.1:8081
```

### Enable Motion Detection and Recording

```bash
# In /etc/motion.conf

# Enable snapshot on motion
output_pictures on

# Save location (use USB storage)
target_dir /mnt/sda1/motion

# Picture settings
picture_output_motion on
picture_type jpeg
picture_quality 85

# Movie settings (requires ffmpeg)
ffmpeg_output_movies on
ffmpeg_video_codec mkv
```

**Note:** Default motion package may not include ffmpeg support. Recordings may be limited to ~3-5 fps snapshots.

### Start Motion

```bash
# Create target directory
mkdir -p /mnt/sda1/motion

# Start motion
motion

# Or use init script
/etc/init.d/motion enable
/etc/init.d/motion start
```

### Motion Configuration File Complete Example

```bash
cat > /etc/motion.conf << 'EOF'
# Motion configuration

daemon on
process_id_file /var/run/motion/motion.pid

videodevice /dev/video0
width 640
height 480
framerate 15
auto_brightness off

threshold 1500
minimum_motion_frames 1
event_gap 60
max_movie_time 0

output_pictures on
output_debug_pictures off
picture_output_motion on
picture_type jpeg
picture_quality 85

target_dir /mnt/sda1/motion
snapshot_interval 0

stream_port 8081
stream_localhost off
stream_maxrate 15
stream_quality 85
stream_motion off
stream_auth_method 0

text_right %Y-%m-%d %T-%q
text_changes off
text_double off

webcontrol_port 8080
webcontrol_localhost off
EOF
```

---

## Method 2: mjpg-streamer (Live Streaming)

### About mjpg-streamer

Lightweight, efficient MJPEG streaming server designed for embedded systems.

**Advantages:**
- Low CPU usage
- Minimal memory footprint
- Fast streaming
- Simple configuration
- Web interface included

### Installation

```bash
opkg update
opkg install mjpg-streamer
```

### Configuration via UCI

**Configuration file:** `/etc/config/mjpg-streamer`

```bash
# Enable mjpg-streamer
uci set mjpg-streamer.core.enabled='1'

# Input settings (UVC camera)
uci set mjpg-streamer.core.input='uvc'
uci set mjpg-streamer.core.device='/dev/video0'
uci set mjpg-streamer.core.resolution='640x480'
uci set mjpg-streamer.core.fps='15'
uci set mjpg-streamer.core.yuv='off'
uci set mjpg-streamer.core.quality='85'

# Output settings (HTTP)
uci set mjpg-streamer.core.port='8080'
uci set mjpg-streamer.core.www='/www/webcam'

# Commit changes
uci commit mjpg-streamer
```

### Manual Configuration File

Edit `/etc/config/mjpg-streamer`:

```bash
config mjpg-streamer 'core'
    option enabled '1'
    option input 'uvc'
    option device '/dev/video0'
    option resolution '640x480'
    option fps '15'
    option yuv 'off'
    option quality '85'
    option port '8080'
    option www '/www/webcam'
    option username ''
    option password ''
```

### Start mjpg-streamer

```bash
# Enable on boot
/etc/init.d/mjpg-streamer enable

# Start service
/etc/init.d/mjpg-streamer start

# Check status
/etc/init.d/mjpg-streamer status
```

### Access Stream

**Web interface:**
```
http://192.168.1.1:8080/stream.html
```

**Direct stream URL:**
```
http://192.168.1.1:8080/?action=stream
```

**Single snapshot:**
```
http://192.168.1.1:8080/?action=snapshot
```

### Verify mjpg-streamer is Running

```bash
# Check process
ps | grep mjpg

# Check listening port
netstat -tulpn | grep 8080

# Test stream
wget -O /tmp/test.jpg "http://127.0.0.1:8080/?action=snapshot"
```

---

## Method 3: fswebcam (Snapshot/Timelapse)

### About fswebcam

Simple command-line tool for capturing still images from webcams.

**Use cases:**
- Single snapshots
- Timelapse photography
- Periodic image capture
- Low-resource systems

### Installation

```bash
opkg update
opkg install fswebcam
```

### Basic Usage

**Capture single image:**

```bash
fswebcam /tmp/snapshot.jpg
```

**Capture with options:**

```bash
# Quiet mode, no banner, 5 frame skip, 640x480 resolution
fswebcam -q -b -l 5 -r 640x480 /tmp/image.jpg
```

**Options explained:**
- `-q` : Quiet mode (no verbose output)
- `-b` : No banner/timestamp overlay
- `-l 5` : Skip first 5 frames (allow camera to adjust)
- `-r 640x480` : Resolution
- `-d /dev/video0` : Specify device (if multiple cameras)

### Web Interface for Snapshots

**Create web directory:**

```bash
mkdir -p /webcam
```

**Install web server (if not already installed):**

```bash
opkg install uhttpd
```

**Configure uhttpd for webcam:**

```bash
# Create new uhttpd instance
uci set uhttpd.webcam=uhttpd
uci set uhttpd.webcam.listen_http='0.0.0.0:88'
uci set uhttpd.webcam.home='/webcam'
uci set uhttpd.webcam.error_page='/webcam/index.html'

# Commit and restart
uci commit uhttpd
/etc/init.d/uhttpd enable
/etc/init.d/uhttpd restart
```

**Create HTML page with auto-refresh:**

```bash
cat > /webcam/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="5">
    <title>Webcam View</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            background-color: #000;
            text-align: center;
        }
        h1 {
            color: #fff;
            font-family: Arial, sans-serif;
        }
        img {
            max-width: 100%;
            height: auto;
            border: 2px solid #fff;
            box-shadow: 0 4px 8px rgba(0,0,0,0.5);
        }
        .info {
            color: #ccc;
            font-family: monospace;
            margin-top: 10px;
        }
    </style>
</head>
<body>
    <h1>Live Webcam</h1>
    <img src="image.jpg" alt="Webcam Image">
    <div class="info">Auto-refresh every 5 seconds</div>
</body>
</html>
EOF
```

**Create symbolic link:**

```bash
ln -s /tmp/image.jpg /webcam/image.jpg
```

**Continuous capture script:**

```bash
cat > /usr/bin/webcam-capture.sh << 'EOF'
#!/bin/sh
# Continuous webcam capture

while true; do
    fswebcam -q -b -l 5 -r 640x480 /tmp/image.jpg
    sleep 5
done
EOF

chmod +x /usr/bin/webcam-capture.sh
```

**Add to startup:**

```bash
# Edit /etc/rc.local (before 'exit 0')
cat >> /etc/rc.local << 'EOF'
# Start webcam capture
/usr/bin/webcam-capture.sh &
EOF
```

**Start immediately:**

```bash
/usr/bin/webcam-capture.sh &
```

**Access webcam:**
```
http://192.168.1.1:88
```

### Timelapse Photography

**Capture every 60 seconds to USB storage:**

```bash
cat > /usr/bin/timelapse.sh << 'EOF'
#!/bin/sh
# Timelapse capture script

STORAGE_DIR="/mnt/sda1/timelapse"
mkdir -p "$STORAGE_DIR"

while true; do
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    fswebcam -q -b -l 5 -r 1280x720 "$STORAGE_DIR/img_$TIMESTAMP.jpg"
    sleep 60
done
EOF

chmod +x /usr/bin/timelapse.sh
```

**Start timelapse:**

```bash
/usr/bin/timelapse.sh &
```

**Create video from images:**

```bash
# On desktop computer with ffmpeg
ffmpeg -framerate 30 -pattern_type glob -i '*.jpg' -c:v libx264 timelapse.mp4
```

---

## Advanced Configuration

### Password Protection (mjpg-streamer)

```bash
# Set username and password
uci set mjpg-streamer.core.username='admin'
uci set mjpg-streamer.core.password='secretpass'
uci commit mjpg-streamer
/etc/init.d/mjpg-streamer restart
```

### Custom Resolution and FPS

```bash
# For mjpg-streamer
uci set mjpg-streamer.core.resolution='1280x720'
uci set mjpg-streamer.core.fps='30'
uci commit mjpg-streamer

# For fswebcam
fswebcam -r 1920x1080 /tmp/hd.jpg
```

### Night Vision / Low Light

```bash
# Increase exposure (v4l2-ctl)
v4l2-ctl --set-ctrl=exposure_absolute=200

# Disable auto exposure
v4l2-ctl --set-ctrl=exposure_auto=1
```

### Motion Event Scripts

**Execute script on motion detection:**

Edit `/etc/motion.conf`:

```bash
# Event script on motion start
on_event_start /usr/bin/motion-alert.sh
```

**Create alert script:**

```bash
cat > /usr/bin/motion-alert.sh << 'EOF'
#!/bin/sh
# Send alert on motion detection

logger -t motion "Motion detected!"

# Send email (if configured)
echo "Motion detected at $(date)" | mail -s "Motion Alert" admin@example.com

# Send Telegram notification (if bot configured)
# curl -s -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
#     -d chat_id=<CHAT_ID> \
#     -d text="Motion detected!"
EOF

chmod +x /usr/bin/motion-alert.sh
```

---

## Network Access and Security

### Firewall Configuration

```bash
# Allow webcam access from LAN
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-Webcam'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest_port='8080'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'

uci commit firewall
/etc/init.d/firewall reload
```

### Remote Access (Port Forwarding)

```bash
# Forward external port to webcam
uci add firewall redirect
uci set firewall.@redirect[-1].name='Webcam-Forward'
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].src_dport='18080'
uci set firewall.@redirect[-1].dest='lan'
uci set firewall.@redirect[-1].dest_ip='192.168.1.1'
uci set firewall.@redirect[-1].dest_port='8080'
uci set firewall.@redirect[-1].proto='tcp'

uci commit firewall
/etc/init.d/firewall reload
```

**Access from internet:**
```
http://your-public-ip:18080
```

### HTTPS/SSL Configuration

```bash
# Generate self-signed certificate
opkg install openssl-util

openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout /etc/webcam.key -out /etc/webcam.crt \
    -days 365 -subj "/CN=webcam"

# Configure uhttpd for HTTPS
uci set uhttpd.webcam.listen_https='0.0.0.0:443'
uci set uhttpd.webcam.cert='/etc/webcam.crt'
uci set uhttpd.webcam.key='/etc/webcam.key'
uci commit uhttpd
/etc/init.d/uhttpd restart
```

---

## Storage Solutions

### USB Storage Setup

```bash
# Install USB storage support
opkg install kmod-usb-storage block-mount

# Detect and mount
block detect > /etc/config/fstab
uci set fstab.@global[0].anon_mount='1'
uci commit fstab
/etc/init.d/fstab boot

# Verify mount
df -h | grep sda
```

### Automatic Cleanup Script

```bash
cat > /usr/bin/cleanup-old-images.sh << 'EOF'
#!/bin/sh
# Delete images older than 7 days

STORAGE_DIR="/mnt/sda1/motion"
find "$STORAGE_DIR" -name "*.jpg" -mtime +7 -delete
find "$STORAGE_DIR" -name "*.avi" -mtime +7 -delete
EOF

chmod +x /usr/bin/cleanup-old-images.sh

# Add to cron (daily at 2 AM)
echo "0 2 * * * /usr/bin/cleanup-old-images.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

---

## Performance Optimization

### Reduce CPU Load

```bash
# Lower resolution
uci set mjpg-streamer.core.resolution='320x240'

# Lower frame rate
uci set mjpg-streamer.core.fps='10'

# Lower quality
uci set mjpg-streamer.core.quality='70'

uci commit mjpg-streamer
/etc/init.d/mjpg-streamer restart
```

### Monitor Resource Usage

```bash
# CPU and memory usage
top

# Check specific process
top -bn1 | grep mjpg-streamer
```

---

## Troubleshooting

### Camera Not Detected

**Problem:** `/dev/video0` does not exist.

**Solutions:**

1. Check USB connection:
   ```bash
   lsusb
   ```

2. Verify drivers loaded:
   ```bash
   lsmod | grep video
   ```

3. Check dmesg:
   ```bash
   dmesg | grep -i camera
   ```

4. Install correct driver:
   ```bash
   opkg install kmod-video-uvc
   reboot
   ```

### Stream Not Accessible

**Problem:** Cannot access stream in browser.

**Solutions:**

1. Check service running:
   ```bash
   /etc/init.d/mjpg-streamer status
   ps | grep mjpg
   ```

2. Verify port:
   ```bash
   netstat -tulpn | grep 8080
   ```

3. Check firewall:
   ```bash
   uci show firewall | grep 8080
   ```

4. Test locally:
   ```bash
   wget -O /tmp/test.jpg "http://127.0.0.1:8080/?action=snapshot"
   ```

### Poor Video Quality

**Problem:** Blurry or choppy video.

**Solutions:**

1. Increase resolution:
   ```bash
   uci set mjpg-streamer.core.resolution='1280x720'
   ```

2. Adjust quality:
   ```bash
   uci set mjpg-streamer.core.quality='95'
   ```

3. Improve lighting

4. Clean camera lens

### High CPU Usage

**Problem:** Router overloaded by webcam.

**Solutions:**

1. Use fswebcam instead (snapshots only)
2. Lower resolution/framerate
3. Use camera with hardware MJPEG encoding
4. Upgrade to more powerful router

---

## Supported Camera Models

### UVC-Compatible Cameras

Most modern USB webcams support UVC (USB Video Class):

- Logitech C270, C920, C922, C930e
- Microsoft LifeCam HD-3000, Studio
- Generic Chinese webcams
- Laptop built-in cameras (with USB adapter)

### GSPCA-Supported Cameras

Cameras requiring specific GSPCA drivers (older models):

**Common chipsets and drivers:**

| Chipset | Driver Package | Example Models |
|---------|----------------|----------------|
| ZC3xx | kmod-video-gspca-zc3xx | Vimicro webcams |
| SPCA5xx | kmod-video-gspca-spca* | Many Creative Labs |
| OV519/534 | kmod-video-gspca-ov* | OmniVision cameras |
| PAC7311 | kmod-video-gspca-pac7311 | PixArt cameras |
| SN9C102 | kmod-video-gspca-sonixb | Sonix cameras |

**To identify your camera:**

```bash
# Get USB ID
lsusb

# Example: ID 046d:0825
# Search online: "046d:0825 linux driver"
```

---

## Best Practices

### 1. Use USB Storage

```bash
# Always save recordings to USB, not internal flash
target_dir /mnt/sda1/motion
```

### 2. Implement Cleanup

```bash
# Automatic deletion of old files
find /mnt/sda1/motion -mtime +7 -delete
```

### 3. Optimize Settings

```bash
# Balance quality vs. performance
# 640x480 @ 15fps is usually sufficient
```

### 4. Secure Access

```bash
# Use password protection
# Enable HTTPS
# Restrict firewall access
```

### 5. Monitor Resources

```bash
# Check CPU/RAM regularly
top
free
```

### 6. Regular Backups

```bash
# Copy important recordings off-device
rsync -av /mnt/sda1/motion/ user@server:/backup/
```

---

## References

### Official Documentation
- **Motion:** https://motion-project.github.io/
- **mjpg-streamer:** https://github.com/jacksonliam/mjpg-streamer
- **fswebcam:** https://www.sanslogic.co.uk/fswebcam/

### Related Pages
- **eko.one.pl Webcam Guide:** https://eko.one.pl/?p=openwrt-webcam
- **OpenWRT USB Storage:** https://openwrt.org/docs/guide-user/storage/usb-drives

### Camera Support
- **Linux UVC Driver:** http://www.ideasonboard.org/uvc/
- **GSPCA Project:** http://mxhaard.free.fr/spca5xx.html

---

## Summary

OpenWRT routers can be transformed into functional network cameras using USB webcams:

**Software Options:**
1. **Motion** - Full-featured motion detection and recording
2. **mjpg-streamer** - Lightweight live streaming
3. **fswebcam** - Simple snapshots and timelapse

**Installation (mjpg-streamer example):**
```bash
opkg install kmod-usb-core kmod-usb2 kmod-video-uvc mjpg-streamer
uci set mjpg-streamer.core.enabled='1'
uci commit mjpg-streamer
/etc/init.d/mjpg-streamer enable
/etc/init.d/mjpg-streamer start
```

**Access:**
```
http://192.168.1.1:8080/stream.html
```

**Key Considerations:**
- USB camera compatibility (UVC preferred)
- Router CPU/RAM capacity
- Storage for recordings
- Network bandwidth
- Power consumption

This solution provides a cost-effective, customizable alternative to commercial IP cameras with full control over privacy and features.

---

*This guide is based on the eko.one.pl webcam integration tutorial and community webcam streaming practices.*
