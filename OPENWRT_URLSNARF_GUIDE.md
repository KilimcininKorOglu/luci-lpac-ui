# OpenWrt URLSnarf - Complete Network Monitoring Guide

**Document Version:** 1.0
**Last Updated:** October 2025
**Difficulty Level:** Intermediate
**Estimated Reading Time:** 25 minutes

---

## Table of Contents

1. [Introduction](#introduction)
2. [What is URLSnarf?](#what-is-urlsnarf)
3. [Installation](#installation)
4. [Basic Usage](#basic-usage)
5. [Configuration](#configuration)
6. [Advanced Filtering](#advanced-filtering)
7. [Persistent Logging Setup](#persistent-logging-setup)
8. [Log Analysis](#log-analysis)
9. [Performance Considerations](#performance-considerations)
10. [Security and Privacy](#security-and-privacy)
11. [Practical Use Cases](#practical-use-cases)
12. [Troubleshooting](#troubleshooting)
13. [Alternatives and Complementary Tools](#alternatives-and-complementary-tools)

---

## Introduction

URLSnarf is a powerful network monitoring tool that captures and logs HTTP requests passing through your OpenWrt router. Part of the venerable **dsniff** package suite, it provides real-time visibility into web browsing activity on your network.

### What You'll Learn

- How to install and configure URLSnarf on OpenWrt
- Monitor HTTP traffic across your network
- Create persistent logging systems
- Analyze web browsing patterns
- Implement filtering and selective monitoring
- Balance monitoring needs with system performance

### Prerequisites

**Required:**
- OpenWrt router with at least 64MB RAM
- Basic command-line knowledge
- SSH access to your router
- External storage (USB drive, SD card) for log storage

**Recommended:**
- Understanding of network interfaces (br-lan, eth0, wlan0)
- Familiarity with init scripts
- Basic knowledge of tcpdump/packet capture concepts

---

## What is URLSnarf?

### Overview

URLSnarf is a **passive network monitoring tool** that captures HTTP requests by analyzing packet data passing through network interfaces. It extracts and logs:

- **Source IP addresses** (who made the request)
- **Timestamps** (when the request occurred)
- **Full URLs** (what was requested)
- **HTTP methods** (GET, POST, etc.)
- **User-Agent strings** (browser/device information)
- **Referrer information** (where the request came from)

### How It Works

```
[Client Device] → [OpenWrt Router] → [Internet]
                       ↑
                  URLSnarf monitors
                  network interface
                  and captures HTTP
                  traffic metadata
```

URLSnarf operates in **promiscuous mode**, capturing all packets on the specified interface and filtering for HTTP traffic (ports 80, 8080, 3128 by default).

### Key Characteristics

**Passive Monitoring:**
- No interference with network traffic
- No proxy configuration required on client devices
- Transparent to network users

**Protocol Support:**
- ✅ HTTP (unencrypted web traffic)
- ❌ HTTPS (encrypted traffic - only sees encrypted data, not URLs)
- ✅ HTTP proxies (can capture proxied requests)

**Part of dsniff Suite:**

URLSnarf is one of many tools in the dsniff package:
- **dsniff** - Password sniffer
- **urlsnarf** - URL logger (this guide)
- **webspy** - Web traffic replayer
- **mailsnarf** - Email traffic monitor
- **msgsnarf** - IM traffic monitor

---

## Installation

### Method 1: Install URLSnarf Only

If you only need the URL monitoring capability:

```bash
# Update package lists
opkg update

# Install urlsnarf
opkg install urlsnarf
```

**Package size:** Approximately 10-15 KB

### Method 2: Install Complete dsniff Suite

For access to all dsniff tools:

```bash
# Update package lists
opkg update

# Install complete dsniff package
opkg install dsniff
```

**Package size:** Approximately 150-200 KB

### Verify Installation

```bash
# Check URLSnarf version and help
urlsnarf -h

# Expected output:
# Usage: urlsnarf [-n] [-i interface] [expression]
#   -n  do not resolve IP addresses
#   -i  specify interface to sniff
```

### Check Dependencies

URLSnarf depends on:
- **libpcap** - Packet capture library
- **libnet** - Network packet construction library

These are usually installed automatically as dependencies.

```bash
# Verify libpcap is installed
opkg list-installed | grep libpcap

# Expected output:
# libpcap - 1.10.1-1
```

### Troubleshooting Installation

**Problem:** "Package urlsnarf not found"

**Solution:**
```bash
# Check if your OpenWrt version has the package
opkg update
opkg find urlsnarf

# If not available, compile from source or use alternative repo
```

**Problem:** "Insufficient space in /overlay"

**Solution:**
```bash
# Check available space
df -h

# Remove unnecessary packages or use extroot
# See OpenWrt Extroot guide for expanding storage
```

---

## Basic Usage

### Command Syntax

```bash
urlsnarf [-n] [-i interface] [expression]
```

**Parameters:**

| Parameter | Description |
|-----------|-------------|
| `-n` | Do not resolve IP addresses to hostnames (faster) |
| `-i interface` | Specify network interface to monitor |
| `expression` | Optional BPF filter expression |

### Simple Test

Capture HTTP traffic on the LAN bridge interface:

```bash
urlsnarf -i br-lan
```

**Example output:**
```
192.168.1.100 - - [25/Oct/2025:14:23:15 +0000] "GET http://example.com/ HTTP/1.1" - - "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/118.0.0.0"
192.168.1.101 - - [25/Oct/2025:14:23:18 +0000] "GET http://news.ycombinator.com/ HTTP/1.1" - - "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) Safari/604.1"
192.168.1.100 - - [25/Oct/2025:14:23:22 +0000] "GET http://example.com/images/logo.png HTTP/1.1" - - "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/118.0.0.0"
```

### Understanding Output Format

URLSnarf uses **Common Log Format (CLF)**, the standard Apache web server log format:

```
<IP> - - [<Timestamp>] "<Method> <URL> <Protocol>" - - "<User-Agent>"
```

**Example breakdown:**
```
192.168.1.100 - - [25/Oct/2025:14:23:15 +0000] "GET http://example.com/ HTTP/1.1" - - "Mozilla/5.0..."
│             │ │ │                             │   │                    │          │ │ │
│             │ │ │                             │   │                    │          │ │ └─ User-Agent
│             │ │ │                             │   │                    │          │ └─ Separator
│             │ │ │                             │   │                    │          └─ Status code (always -)
│             │ │ │                             │   │                    └─ HTTP version
│             │ │ │                             │   └─ Full URL
│             │ │ │                             └─ HTTP method
│             │ │ └─ Timestamp with timezone
│             │ └─ Auth user (always -)
│             └─ Remote logname (always -)
└─ Source IP address
```

### Monitoring Specific Interfaces

OpenWrt routers typically have multiple network interfaces:

**Monitor LAN traffic (wired + wireless):**
```bash
urlsnarf -i br-lan
```

**Monitor WAN traffic (outbound only):**
```bash
urlsnarf -i eth1
```

**Monitor specific wireless interface:**
```bash
urlsnarf -i wlan0
```

**List available interfaces:**
```bash
ip link show
# or
ifconfig
```

### Running in Background

To run URLSnarf continuously in the background:

```bash
# Run in background and redirect output to file
urlsnarf -i br-lan > /tmp/urls.log &

# Check if running
ps | grep urlsnarf

# Stop URLSnarf
pkill urlsnarf
```

---

## Configuration

### Default Monitored Ports

URLSnarf automatically monitors these ports:

| Port | Service |
|------|---------|
| 80 | HTTP (standard web traffic) |
| 8080 | HTTP alternate (proxy, development servers) |
| 3128 | Squid proxy |

### Custom Port Filtering

To monitor additional or specific ports, use BPF (Berkeley Packet Filter) expressions:

**Monitor only port 80:**
```bash
urlsnarf -i br-lan 'tcp port 80'
```

**Monitor ports 80 and 8080:**
```bash
urlsnarf -i br-lan 'tcp port 80 or tcp port 8080'
```

**Monitor custom port (e.g., 8000):**
```bash
urlsnarf -i br-lan 'tcp port 8000'
```

**Monitor port range:**
```bash
urlsnarf -i br-lan 'tcp portrange 8000-9000'
```

### Filtering by IP Address

**Monitor traffic from specific client:**
```bash
urlsnarf -i br-lan 'src host 192.168.1.100'
```

**Monitor traffic to specific destination:**
```bash
urlsnarf -i br-lan 'dst host 93.184.216.34'
```

**Monitor traffic between two hosts:**
```bash
urlsnarf -i br-lan 'host 192.168.1.100 and host 93.184.216.34'
```

**Exclude specific client:**
```bash
urlsnarf -i br-lan 'not src host 192.168.1.50'
```

### Filtering by Network

**Monitor traffic from specific subnet:**
```bash
urlsnarf -i br-lan 'src net 192.168.1.0/24'
```

**Monitor only wireless clients (if on separate subnet):**
```bash
urlsnarf -i br-lan 'src net 192.168.2.0/24'
```

### Combined Filters

BPF expressions can be combined with logical operators:

**Monitor specific client on port 80:**
```bash
urlsnarf -i br-lan 'src host 192.168.1.100 and tcp port 80'
```

**Monitor all clients except one:**
```bash
urlsnarf -i br-lan 'tcp port 80 and not src host 192.168.1.1'
```

**Complex filter example:**
```bash
urlsnarf -i br-lan '(src net 192.168.1.0/24 or src net 192.168.2.0/24) and tcp port 80'
```

### Hostname Resolution

**Default behavior (with DNS lookup):**
```bash
urlsnarf -i br-lan
# Output shows hostnames: client1.local, smartphone.local, etc.
```

**Disable hostname resolution (faster, less DNS traffic):**
```bash
urlsnarf -n -i br-lan
# Output shows only IP addresses: 192.168.1.100, 192.168.1.101, etc.
```

**When to use `-n` flag:**
- ✅ High-traffic networks (reduces processing overhead)
- ✅ Networks without proper DNS reverse lookups
- ✅ When privacy is important (no DNS queries revealing monitoring)
- ❌ When you need readable hostnames in logs

---

## Advanced Filtering

### BPF Expression Reference

Common BPF expressions for URLSnarf:

**Protocol filters:**
```bash
tcp                    # TCP traffic only
udp                    # UDP traffic only
icmp                   # ICMP traffic only
```

**Direction filters:**
```bash
src host 192.168.1.100    # Traffic FROM this host
dst host 93.184.216.34    # Traffic TO this host
host 192.168.1.100        # Traffic FROM or TO this host
```

**Port filters:**
```bash
port 80                   # Port 80 in either direction
src port 80               # Source port 80
dst port 80               # Destination port 80
portrange 8000-9000       # Port range
```

**Network filters:**
```bash
net 192.168.1.0/24        # Traffic from/to this network
src net 192.168.1.0/24    # Traffic FROM this network
dst net 10.0.0.0/8        # Traffic TO this network
```

**Logical operators:**
```bash
and                       # Both conditions must be true
or                        # Either condition must be true
not                       # Negation
```

### Practical Filter Examples

**Monitor only HTTP traffic from wireless clients (192.168.2.x):**
```bash
urlsnarf -i br-lan 'src net 192.168.2.0/24 and tcp port 80'
```

**Monitor web traffic from all clients except the router itself:**
```bash
urlsnarf -i br-lan 'not src host 192.168.1.1 and tcp port 80'
```

**Monitor traffic to external websites only (not local network):**
```bash
urlsnarf -i br-lan 'not dst net 192.168.0.0/16 and not dst net 10.0.0.0/8'
```

**Monitor HTTP and HTTPS handshakes (CONNECT method for proxies):**
```bash
urlsnarf -i br-lan 'tcp port 80 or tcp port 443'
# Note: HTTPS URLs won't be visible, only CONNECT requests
```

**Monitor traffic during specific time (combine with scheduling):**
```bash
# Use in cron job for 9 AM - 5 PM monitoring (see Persistent Logging section)
```

### Testing Filters

Before deploying filters in production, test with `tcpdump` first:

```bash
# Test filter syntax with tcpdump
tcpdump -i br-lan 'src net 192.168.1.0/24 and tcp port 80'

# If tcpdump works, the same filter works with urlsnarf
urlsnarf -i br-lan 'src net 192.168.1.0/24 and tcp port 80'
```

---

## Persistent Logging Setup

### Storage Considerations

**⚠️ CRITICAL: Never log to router's flash memory**

OpenWrt routers use flash storage with limited write cycles. Continuous logging to `/overlay` will quickly wear out the flash and brick your router.

**Correct storage locations:**
- ✅ USB flash drive mounted at `/mnt/usb`
- ✅ SD card mounted at `/mnt/sdcard`
- ✅ External hard drive mounted at `/mnt/hdd`
- ✅ Network storage (NFS, CIFS) mounted at `/mnt/nas`
- ✅ RAM disk at `/tmp` (for temporary monitoring only)

**Incorrect storage locations:**
- ❌ `/etc` (flash storage)
- ❌ `/root` (flash storage)
- ❌ `/overlay` (flash storage)

### Preparing External Storage

**Mount USB drive:**
```bash
# Install USB storage support
opkg update
opkg install kmod-usb-storage block-mount

# Create mount point
mkdir -p /mnt/usb

# Find USB device
ls /dev/sd*
# Example output: /dev/sda1

# Mount USB drive
mount /dev/sda1 /mnt/usb

# Verify mount
df -h | grep usb
# Output: /dev/sda1  7.3G  1.2G  6.1G  16% /mnt/usb

# Create logs directory
mkdir -p /mnt/usb/urlsnarf_logs
```

**Make mount persistent (auto-mount on boot):**
```bash
# Edit /etc/config/fstab
uci set fstab.@mount[0]=mount
uci set fstab.@mount[0].target='/mnt/usb'
uci set fstab.@mount[0].device='/dev/sda1'
uci set fstab.@mount[0].fstype='ext4'
uci set fstab.@mount[0].options='rw,sync'
uci set fstab.@mount[0].enabled='1'
uci commit fstab

# Enable block-mount
/etc/init.d/fstab enable

# Reboot to test
reboot
```

### Creating Init Script

Create a startup script to run URLSnarf automatically on boot:

**Create `/etc/init.d/urlsnarf_log`:**
```bash
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1

INTERFACE="br-lan"
LOG_DIR="/mnt/usb/urlsnarf_logs"
LOG_FILE="$LOG_DIR/urls_$(date +%Y%m%d).log.gz"

start_service() {
    # Ensure log directory exists
    mkdir -p "$LOG_DIR"

    # Start URLSnarf with compression
    procd_open_instance
    procd_set_param command /usr/sbin/urlsnarf -n -i "$INTERFACE"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_append_param command | gzip >> "$LOG_FILE"
    procd_close_instance
}

stop_service() {
    pkill urlsnarf
}
```

**Alternative simpler version:**
```bash
#!/bin/sh /etc/rc.common

START=99

start() {
    # Run URLSnarf in background with compressed output
    /usr/sbin/urlsnarf -n -i br-lan | gzip >> /mnt/usb/urlsnarf_logs/urls.log.gz &
}

stop() {
    pkill urlsnarf
}
```

**Enable and start the service:**
```bash
# Make script executable
chmod +x /etc/init.d/urlsnarf_log

# Enable on boot
/etc/init.d/urlsnarf_log enable

# Start now
/etc/init.d/urlsnarf_log start

# Check if running
ps | grep urlsnarf
# Output: 12345 root   urlsnarf -n -i br-lan
```

### Log Rotation

Prevent log files from growing indefinitely:

**Method 1: Daily Log Files**

Modify init script to use date-stamped filenames:

```bash
#!/bin/sh /etc/rc.common

START=99

start() {
    LOG_FILE="/mnt/usb/urlsnarf_logs/urls_$(date +%Y%m%d).log.gz"
    /usr/sbin/urlsnarf -n -i br-lan | gzip >> "$LOG_FILE" &
}

stop() {
    pkill urlsnarf
}
```

Add cron job to restart URLSnarf daily:
```bash
# Edit crontab
crontab -e

# Add line to restart at midnight
0 0 * * * /etc/init.d/urlsnarf_log restart
```

**Method 2: Logrotate**

Install and configure logrotate:

```bash
# Install logrotate
opkg update
opkg install logrotate

# Create /etc/logrotate.d/urlsnarf
cat > /etc/logrotate.d/urlsnarf <<'EOF'
/mnt/usb/urlsnarf_logs/urls.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
    postrotate
        /etc/init.d/urlsnarf_log restart
    endscript
}
EOF

# Test logrotate
logrotate -d /etc/logrotate.d/urlsnarf

# Add to cron
echo "0 2 * * * /usr/sbin/logrotate /etc/logrotate.conf" >> /etc/crontabs/root
/etc/init.d/cron restart
```

**Method 3: Size-Based Rotation Script**

Create custom rotation script:

```bash
#!/bin/sh
# /usr/bin/rotate_urlsnarf_logs.sh

LOG_DIR="/mnt/usb/urlsnarf_logs"
MAX_SIZE=104857600  # 100MB in bytes

cd "$LOG_DIR" || exit 1

for log in *.log.gz; do
    [ -f "$log" ] || continue

    size=$(stat -c%s "$log")

    if [ "$size" -gt "$MAX_SIZE" ]; then
        # Archive old log
        mv "$log" "archived_$(date +%Y%m%d_%H%M%S)_$log"

        # Restart URLSnarf to create new log
        /etc/init.d/urlsnarf_log restart
    fi
done

# Delete logs older than 90 days
find "$LOG_DIR" -name "archived_*.log.gz" -mtime +90 -delete
```

**Make executable and schedule:**
```bash
chmod +x /usr/bin/rotate_urlsnarf_logs.sh

# Add to cron (run hourly)
echo "0 * * * * /usr/bin/rotate_urlsnarf_logs.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

### Verifying Logging

**Check if URLSnarf is running:**
```bash
ps | grep urlsnarf
```

**Monitor log file growth:**
```bash
# Watch log file size
watch -n 5 'ls -lh /mnt/usb/urlsnarf_logs/'

# View real-time logs
zcat /mnt/usb/urlsnarf_logs/urls.log.gz | tail -f
```

**Generate test traffic:**
```bash
# From a client device, browse to:
http://example.com
http://neverssl.com

# Check if captured
zcat /mnt/usb/urlsnarf_logs/urls.log.gz | grep example.com
```

---

## Log Analysis

### Reading Compressed Logs

**View entire log:**
```bash
zcat /mnt/usb/urlsnarf_logs/urls.log.gz
```

**View last 50 entries:**
```bash
zcat /mnt/usb/urlsnarf_logs/urls.log.gz | tail -50
```

**Search for specific domain:**
```bash
zcat /mnt/usb/urlsnarf_logs/urls.log.gz | grep "facebook.com"
```

**Search for specific IP:**
```bash
zcat /mnt/usb/urlsnarf_logs/urls.log.gz | grep "192.168.1.100"
```

### Common Analysis Tasks

**1. Most visited domains:**
```bash
zcat /mnt/usb/urlsnarf_logs/urls_*.log.gz | \
  grep -oP 'http://\K[^/]+' | \
  sort | uniq -c | sort -rn | head -20
```

**Example output:**
```
    245 example.com
    189 news.ycombinator.com
    156 github.com
    134 reddit.com
     98 stackoverflow.com
```

**2. Traffic by client IP:**
```bash
zcat /mnt/usb/urlsnarf_logs/urls_*.log.gz | \
  awk '{print $1}' | \
  sort | uniq -c | sort -rn
```

**Example output:**
```
   1234 192.168.1.100
    567 192.168.1.101
    234 192.168.1.102
```

**3. Hourly traffic distribution:**
```bash
zcat /mnt/usb/urlsnarf_logs/urls_*.log.gz | \
  grep -oP '\[\d{2}/\w+/\d{4}:\K\d{2}' | \
  sort | uniq -c
```

**Example output:**
```
     45 08
    123 09
    234 10
    345 11
    289 12
```

**4. User-Agent distribution (browsers/devices):**
```bash
zcat /mnt/usb/urlsnarf_logs/urls_*.log.gz | \
  grep -oP '"Mozilla[^"]*' | \
  sed 's/.*(\([^;)]*\).*/\1/' | \
  sort | uniq -c | sort -rn | head -10
```

**Example output:**
```
    456 Windows NT 10.0; Win64; x64
    234 iPhone; CPU iPhone OS 16_0
    123 X11; Linux x86_64
     89 Macintosh; Intel Mac OS X 10_15_7
```

**5. POST requests (form submissions):**
```bash
zcat /mnt/usb/urlsnarf_logs/urls_*.log.gz | grep "POST"
```

**6. Traffic during specific time range:**
```bash
zcat /mnt/usb/urlsnarf_logs/urls_20251025.log.gz | \
  grep '\[25/Oct/2025:14:'
```

**7. Identify heaviest user:**
```bash
zcat /mnt/usb/urlsnarf_logs/urls_*.log.gz | \
  awk '{print $1}' | \
  sort | uniq -c | sort -rn | head -1
```

### Advanced Analysis with awk

**Extract URL, IP, and timestamp:**
```bash
zcat /mnt/usb/urlsnarf_logs/urls.log.gz | \
  awk '{print $1, $4, $7}'
```

**Filter by date:**
```bash
zcat /mnt/usb/urlsnarf_logs/urls.log.gz | \
  awk '/25\/Oct\/2025/ {print}'
```

**Count requests per hour:**
```bash
zcat /mnt/usb/urlsnarf_logs/urls.log.gz | \
  awk -F'[: []' '{print $3}' | \
  sort | uniq -c
```

### Creating Reports

**Daily traffic report script:**
```bash
#!/bin/sh
# /usr/bin/urlsnarf_daily_report.sh

LOG_DIR="/mnt/usb/urlsnarf_logs"
REPORT_DIR="/mnt/usb/urlsnarf_reports"
DATE=$(date -d "yesterday" +%Y%m%d)
LOG_FILE="$LOG_DIR/urls_$DATE.log.gz"
REPORT_FILE="$REPORT_DIR/report_$DATE.txt"

mkdir -p "$REPORT_DIR"

cat > "$REPORT_FILE" <<EOF
URLSnarf Daily Report - $DATE
===============================

Total Requests: $(zcat "$LOG_FILE" | wc -l)

Top 10 Domains:
$(zcat "$LOG_FILE" | grep -oP 'http://\K[^/]+' | sort | uniq -c | sort -rn | head -10)

Top 10 Clients:
$(zcat "$LOG_FILE" | awk '{print $1}' | sort | uniq -c | sort -rn | head -10)

Hourly Distribution:
$(zcat "$LOG_FILE" | grep -oP '\[\d{2}/\w+/\d{4}:\K\d{2}' | sort | uniq -c)

EOF

# Optional: Email report
# (requires ssmtp or similar)
# cat "$REPORT_FILE" | mail -s "URLSnarf Report $DATE" admin@example.com
```

**Schedule daily report:**
```bash
chmod +x /usr/bin/urlsnarf_daily_report.sh
echo "0 3 * * * /usr/bin/urlsnarf_daily_report.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

---

## Performance Considerations

### CPU Impact

URLSnarf performs packet inspection, which consumes CPU resources.

**Expected CPU usage:**
- Idle network: ~1-2% CPU
- Normal browsing (10-20 clients): ~5-10% CPU
- Heavy traffic (50+ clients, video streaming): ~15-30% CPU

**Monitor CPU usage:**
```bash
# Real-time monitoring
top

# Watch URLSnarf CPU usage specifically
top | grep urlsnarf
```

**Reduce CPU impact:**

1. **Use `-n` flag** to disable hostname lookups:
   ```bash
   urlsnarf -n -i br-lan
   # Saves ~20-30% CPU
   ```

2. **Filter unnecessary traffic** with BPF expressions:
   ```bash
   # Only monitor port 80, not 8080 or 3128
   urlsnarf -i br-lan 'tcp port 80'
   ```

3. **Monitor specific clients** instead of all traffic:
   ```bash
   urlsnarf -i br-lan 'src net 192.168.2.0/24'
   ```

4. **Use hardware acceleration** (if available):
   ```bash
   # Some routers support packet filtering offload
   # Check your router's chipset documentation
   ```

### Memory Impact

URLSnarf uses minimal memory (~5-10 MB typical).

**Monitor memory usage:**
```bash
free -m
```

**If memory is constrained:**
- Reduce buffer sizes (may lose packets on high traffic)
- Use more aggressive filtering
- Close other services while monitoring

### Storage Impact

**Log growth rates:**

| Network Activity | Hourly Growth | Daily Growth | Monthly Growth |
|------------------|---------------|--------------|----------------|
| Light (5 clients, casual browsing) | 0.5 MB | 12 MB | 360 MB |
| Medium (20 clients, normal usage) | 2 MB | 48 MB | 1.4 GB |
| Heavy (50+ clients, streaming) | 5 MB | 120 MB | 3.6 GB |

*Compressed (.gz) sizes shown*

**Monitor storage usage:**
```bash
# Check USB drive space
df -h /mnt/usb

# Check log directory size
du -sh /mnt/usb/urlsnarf_logs
```

**Storage best practices:**
- Use compression (gzip, as shown in examples)
- Implement log rotation (delete logs older than X days)
- Use large USB drive (8GB minimum, 32GB+ recommended)

### Network Impact

**Bandwidth overhead:**
URLSnarf is passive and adds **zero network overhead**. It only reads existing packets, doesn't generate new traffic.

**Potential issues:**
- None for normal operation
- If using hostname resolution (-n flag not used), DNS queries add minimal traffic

---

## Security and Privacy

### Legal and Ethical Considerations

⚠️ **Important Legal Notice**

Monitoring network traffic may be subject to legal restrictions:

**Legal use cases:**
- ✅ Monitoring your own home network
- ✅ Monitoring corporate network with proper authorization
- ✅ Educational/research purposes on isolated test networks
- ✅ Parental monitoring of minor children's devices (jurisdiction-dependent)

**Illegal use cases:**
- ❌ Monitoring networks you don't own/control
- ❌ Monitoring without user consent (in jurisdictions requiring it)
- ❌ Monitoring to steal credentials or sensitive data
- ❌ Monitoring for harassment or stalking purposes

**Best practices:**
1. **Inform users**: Post notice that network traffic is monitored
2. **Document authorization**: Keep written approval for corporate environments
3. **Limit access**: Restrict log file access to authorized personnel only
4. **Secure logs**: Encrypt logs containing sensitive browsing data
5. **Retention policy**: Delete logs after reasonable retention period

### Privacy Protection

**Securing log files:**

```bash
# Set restrictive permissions
chmod 600 /mnt/usb/urlsnarf_logs/*.log.gz
chown root:root /mnt/usb/urlsnarf_logs/*.log.gz

# Encrypt logs (optional)
opkg install openssl-util

# Encrypt existing log
openssl aes-256-cbc -salt -in urls.log.gz -out urls.log.gz.enc
# Then delete unencrypted version
rm urls.log.gz

# Decrypt when needed
openssl aes-256-cbc -d -in urls.log.gz.enc -out urls.log.gz
```

**Anonymizing logs:**

Remove IP addresses from logs before sharing:

```bash
# Replace IPs with hashed values
zcat urls.log.gz | \
  sed -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[REDACTED]/g' | \
  gzip > urls_anonymized.log.gz
```

### HTTPS and Encryption

**Important limitation:**

URLSnarf **cannot** decrypt HTTPS traffic. Modern websites use HTTPS (encrypted HTTP), which protects:
- URL paths (you only see the domain in CONNECT requests)
- Query parameters
- POST data
- Cookies and headers

**What URLSnarf sees with HTTPS:**

Unencrypted (HTTP):
```
192.168.1.100 - - [25/Oct/2025:14:23:15 +0000] "GET http://example.com/search?q=secret HTTP/1.1"
                                                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                                     Full URL visible
```

Encrypted (HTTPS):
```
(Nothing captured, or only CONNECT request to proxy)
```

**Monitoring HTTPS traffic (alternatives):**

1. **SSL/TLS interception** (requires installing custom CA certificate on all clients)
   - Complex setup
   - Breaks some applications
   - Privacy/legal concerns
   - See: Squid with SSL Bump

2. **DNS monitoring** (see what domains are accessed, but not full URLs)
   ```bash
   # Monitor DNS queries instead
   tcpdump -i br-lan port 53
   ```

3. **Client-side monitoring** (browser extensions, parental control software)

### Preventing Detection

If you want monitoring to be less obvious:

**Don't:**
- ❌ Log to visible locations on shared systems
- ❌ Use obvious filenames like "monitoring.log"
- ❌ Generate high CPU usage (use `-n` flag)

**Do:**
- ✅ Use discrete log locations
- ✅ Compress logs to reduce I/O
- ✅ Use efficient BPF filters
- ✅ Post transparent notice (ethical approach)

---

## Practical Use Cases

### 1. Parental Monitoring

Monitor children's web browsing on home network.

**Setup:**
```bash
# Create filtered view for child's device
urlsnarf -i br-lan 'src host 192.168.1.150' | \
  gzip >> /mnt/usb/logs/child_browsing.log.gz &
```

**Daily review:**
```bash
# Check today's browsing
zcat /mnt/usb/logs/child_browsing.log.gz | \
  grep "$(date +%d/%b/%Y)"
```

**Alert on concerning domains:**
```bash
#!/bin/sh
# /usr/bin/parental_alert.sh

BLOCK_LIST="gambling.com inappropriate.site"
CHILD_IP="192.168.1.150"
LOG="/mnt/usb/logs/child_browsing.log.gz"

for domain in $BLOCK_LIST; do
    if zcat "$LOG" | tail -100 | grep "$CHILD_IP" | grep "$domain"; then
        echo "Alert: $CHILD_IP accessed $domain at $(date)" | \
          mail -s "Parental Alert" parent@example.com
    fi
done
```

### 2. Corporate Network Auditing

Monitor employee internet usage for policy compliance.

**Setup with user identification:**
```bash
# Map IP to employee (static DHCP assignments)
# /etc/urlsnarf_users.conf
192.168.1.10=john.doe
192.168.1.11=jane.smith
192.168.1.12=bob.johnson

# Enhanced logging script
urlsnarf -n -i br-lan | \
  while read line; do
    ip=$(echo $line | awk '{print $1}')
    user=$(grep "^$ip=" /etc/urlsnarf_users.conf | cut -d= -f2)
    echo "[$user] $line"
  done | gzip >> /mnt/usb/logs/corporate.log.gz &
```

**Generate productivity report:**
```bash
#!/bin/sh
# /usr/bin/productivity_report.sh

PRODUCTIVITY_SITES="stackoverflow.com github.com documentation"
NONPRODUCTIVE_SITES="facebook.com youtube.com reddit.com"

LOG="/mnt/usb/logs/corporate.log.gz"

echo "Productivity Report - $(date)"
echo "================================"

for user in john.doe jane.smith bob.johnson; do
    echo ""
    echo "User: $user"

    productive=$(zcat $LOG | grep "\[$user\]" | grep -E "$(echo $PRODUCTIVITY_SITES | tr ' ' '|')" | wc -l)
    nonproductive=$(zcat $LOG | grep "\[$user\]" | grep -E "$(echo $NONPRODUCTIVE_SITES | tr ' ' '|')" | wc -l)

    echo "  Productive requests: $productive"
    echo "  Non-productive requests: $nonproductive"
    echo "  Ratio: $(echo "scale=2; $productive / ($productive + $nonproductive)" | bc)"
done
```

### 3. IoT Device Monitoring

Track what smart home devices are communicating with.

**Setup:**
```bash
# Monitor IoT VLAN (192.168.3.x)
urlsnarf -i br-lan 'src net 192.168.3.0/24' | \
  gzip >> /mnt/usb/logs/iot_devices.log.gz &
```

**Identify unexpected connections:**
```bash
# List all external domains contacted by IoT devices
zcat /mnt/usb/logs/iot_devices.log.gz | \
  grep -oP 'http://\K[^/]+' | \
  sort -u > /tmp/iot_domains.txt

# Review for unexpected Chinese/Russian servers
cat /tmp/iot_domains.txt | grep -E '\.(cn|ru)$'
```

### 4. Malware Detection

Detect compromised devices by unusual HTTP patterns.

**Setup with pattern detection:**
```bash
#!/bin/sh
# /usr/bin/malware_detector.sh

MALWARE_PATTERNS="
/cmd.php
/shell.php
/admin/config.php
.exe
.scr
"

urlsnarf -n -i br-lan | \
  while read line; do
    for pattern in $MALWARE_PATTERNS; do
        if echo "$line" | grep -q "$pattern"; then
            echo "ALERT: Possible malware activity: $line" >> /var/log/malware_alerts.log
            # Optional: Trigger firewall block
            # source_ip=$(echo $line | awk '{print $1}')
            # iptables -I FORWARD -s $source_ip -j DROP
        fi
    done
  done &
```

### 5. Bandwidth Investigation

Identify which sites consume most bandwidth (combine with iftop or vnstat).

**Setup:**
```bash
# Run URLSnarf and iftop simultaneously
urlsnarf -n -i br-lan | gzip >> /mnt/usb/logs/bandwidth.log.gz &
iftop -i br-lan -t -s 60 > /mnt/usb/logs/iftop.log &

# Correlate logs to find bandwidth hogs
# (Manual analysis or custom script)
```

### 6. Guest Network Monitoring

Monitor guest WiFi for abuse.

**Setup:**
```bash
# Guest network on wlan0-1 (192.168.4.x)
urlsnarf -i wlan0-1 | \
  gzip >> /mnt/usb/logs/guest_network.log.gz &
```

**Block abusive guests:**
```bash
#!/bin/sh
# Auto-block guests downloading suspicious content

urlsnarf -n -i wlan0-1 | \
  while read line; do
    if echo "$line" | grep -qE '\.(torrent|exe|dmg)$'; then
        ip=$(echo $line | awk '{print $1}')
        echo "Blocking $ip for suspicious download"
        iptables -I FORWARD -s $ip -j REJECT
    fi
  done &
```

---

## Troubleshooting

### URLSnarf Not Capturing Traffic

**Problem:** URLSnarf runs but doesn't show any output.

**Diagnostic steps:**

```bash
# 1. Verify URLSnarf is running
ps | grep urlsnarf

# 2. Check if interface is correct
ip link show
# Verify interface exists (br-lan, eth0, wlan0, etc.)

# 3. Test with tcpdump to confirm traffic exists
tcpdump -i br-lan -c 10 port 80
# Should show HTTP packets

# 4. Generate test traffic
# From client device, browse to: http://neverssl.com

# 5. Check for permission issues
# URLSnarf must run as root
whoami
# Should output: root

# 6. Verify libpcap is working
ldd /usr/sbin/urlsnarf | grep pcap
# Should show: libpcap.so => /usr/lib/libpcap.so

# 7. Try simplest possible command
urlsnarf -i br-lan
# No filters, default ports
```

**Common causes:**

| Cause | Solution |
|-------|----------|
| Wrong interface name | Use `ip link` to find correct interface |
| All traffic is HTTPS | URLSnarf can't decrypt HTTPS (expected behavior) |
| No traffic on port 80 | Normal for modern web (use DNS monitoring instead) |
| Permission denied | Run as root or with sudo |
| libpcap not installed | `opkg install libpcap` |

---

### High CPU Usage

**Problem:** URLSnarf consuming excessive CPU (>30%).

**Solutions:**

```bash
# 1. Disable hostname resolution
urlsnarf -n -i br-lan

# 2. Add restrictive filters
urlsnarf -n -i br-lan 'tcp port 80'

# 3. Reduce captured traffic with sampling
# (Capture 1 in 10 packets - advanced)
urlsnarf -i br-lan 'tcp port 80 and (tcp[13:1] & 0x10 != 0) and (rand() < RAND_MAX / 10)'

# 4. Lower process priority
nice -n 19 urlsnarf -n -i br-lan

# 5. Use hardware offload if available
# (Router-specific, check documentation)

# 6. Monitor fewer clients
urlsnarf -n -i br-lan 'src host 192.168.1.100'
```

---

### Logs Not Being Created

**Problem:** URLSnarf runs but log file remains empty.

**Diagnostic steps:**

```bash
# 1. Check file permissions
ls -l /mnt/usb/urlsnarf_logs/
# Should be writable by root

# 2. Check disk space
df -h /mnt/usb
# Should have free space

# 3. Test manual logging
urlsnarf -i br-lan > /mnt/usb/test.log
# Browse from client, then check:
cat /mnt/usb/test.log

# 4. Verify gzip is working
echo "test" | gzip > /mnt/usb/test.gz
zcat /mnt/usb/test.gz
# Should output: test

# 5. Check if filesystem is mounted read-only
mount | grep /mnt/usb
# Should NOT show "ro" (read-only)

# 6. Verify init script syntax
sh -n /etc/init.d/urlsnarf_log
# No output = syntax OK
```

**Common causes:**

| Cause | Solution |
|-------|----------|
| Filesystem full | Delete old logs, use larger USB drive |
| Mounted read-only | Remount: `mount -o remount,rw /mnt/usb` |
| Permission denied | `chmod 777 /mnt/usb/urlsnarf_logs` |
| gzip not installed | `opkg install gzip` |
| Incorrect pipe syntax | Use `|` not `>` when compressing |

---

### Init Script Not Starting on Boot

**Problem:** URLSnarf doesn't start automatically after reboot.

**Diagnostic steps:**

```bash
# 1. Check if script is enabled
ls /etc/rc.d/ | grep urlsnarf
# Should show: S99urlsnarf_log

# 2. Test script manually
/etc/init.d/urlsnarf_log start
# Check for errors

# 3. Check script syntax
sh -n /etc/init.d/urlsnarf_log

# 4. Verify START number
grep "START=" /etc/init.d/urlsnarf_log
# Should be high (99) to run after network is up

# 5. Check system logs
logread | grep urlsnarf

# 6. Ensure USB is mounted before URLSnarf starts
# Add dependency in init script:
# START=99  (runs after START=90 for block-mount)
```

**Solution - Add dependency:**

```bash
#!/bin/sh /etc/rc.common

START=99
STOP=10

# Add boot() function for startup checks
boot() {
    # Wait for USB to mount
    sleep 10
    start
}

start() {
    # Ensure mount point exists
    [ -d /mnt/usb/urlsnarf_logs ] || mkdir -p /mnt/usb/urlsnarf_logs

    /usr/sbin/urlsnarf -n -i br-lan | gzip >> /mnt/usb/urlsnarf_logs/urls.log.gz &
}

stop() {
    pkill urlsnarf
}
```

---

### Capturing Only HTTPS (Encrypted) Traffic

**Problem:** All websites use HTTPS, so URLSnarf captures nothing.

**Understanding:**

URLSnarf **cannot decrypt HTTPS traffic**. This is expected and by design. HTTPS encryption protects user privacy.

**Alternatives for HTTPS visibility:**

**Option 1: DNS Query Logging**
```bash
# Monitor DNS to see which domains are accessed
tcpdump -i br-lan -n port 53 | \
  tee /tmp/dns.log
```

**Option 2: SSL/TLS Interception (Advanced)**

Requires:
- Installing custom CA certificate on all client devices
- Squid proxy with SSL Bump
- Legal authorization and user consent

Not recommended for most use cases due to complexity and privacy concerns.

**Option 3: Client-Side Monitoring**

- Browser extensions (for limited users)
- Endpoint protection software
- Parental control applications

**Option 4: SNI Monitoring**

Server Name Indication (SNI) in TLS handshake reveals domain:

```bash
# Capture TLS SNI (shows domain, not full URL)
tcpdump -i br-lan -n 'tcp port 443' -A | \
  grep -oP '(?<=\x00)[a-z0-9\.-]+\.(com|net|org)'
```

---

## Alternatives and Complementary Tools

### DNS Query Logging

Monitor DNS requests to see which domains are accessed:

**Method 1: dnsmasq logging**
```bash
# Edit /etc/config/dhcp
uci set dhcp.@dnsmasq[0].logqueries='1'
uci commit dhcp
/etc/init.d/dnsmasq restart

# View logs
logread | grep dnsmasq
```

**Method 2: tcpdump DNS**
```bash
tcpdump -i br-lan -n port 53 > /mnt/usb/dns.log &
```

**Method 3: Unbound with logging**
```bash
opkg install unbound
# Configure logging in /etc/unbound/unbound.conf
verbosity: 1
logfile: "/mnt/usb/unbound.log"
```

---

### iftop - Real-Time Bandwidth Monitoring

See which hosts/connections use most bandwidth:

```bash
# Install
opkg install iftop

# Run
iftop -i br-lan

# Save to log
iftop -i br-lan -t -s 60 > /mnt/usb/iftop.log
```

---

### vnStat - Long-Term Traffic Statistics

Track monthly bandwidth usage:

```bash
# Install
opkg install vnstat

# Initialize
vnstat -u -i br-lan

# View stats
vnstat -i br-lan -d  # Daily
vnstat -i br-lan -m  # Monthly
```

---

### Squid Proxy with Logging

Full-featured HTTP proxy with detailed logs:

**Advantages:**
- Logs HTTPS domains (via CONNECT requests)
- More detailed logs than URLSnarf
- Supports authentication
- Can cache content (save bandwidth)

**Disadvantages:**
- Requires client configuration (or transparent proxy)
- More resource-intensive than URLSnarf
- Complex setup

**Basic installation:**
```bash
opkg install squid
# Configure /etc/squid/squid.conf
# Set clients to use proxy: 192.168.1.1:3128
```

---

### Comparison Table

| Tool | HTTP | HTTPS | Passive | Detailed Logs | Resource Usage |
|------|------|-------|---------|---------------|----------------|
| **URLSnarf** | ✅ Full URLs | ❌ Encrypted | ✅ Yes | ✅ High | 🟢 Low |
| **DNS Logging** | ✅ Domains only | ✅ Domains only | ✅ Yes | 🟡 Medium | 🟢 Very Low |
| **Squid Proxy** | ✅ Full URLs | 🟡 Domains only | ❌ No (proxy) | ✅ High | 🔴 High |
| **iftop** | ❌ No URLs | ❌ No URLs | ✅ Yes | ❌ Bandwidth only | 🟢 Low |
| **SSL Interception** | ✅ Full URLs | ✅ Full URLs | ❌ No (MITM) | ✅ High | 🔴 Very High |

---

## Conclusion

URLSnarf is a powerful tool for monitoring HTTP traffic on OpenWrt routers, providing visibility into network browsing patterns.

### Key Takeaways

**Installation:**
```bash
opkg install urlsnarf
```

**Basic usage:**
```bash
urlsnarf -n -i br-lan
```

**Persistent logging:**
```bash
urlsnarf -n -i br-lan | gzip >> /mnt/usb/logs/urls.log.gz &
```

**Log analysis:**
```bash
zcat /mnt/usb/logs/urls.log.gz | grep "192.168.1.100"
```

### Important Reminders

- ⚠️ **Never log to flash storage** (use USB/external storage only)
- 🔒 **Respect privacy and legal requirements**
- 📊 **Implement log rotation** to manage storage
- 🔐 **HTTPS traffic is encrypted** (URLSnarf can't decrypt it)
- ⚡ **Use `-n` flag** to reduce CPU usage
- 🎯 **Apply BPF filters** for targeted monitoring

### Best Practices

1. **Start simple**: Test with basic command before deploying persistent logging
2. **Monitor resource usage**: Check CPU, memory, and storage regularly
3. **Implement rotation**: Set up automatic log deletion/archiving
4. **Document purpose**: Keep written record of monitoring justification
5. **Secure logs**: Restrict access, consider encryption
6. **Review regularly**: Analyze logs to ensure monitoring meets objectives

### Next Steps

- Set up persistent logging with init script
- Implement log rotation strategy
- Create custom analysis scripts for your use case
- Explore complementary tools (DNS logging, iftop)
- Document your monitoring policy

For more OpenWrt guides, see:
- OPENWRT_CONFIGURATION_GUIDE.md
- OPENWRT_SCRIPTING_GUIDE.md
- OPENWRT_FAILOVER_GUIDE.md

---

**Document History:**

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | October 2025 | Initial comprehensive guide |

**License:** This documentation is provided for educational purposes. URLSnarf is part of the dsniff suite. Use responsibly and in compliance with applicable laws.
