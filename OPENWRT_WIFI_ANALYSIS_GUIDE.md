# OpenWrt WiFi Analysis and Optimization Guide

Comprehensive guide for analyzing, troubleshooting, and optimizing WiFi networks on OpenWrt routers using built-in tools and utilities.

**Based on:** https://eko.one.pl/?p=openwrt-wifianalyzer
**Target Audience:** Network administrators, WiFi optimization specialists, OpenWrt users
**OpenWrt Versions:** Compatible with OpenWrt 15.05 through current releases

---

## Table of Contents

1. [Introduction](#introduction)
2. [WiFi Analysis Tools](#wifi-analysis-tools)
3. [Network Scanning](#network-scanning)
4. [Signal Strength Analysis](#signal-strength-analysis)
5. [Channel Analysis](#channel-analysis)
6. [WiFi Performance Monitoring](#wifi-performance-monitoring)
7. [Troubleshooting WiFi Issues](#troubleshooting-wifi-issues)
8. [WiFi Analyzer Script](#wifi-analyzer-script)
9. [Advanced WiFi Diagnostics](#advanced-wifi-diagnostics)
10. [WiFi Optimization Best Practices](#wifi-optimization-best-practices)

---

## Introduction

### Why WiFi Analysis Matters

WiFi performance depends on many factors:
- **Channel congestion** - Too many networks on same channel
- **Signal interference** - Microwave ovens, Bluetooth devices, neighboring APs
- **Signal strength** - Distance, walls, obstacles
- **Channel width** - 20MHz vs 40MHz vs 80MHz bandwidth
- **Transmission power** - Too high or too low
- **Client capabilities** - Mixed 802.11n/ac/ax devices

Proper analysis helps:
- Select optimal WiFi channels
- Identify interference sources
- Optimize transmit power
- Troubleshoot connectivity issues
- Monitor network performance

---

## WiFi Analysis Tools

### Available Tools on OpenWrt

| Tool | Purpose | Availability |
|------|---------|--------------|
| `iwinfo` | Primary WiFi analysis tool | Pre-installed |
| `iw` | Advanced 802.11 configuration | Usually pre-installed |
| `iwlist` | Legacy wireless scanning | Package: `wireless-tools` |
| `iwconfig` | Legacy wireless configuration | Package: `wireless-tools` |
| `wavemon` | Real-time monitoring | Package: `wavemon` |
| `horst` | WiFi analyzer with visualization | Package: `horst` |
| `tcpdump` | Packet capture | Package: `tcpdump` |
| `iperf3` | Network performance testing | Package: `iperf3` |

### Installing Additional Tools

```bash
# Update package list
opkg update

# Install wireless tools (legacy)
opkg install wireless-tools

# Install wavemon (real-time monitor)
opkg install wavemon

# Install horst (advanced analyzer)
opkg install horst

# Install network performance tools
opkg install iperf3 tcpdump

# Install gnuplot for visualization
opkg install gnuplot
```

---

## Network Scanning

### iwinfo - Primary Scanning Tool

**iwinfo** is OpenWrt's primary WiFi information tool, providing comprehensive network scanning and status information.

#### Basic Network Scan

```bash
# Scan for nearby networks on wlan0
iwinfo wlan0 scan

# Scan on wlan1 (5GHz interface)
iwinfo wlan1 scan
```

**Example Output:**
```
Cell 01 - Address: AA:BB:CC:DD:EE:01
          ESSID: "HomeNetwork"
          Mode: Master  Channel: 6
          Signal: -45 dBm  Quality: 65/70
          Encryption: WPA2 PSK (CCMP)

Cell 02 - Address: AA:BB:CC:DD:EE:02
          ESSID: "NeighborWiFi"
          Mode: Master  Channel: 6
          Signal: -67 dBm  Quality: 43/70
          Encryption: WPA2 PSK (CCMP)

Cell 03 - Address: AA:BB:CC:DD:EE:03
          ESSID: "Office5G"
          Mode: Master  Channel: 36
          Signal: -52 dBm  Quality: 58/70
          Encryption: WPA2 PSK (CCMP)
```

#### Scan All Interfaces

```bash
# Scan all wireless interfaces
for iface in /sys/class/net/wlan*; do
    IFACE=$(basename $iface)
    echo "=== Scanning $IFACE ==="
    iwinfo $IFACE scan
    echo ""
done
```

#### Parse Scan Results

**Extract SSIDs:**
```bash
iwinfo wlan0 scan | grep ESSID | cut -d'"' -f2
```

**Extract channels:**
```bash
iwinfo wlan0 scan | grep Channel | awk '{print $4}'
```

**Count networks per channel:**
```bash
iwinfo wlan0 scan | grep Channel | awk '{print $4}' | sort | uniq -c
```

**Example output:**
```
      5 1
      8 6
      3 11
      2 36
      1 149
```
This shows 8 networks on channel 6 (congested).

### iw - Advanced Scanning

**iw** is the modern replacement for iwconfig/iwlist with more features.

#### Basic Scan

```bash
# Scan for networks
iw dev wlan0 scan

# Scan with specific options
iw dev wlan0 scan flush
```

#### Scan for Specific SSID

```bash
iw dev wlan0 scan ssid "TargetNetwork"
```

#### View Last Scan Results

```bash
iw dev wlan0 scan dump
```

#### Parse iw Output

**Extract BSS (MAC addresses):**
```bash
iw dev wlan0 scan | grep "^BSS" | awk '{print $2}'
```

**Extract signal strength:**
```bash
iw dev wlan0 scan | grep "signal:" | awk '{print $2, $3}'
```

**Channel occupancy:**
```bash
iw dev wlan0 scan | grep "DS Parameter set: channel" | awk '{print $5}' | sort | uniq -c
```

### iwlist - Legacy Scanning

If you have `wireless-tools` installed:

```bash
# Scan for networks
iwlist wlan0 scan

# Scan with frequency info
iwlist wlan0 scan | grep -E "Cell|ESSID|Channel|Quality|Signal"
```

---

## Signal Strength Analysis

### Understanding Signal Levels

**Signal Strength (RSSI - Received Signal Strength Indicator):**

| dBm Range | Quality | Description |
|-----------|---------|-------------|
| -30 to -50 dBm | Excellent | Maximum performance, close to AP |
| -50 to -60 dBm | Very Good | High throughput, reliable |
| -60 to -67 dBm | Good | Reliable connectivity, moderate speed |
| -67 to -70 dBm | Fair | Minimum for reliable VoIP/video |
| -70 to -80 dBm | Poor | Unreliable, low throughput |
| -80 to -90 dBm | Very Poor | Unusable for most purposes |
| < -90 dBm | No Signal | Connection drops frequently |

### Measure Signal Strength

#### Current Connection Signal

```bash
# Show current WiFi info
iwinfo wlan0 info

# Extract signal strength only
iwinfo wlan0 info | grep "Signal"
```

**Example output:**
```
Signal: -45 dBm  Noise: -95 dBm
```

**Signal-to-Noise Ratio (SNR):**
```
SNR = Signal - Noise = -45 - (-95) = 50 dB (excellent)
```

**SNR Guidelines:**
- **> 40 dB**: Excellent
- **25-40 dB**: Good
- **15-25 dB**: Fair
- **10-15 dB**: Poor
- **< 10 dB**: Unusable

#### Monitor Signal in Real-Time

**Using iwinfo in loop:**
```bash
#!/bin/sh
# /usr/bin/wifi-signal-monitor.sh

while true; do
    clear
    echo "=== WiFi Signal Monitor ==="
    date
    echo ""
    iwinfo wlan0 info | grep -E "ESSID|Signal|Noise|Link Quality"
    echo ""
    echo "Press Ctrl+C to stop"
    sleep 2
done
```

**Using watch command:**
```bash
watch -n 2 'iwinfo wlan0 info | grep -E "Signal|Noise"'
```

#### Signal Strength from Scan

```bash
# Show all networks with signal strength
iwinfo wlan0 scan | grep -E "Address|ESSID|Signal" | paste - - -

# Sort by signal strength (strongest first)
iwinfo wlan0 scan | awk '/Address/{addr=$3} /ESSID/{essid=$3} /Signal/{print $2, addr, essid}' | sort -n -r
```

### wavemon - Real-Time Monitor

**wavemon** provides an interactive, ncurses-based WiFi monitor.

```bash
# Install
opkg update
opkg install wavemon

# Run
wavemon
```

**wavemon features:**
- Real-time signal level graphs
- Noise level monitoring
- Channel information
- Network statistics
- Packet error rates

**Usage:**
- `F2`: Scan networks
- `F3`: Signal histogram
- `F7`: Info screen
- `q`: Quit

---

## Channel Analysis

### WiFi Channel Basics

#### 2.4GHz Channels

**Channel layout:**
- **Channels 1-13** (14 in Japan)
- **Channel width**: 20MHz (standard) or 40MHz (HT40)
- **Non-overlapping channels**: 1, 6, 11

**Frequency mapping:**
- Channel 1: 2.412 GHz
- Channel 6: 2.437 GHz
- Channel 11: 2.462 GHz
- Channel 13: 2.472 GHz

**Overlap pattern:**
```
Channel:  1  2  3  4  5  6  7  8  9 10 11 12 13
          |===========|
             |===========|
                |===========|
                   |===========|
                      |===========|
                         |===========|
                            |===========|
```

#### 5GHz Channels

**UNII-1 (Indoor):** 36, 40, 44, 48
**UNII-2A (Indoor):** 52, 56, 60, 64
**UNII-2C (DFS):** 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140, 144
**UNII-3 (Outdoor):** 149, 153, 157, 161, 165

**Channel widths:**
- 20MHz: Single channel
- 40MHz: Two adjacent channels (HT40)
- 80MHz: Four adjacent channels (VHT80)
- 160MHz: Eight adjacent channels (VHT160)

### Channel Occupancy Analysis

#### Count Networks per Channel

```bash
#!/bin/sh
# /usr/bin/wifi-channel-analysis.sh

echo "=== 2.4GHz Channel Occupancy ==="
iwinfo wlan0 scan | grep "Channel:" | awk '{print $4}' | sort -n | uniq -c | awk '{print "Channel", $2":", $1, "networks"}'

echo ""
echo "=== 5GHz Channel Occupancy ==="
iwinfo wlan1 scan | grep "Channel:" | awk '{print $4}' | sort -n | uniq -c | awk '{print "Channel", $2":", $1, "networks"}'
```

**Example output:**
```
=== 2.4GHz Channel Occupancy ===
Channel 1: 3 networks
Channel 6: 8 networks
Channel 11: 4 networks

=== 5GHz Channel Occupancy ===
Channel 36: 2 networks
Channel 149: 1 networks
```

**Recommendation:** Choose channel with fewest networks.

#### Signal Strength per Channel

```bash
#!/bin/sh
# Show average signal per channel

iwinfo wlan0 scan | awk '
/Channel:/{channel=$4}
/Signal:/{signal=$2; sum[channel]+=signal; count[channel]++}
END {
    for (ch in sum) {
        avg = sum[ch]/count[ch]
        printf "Channel %2d: %d networks, avg signal: %.1f dBm\n", ch, count[ch], avg
    }
}' | sort -n -k2
```

### Best Channel Selection

**Algorithm:**
1. Scan all channels
2. Count networks per channel
3. Measure average signal strength
4. Prefer non-overlapping channels (1, 6, 11 for 2.4GHz)
5. Choose channel with least interference

**Automated channel selection:**
```bash
#!/bin/sh
# /usr/bin/auto-select-channel.sh

# Scan and find least congested channel among 1, 6, 11
BEST_CHANNEL=$(iwinfo wlan0 scan | grep "Channel:" | awk '{print $4}' | grep -E '^(1|6|11)$' | sort | uniq -c | sort -n | head -1 | awk '{print $2}')

if [ -n "$BEST_CHANNEL" ]; then
    echo "Best channel: $BEST_CHANNEL"

    # Update configuration
    uci set wireless.radio0.channel="$BEST_CHANNEL"
    uci commit wireless
    wifi

    echo "Channel changed to $BEST_CHANNEL"
else
    echo "No suitable channel found"
fi
```

---

## WiFi Performance Monitoring

### Connected Clients Analysis

#### List Connected Clients

```bash
# Show associated clients
iwinfo wlan0 assoclist
```

**Example output:**
```
AA:BB:CC:DD:EE:01  -42 dBm / -95 dBm (SNR 53)  120 ms ago
    RX: 135.1 MBit/s, MCS 7, 40MHz          52 Pkts.
    TX: 150.0 MBit/s, MCS 7, 40MHz, short GI 89 Pkts.
    expected throughput: 144.0 MBit/s

AA:BB:CC:DD:EE:02  -67 dBm / -95 dBm (SNR 28)  340 ms ago
    RX: 54.0 MBit/s                         234 Pkts.
    TX: 65.0 MBit/s, MCS 5, 20MHz           198 Pkts.
    expected throughput: 65.0 MBit/s
```

#### Client Statistics Script

```bash
#!/bin/sh
# /usr/bin/wifi-clients.sh

echo "=== Connected WiFi Clients ==="
echo ""

for iface in wlan0 wlan1; do
    if [ -d "/sys/class/net/$iface" ]; then
        echo "Interface: $iface ($(uci get wireless.default_$iface.ssid 2>/dev/null))"

        CLIENT_COUNT=$(iwinfo $iface assoclist | grep -c "dBm")
        echo "Clients: $CLIENT_COUNT"

        if [ $CLIENT_COUNT -gt 0 ]; then
            iwinfo $iface assoclist
        fi

        echo ""
    fi
done
```

### Link Quality Monitoring

```bash
# Show link quality for current connection
iwinfo wlan0 info | grep "Link Quality"

# Monitor continuously
watch -n 1 'iwinfo wlan0 info | grep "Link Quality"'
```

### Throughput Testing with iperf3

**On server (another device):**
```bash
iperf3 -s
```

**On OpenWrt router:**
```bash
# Install iperf3
opkg update
opkg install iperf3

# Test download speed
iperf3 -c server-ip -t 30

# Test upload speed
iperf3 -c server-ip -t 30 -R

# Test both directions
iperf3 -c server-ip -t 30 --bidir
```

### Packet Loss Testing

```bash
# Ping test with statistics
ping -c 100 8.8.8.8 | tail -2

# Example output:
# 100 packets transmitted, 98 received, 2% packet loss, time 99045ms
# rtt min/avg/max/mdev = 12.456/25.789/89.123/15.234 ms
```

---

## Troubleshooting WiFi Issues

### Common WiFi Problems

| Problem | Possible Causes | Diagnostic Commands |
|---------|----------------|---------------------|
| No WiFi signal | Radio disabled, driver issue | `iwinfo`, `wifi status`, `dmesg` |
| Weak signal | Distance, obstacles, low TX power | `iwinfo wlan0 scan`, `iwinfo wlan0 info` |
| Frequent disconnects | Interference, poor signal, channel congestion | `logread -f`, signal monitoring |
| Slow speeds | Channel congestion, weak signal, interference | `iperf3`, channel analysis |
| Cannot connect | Wrong password, MAC filtering, max clients | `logread`, `iwinfo assoclist` |

### Diagnostic Steps

#### 1. Check WiFi Radio Status

```bash
# Check if radio is enabled
wifi status

# Check UCI configuration
uci show wireless | grep disabled

# Enable if disabled
uci set wireless.radio0.disabled=0
uci commit wireless
wifi
```

#### 2. Check Driver and Hardware

```bash
# Check wireless driver
lsmod | grep -E "mac80211|ath|rt2800"

# Check kernel messages for WiFi errors
dmesg | grep -iE "wifi|wlan|phy"

# Check hardware info
iw list
```

#### 3. Scan for Interference

```bash
# Scan current channel
CURRENT_CHANNEL=$(iwinfo wlan0 info | grep Channel | awk '{print $2}')
echo "Current channel: $CURRENT_CHANNEL"

# Count networks on same channel
INTERFERENCE=$(iwinfo wlan0 scan | grep "Channel: $CURRENT_CHANNEL" | wc -l)
echo "Networks on channel $CURRENT_CHANNEL: $INTERFERENCE"
```

#### 4. Monitor System Logs

```bash
# Watch WiFi-related logs in real-time
logread -f | grep -iE "wifi|wlan|hostapd|wpa"

# Check for authentication issues
logread | grep -i "authentication\|association"

# Check for driver errors
logread | grep -i "phy\|mac80211"
```

#### 5. Test Signal Strength Path

```bash
# Create a signal strength tester script
#!/bin/sh
# /usr/bin/signal-path-test.sh

echo "=== Signal Strength Path Test ==="
echo "Walk around and observe signal changes"
echo "Press Ctrl+C to stop"
echo ""

while true; do
    SIGNAL=$(iwinfo wlan0 info | grep Signal | awk '{print $2}')
    QUALITY=$(iwinfo wlan0 info | grep "Link Quality" | awk '{print $3}')

    echo "$(date +%H:%M:%S) - Signal: $SIGNAL dBm, Quality: $QUALITY"
    sleep 1
done
```

### WiFi Reset Procedures

#### Soft Reset (Reload WiFi)

```bash
# Restart WiFi without reboot
wifi down
sleep 2
wifi up
```

#### Hard Reset (Restart Network)

```bash
# Restart entire network stack
/etc/init.d/network restart
```

#### Clear WiFi Cache

```bash
# Remove WiFi state files
rm -f /var/run/hostapd-*.conf
rm -f /var/run/wpa_supplicant-*.conf
rm -rf /tmp/wifi-*

# Restart WiFi
wifi
```

#### Factory Reset WiFi Configuration

```bash
# Reset wireless config to defaults
wifi detect > /etc/config/wireless
uci commit wireless
wifi
```

---

## WiFi Analyzer Script

### WiFi Analyzer with Visualization

Based on the original eko.one.pl script concept, here's an enhanced WiFi analyzer that generates visual graphs.

#### Installation

```bash
# Install dependencies
opkg update
opkg install gnuplot iwinfo

# Create script directory
mkdir -p /usr/bin
```

#### WiFi Analyzer Script

```bash
#!/bin/sh
# /usr/bin/wifi-analyzer.sh
# Visualize WiFi channel occupancy using gnuplot

OUTPUT_DIR="/tmp"
DATA_FILE="$OUTPUT_DIR/wifi-data.txt"
GRAPH_FILE="$OUTPUT_DIR/wifi-graph.png"

# Scan and collect data
echo "Scanning WiFi networks..."
iwinfo wlan0 scan > "$OUTPUT_DIR/wifi-scan.txt"

# Parse data: Channel, Signal, ESSID
awk '
/Address/{mac=$3}
/ESSID/{essid=$3; gsub(/"/, "", essid)}
/Channel/{channel=$4}
/Signal/{signal=$2; print channel, signal, essid, mac}
' "$OUTPUT_DIR/wifi-scan.txt" | sort -n > "$DATA_FILE"

# Count networks per channel
awk '{count[$1]++} END {for (ch in count) print ch, count[ch]}' "$DATA_FILE" | sort -n > "$OUTPUT_DIR/channel-count.txt"

# Generate gnuplot script
cat > "$OUTPUT_DIR/plot-wifi.gp" << 'EOF'
set terminal png size 1200,600
set output '/tmp/wifi-graph.png'
set title "WiFi Channel Occupancy - 2.4GHz"
set xlabel "Channel"
set ylabel "Number of Networks"
set xrange [0:14]
set yrange [0:*]
set grid
set style fill solid 0.5
set boxwidth 0.8
plot '/tmp/channel-count.txt' using 1:2 with boxes title 'Networks per Channel' linecolor rgb "blue"
EOF

# Generate graph
gnuplot "$OUTPUT_DIR/plot-wifi.gp"

if [ -f "$GRAPH_FILE" ]; then
    echo "Graph generated: $GRAPH_FILE"
    echo ""
    echo "=== Channel Summary ==="
    cat "$OUTPUT_DIR/channel-count.txt"
    echo ""
    echo "=== Recommendations ==="

    # Find least congested channel among 1, 6, 11
    BEST=$(awk '$1 ~ /^(1|6|11)$/ {print $2, $1}' "$OUTPUT_DIR/channel-count.txt" | sort -n | head -1 | awk '{print $2}')
    echo "Best channel (1/6/11): $BEST"
else
    echo "Error: Failed to generate graph"
fi
```

**Make executable:**
```bash
chmod +x /usr/bin/wifi-analyzer.sh
```

#### Usage

```bash
# Run analyzer
/usr/bin/wifi-analyzer.sh

# View graph
# Transfer /tmp/wifi-graph.png to your computer or view via web server
```

### Advanced WiFi Analyzer with 5GHz Support

```bash
#!/bin/sh
# /usr/bin/wifi-analyzer-dual.sh
# Analyze both 2.4GHz and 5GHz bands

analyze_band() {
    IFACE=$1
    BAND=$2
    OUTPUT_BASE="/tmp/wifi-${BAND}"

    echo "=== Analyzing $BAND band on $IFACE ==="

    # Scan
    iwinfo $IFACE scan > "${OUTPUT_BASE}-scan.txt"

    # Parse and count
    awk '
    /Channel/{channel=$4}
    /Signal/{signal=$2; print channel, signal}
    ' "${OUTPUT_BASE}-scan.txt" | sort -n > "${OUTPUT_BASE}-data.txt"

    # Channel occupancy
    awk '{count[$1]++; sum[$1]+=$2} END {
        for (ch in count)
            printf "%d %d %.1f\n", ch, count[ch], sum[ch]/count[ch]
    }' "${OUTPUT_BASE}-data.txt" | sort -n > "${OUTPUT_BASE}-summary.txt"

    echo "Networks found:"
    cat "${OUTPUT_BASE}-summary.txt"
    echo ""
}

# Analyze 2.4GHz
if [ -d "/sys/class/net/wlan0" ]; then
    analyze_band wlan0 "2.4GHz"
fi

# Analyze 5GHz
if [ -d "/sys/class/net/wlan1" ]; then
    analyze_band wlan1 "5GHz"
fi

echo "=== Analysis Complete ==="
echo "Data files: /tmp/wifi-*"
```

### Web-Based WiFi Analyzer

Serve the WiFi graph via uhttpd:

```bash
# Create web directory
mkdir -p /www/wifi

# Create index page
cat > /www/wifi/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>WiFi Analyzer</title>
    <meta http-equiv="refresh" content="30">
</head>
<body>
    <h1>WiFi Channel Analysis</h1>
    <img src="wifi-graph.png" alt="WiFi Graph">
    <p>Auto-refresh every 30 seconds</p>
</body>
</html>
EOF

# Create update script
cat > /usr/bin/wifi-web-update.sh << 'EOF'
#!/bin/sh
/usr/bin/wifi-analyzer.sh
cp /tmp/wifi-graph.png /www/wifi/
EOF

chmod +x /usr/bin/wifi-web-update.sh

# Add to cron (update every 5 minutes)
echo "*/5 * * * * /usr/bin/wifi-web-update.sh" >> /etc/crontabs/root
/etc/init.d/cron restart

# Access at: http://router-ip/wifi/
```

---

## Advanced WiFi Diagnostics

### Driver-Specific Commands

#### mac80211 Drivers (Most Modern Devices)

```bash
# Station information
iw dev wlan0 station dump

# Link statistics
iw dev wlan0 link

# Survey data (channel usage)
iw dev wlan0 survey dump

# Interface capabilities
iw list
```

#### ath9k/ath10k Debugging

```bash
# Enable ath9k debug
echo 0xffffffff > /sys/kernel/debug/ieee80211/phy0/ath9k/debug

# Read debug info
cat /sys/kernel/debug/ieee80211/phy0/ath9k/dma
cat /sys/kernel/debug/ieee80211/phy0/ath9k/interrupt
cat /sys/kernel/debug/ieee80211/phy0/ath9k/recv
```

### Packet Capture

```bash
# Install tcpdump
opkg update
opkg install tcpdump

# Capture WiFi traffic
tcpdump -i wlan0 -w /tmp/wifi-capture.pcap

# Capture only beacon frames
tcpdump -i wlan0 -e -s 256 type mgt subtype beacon

# Capture with filters
tcpdump -i wlan0 'wlan type data'
```

### Spectral Scan (Advanced)

For ath9k/ath10k with spectral scan support:

```bash
# Check if supported
ls /sys/kernel/debug/ieee80211/phy0/ath9k/spectral_*

# Enable spectral scan
echo "chanscan" > /sys/kernel/debug/ieee80211/phy0/ath9k/spectral_scan_ctl

# Read spectral data
cat /sys/kernel/debug/ieee80211/phy0/ath9k/spectral_scan0
```

---

## WiFi Optimization Best Practices

### Channel Selection

**2.4GHz:**
- ✅ Use channels 1, 6, or 11 (non-overlapping)
- ✅ Choose channel with fewest networks
- ✅ Avoid adjacent channels (e.g., don't use 1 and 2)
- ❌ Avoid 40MHz channel width (too much interference in 2.4GHz)

**5GHz:**
- ✅ Prefer UNII-1 (36-48) or UNII-3 (149-165) for reliability
- ✅ Use 80MHz width for maximum performance (if supported)
- ✅ Avoid DFS channels (100-144) unless necessary
- ✅ Check local regulations for allowed channels

### Transmit Power

```bash
# Check current TX power
iwinfo wlan0 info | grep "Tx-Power"

# Set TX power (dBm)
iw dev wlan0 set txpower fixed 2000  # 20 dBm = 100mW

# Set via UCI
uci set wireless.radio0.txpower='20'
uci commit wireless
wifi
```

**Guidelines:**
- **Home (small)**: 15-17 dBm (30-50mW)
- **Home (large)**: 17-20 dBm (50-100mW)
- **Office**: 20-23 dBm (100-200mW)
- **Outdoor**: 23-27 dBm (200-500mW)

**Note:** Higher power doesn't always mean better. Too high causes interference.

### Distance Settings

```bash
# Set distance (meters) for ACK timing
iw phy phy0 set distance 300

# Or auto (recommended)
iw phy phy0 set distance auto
```

### Channel Width Optimization

```bash
# 2.4GHz - Use 20MHz
uci set wireless.radio0.htmode='HT20'

# 5GHz - Use 80MHz if no interference
uci set wireless.radio1.htmode='VHT80'

# Available options: HT20, HT40, VHT80, VHT160
uci commit wireless
wifi
```

### Beacon Interval and DTIM

```bash
# Set beacon interval (default 100ms)
uci set wireless.default_radio0.beacon_int='100'

# Set DTIM period (default 2)
uci set wireless.default_radio0.dtim_period='2'

uci commit wireless
wifi
```

**Lower values:**
- Better for roaming
- Higher power consumption
- More overhead

**Higher values:**
- Better power saving
- Slower roaming
- Less overhead

---

## Monitoring and Automation

### Automated Channel Optimization

```bash
#!/bin/sh
# /usr/bin/auto-optimize-wifi.sh
# Automatically select best channel weekly

# Scan and analyze
/usr/bin/wifi-analyzer.sh > /tmp/wifi-analysis.log

# Select best channel for 2.4GHz (among 1, 6, 11)
BEST_24=$(iwinfo wlan0 scan | grep "Channel:" | awk '{print $4}' | \
    grep -E '^(1|6|11)$' | sort | uniq -c | sort -n | head -1 | awk '{print $2}')

# Select best channel for 5GHz (among non-DFS)
BEST_5=$(iwinfo wlan1 scan | grep "Channel:" | awk '{print $4}' | \
    grep -E '^(36|40|44|48|149|153|157|161)$' | sort | uniq -c | sort -n | head -1 | awk '{print $2}')

# Apply changes
if [ -n "$BEST_24" ]; then
    uci set wireless.radio0.channel="$BEST_24"
    logger -t wifi-optimize "Changed 2.4GHz channel to $BEST_24"
fi

if [ -n "$BEST_5" ]; then
    uci set wireless.radio1.channel="$BEST_5"
    logger -t wifi-optimize "Changed 5GHz channel to $BEST_5"
fi

uci commit wireless
wifi
```

**Schedule weekly optimization:**
```bash
# Add to cron (every Sunday at 3 AM)
echo "0 3 * * 0 /usr/bin/auto-optimize-wifi.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

### WiFi Health Monitor

```bash
#!/bin/sh
# /usr/bin/wifi-health-monitor.sh
# Alert if WiFi performance degrades

SIGNAL_THRESHOLD=-70
CLIENT_THRESHOLD=10

# Check signal strength
SIGNAL=$(iwinfo wlan0 info | grep Signal | awk '{print $2}')

if [ ${SIGNAL#-} -gt ${SIGNAL_THRESHOLD#-} ]; then
    logger -p user.warn -t wifi-health "WARNING: Low signal strength: $SIGNAL dBm"
fi

# Check client count
CLIENTS=$(iwinfo wlan0 assoclist | grep -c "dBm")

if [ $CLIENTS -gt $CLIENT_THRESHOLD ]; then
    logger -p user.warn -t wifi-health "WARNING: High client count: $CLIENTS"
fi

# Check for errors in logs
ERRORS=$(logread | grep -c "phy0.*error")

if [ $ERRORS -gt 10 ]; then
    logger -p user.err -t wifi-health "ERROR: WiFi driver errors detected: $ERRORS"
fi
```

---

## Quick Reference

### Common Commands

```bash
# Scan networks
iwinfo wlan0 scan

# Show WiFi info
iwinfo wlan0 info

# Show connected clients
iwinfo wlan0 assoclist

# Restart WiFi
wifi down && wifi up

# Change channel
uci set wireless.radio0.channel='6'
uci commit wireless && wifi

# Check signal
iwinfo wlan0 info | grep Signal

# Monitor logs
logread -f | grep wifi
```

### Signal Quality

| Signal (dBm) | Quality |
|--------------|---------|
| -30 to -50   | Excellent |
| -50 to -60   | Very Good |
| -60 to -67   | Good |
| -67 to -70   | Fair |
| -70 to -80   | Poor |
| < -80        | Very Poor |

### Recommended Channels

**2.4GHz:** 1, 6, 11 (non-overlapping)
**5GHz (indoor):** 36, 40, 44, 48, 149, 153, 157, 161

---

## Additional Resources

- **OpenWrt WiFi Documentation**: https://openwrt.org/docs/guide-user/network/wifi/start
- **WiFi Troubleshooting**: https://openwrt.org/docs/guide-user/network/wifi/troubleshooting
- **iw Documentation**: https://wireless.wiki.kernel.org/en/users/documentation/iw
- **Channel Planning**: https://www.metageek.com/training/resources/design-dual-band-wifi.html
- **WiFi Standards**: https://en.wikipedia.org/wiki/IEEE_802.11

---

**Document Version:** 1.0
**Last Updated:** 2025-10-25
**Based on:** https://eko.one.pl/?p=openwrt-wifianalyzer (Polish original)
**License:** CC BY-SA 4.0
