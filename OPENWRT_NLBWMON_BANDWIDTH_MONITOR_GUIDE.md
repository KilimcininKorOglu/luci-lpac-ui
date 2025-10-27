# OpenWRT nlbwmon Network Bandwidth Monitor Guide

## Table of Contents
1. [Overview](#overview)
2. [Features and Capabilities](#features-and-capabilities)
3. [How nlbwmon Works](#how-nlbwmon-works)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Web Interface (LuCI)](#web-interface-luci)
7. [Command-Line Usage](#command-line-usage)
8. [Data Analysis](#data-analysis)
9. [Database Management](#database-management)
10. [Advanced Configuration](#advanced-configuration)
11. [Performance Considerations](#performance-considerations)
12. [Troubleshooting](#troubleshooting)
13. [Use Cases](#use-cases)

---

## Overview

**nlbwmon** (Netlink Bandwidth Monitor) is a lightweight, efficient network traffic accounting daemon for OpenWRT. Unlike traditional bandwidth monitors that use packet capture, nlbwmon leverages the kernel's netlink connection tracking subsystem for minimal CPU overhead.

### What is nlbwmon?

nlbwmon monitors and records:
- **Per-host traffic**: Upload/download data per IP/MAC address
- **Protocol statistics**: TCP, UDP, ICMP, and application protocols
- **Connection tracking**: Number of connections per host
- **IPv4 and IPv6**: Dual-stack support
- **Layer 7 protocols**: HTTP, HTTPS, DNS, SSH, etc.

### Key Advantages

- ✅ **Low CPU overhead** - Uses kernel netlink, not packet capture
- ✅ **Lightweight** - Small memory footprint (~1-2MB RAM)
- ✅ **Persistent storage** - Survives reboots (when configured)
- ✅ **Flexible reporting** - Web interface and command-line tools
- ✅ **Protocol detection** - Identifies applications by port/protocol
- ✅ **No network impact** - Passive monitoring, no performance degradation

### Comparison with Other Tools

| Feature | nlbwmon | wrtbwmon | vnstat | iftop |
|---------|---------|----------|--------|-------|
| CPU Usage | Very Low | Medium | Low | Medium |
| RAM Usage | Low (1-2MB) | Medium | Low | Medium |
| Per-host stats | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| Protocol detection | ✅ Yes | ❌ No | ❌ No | ⚠️ Limited |
| Historical data | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| Web interface | ✅ Yes | ✅ Yes | ❌ No | ❌ No |
| Real-time view | ❌ No | ⚠️ Limited | ❌ No | ✅ Yes |

**nlbwmon is best for:**
- Long-term traffic accounting
- Per-device usage tracking
- Protocol-level analysis
- Monthly/yearly statistics

---

## Features and Capabilities

### Traffic Monitoring

**Per-Host Statistics:**
- IP address (IPv4/IPv6)
- MAC address
- Upload bytes/packets
- Download bytes/packets
- Total traffic
- Connection counts

**Protocol Classification:**
- Layer 3: IP, IPv6
- Layer 4: TCP, UDP, ICMP, IGMP, GRE, ESP
- Layer 7: HTTP, HTTPS, DNS, SSH, FTP, SMTP, etc.

**Time Periods:**
- Monthly (default)
- Daily
- Hourly (if configured)
- Custom intervals

### Data Collection

**What nlbwmon tracks:**
- Source/destination IP addresses
- MAC addresses (via ARP)
- Connection states (established, closed)
- Protocol and port numbers
- Data transfer volumes (bytes/packets)
- Connection timestamps

**What nlbwmon does NOT track:**
- Packet contents (payload)
- URLs or domains (beyond DNS queries)
- User identity (only IP/MAC)
- Application names (only ports)

### Storage and Reporting

**Database:**
- Default location: `/var/lib/nlbwmon/`
- Format: Binary database
- Commit interval: 24 hours (configurable)
- Rotation: Monthly by default

**Output Formats:**
- Web interface (LuCI): Interactive charts and tables
- Command-line: Text, JSON, CSV

---

## How nlbwmon Works

### Architecture

```
[Kernel Netfilter] → [conntrack] → [netlink] → [nlbwmon daemon]
                                                        ↓
                                                 [Database]
                                                        ↓
                                              [Web Interface/CLI]
```

**Components:**

1. **Kernel conntrack**: Tracks active network connections
2. **Netlink interface**: Provides connection events to userspace
3. **nlbwmon daemon**: Receives events, aggregates data
4. **Database**: Stores accumulated statistics
5. **Reporting tools**: Display and analyze data

### Data Flow

1. **Connection starts**: Client device initiates connection
2. **Conntrack registers**: Kernel tracks connection
3. **nlbwmon receives**: Daemon gets notification via netlink
4. **Data accumulation**: Traffic bytes/packets counted
5. **Periodic commit**: Data written to database (24h default)
6. **Connection ends**: Conntrack removes entry
7. **Monthly rotation**: Database archived, new period starts

### Why Netlink is Efficient

**Traditional packet capture (pcap):**
- Every packet copied to userspace
- High CPU overhead
- Processes entire packet

**Netlink conntrack approach:**
- Only connection events monitored
- Minimal CPU usage
- No packet copying
- Kernel does the work

---

## Installation

### Prerequisites

```bash
# Update package list
opkg update

# Check available space
df -h
# nlbwmon requires ~5-20MB for database (depending on network size)
```

### Install nlbwmon

```bash
# Install nlbwmon daemon
opkg install nlbwmon

# Install LuCI web interface (optional but recommended)
opkg install luci-app-nlbwmon

# Verify installation
which nlbwmon
# Output: /usr/sbin/nlbwmon

which nlbw
# Output: /usr/bin/nlbw
```

### Check Installation

```bash
# List nlbwmon files
opkg files nlbwmon

# Key files:
# /usr/sbin/nlbwmon - Main daemon
# /usr/bin/nlbw - CLI tool
# /etc/config/nlbwmon - Configuration
# /etc/init.d/nlbwmon - Init script
```

---

## Configuration

### Basic Configuration

Edit `/etc/config/nlbwmon`:

```conf
config nlbwmon
    # Enable monitoring
    option enabled '1'

    # Network to monitor (local network)
    option local_network '192.168.1.0/24'

    # Database directory
    option database_directory '/var/lib/nlbwmon'

    # Commit interval (seconds) - how often to write to disk
    option commit_interval '86400'  # 24 hours

    # Refresh interval (seconds) - data collection granularity
    option refresh_interval '30'  # 30 seconds

    # Protocol database for service name resolution
    option protocol_database '/usr/share/nlbwmon/protocols'

    # Database generations to keep (monthly archives)
    option database_generations '10'  # Keep 10 months

    # Database limit (KB)
    option database_limit '10000'  # 10MB max database size

    # Compressed archives
    option database_compress '1'  # Compress old databases
```

**Configuration options explained:**

**enabled** (`0` or `1`):
- Enable or disable monitoring
- Default: `1` (enabled)

**local_network** (IP/CIDR):
- Networks to monitor
- Can specify multiple networks
- Default: `192.168.1.0/24`

**database_directory** (path):
- Where to store database files
- `/var/lib/nlbwmon` (RAM) - lost on reboot
- `/mnt/usb/nlbwmon` (USB) - persistent

**commit_interval** (seconds):
- How often to write data to disk
- Smaller = more frequent writes, less data loss on crash
- Larger = better performance, more data loss on crash
- Default: `86400` (24 hours)

**refresh_interval** (seconds):
- Data collection granularity
- Smaller = more accurate, higher CPU
- Default: `30` seconds

**database_generations** (number):
- How many monthly archives to keep
- Default: `10` (10 months of history)

**database_limit** (KB):
- Maximum database size per period
- Prevents runaway disk usage
- Default: `10000` (10MB)

### Multiple Networks

**Monitor multiple subnets:**

```conf
config nlbwmon
    option enabled '1'
    list local_network '192.168.1.0/24'
    list local_network '192.168.2.0/24'
    list local_network '10.0.0.0/8'
```

### Persistent Storage

**⚠️ Important:** Default location `/var/lib/nlbwmon` is in RAM (lost on reboot).

**Use USB storage for persistence:**

```bash
# Create directory on USB
mkdir -p /mnt/usb/nlbwmon

# Update configuration
uci set nlbwmon.@nlbwmon[0].database_directory='/mnt/usb/nlbwmon'
uci commit nlbwmon

# Restart nlbwmon
/etc/init.d/nlbwmon restart
```

### Start nlbwmon

```bash
# Enable service (start on boot)
/etc/init.d/nlbwmon enable

# Start service
/etc/init.d/nlbwmon start

# Check status
/etc/init.d/nlbwmon status

# Verify running
ps | grep nlbwmon
# Output: 12345 root      1234 S    /usr/sbin/nlbwmon
```

---

## Web Interface (LuCI)

### Access LuCI Interface

1. Navigate to: **Statistics → Bandwidth Monitor**
2. Or: **Status → Bandwidth Monitor** (depending on LuCI version)

### Web Interface Features

**Overview Tab:**
- Pie charts showing traffic distribution
- Top consumers
- Protocol breakdown
- Upload/download totals

**Display Options:**
- Group by: IP Address, MAC Address, Family (IPv4/IPv6), Protocol
- Time period: Current, Previous months
- Sort by: Traffic, Connections, Protocol

**Actions:**
- Download database backup (CSV/JSON)
- Clear current database
- Archive current period

### Interactive Charts

**Traffic by Host:**
- Visual representation of per-device usage
- Hover for details
- Click to filter

**Protocol Distribution:**
- Pie chart showing protocol usage
- HTTP, HTTPS, DNS, etc.
- Bandwidth per protocol

**Top Consumers:**
- Table of highest bandwidth users
- Sortable columns
- Download/upload breakdown

### Export Data

**Download reports:**
1. Web interface → "Download" button
2. Choose format: CSV or JSON
3. Opens in browser or saves file

**CSV format:**
```csv
IP,MAC,Family,Protocol,Connections,RX_Bytes,RX_Packets,TX_Bytes,TX_Packets
192.168.1.100,aa:bb:cc:dd:ee:ff,IPv4,TCP,152,12345678,98765,2345678,45678
```

**JSON format:**
```json
{
  "192.168.1.100": {
    "mac": "aa:bb:cc:dd:ee:ff",
    "download": 12345678,
    "upload": 2345678,
    "protocols": {
      "tcp": {"rx": 10000000, "tx": 2000000},
      "udp": {"rx": 2345678, "tx": 345678}
    }
  }
}
```

---

## Command-Line Usage

### nlbw Command

**Basic usage:**

```bash
# Show current statistics
nlbw

# Output:
# Database: /var/lib/nlbwmon/2024-10.db
#
# IP Address       MAC Address        Download    Upload      Total
# 192.168.1.100    aa:bb:cc:dd:ee:ff  1.2 GB      345 MB      1.5 GB
# 192.168.1.101    11:22:33:44:55:66  567 MB      123 MB      690 MB
```

### Output Formats

**Human-readable (default):**

```bash
nlbw
```

**JSON output:**

```bash
nlbw -j

# Or
nlbw --json
```

**CSV output:**

```bash
nlbw -c

# Or
nlbw --csv
```

### Filtering Options

**Group by IP address:**

```bash
nlbw -g ip
```

**Group by MAC address:**

```bash
nlbw -g mac
```

**Group by protocol:**

```bash
nlbw -g protocol
```

**Group by family (IPv4/IPv6):**

```bash
nlbw -g family
```

### Time Period Selection

**Show specific month:**

```bash
# List available periods
ls /var/lib/nlbwmon/

# Show specific period
nlbw -p 2024-09

# Show current period (default)
nlbw
```

### Advanced Queries

**Top 10 consumers:**

```bash
nlbw | head -11
```

**Filter by IP:**

```bash
nlbw | grep 192.168.1.100
```

**Total traffic:**

```bash
nlbw -j | jq '.stats.total'
```

**Protocol breakdown:**

```bash
nlbw -g protocol
```

---

## Data Analysis

### Analyze Traffic Patterns

**Find bandwidth hogs:**

```bash
# Top 5 download users
nlbw -c | sort -t',' -k6 -nr | head -5

# Top 5 upload users
nlbw -c | sort -t',' -k8 -nr | head -5
```

**Protocol usage:**

```bash
# Show traffic by protocol
nlbw -g protocol

# Export protocol stats to CSV
nlbw -g protocol -c > protocol-stats.csv
```

**Identify heavy connections:**

```bash
# Hosts with most connections
nlbw -c | sort -t',' -k5 -nr | head -10
```

### Calculate Statistics

**Total monthly usage:**

```bash
# Using JSON output
nlbw -j | jq '.stats.total.bytes' | awk '{print $1/1024/1024/1024 " GB"}'
```

**Average per device:**

```bash
# Count devices and calculate average
DEVICES=$(nlbw | tail -n +4 | wc -l)
TOTAL=$(nlbw -j | jq '.stats.total.bytes')
echo "Average: $(($TOTAL / $DEVICES / 1024 / 1024)) MB per device"
```

### Generate Reports

**Create monthly report script:**

```bash
cat > /root/nlbwmon-report.sh << 'EOF'
#!/bin/sh

MONTH=$(date +%Y-%m)
REPORT="/mnt/usb/reports/nlbwmon-$MONTH.txt"

mkdir -p /mnt/usb/reports

echo "=== Network Bandwidth Report for $MONTH ===" > $REPORT
echo "" >> $REPORT

echo "Top 10 Consumers:" >> $REPORT
nlbw | head -14 >> $REPORT

echo "" >> $REPORT
echo "Protocol Breakdown:" >> $REPORT
nlbw -g protocol >> $REPORT

echo "" >> $REPORT
echo "Total Traffic:" >> $REPORT
nlbw -j | jq '.stats.total' >> $REPORT

# Export CSV
nlbw -c > "/mnt/usb/reports/nlbwmon-$MONTH.csv"

echo "Report generated: $REPORT"
EOF

chmod +x /root/nlbwmon-report.sh

# Run monthly
echo "0 0 1 * * /root/nlbwmon-report.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

---

## Database Management

### Database Location

**Default (RAM, non-persistent):**
```
/var/lib/nlbwmon/
```

**Files:**
- `YYYY-MM.db` - Current month database
- `YYYY-MM.db.gz` - Archived/compressed older months

### Backup Database

**Manual backup:**

```bash
# Backup to USB
cp -r /var/lib/nlbwmon /mnt/usb/nlbwmon-backup-$(date +%Y%m%d)

# Or create tar archive
tar czf /mnt/usb/nlbwmon-backup.tar.gz /var/lib/nlbwmon
```

**Automated backup script:**

```bash
cat > /root/backup-nlbwmon.sh << 'EOF'
#!/bin/sh

BACKUP_DIR="/mnt/usb/nlbwmon-backups"
DATE=$(date +%Y%m%d)

mkdir -p $BACKUP_DIR

# Backup database
tar czf $BACKUP_DIR/nlbwmon-$DATE.tar.gz /var/lib/nlbwmon

# Keep only last 30 days
find $BACKUP_DIR -name "nlbwmon-*.tar.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR/nlbwmon-$DATE.tar.gz"
EOF

chmod +x /root/backup-nlbwmon.sh

# Run daily
echo "0 2 * * * /root/backup-nlbwmon.sh" >> /etc/crontabs/root
```

### Restore Database

```bash
# Stop nlbwmon
/etc/init.d/nlbwmon stop

# Restore from backup
tar xzf /mnt/usb/nlbwmon-backup.tar.gz -C /

# Start nlbwmon
/etc/init.d/nlbwmon start
```

### Clear Database

**Clear current period:**

```bash
# Via web interface: Delete button

# Or via command line
/etc/init.d/nlbwmon stop
rm /var/lib/nlbwmon/*.db
/etc/init.d/nlbwmon start
```

**Clear all data:**

```bash
/etc/init.d/nlbwmon stop
rm -rf /var/lib/nlbwmon/*
/etc/init.d/nlbwmon start
```

### Database Rotation

**Manual rotation (start new period):**

```bash
# Archive current database
/etc/init.d/nlbwmon stop
mv /var/lib/nlbwmon/$(date +%Y-%m).db /var/lib/nlbwmon/$(date +%Y-%m).db.archive
/etc/init.d/nlbwmon start
```

**Automatic rotation:**
- Happens automatically on month change
- Old databases compressed to `.db.gz`
- Configurable retention via `database_generations`

---

## Advanced Configuration

### Custom Protocol Database

**Edit protocol mappings:**

```bash
# Copy default protocol database
cp /usr/share/nlbwmon/protocols /etc/nlbwmon-protocols

# Edit custom mappings
vi /etc/nlbwmon-protocols

# Add custom entries:
# Format: port/protocol name
8080/tcp Custom-HTTP
9000/tcp Custom-App

# Update configuration
uci set nlbwmon.@nlbwmon[0].protocol_database='/etc/nlbwmon-protocols'
uci commit nlbwmon
/etc/init.d/nlbwmon restart
```

### Ignore Specific Traffic

**Via iptables marking (not directly supported by nlbwmon):**

nlbwmon monitors all conntrack entries. To exclude traffic, prevent it from being tracked:

```bash
# Example: Exclude local DNS queries
iptables -t raw -A PREROUTING -p udp --dport 53 -s 192.168.1.0/24 -d 192.168.1.1 -j NOTRACK
iptables -t raw -A OUTPUT -p udp --sport 53 -d 192.168.1.0/24 -s 192.168.1.1 -j NOTRACK
```

### Integration with Other Tools

**Export to external monitoring:**

```bash
# Export JSON for processing
nlbw -j > /tmp/nlbwmon-data.json

# Send to external server
curl -X POST -H "Content-Type: application/json" \
  -d @/tmp/nlbwmon-data.json \
  http://monitoring-server/api/bandwidth

# Or use MQTT
mosquitto_pub -h mqtt-server -t "network/bandwidth" -f /tmp/nlbwmon-data.json
```

### Alerting on High Usage

**Create alert script:**

```bash
cat > /root/nlbwmon-alert.sh << 'EOF'
#!/bin/sh

THRESHOLD_GB=50  # Alert if any device exceeds 50GB

nlbw -j | jq -r '.hosts[] | select(.total.bytes > '$((THRESHOLD_GB * 1024 * 1024 * 1024))') | "\(.ip) has used \(.total.bytes / 1024 / 1024 / 1024)GB"' | while read ALERT; do
    echo "ALERT: $ALERT"
    logger -t nlbwmon-alert "$ALERT"
    # Send email or notification
    # echo "$ALERT" | mail -s "Bandwidth Alert" admin@example.com
done
EOF

chmod +x /root/nlbwmon-alert.sh

# Run daily
echo "0 0 * * * /root/nlbwmon-alert.sh" >> /etc/crontabs/root
```

---

## Performance Considerations

### Resource Usage

**Typical nlbwmon usage:**
- **CPU**: 0.1-1% (idle to moderate traffic)
- **RAM**: 1-3MB (depending on number of tracked hosts)
- **Disk I/O**: Minimal (only during commits)
- **Storage**: 5-50MB per month (depends on network size)

### Optimization Tips

**1. Adjust commit interval:**

```conf
# More frequent commits = better data safety, more I/O
option commit_interval '3600'  # 1 hour

# Less frequent commits = better performance, potential data loss
option commit_interval '172800'  # 48 hours
```

**2. Limit database size:**

```conf
# Prevent runaway growth
option database_limit '20000'  # 20MB max
```

**3. Reduce refresh interval:**

```conf
# Less frequent = lower CPU, less accurate
option refresh_interval '60'  # 60 seconds instead of 30
```

**4. Use compressed archives:**

```conf
# Compress old databases
option database_compress '1'
```

**5. Limit generations:**

```conf
# Keep fewer months
option database_generations '6'  # 6 months instead of 10
```

### Monitoring nlbwmon Performance

```bash
# Check CPU usage
top | grep nlbwmon

# Check memory usage
ps aux | grep nlbwmon

# Check database size
du -sh /var/lib/nlbwmon

# Check commit frequency
logread | grep nlbwmon | grep commit
```

---

## Troubleshooting

### nlbwmon Not Collecting Data

**Check service running:**

```bash
/etc/init.d/nlbwmon status

# If not running, start it
/etc/init.d/nlbwmon start
```

**Check configuration:**

```bash
# Verify local_network is correct
uci show nlbwmon | grep local_network

# Should match your LAN subnet
```

**Check conntrack enabled:**

```bash
# Verify conntrack module loaded
lsmod | grep nf_conntrack

# If missing, load it
insmod nf_conntrack
```

**Check netlink permissions:**

```bash
# nlbwmon needs root access
ps aux | grep nlbwmon
# Should show: root
```

### No Data in Web Interface

**Check LuCI app installed:**

```bash
opkg list-installed | grep luci-app-nlbwmon
```

**Clear browser cache:**
- Force refresh: Ctrl+F5 (Windows/Linux) or Cmd+Shift+R (Mac)

**Check database location:**

```bash
ls -la /var/lib/nlbwmon/

# Should contain .db files
```

**Restart services:**

```bash
/etc/init.d/nlbwmon restart
/etc/init.d/uhttpd restart  # Restart web server
```

### Database Corruption

**Symptoms:**
- nlbw command fails
- Web interface shows errors
- Service crashes

**Solution:**

```bash
# Stop service
/etc/init.d/nlbwmon stop

# Backup database (if possible)
cp -r /var/lib/nlbwmon /tmp/nlbwmon-backup

# Remove corrupted database
rm /var/lib/nlbwmon/*.db

# Start service (creates new database)
/etc/init.d/nlbwmon start
```

### High CPU Usage

**Check commit interval:**

```bash
uci show nlbwmon | grep commit_interval

# Increase if too low
uci set nlbwmon.@nlbwmon[0].commit_interval='86400'
uci commit nlbwmon
/etc/init.d/nlbwmon restart
```

**Check database size:**

```bash
du -h /var/lib/nlbwmon/

# If very large, reduce generations
uci set nlbwmon.@nlbwmon[0].database_generations='3'
uci set nlbwmon.@nlbwmon[0].database_limit='5000'
uci commit nlbwmon
```

### Data Loss After Reboot

**Problem:** Database in RAM lost on reboot

**Solution:** Move to persistent storage

```bash
# Create directory on USB
mkdir -p /mnt/usb/nlbwmon

# Move existing data
mv /var/lib/nlbwmon/* /mnt/usb/nlbwmon/

# Update configuration
uci set nlbwmon.@nlbwmon[0].database_directory='/mnt/usb/nlbwmon'
uci commit nlbwmon

# Restart service
/etc/init.d/nlbwmon restart
```

---

## Use Cases

### Use Case 1: Home Network Monitoring

**Scenario:** Track family member internet usage

```bash
# Configure for home network
uci set nlbwmon.@nlbwmon[0].local_network='192.168.1.0/24'
uci set nlbwmon.@nlbwmon[0].database_directory='/mnt/usb/nlbwmon'
uci set nlbwmon.@nlbwmon[0].database_generations='12'  # 1 year history
uci commit nlbwmon

# View usage via web interface
# Identify bandwidth-heavy devices
# Set usage limits if needed
```

### Use Case 2: Small Office

**Scenario:** Monitor employee internet usage for billing/compliance

```bash
# Monthly reports for management
/root/nlbwmon-report.sh

# Export for accounting
nlbw -c > /mnt/usb/reports/usage-$(date +%Y%m).csv

# Identify non-work traffic (gaming, streaming)
nlbw -g protocol | grep -E "games|video|torrent"
```

### Use Case 3: ISP/Hotspot

**Scenario:** Track customer data usage for billing

```bash
# High-frequency commits for accuracy
uci set nlbwmon.@nlbwmon[0].commit_interval='3600'  # 1 hour

# Monitor multiple networks
uci add_list nlbwmon.@nlbwmon[0].local_network='10.0.1.0/24'
uci add_list nlbwmon.@nlbwmon[0].local_network='10.0.2.0/24'

# Export for billing system
nlbw -j | jq '.hosts[] | {ip: .ip, usage: .total.bytes}' > billing-data.json
```

### Use Case 4: Network Troubleshooting

**Scenario:** Identify source of high bandwidth usage

```bash
# Real-time top talkers
watch -n 5 'nlbw | head -15'

# Protocol causing high usage
nlbw -g protocol

# Check specific device
nlbw | grep 192.168.1.100

# Identify connections
cat /proc/net/nf_conntrack | grep 192.168.1.100
```

---

## Conclusion

nlbwmon provides efficient, lightweight network bandwidth monitoring for OpenWRT with minimal resource overhead.

### Summary

✅ **Installation:**
- Install nlbwmon and luci-app-nlbwmon
- Configure local network range
- Set database location (USB for persistence)

✅ **Configuration:**
- Adjust commit interval for performance/accuracy tradeoff
- Set database retention policy
- Configure protocol mappings if needed

✅ **Usage:**
- Web interface for visual analysis
- Command-line (nlbw) for automation
- Export data (CSV/JSON) for external processing

✅ **Best Practices:**
- Use persistent storage (USB)
- Regular backups
- Monitor database size
- Adjust retention based on needs

### Key Takeaways

1. **Low overhead** - Uses kernel conntrack, not packet capture
2. **Persistent tracking** - Survives reboots (with proper storage)
3. **Flexible reporting** - Web and CLI interfaces
4. **Protocol awareness** - Identifies applications
5. **Historical data** - Keeps monthly archives

### When to Use nlbwmon

**Good fit:**
- Long-term bandwidth accounting
- Per-device usage tracking
- Monthly/yearly reports
- Small to medium networks (<100 devices)

**Not suitable for:**
- Real-time monitoring (use iftop instead)
- Deep packet inspection
- Content filtering
- Sub-second granularity

### Resources

- OpenWRT nlbwmon: https://openwrt.org/docs/guide-user/services/network_monitoring/nlbwmon
- GitHub: https://github.com/jow-/nlbwmon
- LuCI app: https://github.com/openwrt/luci/tree/master/applications/luci-app-nlbwmon

---

*Document Version: 1.0*
*Last Updated: 2025*
*Based on: https://eko.one.pl/?p=openwrt-nlbwmon*
*Compatible with: OpenWRT 19.07+*
