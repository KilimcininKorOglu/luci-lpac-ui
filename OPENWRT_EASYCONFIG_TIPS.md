# OpenWrt EasyConfig Tips and Tricks

Advanced tips, tricks, and power user techniques for EasyConfig - extending functionality beyond basic usage.

**Based on:** https://eko.one.pl/?p=easyconfig-tipsandtricks
**Target Audience:** Advanced EasyConfig users, power users, system administrators
**Prerequisites:** Basic EasyConfig knowledge, SSH access, UCI familiarity

---

## Table of Contents

1. [Cellular Modem Advanced Configuration](#cellular-modem-advanced-configuration)
2. [Connection Monitoring Strategies](#connection-monitoring-strategies)
3. [Multi-WAN and Load Balancing](#multi-wan-and-load-balancing)
4. [Security and Access Control](#security-and-access-control)
5. [Network Isolation Techniques](#network-isolation-techniques)
6. [WiFi Scheduling and Automation](#wifi-scheduling-and-automation)
7. [VPN Power User Techniques](#vpn-power-user-techniques)
8. [Performance Optimization](#performance-optimization)
9. [Custom Scripts and Automation](#custom-scripts-and-automation)
10. [Advanced Troubleshooting](#advanced-troubleshooting)

---

## Cellular Modem Advanced Configuration

### USSD and SMS Configuration Issues

**Problem:** USSD messages or SMS not reading correctly

**Root cause:** Different modem models use different encoding/decoding methods

**Solution - Access hidden settings:**
```
System tab → Modem section → Additional settings link
```

**Available options:**

#### Raw Input/Output Control

```bash
# Bypass PDU encoding for USSD input (use plain ASCII)
uci set easyconfig.ussd.raw_input='1'
uci commit easyconfig

# Disable PDU decoding for USSD output
uci set easyconfig.ussd.raw_output='1'
uci commit easyconfig

# Or specify decoding method:
# raw_output='2' for 7BIT encoding
# raw_output='3' for UCS-2 encoding
```

**When to use:**
- USSD returns garbled text: Try `raw_output='1'` or `raw_output='2'`
- USSD codes don't send properly: Try `raw_input='1'`
- Balance check shows strange characters: Adjust `raw_output`

#### SMS Storage and Display

```bash
# Force SMS storage on SIM card
uci set easyconfig.sms.storage='SM'

# Or store in modem memory
uci set easyconfig.sms.storage='ME'

# Join multi-part SMS into single message
uci set easyconfig.sms.join='1'

# Display multi-part SMS separately
uci set easyconfig.sms.join='0'

uci commit easyconfig
```

**Troubleshooting:**
- SMS not appearing: Try switching storage location
- Multi-part SMS broken: Enable `join='1'`
- Old SMS filling memory: Use `storage='SM'` and delete via phone

#### Force QMI Protocol Reading

**For Qualcomm-based modems:**
```bash
uci set easyconfig.modem.force_qmi='1'
uci commit easyconfig
```

**Effect:** Forces reading modem information via QMI instead of AT commands

**When to use:**
- Modem information not displaying
- Signal strength shows as 0
- Operator name missing

#### Force PLMN Operator Name

```bash
uci set easyconfig.modem.force_plmn='1'
uci commit easyconfig
```

**Effect:** Uses PLMN code to determine operator name instead of modem-reported name

**Benefit:** More accurate operator identification in roaming scenarios

#### Custom Modem Device

```bash
# Set specific AT command port
uci set easyconfig.modem.device='/dev/ttyUSB2'
uci commit easyconfig
```

**Use case:** Auto-detection selects wrong port

**Common ports:**
- `/dev/ttyUSB0` - First serial port (usually GPS)
- `/dev/ttyUSB1` - Second serial port (often diagnostics)
- `/dev/ttyUSB2` - Third serial port (typically AT commands)
- `/dev/ttyUSB3` - Fourth serial port (sometimes audio)

**How to identify correct port:**
```bash
# Test each port manually
echo "AT" > /dev/ttyUSB0 && cat /dev/ttyUSB0 &
# Look for "OK" response
pkill cat

echo "AT" > /dev/ttyUSB1 && cat /dev/ttyUSB1 &
pkill cat

echo "AT" > /dev/ttyUSB2 && cat /dev/ttyUSB2 &
pkill cat
```

### Force LTE Technology

**GUI method:**
```
Settings → Internet → Connection Technology: "Only 4G (LTE-A/LTE)"
Save
```

**Result:** Modem restricted to 4G LTE, no fallback to 3G/2G

**To restore automatic selection:**
```
Settings → Internet → Connection Technology: "Automatic 4G/3G/2G selection"
Save
```

**Important note:** Selecting "Modem default settings" does NOT revert forced technology if previously configured via GUI or AT commands.

**Complete reset via AT commands:**
```bash
# For common modems (Huawei, ZTE, Quectel)
# Access System → Modem → AT Commands

# Reset to auto mode
AT+QCFG="nwscanmode",0,1

# Or via command line
echo 'AT+QCFG="nwscanmode",0,1' > /dev/ttyUSB2
```

**Verification:**
```bash
# Check current network mode
echo 'AT+QCFG="nwscanmode"' > /dev/ttyUSB2 && cat /dev/ttyUSB2
```

### Custom USSD Shortcuts

**Add frequently used codes:**
```bash
# Account balance (example for Polish operators)
uci add easyconfig ussd
uci set easyconfig.@ussd[-1].code='*101#'
uci set easyconfig.@ussd[-1].description='Saldo konta'

# Data package info
uci add easyconfig ussd
uci set easyconfig.@ussd[-1].code='*121#'
uci set easyconfig.@ussd[-1].description='Pakiet danych'

# Check phone number
uci add easyconfig ussd
uci set easyconfig.@ussd[-1].code='*111#'
uci set easyconfig.@ussd[-1].description='Numer telefonu'

uci commit easyconfig
```

**Result:** Buttons appear in USSD/SMS tab for one-click access

### Modem Band Locking

**Advanced users can lock specific LTE bands:**

**Via modemband package:**
```bash
# Install if not present
opkg update
opkg install modemband

# Access via System → Modem → Band Switching
# Or via CLI (example for Quectel EC25):
AT+QCFG="band",0,80,0,1  # Lock to Band 7 (2600 MHz)
```

**Common scenarios:**
- Avoid congested band: Lock to less-used frequency
- Maximize speed: Lock to carrier's primary band
- Roaming: Lock to known compatible band

---

## Connection Monitoring Strategies

EasyConfig's connection monitor is highly flexible. Here are proven strategies for different scenarios.

### Strategy A: Immediate Response (Critical Applications)

**Use case:** VoIP phone, alarm system, critical monitoring

**Configuration:**
```
Connection Monitor tab:
- Enabled: Yes
- Startup delay: 3 minutes
- Monitor host: google.com (or 8.8.8.8)
- Check interval: 1 minute
- Failed checks before action: 1
- Action: Reboot device
```

**Behavior:**
1. Router boots, waits 3 minutes for initialization
2. Every 1 minute: ping google.com
3. Single failed ping → immediate reboot
4. Aggressive but ensures maximum uptime

**Pros:**
- ✅ Fastest recovery (1-2 minutes total downtime)
- ✅ No prolonged disconnections

**Cons:**
- ❌ May reboot due to temporary network blip
- ❌ Frequent reboots reduce flash lifespan

### Strategy B: Tolerant of Weak Signal (Mobile Networks)

**Use case:** Rural area, weak 4G signal, occasional packet loss

**Configuration:**
```
Connection Monitor tab:
- Enabled: Yes
- Startup delay: 3 minutes
- Monitor host: google.com
- Check interval: 1 minute
- Failed checks before action: 10
- Action: Reconnect internet
```

**Behavior:**
1. Allows 10 consecutive ping failures (10 minutes)
2. Reconnects WAN interface instead of rebooting
3. Faster recovery than full reboot
4. Tolerates brief signal losses

**Pros:**
- ✅ Avoids reboots for temporary issues
- ✅ Reconnection preserves statistics
- ✅ Better for unreliable connections

**Cons:**
- ❌ 10-minute delay before action
- ❌ Reconnection may not fix modem crash

### Strategy C: Escalating Response (Modem Hardware Issues)

**Use case:** Modem occasionally freezes, needs power cycle

**Base configuration:**
Same as Strategy B (reconnect after 10 failures)

**Add escalation script:**
Create `/etc/easyconfig_watchdog.user`:

```bash
#!/bin/sh
# Escalating watchdog: reconnect → reboot after 4 failed reconnects

if [ "$ACTION" = "wan" ]; then
    # Increment counter on each reconnect
    echo 1 >> /tmp/licznik

    # Count total reconnects
    CNT=$(wc -l < /tmp/licznik)

    # After 4 reconnects (40 minutes total), reboot
    if [ "$CNT" -ge 4 ]; then
        # Proper reboot preserving statistics
        ubus call easyconfig reboot
    fi
fi

# Reset counter on successful connection
if [ "$ACTION" = "success" ]; then
    rm -f /tmp/licznik
fi
```

**Make executable:**
```bash
chmod +x /etc/easyconfig_watchdog.user
```

**Behavior:**
1. First 10 failed pings (10 min) → reconnect (attempt 1)
2. Still down after 10 more pings (20 min) → reconnect (attempt 2)
3. Still down after 10 more pings (30 min) → reconnect (attempt 3)
4. Still down after 10 more pings (40 min) → reconnect (attempt 4)
5. After 4th reconnect → **full device reboot**

**Pros:**
- ✅ Tries gentle fix first (reconnect)
- ✅ Escalates to hard fix (reboot) if needed
- ✅ Minimizes unnecessary reboots
- ✅ Preserves statistics with `ubus call easyconfig reboot`

**Important:** Always use `ubus call easyconfig reboot` instead of `reboot` command to preserve EasyConfig statistics database.

### Strategy D: Time-Based Monitoring

**Use case:** Known ISP maintenance windows

**Create custom script:**
```bash
#!/bin/sh
# /etc/easyconfig_watchdog.user
# Skip monitoring during maintenance (2 AM - 4 AM)

HOUR=$(date +%H)

if [ "$HOUR" -ge 2 ] && [ "$HOUR" -lt 4 ]; then
    # Maintenance window - don't take action
    logger "Connection monitor: In maintenance window, ignoring failure"
    exit 0
fi

# Normal action
if [ "$ACTION" = "wan" ]; then
    logger "Connection monitor: Reconnecting WAN"
fi
```

### Advanced Ping Targets

**Multiple targets for redundancy:**

EasyConfig uses single target, but you can script multiple checks:

```bash
#!/bin/sh
# /etc/easyconfig_watchdog.user
# Check multiple hosts before acting

if [ "$ACTION" = "wan" ]; then
    # Verify connection is truly down
    ping -c 3 8.8.8.8 > /dev/null 2>&1 && exit 0
    ping -c 3 1.1.1.1 > /dev/null 2>&1 && exit 0
    ping -c 3 9.9.9.9 > /dev/null 2>&1 && exit 0

    # All three failed - connection truly down
    logger "Connection monitor: All ping targets failed, proceeding with action"
fi
```

---

## Multi-WAN and Load Balancing

### Integration with mwan3

**Important:** EasyConfig GUI does **not** configure multi-WAN, but **displays** mwan3 status on Status tab if installed and configured.

**Complete mwan3 setup for dual WAN:**

#### 1. Install mwan3

```bash
opkg update
opkg install mwan3
```

#### 2. Configure Primary WAN (Existing)

```bash
# Set lower metric (higher priority)
uci set network.wan.metric='10'
uci commit network

# Enable in mwan3
uci set mwan3.wan=interface
uci set mwan3.wan.enabled='1'
uci set mwan3.wan.initial_state='online'
uci set mwan3.wan.family='ipv4'
uci set mwan3.wan.track_method='ping'
uci set mwan3.wan.track_hosts='8.8.8.8 1.1.1.1'
uci set mwan3.wan.reliability='1'
uci set mwan3.wan.count='1'
uci set mwan3.wan.size='56'
uci set mwan3.wan.timeout='2'
uci set mwan3.wan.interval='5'
uci set mwan3.wan.down='3'
uci set mwan3.wan.up='3'
uci commit mwan3
```

#### 3. Create Second WAN Interface

```bash
# Delete if exists
uci -q delete network.wanb

# Create new interface
uci set network.wanb=interface
uci set network.wanb.proto='dhcp'
uci set network.wanb.device='eth1'  # Adjust to your hardware
uci set network.wanb.metric='20'    # Lower priority than wan
uci commit network

# Add to firewall WAN zone
uci add_list firewall.@zone[1].network='wanb'
uci commit firewall
```

#### 4. Configure mwan3 for Second WAN

```bash
uci set mwan3.wanb=interface
uci set mwan3.wanb.enabled='1'
uci set mwan3.wanb.initial_state='online'
uci set mwan3.wanb.family='ipv4'
uci set mwan3.wanb.track_method='ping'
uci set mwan3.wanb.track_hosts='8.8.8.8'
uci set mwan3.wanb.reliability='1'
uci set mwan3.wanb.count='1'
uci set mwan3.wanb.timeout='2'
uci set mwan3.wanb.interval='10'
uci set mwan3.wanb.down='3'
uci set mwan3.wanb.up='3'
uci commit mwan3
```

#### 5. Create Members and Policies

```bash
# WAN member (primary, metric 1)
uci set mwan3.wan_m1_w1=member
uci set mwan3.wan_m1_w1.interface='wan'
uci set mwan3.wan_m1_w1.metric='1'
uci set mwan3.wan_m1_w1.weight='1'

# WANB member (backup, metric 2)
uci set mwan3.wanb_m2_w1=member
uci set mwan3.wanb_m2_w1.interface='wanb'
uci set mwan3.wanb_m2_w1.metric='2'
uci set mwan3.wanb_m2_w1.weight='1'

# Failover policy
uci set mwan3.failover=policy
uci set mwan3.failover.last_resort='unreachable'
uci add_list mwan3.failover.use_member='wan_m1_w1'
uci add_list mwan3.failover.use_member='wanb_m2_w1'

# Default rule
uci set mwan3.default_rule=rule
uci set mwan3.default_rule.dest_ip='0.0.0.0/0'
uci set mwan3.default_rule.proto='all'
uci set mwan3.default_rule.use_policy='failover'

uci commit mwan3
```

#### 6. Apply and Reboot

```bash
/etc/init.d/mwan3 enable
/etc/init.d/mwan3 start
reboot
```

#### 7. Verify in EasyConfig

After reboot:
- Status tab will show "Load Balancing" section
- Displays status of both WANs
- Shows active/inactive state

### Load Balancing Configuration

**Modify members for equal load balancing:**

```bash
# Both WANs with same metric (equal priority)
uci set mwan3.wan_m1_w1.metric='1'
uci set mwan3.wanb_m1_w1.metric='1'

# Balanced policy
uci set mwan3.balanced=policy
uci add_list mwan3.balanced.use_member='wan_m1_w1'
uci add_list mwan3.balanced.use_member='wanb_m1_w1'

# Use balanced policy
uci set mwan3.default_rule.use_policy='balanced'

uci commit mwan3
/etc/init.d/mwan3 restart
```

### Cellular + Cable Failover

**Common scenario: Cable primary, 4G backup**

```bash
# Cable as wan (already configured)
# 4G as wanb

# Configure 4G
uci set network.wanb.proto='qmi'
uci set network.wanb.device='/dev/cdc-wdm0'
uci set network.wanb.apn='internet'
uci set network.wanb.metric='20'
uci commit network

# Configure mwan3 as above
# Result: Cable active, 4G idle until cable fails
```

---

## Security and Access Control

### Disable Reset Button

**Problem:** Physical reset button can restore factory defaults

**Solution:**
```
Configuration tab → Disable reset button: Enable
Save
```

**Effect:**
- Hardware reset button no longer triggers factory reset
- Failsafe mode still works (boot with button held)
- Prevents accidental or malicious configuration wipe

**Recommended for:**
- Public installations
- Unsupervised locations
- Preventing unauthorized access

**Restore reset functionality:**
Disable the toggle or access via failsafe mode

### Client Internet Blocking

**Block specific devices from internet:**

```
Clients tab → [select device] → Block Internet: Enable
```

**Use cases:**
- Parental controls (block gaming device)
- Enforce network policy
- Temporary punishment/restriction
- IoT devices that don't need internet

**Note:** Device can still access LAN resources (NAS, printer, router)

### Per-Client Speed Limits

**Prevent bandwidth hogging:**

```
Clients tab → [select device] → Speed Limit
Upload: 2 Mbps
Download: 10 Mbps
Save
```

**Use cases:**
- Fair bandwidth sharing
- Guest network throttling
- QoS for specific devices
- Limit background devices (cameras, sensors)

### MAC Address Filtering

**Not in EasyConfig GUI, but via UCI:**

```bash
# Whitelist mode (only allow specific MACs)
uci set wireless.default_radio0.macfilter='allow'
uci add_list wireless.default_radio0.maclist='AA:BB:CC:DD:EE:01'
uci add_list wireless.default_radio0.maclist='AA:BB:CC:DD:EE:02'
uci commit wireless
wifi

# Blacklist mode (block specific MACs)
uci set wireless.default_radio0.macfilter='deny'
uci add_list wireless.default_radio0.maclist='AA:BB:CC:DD:EE:FF'
uci commit wireless
wifi
```

---

## Network Isolation Techniques

### IoT Device Isolation

**Create isolated IoT network with selective internet access:**

```
Additional Networks tab → Add Network

Configuration:
- Network name: IoT
- IPv4 address: 192.168.3.1
- WiFi enabled: Yes
- WiFi SSID: SmartHome
- Internet access: Enabled (for cloud-connected devices)
- Isolation: Enabled (default - isolates from LAN)
```

**Result:**
- IoT devices can access internet
- IoT devices **cannot** access LAN (192.168.1.x)
- LAN devices **cannot** access IoT network
- Protects NAS, computers from compromised IoT devices

### Guest Network Best Practices

**Secure guest network setup:**

```
Additional Networks tab → Add Network

Configuration:
- Network name: Guest
- IPv4 address: 192.168.2.1
- WiFi enabled: Yes
- WiFi SSID: Guest-WiFi
- WiFi security: WPA2 Personal
- WiFi password: (simple but secure)
- Internet access: Enabled
- Isolation: Enabled
- Client isolation: Enabled (if available)
```

**Benefits:**
- Guests can browse internet
- Guests cannot see each other's devices
- Guests cannot access your files/printers
- Separate password prevents main network compromise

### Captive Portal for Guests

**Not built into EasyConfig, but can add nodogsplash:**

```bash
opkg update
opkg install nodogsplash

# Configure for guest network
uci set nodogsplash.@nodogsplash[0].gatewayinterface='br-guest'
uci set nodogsplash.@nodogsplash[0].gatewayname='Guest WiFi'
uci commit nodogsplash

/etc/init.d/nodogsplash enable
/etc/init.d/nodogsplash start
```

**Result:** Guests see splash page before internet access

---

## WiFi Scheduling and Automation

### Night Mode Configuration

**Basic weekly schedule:**

```
Night Mode tab → Weekly Schedule

Monday-Friday:
- WiFi off: 23:00
- WiFi on: 07:00

Saturday-Sunday:
- WiFi off: 01:00
- WiFi on: 09:00
```

**Important prerequisites:**
1. WiFi must be **enabled** by default
2. Router must have correct time (NTP synchronized)
3. Schedule activates after time synchronization

**How it works:**
- Router checks time at boot
- Disables WiFi if current time is in "off" period
- Enables WiFi if current time is in "on" period
- Continues checking and toggling according to schedule

### Sunrise/Sunset Automation

**Requires GPS coordinates and sunwait package:**

```bash
opkg update
opkg install sunwait
```

**Configuration:**
```
Night Mode tab → Sunrise/Sunset

Options:
- WiFi off: Sunset + 30 minutes
- WiFi on: Sunrise - 30 minutes

Location:
- Manual entry: Latitude/Longitude
- Or from GPS (if ugps installed)
```

**Use case:**
- Outdoor WiFi access points
- Energy savings aligned with daylight
- Automatic adjustment for seasons

**Note:** Requires internet connection to determine sunrise/sunset times via geolocation API

### Button-Controlled WiFi

**Toggle guest network with hardware button:**

```
Additional Networks tab → [network] → Button control: Enabled
```

**Result:** Press WPS or configured button to enable/disable guest WiFi

**Practical scenario:**
- Guest arrives → press button → WiFi on
- Guest leaves → press button → WiFi off
- No need to access web interface

---

## VPN Power User Techniques

### Commercial VPN Import

**For NordVPN, ExpressVPN, Surfshark, etc.:**

1. Download .ovpn or .conf file from provider
2. Access VPN tab → New Connection
3. Select connection type (OpenVPN/WireGuard)
4. Import configuration file (drag & drop or paste)
5. Enter username/password if required
6. Enable "Start on boot" for persistent VPN
7. Save

**File requirements:**
- Text files only (.txt, .conf, .ovpn)
- No archives (.zip, .rar) - extract first
- IPv6 addresses may cause issues - remove if errors occur

### Killswitch Configuration

**Prevent internet leaks if VPN disconnects:**

```
VPN tab → [connection] → Killswitch: Enabled
Firewall policy: DROP (recommended for privacy)
```

**Behavior:**
- VPN connected: All internet traffic through VPN
- VPN disconnected: **No internet access** (leak prevention)
- LAN access: Still works

**Testing killswitch:**
1. Enable VPN with killswitch
2. Verify internet works (check IP address)
3. Disable VPN connection
4. Try browsing - should fail
5. Re-enable VPN - internet restored

### Split Tunneling

**Route specific devices through VPN, others direct:**

Not available in EasyConfig GUI, requires mwan3 configuration:

```bash
# Install mwan3
opkg install mwan3

# Configure VPN as separate WAN
# Configure policy routing per IP/device
# See mwan3 documentation for details
```

### Multiple VPN Profiles

**Create profiles for different locations:**

```
VPN tab:
- Connection 1: "US Server" (OpenVPN)
- Connection 2: "UK Server" (OpenVPN)
- Connection 3: "Home Network" (WireGuard)
```

**Manual switching:**
- Disable active connection
- Enable desired connection
- Wait for connection (~10-30 seconds)

**Limitation:** Only one VPN active at a time in EasyConfig

---

## Performance Optimization

### Statistics Write Frequency

**Reduce flash wear on high-traffic networks:**

```
Settings → System → Data save period: 5 minutes
```

**Trade-offs:**

| Interval | Flash Wear | Data Loss Risk | Recommended For |
|----------|------------|----------------|-----------------|
| 1 minute | High | Minimal | Low traffic, temporary setups |
| 5 minutes | Medium | 5 min data | Balanced |
| 15 minutes | Low | 15 min data | High traffic, flash-constrained |
| Disabled | None | All on reboot | Testing only |

**Explanation:**
- Statistics stored in RAM between writes
- Periodic writes copy to flash storage
- Power loss = lost statistics since last write
- Longer interval = fewer flash writes = longer lifespan

### WiFi Channel Optimization

**Use WiFi Networks scanner:**

```
WiFi Networks tab → Scan → Sort by Signal Strength
```

**Look for:**
- Congested channels (many networks)
- Strong interfering signals
- Clean channels with few networks

**Then configure:**
```
Settings → WiFi → Channel: [least congested]
```

**2.4GHz recommendations:**
- Use 1, 6, or 11 (non-overlapping)
- Avoid intermediate channels (2-5, 7-10)

**5GHz recommendations:**
- Prefer 36-48 (UNII-1) or 149-165 (UNII-3)
- Avoid DFS channels (52-144) if scanning is important

### Transmit Power Adjustment

**Reduce power for better performance:**

**Counter-intuitive but effective:**
```
Settings → WiFi → Transmit Power: 75% (or even 50%)
```

**Benefits of lower power:**
- ✅ Reduces interference to neighbors
- ✅ Neighbors reduce interference to you
- ✅ Better signal-to-noise ratio
- ✅ More stable connections
- ✅ Lower heat generation

**When to use maximum power:**
- Large homes/offices
- Outdoor installations
- Weak signal areas only

### DNS Query Logging Impact

**Disable when not needed:**

```
Settings → Local Network → DNS Query Logging: Disabled
```

**Performance impact:**
- CPU: Moderate (every DNS query logged)
- RAM: Low (syslog circular buffer)
- Flash: None (in-memory logging)

**Enable only when:**
- Troubleshooting DNS issues
- Investigating client behavior
- Configuring domain blocking

---

## Custom Scripts and Automation

### Watchdog User Script

**Location:** `/etc/easyconfig_watchdog.user`

**Called when connection monitor triggers action**

**Available variables:**
- `$ACTION` = "wan" (reconnect) or "reboot" (reboot device)

**Example - Custom LED signaling:**

```bash
#!/bin/sh
# /etc/easyconfig_watchdog.user
# Flash LED when connection lost

if [ "$ACTION" = "wan" ]; then
    # Connection lost - flash red LED
    for i in $(seq 1 10); do
        echo 1 > /sys/class/leds/red:status/brightness
        sleep 0.5
        echo 0 > /sys/class/leds/red:status/brightness
        sleep 0.5
    done

    logger "Connection watchdog: Attempting reconnection"
fi

if [ "$ACTION" = "reboot" ]; then
    # About to reboot - solid red LED
    echo 1 > /sys/class/leds/red:status/brightness
    logger "Connection watchdog: Rebooting device"
fi
```

Make executable:
```bash
chmod +x /etc/easyconfig_watchdog.user
```

### LED Control Script

**Location:** `/etc/easyconfig_leds.user`

**Called when WiFi state changes (night mode)**

**Available variables:**
- `$ACTION` = "on" (WiFi enabled) or "off" (WiFi disabled)

**Example - WiFi status LED:**

```bash
#!/bin/sh
# /etc/easyconfig_leds.user
# Control WiFi LED based on state

if [ "$ACTION" = "on" ]; then
    # WiFi enabled - green LED
    echo 1 > /sys/class/leds/green:wlan/brightness
    logger "WiFi enabled by schedule"
fi

if [ "$ACTION" = "off" ]; then
    # WiFi disabled - turn off LED
    echo 0 > /sys/class/leds/green:wlan/brightness
    logger "WiFi disabled by schedule"
fi
```

Make executable:
```bash
chmod +x /etc/easyconfig_leds.user
```

### Automatic Backup Script

**Create periodic configuration backup:**

```bash
#!/bin/sh
# /root/auto-backup.sh
# Backup EasyConfig configuration weekly

BACKUP_DIR="/mnt/usb/backups"
DATE=$(date +%Y%m%d)

mkdir -p "$BACKUP_DIR"

# Backup EasyConfig config
cp /etc/config/easyconfig "$BACKUP_DIR/easyconfig-$DATE"

# Backup statistics
cp /usr/lib/easyconfig/easyconfig_statistics.json.gz "$BACKUP_DIR/statistics-$DATE.json.gz"

# Backup network config
cp /etc/config/network "$BACKUP_DIR/network-$DATE"
cp /etc/config/wireless "$BACKUP_DIR/wireless-$DATE"

# Keep only last 4 backups
ls -t "$BACKUP_DIR"/easyconfig-* | tail -n +5 | xargs -r rm
ls -t "$BACKUP_DIR"/statistics-* | tail -n +5 | xargs -r rm
ls -t "$BACKUP_DIR"/network-* | tail -n +5 | xargs -r rm
ls -t "$BACKUP_DIR"/wireless-* | tail -n +5 | xargs -r rm

logger "EasyConfig backup completed: $DATE"
```

**Schedule weekly:**
```bash
chmod +x /root/auto-backup.sh

# Add to cron (every Sunday at 3 AM)
echo "0 3 * * 0 /root/auto-backup.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

---

## Advanced Troubleshooting

### Force Modem Reset

**When modem freezes:**

```bash
# Soft reset via AT command
echo "AT+CFUN=1,1" > /dev/ttyUSB2

# Or via QMI
uqmi -d /dev/cdc-wdm0 --reset-dms

# Hard reset via USB power cycle (if supported)
# Disable USB port
echo '1-1' > /sys/bus/usb/drivers/usb/unbind
sleep 5
# Enable USB port
echo '1-1' > /sys/bus/usb/drivers/usb/bind
```

### Clear Statistics Database

**If statistics corrupted or want fresh start:**

```bash
# Stop cron
/etc/init.d/cron stop

# Remove statistics file
rm /usr/lib/easyconfig/easyconfig_statistics.json.gz

# Restart cron (will create new file)
/etc/init.d/cron start
```

**Note:** All historical data lost

### Fix Time Synchronization

**If WiFi schedules not working:**

```bash
# Check current time
date

# Manual time set (if NTP fails)
date -s "2025-10-25 14:30:00"

# Restart NTP
/etc/init.d/sysntpd restart

# Force sync
ntpd -q -p pool.ntp.org
```

### Repair Broken mwan3 Configuration

**If multi-WAN stops working:**

```bash
# Restart mwan3
/etc/init.d/mwan3 restart

# Check status
mwan3 status

# If still broken, reconfigure
/etc/init.d/mwan3 stop
rm /etc/config/mwan3
opkg reinstall mwan3
# Reconfigure from scratch
```

### Recovery from Bad Configuration

**If locked out of router:**

1. **Failsafe mode:**
   - Power off router
   - Power on, immediately press reset button repeatedly
   - Wait for rapid LED flashing
   - Connect via Ethernet
   - Access router at 192.168.1.1
   - No password required

2. **Restore configuration:**
```bash
# In failsafe mode
mount_root

# Edit or restore configs
vi /etc/config/easyconfig
vi /etc/config/network

# Reboot normally
reboot
```

---

## Quick Reference

### Important File Locations

```
/etc/config/easyconfig                               # Main configuration
/usr/lib/easyconfig/easyconfig_statistics.json.gz   # Statistics database
/etc/easyconfig_watchdog.user                        # Connection monitor script
/etc/easyconfig_leds.user                            # LED control script
```

### Useful Commands

```bash
# Reboot preserving statistics
ubus call easyconfig reboot

# Get modem info
easyconfig_modeminfo.sh

# Set APN
easyconfig_setapn.sh

# Manage PIN
easyconfig_pincode.sh

# Manual statistics update
easyconfig_statistics.sh

# Check mwan3 status (if installed)
mwan3 status
```

### Common UCI Paths

```bash
# EasyConfig settings
uci show easyconfig

# Modem settings
uci get easyconfig.modem.device
uci set easyconfig.modem.force_qmi='1'

# USSD settings
uci set easyconfig.ussd.raw_input='1'
uci set easyconfig.ussd.raw_output='1'

# SMS settings
uci set easyconfig.sms.storage='SM'
uci set easyconfig.sms.join='1'

# Commit changes
uci commit easyconfig
```

---

## Additional Resources

- **Main EasyConfig Guide**: OPENWRT_EASYCONFIG_GUIDE.md
- **OpenWrt Wiki**: https://openwrt.org/
- **mwan3 Documentation**: https://openwrt.org/docs/guide-user/network/wan/multiwan/mwan3
- **EasyConfig Project**: https://eko.one.pl/?p=easyconfig

---

**Document Version:** 1.0
**Last Updated:** 2025-10-25
**Based on:** https://eko.one.pl/?p=easyconfig-tipsandtricks (Polish original)
**License:** CC BY-SA 4.0
**Target Audience:** Advanced users, power users, system administrators
