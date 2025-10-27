# OpenWRT Network Traffic Monitoring with URLSnarf Guide

## Table of Contents
1. [Overview](#overview)
2. [Legal and Ethical Considerations](#legal-and-ethical-considerations)
3. [How URLSnarf Works](#how-urlsnarf-works)
4. [Installation](#installation)
5. [Basic Usage](#basic-usage)
6. [Advanced Configuration](#advanced-configuration)
7. [Log Management](#log-management)
8. [Automation and Service Setup](#automation-and-service-setup)
9. [Log Analysis](#log-analysis)
10. [Performance Considerations](#performance-considerations)
11. [Privacy and Security](#privacy-and-security)
12. [Alternatives and Related Tools](#alternatives-and-related-tools)
13. [Troubleshooting](#troubleshooting)

---

## Overview

URLSnarf is a network monitoring tool that captures and logs HTTP requests passing through your OpenWRT router. It's part of the `dsniff` suite of network auditing tools.

### What is URLSnarf?

URLSnarf passively monitors network traffic and extracts:
- **URLs**: Complete HTTP URLs accessed
- **User Agents**: Browser and device information
- **Timestamps**: When requests occurred
- **Source IPs**: Which device made the request
- **HTTP Methods**: GET, POST, etc.

### Use Cases

**Legitimate Uses:**
- **Parental Controls**: Monitor children's internet usage
- **Network Security**: Detect malicious URLs or compromised devices
- **Bandwidth Analysis**: Identify bandwidth-heavy websites
- **Troubleshooting**: Debug network issues
- **Research**: Analyze internet usage patterns
- **Compliance**: Document network activity for auditing

**⚠️ NOT for:**
- Spying on others without consent
- Intercepting confidential information
- Violating privacy laws
- Commercial surveillance without disclosure

### How It Works

```
[Client Device] → [HTTP Request] → [OpenWRT Router] → [URLSnarf] → [Log File]
                                           ↓
                                     [Internet]
```

URLSnarf operates as a **passive sniffer**:
1. Captures packets on specified network interface
2. Filters HTTP traffic (ports 80, 8080, 3128, etc.)
3. Extracts URL and metadata from HTTP headers
4. Writes to log file in Common Log Format

**Important Limitations:**
- ❌ **Cannot capture HTTPS traffic** (SSL/TLS encrypted)
- ❌ Does not work with HTTP/2 or HTTP/3 by default
- ❌ Cannot decrypt VPN traffic
- ✅ Only captures unencrypted HTTP (port 80)

---

## Legal and Ethical Considerations

### Legal Framework

**⚠️ CRITICAL: Know Your Local Laws**

**In many jurisdictions:**
- **Monitoring your own network**: Generally legal
- **Monitoring shared network**: May require disclosure
- **Monitoring workplace**: Usually requires employee notification
- **Monitoring public WiFi**: Heavily regulated or illegal
- **Intercepting others' traffic**: Often illegal without consent

**Recommendations:**
1. **Consult local laws** before implementing
2. **Post clear notice** that network is monitored
3. **Obtain consent** from all network users
4. **Document legitimate purpose**
5. **Secure logs** from unauthorized access

### Ethical Guidelines

**Best Practices:**
- Use for security, not surveillance
- Inform users they're being monitored
- Log only what's necessary
- Respect privacy expectations
- Delete logs when no longer needed
- Don't share logs without authorization

**Example Notice:**
```
NETWORK MONITORING NOTICE

This network is monitored for security and performance purposes.
By using this network, you consent to:
- Logging of URLs visited (non-HTTPS only)
- Recording of timestamps and device identifiers
- Analysis for security threats and bandwidth usage

Contact: admin@example.com for questions.
```

### Privacy Considerations

**What URLSnarf Captures:**
- ✅ HTTP URLs (non-encrypted)
- ✅ Source IP addresses
- ✅ Timestamps
- ✅ User-Agent strings

**What URLSnarf Does NOT Capture:**
- ❌ HTTPS URLs (encrypted)
- ❌ Passwords or credentials (on HTTPS)
- ❌ Email content
- ❌ Encrypted messenger content
- ❌ Banking details (using HTTPS)

**Reality Check:**
Most modern websites use HTTPS (encrypted), so URLSnarf will capture:
- **~5-15%** of web traffic (unencrypted HTTP)
- Advertising networks (some still use HTTP)
- Insecure websites
- HTTP redirect initial requests
- Some mobile app traffic

---

## How URLSnarf Works

### Technical Overview

URLSnarf uses **libpcap** (packet capture library) to:
1. Put network interface in promiscuous mode
2. Capture all packets on the interface
3. Filter for TCP packets on HTTP ports
4. Parse HTTP request headers
5. Extract URL and metadata
6. Format as Common Log Format (CLF)

### Common Log Format (CLF)

URLSnarf output follows Apache CLF standard:

```
192.168.1.100 - - [10/Oct/2024:13:55:36 +0200] "GET http://example.com/page.html HTTP/1.1" 200 - "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
```

**Format breakdown:**
- `192.168.1.100` - Source IP address
- `-` - Remote logname (always dash)
- `-` - Remote user (always dash)
- `[10/Oct/2024:13:55:36 +0200]` - Timestamp
- `GET` - HTTP method
- `http://example.com/page.html` - Requested URL
- `HTTP/1.1` - HTTP version
- `200` - HTTP status code (if available)
- `-` - Referrer
- `Mozilla/5.0...` - User-Agent string

### Network Interfaces

OpenWRT typical interfaces:
- **br-lan**: LAN bridge (wired + wireless LAN)
- **eth0**: WAN interface
- **wlan0**: Wireless interface
- **eth1**: LAN physical interface

**Monitor LAN traffic:** Use `br-lan`
**Monitor WAN traffic:** Use `eth0` (ISP-facing)

---

## Installation

### Prerequisites

```bash
# Update package list
opkg update

# Check available space
df -h
# URLSnarf is small (~50KB), but logs can grow large
```

### Install URLSnarf

**Option 1: Install only URLSnarf (recommended)**

```bash
# Install urlsnarf package
opkg install urlsnarf

# Verify installation
which urlsnarf
# Should output: /usr/sbin/urlsnarf

# Check version
urlsnarf -h
```

**Option 2: Install full dsniff suite**

```bash
# Install complete dsniff package (includes urlsnarf + other tools)
opkg install dsniff

# This includes:
# - urlsnarf (HTTP URL sniffer)
# - dsniff (password sniffer)
# - arpspoof (ARP spoofing)
# - dnsspoof (DNS spoofing)
# - macof (MAC flooding)
# - tcpkill (TCP connection termination)
# And more...
```

### Dependencies

URLSnarf requires:
- `libpcap` (packet capture library)
- `libnids` (network intrusion detection)

These are installed automatically as dependencies.

---

## Basic Usage

### Simple Capture to Screen

```bash
# Capture HTTP traffic on LAN interface
urlsnarf -i br-lan

# Output appears in real-time:
# 192.168.1.100 - - [10/Oct/2024:13:55:36 +0200] "GET http://example.com/ HTTP/1.1"
# 192.168.1.101 - - [10/Oct/2024:13:56:12 +0200] "GET http://news.site.com/article HTTP/1.1"
```

**Stop capture:** Press `Ctrl+C`

### Capture to File

```bash
# Save to file
urlsnarf -i br-lan > /tmp/urls.log

# Run in background
urlsnarf -i br-lan > /tmp/urls.log &

# Check if running
ps | grep urlsnarf
```

### Specify Custom Ports

```bash
# Default ports: 80, 8080, 3128
# Add custom ports with -p
urlsnarf -i br-lan -p 80,8080,3128,8888

# Monitor only port 80
urlsnarf -i br-lan -p 80
```

### Compressed Logging

**Save disk space with gzip compression:**

```bash
# Pipe to gzip (recommended)
urlsnarf -i br-lan | gzip >> /mnt/usb/urls.log.gz

# Run in background
urlsnarf -i br-lan | gzip >> /mnt/usb/urls.log.gz &
```

**View compressed logs:**

```bash
# View entire log
zcat /mnt/usb/urls.log.gz

# View last 50 lines
zcat /mnt/usb/urls.log.gz | tail -50

# Search in compressed log
zgrep "facebook.com" /mnt/usb/urls.log.gz
```

---

## Advanced Configuration

### Filter by Source IP

Using `tcpdump` filter syntax:

```bash
# Monitor specific IP
urlsnarf -i br-lan 'src host 192.168.1.100'

# Monitor IP range
urlsnarf -i br-lan 'src net 192.168.1.0/24'

# Exclude specific IP
urlsnarf -i br-lan 'not src host 192.168.1.1'
```

### Filter by Destination

```bash
# Monitor traffic to specific website
urlsnarf -i br-lan 'dst host 93.184.216.34'  # example.com IP

# Monitor traffic to specific port on destination
urlsnarf -i br-lan 'dst port 8080'
```

### Combine Filters

```bash
# Monitor specific source to specific destination
urlsnarf -i br-lan 'src host 192.168.1.100 and dst port 80'

# Monitor multiple sources
urlsnarf -i br-lan 'src host 192.168.1.100 or src host 192.168.1.101'

# Complex filter
urlsnarf -i br-lan 'src net 192.168.1.0/24 and dst port 80 and not dst host 192.168.1.1'
```

### BPF Filter Syntax

URLSnarf supports Berkeley Packet Filter (BPF) syntax:

**Common operators:**
- `src host [IP]` - Source IP address
- `dst host [IP]` - Destination IP address
- `src net [CIDR]` - Source network
- `dst net [CIDR]` - Destination network
- `src port [PORT]` - Source port
- `dst port [PORT]` - Destination port
- `and` - Logical AND
- `or` - Logical OR
- `not` - Logical NOT

**Examples:**

```bash
# Monitor wireless clients only (assuming wlan0)
urlsnarf -i wlan0

# Monitor traffic not from router itself
urlsnarf -i br-lan 'not src host 192.168.1.1'

# Monitor only HTTP (port 80)
urlsnarf -i br-lan 'tcp port 80'

# Monitor HTTP proxy traffic
urlsnarf -i br-lan 'tcp port 3128'
```

---

## Log Management

### Storage Considerations

**⚠️ Don't write logs to router's flash memory!**

**Why?**
- Flash memory has limited write cycles
- Logs grow continuously
- Will wear out flash quickly
- Router may become unstable

**Solution: Use external storage**

```bash
# Mount USB drive
mkdir -p /mnt/usb
mount /dev/sda1 /mnt/usb

# Write logs to USB
urlsnarf -i br-lan | gzip >> /mnt/usb/urls.log.gz
```

### Log Rotation

Prevent logs from consuming all storage:

**Method 1: Manual rotation**

```bash
# Stop urlsnarf
killall urlsnarf

# Rotate log
mv /mnt/usb/urls.log.gz /mnt/usb/urls.log.$(date +%Y%m%d).gz

# Start urlsnarf again
urlsnarf -i br-lan | gzip >> /mnt/usb/urls.log.gz &
```

**Method 2: Automated rotation with logrotate**

```bash
# Install logrotate
opkg install logrotate

# Create config: /etc/logrotate.d/urlsnarf
cat > /etc/logrotate.d/urlsnarf << 'EOF'
/mnt/usb/urls.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0644 root root
    postrotate
        killall -HUP urlsnarf
    endscript
}
EOF

# Run logrotate daily via cron
echo "0 0 * * * /usr/sbin/logrotate /etc/logrotate.conf" >> /etc/crontabs/root
/etc/init.d/cron restart
```

**Method 3: Size-based rotation**

```bash
# Create rotation script
cat > /root/rotate-urlsnarf.sh << 'EOF'
#!/bin/sh

LOG_FILE="/mnt/usb/urls.log.gz"
MAX_SIZE=10485760  # 10MB in bytes

if [ -f "$LOG_FILE" ]; then
    SIZE=$(stat -c%s "$LOG_FILE")
    if [ $SIZE -gt $MAX_SIZE ]; then
        # Stop urlsnarf
        killall urlsnarf

        # Rotate log
        mv "$LOG_FILE" "${LOG_FILE}.$(date +%Y%m%d_%H%M%S)"

        # Start urlsnarf
        /etc/init.d/urlsnarf start
    fi
fi
EOF

chmod +x /root/rotate-urlsnarf.sh

# Add to cron (check every hour)
echo "0 * * * * /root/rotate-urlsnarf.sh" >> /etc/crontabs/root
```

### Log Cleanup

```bash
# Delete logs older than 30 days
find /mnt/usb -name "urls.log.*" -mtime +30 -delete

# Keep only last 10 log files
ls -t /mnt/usb/urls.log.* | tail -n +11 | xargs rm -f
```

---

## Automation and Service Setup

### Create Init Script

Create `/etc/init.d/urlsnarf`:

```bash
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1
PROG=/usr/sbin/urlsnarf

start_service() {
    procd_open_instance
    procd_set_param command $PROG -i br-lan -p 80,8080,3128
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn
    procd_close_instance
}

stop_service() {
    killall urlsnarf
}
```

**Make executable:**

```bash
chmod +x /etc/init.d/urlsnarf
```

### Advanced Init Script with Logging

Create `/etc/init.d/urlsnarf-log`:

```bash
#!/bin/sh /etc/rc.common

START=99
STOP=10

INTERFACE="br-lan"
PORTS="80,8080,3128"
LOG_DIR="/mnt/usb"
LOG_FILE="$LOG_DIR/urls.log.gz"
PID_FILE="/var/run/urlsnarf.pid"

start() {
    # Check if already running
    if [ -f "$PID_FILE" ] && kill -0 $(cat $PID_FILE) 2>/dev/null; then
        echo "URLSnarf already running"
        return 1
    fi

    # Check if log directory exists
    if [ ! -d "$LOG_DIR" ]; then
        echo "Error: Log directory $LOG_DIR does not exist"
        return 1
    fi

    # Start urlsnarf
    echo "Starting URLSnarf on $INTERFACE"
    /usr/sbin/urlsnarf -i $INTERFACE -p $PORTS | gzip >> $LOG_FILE &
    echo $! > $PID_FILE

    echo "URLSnarf started with PID $(cat $PID_FILE)"
}

stop() {
    if [ -f "$PID_FILE" ]; then
        echo "Stopping URLSnarf"
        kill $(cat $PID_FILE)
        rm -f $PID_FILE
        echo "URLSnarf stopped"
    else
        echo "URLSnarf not running"
    fi
}

restart() {
    stop
    sleep 2
    start
}

status() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat $PID_FILE) 2>/dev/null; then
        echo "URLSnarf is running (PID: $(cat $PID_FILE))"
        return 0
    else
        echo "URLSnarf is not running"
        return 1
    fi
}
```

### Enable Service

```bash
# Make executable
chmod +x /etc/init.d/urlsnarf-log

# Enable on boot
/etc/init.d/urlsnarf-log enable

# Start service
/etc/init.d/urlsnarf-log start

# Check status
/etc/init.d/urlsnarf-log status

# View logs
zcat /mnt/usb/urls.log.gz | tail -20
```

### Disable Service

```bash
# Stop service
/etc/init.d/urlsnarf-log stop

# Disable from boot
/etc/init.d/urlsnarf-log disable
```

---

## Log Analysis

### Basic Analysis Commands

**Count total requests:**

```bash
zcat /mnt/usb/urls.log.gz | wc -l
```

**View most recent requests:**

```bash
zcat /mnt/usb/urls.log.gz | tail -50
```

**Search for specific domain:**

```bash
zgrep "facebook.com" /mnt/usb/urls.log.gz
```

**Count requests per IP:**

```bash
zcat /mnt/usb/urls.log.gz | awk '{print $1}' | sort | uniq -c | sort -rn
```

**Top 10 visited domains:**

```bash
zcat /mnt/usb/urls.log.gz | awk '{print $7}' | sed 's|http://||' | sed 's|/.*||' | sort | uniq -c | sort -rn | head -10
```

**Requests by date:**

```bash
zcat /mnt/usb/urls.log.gz | awk -F'[' '{print $2}' | awk -F':' '{print $1}' | sort | uniq -c
```

**Filter by time range:**

```bash
# Requests from specific day
zgrep "10/Oct/2024" /mnt/usb/urls.log.gz

# Requests from specific hour
zgrep "10/Oct/2024:14:" /mnt/usb/urls.log.gz
```

### Advanced Analysis Script

Create `/root/analyze-urls.sh`:

```bash
#!/bin/bash

LOG_FILE="/mnt/usb/urls.log.gz"

echo "=== URLSnarf Log Analysis ==="
echo ""

# Total requests
TOTAL=$(zcat $LOG_FILE | wc -l)
echo "Total requests: $TOTAL"
echo ""

# Unique IPs
UNIQUE_IPS=$(zcat $LOG_FILE | awk '{print $1}' | sort -u | wc -l)
echo "Unique IP addresses: $UNIQUE_IPS"
echo ""

# Top 10 IPs
echo "Top 10 source IPs:"
zcat $LOG_FILE | awk '{print $1}' | sort | uniq -c | sort -rn | head -10
echo ""

# Top 10 domains
echo "Top 10 visited domains:"
zcat $LOG_FILE | awk '{print $7}' | sed 's|http://||' | sed 's|/.*||' | sort | uniq -c | sort -rn | head -10
echo ""

# Requests by hour
echo "Requests by hour (last 24h):"
zcat $LOG_FILE | tail -10000 | awk -F'[' '{print $2}' | awk -F':' '{print $2":00"}' | sort | uniq -c | tail -24
echo ""

# Most active user agent
echo "Top 5 user agents:"
zcat $LOG_FILE | awk -F'"' '{print $6}' | sort | uniq -c | sort -rn | head -5
echo ""
```

Make executable and run:

```bash
chmod +x /root/analyze-urls.sh
/root/analyze-urls.sh
```

### Export to CSV

```bash
# Convert log to CSV
cat > /root/urls-to-csv.sh << 'EOF'
#!/bin/bash

LOG_FILE="/mnt/usb/urls.log.gz"
CSV_FILE="/mnt/usb/urls.csv"

echo "IP,Timestamp,Method,URL,UserAgent" > $CSV_FILE

zcat $LOG_FILE | while read line; do
    IP=$(echo "$line" | awk '{print $1}')
    TIMESTAMP=$(echo "$line" | awk -F'[' '{print $2}' | awk -F']' '{print $1}')
    METHOD=$(echo "$line" | awk -F'"' '{print $2}' | awk '{print $1}')
    URL=$(echo "$line" | awk -F'"' '{print $2}' | awk '{print $2}')
    UA=$(echo "$line" | awk -F'"' '{print $6}')

    echo "$IP,\"$TIMESTAMP\",$METHOD,\"$URL\",\"$UA\"" >> $CSV_FILE
done

echo "CSV export complete: $CSV_FILE"
EOF

chmod +x /root/urls-to-csv.sh
/root/urls-to-csv.sh
```

---

## Performance Considerations

### System Impact

URLSnarf resource usage:
- **CPU**: Low (1-5% on typical router)
- **RAM**: 5-10 MB
- **Disk I/O**: Moderate (continuous writes)
- **Network**: Negligible (passive monitoring)

### Performance Issues

**Symptoms:**
- Router sluggishness
- High CPU usage
- Log writing delays
- Network slowdowns

**Causes:**
- Monitoring high-traffic interface
- Writing to slow storage (flash)
- Insufficient RAM
- CPU overload

**Solutions:**

1. **Reduce monitoring scope:**
```bash
# Monitor only specific IPs
urlsnarf -i br-lan 'src host 192.168.1.100'

# Monitor only port 80 (skip 8080, 3128)
urlsnarf -i br-lan -p 80
```

2. **Buffer writes:**
```bash
# Add buffer (requires stdbuf utility)
opkg install coreutils-stdbuf
urlsnarf -i br-lan | stdbuf -oL cat | gzip >> /mnt/usb/urls.log.gz
```

3. **Lower logging frequency:**
```bash
# Sample every 10th packet (requires custom filtering)
# Not directly supported by urlsnarf
```

4. **Use faster storage:**
- USB 3.0 drive instead of USB 2.0
- High-quality USB drive with good write speeds

### Monitoring Performance

```bash
# Check CPU usage
top

# Check memory usage
free

# Check disk I/O
iostat

# Check URLSnarf process
ps aux | grep urlsnarf

# Monitor log file growth
watch -n 60 'ls -lh /mnt/usb/urls.log.gz'
```

---

## Privacy and Security

### Protecting Log Files

**Set proper permissions:**

```bash
# Restrict access to logs
chmod 600 /mnt/usb/urls.log.gz
chown root:root /mnt/usb/urls.log.gz

# Restrict log directory
chmod 700 /mnt/usb
```

**Encrypt logs:**

```bash
# Install encryption tools
opkg install gnupg

# Encrypt log file
gpg --symmetric --cipher-algo AES256 /mnt/usb/urls.log.gz

# Decrypt when needed
gpg --decrypt /mnt/usb/urls.log.gz.gpg | zcat | less
```

### Secure Log Access

**Create read-only viewer user:**

```bash
# Create user (if supported)
opkg install shadow-useradd
useradd -m logviewer

# Grant read access only
chown root:logviewer /mnt/usb/urls.log.gz
chmod 640 /mnt/usb/urls.log.gz
```

### Log Retention Policy

**Recommended:**
- Keep logs for 30-90 days maximum
- Delete after investigation complete
- Document retention policy
- Comply with local data protection laws (GDPR, etc.)

---

## Alternatives and Related Tools

### tcpdump

More flexible packet capture tool:

```bash
# Install tcpdump
opkg install tcpdump

# Capture HTTP traffic
tcpdump -i br-lan -A -s 0 'tcp port 80' -w /mnt/usb/http.pcap

# View captured data
tcpdump -r /mnt/usb/http.pcap -A

# Extract URLs
tcpdump -r /mnt/usb/http.pcap -A | grep "GET\|POST"
```

### ngrep

Network grep for packet data:

```bash
# Install ngrep
opkg install ngrep

# Search for specific patterns
ngrep -q -W byline 'GET|POST' 'tcp port 80'

# Filter by domain
ngrep -q 'Host: .*facebook.com' 'tcp port 80'
```

### Wireshark (Remote Capture)

Capture on OpenWRT, analyze on PC:

```bash
# On OpenWRT
tcpdump -i br-lan -U -w - 'tcp port 80' | nc 192.168.1.100 9999

# On PC with Wireshark installed
nc -l 9999 | wireshark -k -i -
```

### squid (Transparent Proxy)

More comprehensive logging:

```bash
# Install squid
opkg install squid

# Configure as transparent proxy
# Logs all HTTP/HTTPS requests (HTTPS via CONNECT method only)
# See /var/log/squid/access.log
```

### Comparison

| Tool | HTTP URLs | HTTPS URLs | Ease of Use | Resource Usage | Detail Level |
|------|-----------|------------|-------------|----------------|--------------|
| urlsnarf | ✅ Yes | ❌ No | Easy | Low | Medium |
| tcpdump | ✅ Yes | ❌ No | Medium | Medium | High |
| ngrep | ✅ Yes | ❌ No | Medium | Low | Medium |
| squid | ✅ Yes | ⚠️ Limited | Hard | High | High |

---

## Troubleshooting

### URLSnarf Not Capturing Any Data

**Check if running:**
```bash
ps | grep urlsnarf
```

**Check interface name:**
```bash
# List interfaces
ifconfig

# Common interface names:
# - br-lan (LAN bridge)
# - eth0 (WAN)
# - wlan0 (WiFi)

# Test correct interface
urlsnarf -i br-lan
```

**Check for HTTP traffic:**
```bash
# Verify HTTP traffic exists
tcpdump -i br-lan -n 'tcp port 80' -c 10

# If no output, no HTTP traffic (most sites use HTTPS)
```

**Test with known HTTP site:**
```bash
# From client device, visit: http://neverssl.com
# Should appear in urlsnarf output
```

### Permission Denied

**Error:** `urlsnarf: permission denied`

**Solution:** Run as root
```bash
# Check user
whoami

# Run as root
sudo urlsnarf -i br-lan

# Or login as root first
su -
urlsnarf -i br-lan
```

### Interface Not Found

**Error:** `urlsnarf: no suitable device found`

**Solution:**
```bash
# Check available interfaces
ifconfig -a

# Use correct interface name
urlsnarf -i br-lan  # Not eth0 if using bridge
```

### Log File Not Created

**Check disk space:**
```bash
df -h /mnt/usb
```

**Check permissions:**
```bash
ls -la /mnt/usb
chmod 755 /mnt/usb
```

**Check mount:**
```bash
mount | grep usb
# If not mounted, mount USB drive first
```

### High CPU Usage

**Reduce scope:**
```bash
# Monitor only port 80
urlsnarf -i br-lan -p 80

# Monitor only specific IP
urlsnarf -i br-lan 'src host 192.168.1.100'
```

**Check for high traffic:**
```bash
# Monitor traffic volume
iftop -i br-lan

# If very high traffic, URLSnarf may struggle
```

### Logs Show Only HTTPS Requests

**This is normal!**

Most modern websites use HTTPS (encrypted). URLSnarf cannot capture HTTPS URLs.

**What you'll see for HTTPS:**
- Initial HTTP redirect (if any)
- HTTP resources loaded by HTTPS pages
- Advertising networks still using HTTP

**Solution:**
- Accept limitation (cannot decrypt HTTPS without SSL interception)
- Use squid proxy for CONNECT method logging (doesn't reveal actual HTTPS URLs)
- Focus on security monitoring rather than content monitoring

---

## Conclusion

URLSnarf is a simple but effective tool for monitoring HTTP traffic on OpenWRT routers.

### Key Takeaways

✅ **Use Cases:**
- Parental controls
- Network security monitoring
- Bandwidth analysis
- Troubleshooting

✅ **Limitations:**
- Cannot capture HTTPS (encrypted traffic)
- Only works on HTTP (port 80, 8080, etc.)
- Most modern websites use HTTPS (~90%+)

✅ **Best Practices:**
- Obtain consent from monitored users
- Post clear notice of monitoring
- Store logs on external storage (not flash)
- Rotate logs regularly
- Secure log files (permissions, encryption)
- Delete logs when no longer needed

✅ **Legal/Ethical:**
- Know your local laws
- Respect privacy
- Use for security, not surveillance
- Document legitimate purpose

### Recommendations

**For Basic Monitoring:**
- Use URLSnarf with log rotation
- Store on USB drive
- Monitor br-lan interface
- Accept HTTPS limitation

**For Advanced Monitoring:**
- Consider squid proxy (more comprehensive)
- Use tcpdump for detailed analysis
- Implement transparent proxy for better visibility

**For Production:**
- Research commercial solutions
- Consider privacy implications
- Implement proper data protection
- Consult legal counsel

### Modern Reality

⚠️ **Important Note:**

Due to widespread HTTPS adoption, URLSnarf now captures only **5-15% of web traffic**. For comprehensive monitoring:
- Use in combination with other tools
- Focus on security monitoring (malware, exploits)
- Accept limited visibility
- Consider DNS-based monitoring as alternative

### Resources

- dsniff documentation: https://www.monkey.org/~dugsong/dsniff/
- OpenWRT documentation: https://openwrt.org/docs/
- tcpdump tutorial: https://www.tcpdump.org/
- BPF filter syntax: https://biot.com/capstats/bpf.html

---

*Document Version: 1.0*
*Last Updated: 2025*
*Based on: https://eko.one.pl/?p=openwrt-urlsnarf*
*Compatible with: OpenWRT 19.07+*

**⚠️ LEGAL DISCLAIMER:**
*This guide is for educational and legitimate security purposes only. Users are responsible for complying with all applicable laws and regulations regarding network monitoring and privacy. Always obtain appropriate consent before monitoring network traffic. The authors assume no liability for misuse of this information.*
