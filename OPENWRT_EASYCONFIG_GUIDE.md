# OpenWrt EasyConfig Guide

Comprehensive guide for EasyConfig - a simplified, mobile-first configuration interface for OpenWrt routers with focus on cellular modem connectivity and ease of use.

**Based on:** https://eko.one.pl/?p=easyconfig
**Target Audience:** End users, mobile router operators, system administrators
**OpenWrt Versions:** Compatible with OpenWrt 19.07 through current releases
**Language:** Polish only (interface), English documentation

---

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [First Time Setup](#first-time-setup)
4. [Web Interface Overview](#web-interface-overview)
5. [Internet Connection Setup](#internet-connection-setup)
6. [WiFi Configuration](#wifi-configuration)
7. [Additional Networks (Guest/IoT)](#additional-networks-guestiot)
8. [Cellular Modem Management](#cellular-modem-management)
9. [VPN Configuration](#vpn-configuration)
10. [Monitoring and Statistics](#monitoring-and-statistics)
11. [Advanced Features](#advanced-features)
12. [Configuration Reference](#configuration-reference)
13. [Troubleshooting](#troubleshooting)
14. [Best Practices](#best-practices)

---

## Introduction

### What is EasyConfig?

**EasyConfig** is an alternative web-based configuration interface for OpenWrt routers designed to simplify router management, particularly for cellular/mobile routers.

**Key characteristics:**
- **Mobile-first design** - Large touch-friendly elements optimized for smartphones
- **Simplified workflow** - Quick internet connection setup in minutes
- **Cellular modem focus** - Extensive support for 3G/4G/5G modems
- **Lightweight** - Small package size (~350KB)
- **Coexistence-friendly** - Can run alongside LuCI or other interfaces
- **UCI-compatible** - Uses standard OpenWrt configuration system

### Why Use EasyConfig?

**Best for:**
- ✅ Mobile/MiFi routers with cellular modems
- ✅ Users wanting simple, fast configuration
- ✅ Touch-screen devices and smartphones
- ✅ Quick deployment scenarios
- ✅ Non-technical users

**Not ideal for:**
- ❌ Advanced networking configurations
- ❌ IPv6 management (limited support)
- ❌ Multiple VLAN setups
- ❌ Complex routing policies
- ❌ Non-Polish speakers (interface is Polish-only)

### Features Overview

| Feature | Support Level |
|---------|--------------|
| Internet connection (DHCP, Static, PPPoE) | ✅ Full |
| Cellular modems (3G/4G/5G, multiple protocols) | ✅ Full |
| WiFi management (2.4GHz/5GHz) | ✅ Full |
| Guest/IoT networks | ✅ Full |
| VPN clients (OpenVPN, WireGuard, PPTP, etc.) | ✅ Full |
| DNS ad blocking | ✅ Full |
| Traffic statistics | ✅ Full |
| Client management | ✅ Full |
| Connection monitoring | ✅ Full |
| GPS tracking | ✅ Optional |
| Multi-WAN/Load balancing | ✅ Integration with mwan3 |
| IPv6 configuration | ⚠️ Limited |

---

## Installation

### Prerequisites

**Required:**
- OpenWrt router (19.07 or newer)
- uhttpd web server (usually pre-installed)
- At least 2MB free flash storage

**Recommended:**
- 8MB+ flash storage
- 64MB+ RAM
- Internet connection for package installation

### Basic Installation

```bash
# Update package list
opkg update

# Install EasyConfig
opkg install easyconfig

# Install required dependencies (if not already installed)
opkg install uhttpd rpcd rpcd-mod-iwinfo

# Configure uhttpd for ubus support
uci set uhttpd.main.ubus_prefix='/ubus'
uci set uhttpd.main.home='/www'
uci commit uhttpd

# Restart services
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

### Optional Components

#### For PPPoE Support

```bash
opkg install ppp-mod-pppoe
```

#### For USB Cellular Modems

**Basic modem support:**
```bash
opkg install chat comgt usb-modeswitch
opkg install kmod-usb-serial-wwan kmod-usb-serial kmod-usb-serial-option
```

**NCM protocol (modern modems):**
```bash
opkg install comgt-ncm kmod-usb-net-cdc-ether kmod-usb-net-cdc-ncm
```

**QMI protocol (Qualcomm modems):**
```bash
opkg install uqmi kmod-usb-net-qmi-wwan libqmi
```

**MBIM protocol (Microsoft modems):**
```bash
opkg install umbim kmod-usb-net-cdc-mbim libmbim
```

**ModemManager (universal modem support):**
```bash
opkg install modemmanager libmbim libqmi
```

**SMS and USSD:**
```bash
opkg install sms-tool
```

#### For VPN Clients

**OpenVPN:**
```bash
opkg install openvpn-mbedtls
/etc/init.d/openvpn enable
```

**PPTP:**
```bash
opkg install ppp-mod-pptp kmod-nf-nathelper-extra
echo "net.netfilter.nf_conntrack_helper = 1" >> /etc/sysctl.d/local.conf
sysctl -p /etc/sysctl.d/local.conf
```

**SSTP:**
```bash
opkg install sstp-client
```

**WireGuard:**
```bash
opkg install wireguard-tools kmod-wireguard
```

**ZeroTier:**
```bash
opkg install zerotier
/etc/init.d/zerotier enable
```

#### For DNS Features

**Ad blocking:**
```bash
opkg install adblock libustream-mbedtls ca-bundle
/etc/init.d/adblock enable
```

**DNS over TLS/HTTPS:**
```bash
opkg install stubby
/etc/init.d/stubby enable
```

#### For Advanced Features

**Traffic shaping/QoS:**
```bash
opkg install nft-qos
/etc/init.d/nft-qos enable

# Fix nft-qos bug if needed
sed -i 's|^NFT_QOS_HAS_BRIDGE=.*|NFT_QOS_HAS_BRIDGE=y|g' /lib/nft-qos/core.sh
```

**Multi-WAN load balancing:**
```bash
opkg install mwan3
/etc/init.d/mwan3 enable
```

**GPS support:**
```bash
opkg install ugps
/etc/init.d/ugps enable
uci set gps.@gps[0].tty='/dev/ttyACM0'
uci set gps.@gps[0].disabled='0'
uci commit gps
/etc/init.d/ugps start
```

**Modem band management:**
```bash
opkg install modemband modemdata
```

**Wake on LAN:**
```bash
opkg install etherwake
```

**Sunrise/sunset automation:**
```bash
opkg install sunwait
```

**Connection diagnostics:**
```bash
opkg install pingraw
```

### Verify Installation

```bash
# Check if EasyConfig is installed
opkg list-installed | grep easyconfig

# Check if web server is running
/etc/init.d/uhttpd status

# Test web access
curl http://192.168.1.1
```

---

## First Time Setup

### Accessing EasyConfig

**Primary access (if set as default interface):**
```
http://192.168.1.1/
```

**Secondary access (if LuCI or other GUI is primary):**
```
http://192.168.1.1/easyconfig.html
```

**Adjust IP if your router uses different LAN address**

### Login

**Default credentials:**
- Username: `root`
- Password: (whatever you set during OpenWrt initial setup)

**Important:** If no password is set, you'll be prompted to create one.

**Session timeout:** 5 minutes of inactivity

### Initial Configuration Steps

1. **Set root password** (if not already set)
2. **Configure internet connection** (Settings tab)
3. **Set WiFi SSID and password** (Settings tab)
4. **Verify connectivity** (Status tab)
5. **Optional: Create guest network** (Additional Networks tab)

### Language Note

**Interface language:** Polish only

**Common Polish terms:**
- **Stan** = Status
- **Ustawienia** = Settings
- **Klienci** = Clients
- **Transfer** = Transfer/Data Usage
- **System** = System
- **Restart** = Restart/Reboot

---

## Web Interface Overview

### Main Tabs

#### 1. Status (Stan)

**Real-time monitoring:**
- **Modem information** - Operator, signal strength, technology (2G/3G/4G/5G), SIM status
- **Internet connection** - IP address, data usage, session duration
- **WiFi status** - Channels, connected clients per network
- **LAN connections** - Wired client list
- **Load balancing** - Multi-WAN status (if mwan3 installed)
- **System info** - Load average, uptime, current time
- **Sensors** - Temperature, battery level (if available)

**Key indicators:**
- Green = Good signal/active connection
- Yellow = Moderate signal/partial connectivity
- Red = Poor signal/no connection

#### 2. Settings (Ustawienia)

**Configuration options:**
- **Internet connection type**
- **Local network** (LAN IP, DHCP settings)
- **WiFi networks** (SSID, security, channel)
- **System** (hostname, password)

#### 3. Additional Networks (Dodatkowe sieci)

**Create guest/IoT networks:**
- Separate WiFi SSIDs
- Isolated from main LAN
- Optional internet access
- Custom DHCP settings

#### 4. WiFi Networks (Sieci WiFi)

**Network scanner:**
- Available networks in range
- Signal strength visualization
- Channel occupancy graphs
- Band filtering (2.4GHz/5GHz)

#### 5. Clients (Klienci)

**Connected device management:**
- Active client list with traffic percentages
- Historical client data (first/last seen)
- Per-client traffic graphs
- Static IP assignment
- Speed limits
- Internet blocking
- DNS query history

#### 6. Connection Monitor (Monitor połączenia)

**Automated connection testing:**
- Ping-based connectivity checks
- Configurable intervals and thresholds
- Actions on failure (reconnect/reboot)
- Custom script support

#### 7. Connection History (Historia połączeń)

**Event timeline:**
- Connection/disconnection events
- Timestamps and duration
- Reason codes (if available)

#### 8. DNS Queries (Zapytania DNS)

**DNS request logging:**
- Domain lookup history
- Per-client query tracking
- Blocked domain display
- Query testing tool

#### 9. Transfer (Transfer)

**Data usage statistics:**
- Daily totals
- 7-day and 30-day summaries
- Billing period tracking
- Projected usage
- Overage warnings

#### 10. USSD/SMS

**Cellular communication:**
- USSD code sending (balance check, etc.)
- SMS transmission
- SMS inbox (with multi-part support)
- Message deletion

#### 11. VPN

**VPN client management:**
- OpenVPN, PPTP, SSTP, WireGuard, ZeroTier
- Configuration file import
- Auto-start options
- Killswitch (block internet if VPN down)

#### 12. Domain Blocking (Blokowanie domen)

**DNS-based ad blocking:**
- Enable/disable sources
- Custom whitelist/blacklist
- Domain lookup testing

#### 13. Night Mode (Tryb nocny)

**WiFi and LED scheduling:**
- Temporary WiFi toggle
- Weekly schedules
- Sunrise/sunset automation
- LED control

#### 14. GPS

**Location tracking:**
- Live position display
- Map visualization
- Manual coordinate input

#### 15. WoL (Wake on LAN)

**Remote device wake:**
- Saved device list
- Manual MAC entry

#### 16. System

**Device management:**
- Modem information and AT commands
- System details
- Reboot/Reset
- Software updates (for specific MiFi firmware)

---

## Internet Connection Setup

### Connection Types

#### 1. No Internet (Brak internetu)

**Use case:** Router as WiFi AP or switch only

**Configuration:** Simply select "No Internet" option

#### 2. WAN DHCP

**Use case:** Cable modem, fiber ONT, automatic IP assignment

**Configuration:**
```
Settings → Internet Connection → WAN port (DHCP)
```

**Optional:**
- Hostname (for DHCP request)
- MAC address clone

#### 3. WAN Static IP

**Use case:** ISP provides fixed IP address

**Configuration:**
```
Settings → Internet Connection → WAN port (Static IP)

Required fields:
- IP address: 203.0.113.10
- Netmask: 255.255.255.0
- Gateway: 203.0.113.1
- DNS servers: 8.8.8.8, 1.1.1.1
```

#### 4. PPPoE

**Use case:** DSL connections, fiber with PPPoE authentication

**Prerequisites:**
```bash
opkg install ppp-mod-pppoe
```

**Configuration:**
```
Settings → Internet Connection → PPPoE

Required fields:
- Username: user@isp.com
- Password: ********
Optional:
- Service name: (usually not needed)
```

#### 5. Cellular Modem - Auto Detection

**Use case:** USB 3G/4G/5G modem, auto-detect protocol

**Configuration:**
```
Settings → Internet Connection → Cellular Modem

Steps:
1. Plug in USB modem
2. Select "Cellular modem (auto-detect)"
3. Wait for detection (~30 seconds)
4. Enter APN if required
5. Enter PIN code if SIM is locked
```

**Supported protocols (auto-detected):**
- RAS (older 3G modems)
- NCM (newer modems)
- QMI (Qualcomm modems)
- MBIM (Microsoft protocol)
- ModemManager (universal)
- HiLink/RNDIS (Huawei USB sticks)

#### 6. Cellular Modem - Manual Protocol

**Use case:** Auto-detection fails or specific protocol needed

**RAS (3G modems):**
```
Device: /dev/ttyUSB0 (or /dev/ttyUSB1, /dev/ttyUSB2)
APN: internet (or carrier-specific)
PIN: (if required)
```

**QMI (Qualcomm):**
```
Device: /dev/cdc-wdm0
APN: internet
PDPType: IPv4
```

**NCM:**
```
Device: /dev/ttyUSB2 (AT command port)
APN: internet
```

**MBIM:**
```
Device: /dev/cdc-wdm0
APN: internet
PDPType: IPv4
```

**ModemManager:**
```
Modem index: 0 (auto-detected)
APN: internet
```

### Technology Selection (Cellular)

**Options:**
- **Auto 4G/3G/2G** - Modem chooses best available
- **4G only (LTE/LTE-A)** - Force LTE, no fallback
- **3G only (HSPA/UMTS)** - Force 3G
- **2G only (EDGE/GSM)** - Force 2G
- **Modem default** - Don't change modem settings

**When to force:**
- 4G only: When 3G is congested/slow
- 3G only: When 4G signal is unstable
- 2G only: Maximum coverage, voice calls

### Common APNs by Carrier

**Generic:**
- `internet` - Most carriers
- `broadband` - Some carriers
- `data` - Alternative

**Poland:**
- Play: `internet`
- Plus: `internet`
- Orange: `internet`
- T-Mobile: `internet`

**Check with your carrier for correct APN**

### DNS Server Selection

**Predefined options:**
- **AdGuard DNS** (Default/Family protection)
- **Cloudflare** (1.1.1.1, 1.0.0.1)
- **Comodo Secure DNS**
- **DNS4EU**
- **Google Public DNS** (8.8.8.8, 8.8.4.4)
- **OpenDNS/FamilyShield**
- **Quad9** (9.9.9.9)
- **Yandex DNS** (Basic/Safe/Family)

**Custom DNS:**
Enter IP addresses manually if needed

---

## WiFi Configuration

### Basic WiFi Setup

**Access:** Settings → WiFi

**Per-band configuration:**
- 2.4GHz networks
- 5GHz networks

**Basic options:**
```
SSID: MyNetwork
Password: ********
Security: WPA2 Personal (recommended)
Channel: Auto or manual (1-13 for 2.4GHz, 36-165 for 5GHz)
Transmit Power: 100% (or lower for reduced range)
```

### Security Options

**WPA Personal (WPA1):**
- Outdated, not recommended
- Compatible with very old devices

**WPA2 Personal:**
- Recommended for most uses
- Good security + compatibility

**WPA3 Personal:**
- Best security
- Requires recent devices
- Requires `wpad-basic-mbedtls` package

**Open (No security):**
- Not recommended except for public hotspots
- No password required

### Channel Selection

**2.4GHz channels:**
- **Auto** - Router selects best channel
- **1, 6, 11** - Non-overlapping channels (recommended for manual)
- **1-13** - All available channels

**5GHz channels:**
- **Auto** - Router selects best channel
- **36, 40, 44, 48** - UNII-1 (indoor, low power)
- **52-64** - UNII-2A (requires DFS)
- **100-144** - UNII-2C (requires DFS, may delay startup)
- **149, 153, 157, 161, 165** - UNII-3 (outdoor, higher power)

**Note:** DFS (Dynamic Frequency Selection) channels may cause WiFi scanning to fail in EasyConfig. Use non-DFS channels if scanning is important.

### Transmit Power

**Options:** 1% to 100%

**Guidelines:**
- **100%** - Maximum range (default)
- **75%** - Reduced range, less interference
- **50%** - Small apartment/room
- **25%** - Very close range only

**Note:** Power adjustment disabled when channel set to "Auto"

### Advanced Options

**Client isolation:**
- Prevents WiFi clients from communicating with each other
- Useful for guest networks
- Checkbox option

**Random MAC assignment (OpenWrt 23.x+):**
- Router changes its own MAC address
- Privacy feature
- Usually not needed

### Multiple WiFi Networks

**EasyConfig supports:**
- Multiple 2.4GHz networks (if hardware supports)
- Multiple 5GHz networks (if hardware supports)
- Typically 1-2 networks per band on consumer routers
- Enterprise hardware may support more

**Each network configured separately**

---

## Additional Networks (Guest/IoT)

### Creating Guest Network

**Access:** Additional Networks tab → Add Network

**Configuration:**
```
Network name: Guest
IPv4 address: 192.168.2.1
Subnet: /24 (255.255.255.0)
DHCP enabled: Yes
DHCP lease time: 2 hours
Address pool: 150 addresses (192.168.2.100-192.168.2.249)
WiFi enabled: Yes
WiFi SSID: Guest-WiFi
WiFi password: ********
Internet access: Enabled/Disabled
Isolation from LAN: Yes (default)
```

**Isolation:**
- Guest network cannot access LAN (192.168.1.x)
- LAN cannot access guest network
- Prevents unauthorized access to NAS, printers, etc.

**Internet access control:**
- Enable: Guests can browse internet
- Disable: Captive portal or access point mode only

### IoT Network Example

**Use case:** Smart home devices, security cameras

```
Network name: IoT
IPv4 address: 192.168.3.1
WiFi SSID: SmartHome
WiFi security: WPA2 Personal
Internet access: Enabled (devices need cloud access)
Isolation: Enabled (protect main network)
```

**Access IoT devices from LAN:**
Firewall rules must be manually configured via UCI or LuCI

### Button-Controlled WiFi

**Feature:** Toggle guest WiFi with hardware button

**Configuration:**
```
Additional Network → [network] → Button control: Enabled
```

**Usage:** Press configured button to enable/disable guest WiFi

**Typical button:** WPS button or custom button if available

### Network Limits

**Maximum additional networks:**
- Limited by router hardware (usually 4-8 total SSIDs)
- Each network consumes RAM
- Multiple networks may reduce performance

---

## Cellular Modem Management

### Modem Information

**Access:** System → Modem

**Displayed information:**
- Modem model and manufacturer
- Firmware version
- IMEI number
- SIM card ICCID/IMSI
- Operator name (PLMN)
- Signal strength (RSSI, RSRP, RSRQ, SINR)
- Current technology (2G/3G/4G/5G)
- Band/frequency
- Cell ID and tower information

### AT Commands

**Access:** System → Modem → AT Commands

**Use case:** Advanced modem configuration

**Common AT commands:**
```
AT+CGMM          - Check modem model
AT+CGSN          - Get IMEI
AT+CSQ           - Signal quality
AT+COPS?         - Current operator
AT+CGDCONT?      - APN settings
AT+CFUN=1,1      - Restart modem
AT+CPMS?         - SMS storage info
```

**Warning:** Incorrect AT commands can disconnect or damage modem configuration

### Band Selection

**Access:** System → Modem → Band Switching (requires modemband package)

**Available bands:**
- LTE bands (B1, B3, B7, B20, B28, etc.)
- 5G NSA bands (n1, n3, n7, n28, n78, etc.)
- 5G SA bands (if supported)

**Use cases:**
- Avoid congested bands
- Force specific carrier band
- Test coverage on different frequencies
- Roaming optimization

### PIN Code Management

**Set/change PIN:**
```bash
easyconfig_pincode.sh
```

**Enable PIN requirement:**
Protects SIM card if modem stolen

**Disable PIN requirement:**
Allows auto-connection without manual PIN entry

**Unlock locked SIM:**
Use PUK code (provided by carrier)

### APN Configuration

**Change APN:**
```bash
easyconfig_setapn.sh
```

**Or via web interface:**
Settings → Internet Connection → [Edit connection]

**Multiple APN profiles:**
Not supported in EasyConfig (use LuCI or manual UCI)

### USSD Codes

**Access:** USSD/SMS tab → USSD section

**Common uses:**
- Check balance: `*101#` (carrier-specific)
- Check number: `*121#` (carrier-specific)
- Activate services: `*XXX#`

**Custom USSD codes:**
```bash
uci add easyconfig ussd
uci set easyconfig.@ussd[-1].code='*101#'
uci set easyconfig.@ussd[-1].description='Balance Check'
uci commit easyconfig
```

**Raw input/output options:**
```bash
# Bypass PDU encoding (if carrier uses ASCII)
uci set easyconfig.ussd.raw_input='1'

# Disable PDU decoding
uci set easyconfig.ussd.raw_output='1'

uci commit easyconfig
```

### SMS Management

**Access:** USSD/SMS tab → SMS section

**Send SMS:**
```
Recipient: +48123456789
Message: Hello world
```

**Read SMS:**
- Inbox display
- Multi-part SMS joining (if enabled)
- Delete messages

**SMS storage:**
```bash
# Store on SIM card (default)
uci set easyconfig.sms.storage='SM'

# Store in modem memory
uci set easyconfig.sms.storage='ME'

uci commit easyconfig
```

**Multi-part SMS:**
```bash
# Join multi-part SMS into single message
uci set easyconfig.sms.join='1'

# Display each part separately
uci set easyconfig.sms.join='0'

uci commit easyconfig
```

### Modem Troubleshooting

**Modem not detected:**
```bash
# Check USB devices
lsusb

# Check kernel messages
dmesg | tail -30

# Check modem devices
ls -l /dev/ttyUSB*
ls -l /dev/cdc-wdm*

# Try usb-modeswitch
usb_modeswitch -v 12d1 -p 1f01 -J  # Example for Huawei
```

**No signal:**
- Check SIM card insertion
- Check antenna connection
- Verify carrier coverage
- Try different band selection

**Connection drops:**
- Enable connection monitor
- Check signal strength (minimum -100 dBm for 4G)
- Verify APN settings
- Update modem firmware (via manufacturer tools)

---

## VPN Configuration

### Supported VPN Types

1. **OpenVPN** - Most common, good security
2. **WireGuard** - Modern, fast, simple
3. **PPTP** - Outdated, weak security, widely supported
4. **SSTP** - Microsoft protocol, good security
5. **ZeroTier** - P2P mesh VPN

### OpenVPN Setup

**Prerequisites:**
```bash
opkg install openvpn-mbedtls
/etc/init.d/openvpn enable
```

**Configuration:**
```
Access: VPN tab → Add Connection → OpenVPN

Upload files:
- Client configuration (.ovpn or .conf)
- Certificate files (.crt)
- Key files (.key)
- CA certificate (.pem)

Or manually enter:
- Remote server address
- Remote port
- Protocol (UDP/TCP)
- Cipher
- Authentication

Options:
- Enable on boot: Yes/No
- Killswitch: Block internet if VPN disconnects
- Data channel offload: Disable for older servers (add disable-dco)
```

**Import configuration file:**
- Drag and drop .ovpn file
- Or copy/paste configuration text

**Troubleshooting:**
```bash
# Check OpenVPN log
logread | grep openvpn

# Test manually
openvpn --config /etc/openvpn/client.ovpn
```

### WireGuard Setup

**Prerequisites:**
```bash
opkg install wireguard-tools kmod-wireguard
```

**Configuration:**
```
Access: VPN tab → Add Connection → WireGuard

Required fields:
- Private key: (generate or paste)
- Server public key: (from VPN provider)
- Server endpoint: vpn.example.com:51820
- Interface address: 10.0.0.2/24
- Allowed IPs: 0.0.0.0/0 (route all traffic)

Optional:
- Pre-shared key
- Persistent keepalive: 25 (for NAT traversal)
```

**Generate keys:**
```bash
# On router
wg genkey | tee privatekey | wg pubkey > publickey
cat privatekey  # Use this in EasyConfig
cat publickey   # Send this to VPN server admin
```

### PPTP Setup

**Prerequisites:**
```bash
opkg install ppp-mod-pptp kmod-nf-nathelper-extra
echo "net.netfilter.nf_conntrack_helper = 1" >> /etc/sysctl.d/local.conf
sysctl -p
```

**Configuration:**
```
Server: vpn.example.com
Username: user
Password: ********
Encryption: MPPE (enabled/disabled)
```

**Note:** PPTP has known security vulnerabilities, use only when necessary

### SSTP Setup

**Prerequisites:**
```bash
opkg install sstp-client
```

**Configuration:**
```
Server: vpn.example.com
Username: user
Password: ********
Certificate validation: Enabled (recommended)
```

### ZeroTier Setup

**Prerequisites:**
```bash
opkg install zerotier
/etc/init.d/zerotier enable
```

**Configuration:**
```
Network ID: (16-character hex from ZeroTier Central)
```

**Join network:**
1. Enter Network ID in EasyConfig
2. Approve device in ZeroTier Central web interface
3. Wait for device to appear online

### VPN Killswitch

**Purpose:** Block internet access if VPN disconnects (privacy protection)

**Configuration:**
```
VPN tab → [connection] → Killswitch: Enabled
```

**Behavior:**
- VPN connected: Internet works normally
- VPN disconnected: LAN cannot access WAN, only VPN can provide internet

**Firewall policy options:**
- **ACCEPT** - Allow remote management from VPN network
- **REJECT** - Explicit deny (connection refused)
- **DROP** - Silent discard (connection timeout)

### Multiple VPN Connections

**Supported:** Yes, create multiple VPN configurations

**Simultaneous active:** Only one VPN connection active at a time

**Switching:** Manually enable/disable via web interface

---

## Monitoring and Statistics

### Real-Time Status

**Access:** Status tab

**Metrics:**
- Current upload/download speed
- Signal strength (cellular)
- Connected client count
- WAN IP address
- System load
- Uptime

### Data Usage Tracking

**Access:** Transfer tab

**Statistics:**
- **Today:** Current day usage
- **Yesterday:** Previous day usage
- **Last 7 days:** Weekly summary
- **Last 30 days:** Monthly summary
- **Billing period:** Custom start date tracking
- **Projected usage:** Estimated monthly total

**Billing period configuration:**
```
Transfer tab → Settings → Billing period start day
Example: Day 1 (for 1st of month)
```

**Overage warnings:**
- Visual indicator only
- No automatic actions
- Manual limit setting

### Per-Client Statistics

**Access:** Clients tab → [client] → Statistics

**Available data:**
- Daily transfer graph
- Monthly transfer totals
- All-time transfer
- First seen date
- Last seen date
- Current upload/download speed

**Time periods:**
- Daily (24 hours)
- Monthly (30 days)
- Yearly (365 days)

### Connection History

**Access:** Connection History tab

**Information:**
- Connection timestamp
- Disconnection timestamp
- Duration
- Reason (if available)
- IP address assigned

**Storage:** System log (limited history, eventually rotates)

### DNS Query Logging

**Access:** DNS Queries tab

**Enable logging:**
```
Settings → Local Network → DNS Query Logging: Enabled
```

**Information:**
- Timestamp
- Client IP/MAC
- Domain queried
- Response (blocked/allowed)

**Per-client view:**
```
Clients tab → [client] → DNS Queries
```

**Performance impact:** Moderate, disable when not needed

### Connection Monitor

**Access:** Connection Monitor tab

**Configuration:**
```
Enabled: Yes
Ping target: 8.8.8.8 (or custom)
Check interval: 60 seconds
Failure threshold: 3 consecutive failures

Action on failure:
- Reconnect WAN interface
- Reboot device
- Run custom script
```

**Custom script:**
Create `/etc/easyconfig_watchdog.user`:
```bash
#!/bin/sh
# $ACTION = "wan" or "reboot"

if [ "$ACTION" = "wan" ]; then
    logger "Connection monitor triggering WAN reconnect"
    # Custom pre-reconnect actions
fi

if [ "$ACTION" = "reboot" ]; then
    logger "Connection monitor triggering reboot"
    # Custom pre-reboot actions
fi
```

Make executable:
```bash
chmod +x /etc/easyconfig_watchdog.user
```

---

## Advanced Features

### Night Mode (WiFi Scheduling)

**Access:** Night Mode tab

**Temporary toggle:**
- Manually turn WiFi on/off
- Duration: Until manually changed

**Weekly schedule:**
```
Monday-Friday:
  WiFi off: 23:00
  WiFi on: 07:00

Saturday-Sunday:
  WiFi off: 01:00
  WiFi on: 09:00
```

**Sunrise/sunset automation:**
Requires `sunwait` package and GPS location

```
WiFi off: Sunset + 30 minutes
WiFi on: Sunrise - 30 minutes
```

### GPS Tracking

**Prerequisites:**
```bash
opkg install ugps
/etc/init.d/ugps enable
uci set gps.@gps[0].tty='/dev/ttyACM0'  # Adjust device
uci set gps.@gps[0].disabled='0'
uci commit gps
/etc/init.d/ugps start
```

**Access:** GPS tab

**Features:**
- Live position display (lat/lon)
- Map visualization (requires internet)
- Manual coordinate entry
- Used for sunrise/sunset calculations

### Wake on LAN

**Access:** WoL tab

**Usage:**
1. Add device MAC address
2. Click "Wake" button
3. Device must support WoL and be on LAN

**Common use:** Wake sleeping NAS or PC remotely

### Domain Blocking

**Access:** Domain Blocking tab

**Prerequisites:**
```bash
opkg install adblock
/etc/init.d/adblock enable
/etc/init.d/adblock start
```

**Sources:**
- Multiple blocklist sources available
- Enable/disable individually

**Whitelist/Blacklist:**
```
Whitelist: example.com (always allow)
Blacklist: ads.example.com (always block)
```

**Testing:**
- Domain lookup tool in interface
- Check if domain is blocked

### Traffic Shaping (QoS)

**Prerequisites:**
```bash
opkg install nft-qos
sed -i 's|^NFT_QOS_HAS_BRIDGE=.*|NFT_QOS_HAS_BRIDGE=y|g' /lib/nft-qos/core.sh
/etc/init.d/nft-qos enable
```

**Per-client speed limits:**
```
Clients tab → [client] → Speed Limit
Upload limit: 5 Mbps
Download limit: 10 Mbps
```

**Global limits:**
Not available in EasyConfig, use LuCI or UCI

### Load Balancing (Multi-WAN)

**Prerequisites:**
```bash
opkg install mwan3
/etc/init.d/mwan3 enable
/etc/init.d/mwan3 start
```

**Configuration:**
Use LuCI or UCI for mwan3 setup (not in EasyConfig interface)

**Status display:**
EasyConfig shows mwan3 status on Status tab if configured

### Statistics Data Preservation

**Storage location:**
```
/usr/lib/easyconfig/easyconfig_statistics.json.gz
```

**Write frequency:**
Settings → System → Data save period

**Options:**
- Every minute (default, high flash wear)
- Every 5 minutes (balanced)
- Every 15 minutes (low flash wear)
- Disabled (data lost on reboot/power loss)

**Recommendation:**
- High traffic networks: 5-15 minutes
- Low traffic: 1 minute
- Flash-constrained devices: 5-15 minutes

---

## Configuration Reference

### Configuration File Locations

**EasyConfig settings:**
```
/etc/config/easyconfig
```

**Standard OpenWrt:**
```
/etc/config/network       # Network interfaces
/etc/config/wireless      # WiFi settings
/etc/config/firewall      # Firewall rules
/etc/config/dhcp          # DHCP and DNS
/etc/config/system        # System settings
```

**Statistics:**
```
/usr/lib/easyconfig/easyconfig_statistics.json.gz
```

### UCI Commands for EasyConfig

**View configuration:**
```bash
uci show easyconfig
```

**Modem settings:**
```bash
# Force QMI protocol reading
uci set easyconfig.modem.force_qmi='1'

# Set device interface
uci set easyconfig.modem.device='/dev/ttyUSB2'

uci commit easyconfig
```

**USSD settings:**
```bash
# Raw input/output
uci set easyconfig.ussd.raw_input='1'
uci set easyconfig.ussd.raw_output='1'

uci commit easyconfig
```

**SMS settings:**
```bash
# Storage location
uci set easyconfig.sms.storage='SM'  # SIM card
# uci set easyconfig.sms.storage='ME'  # Modem

# Multi-part messages
uci set easyconfig.sms.join='1'  # Combine
# uci set easyconfig.sms.join='0'  # Separate

uci commit easyconfig
```

**Custom USSD codes:**
```bash
uci add easyconfig ussd
uci set easyconfig.@ussd[-1].code='*100#'
uci set easyconfig.@ussd[-1].description='My Code'
uci commit easyconfig
```

### Command-Line Utilities

**Modem information:**
```bash
easyconfig_modeminfo.sh
```

**Set APN:**
```bash
easyconfig_setapn.sh
```

**PIN code management:**
```bash
easyconfig_pincode.sh
```

**Statistics collection (manual trigger):**
```bash
easyconfig_statistics.sh
```

### Custom Scripts

**Connection monitor watchdog:**
```bash
/etc/easyconfig_watchdog.user
# Variables: $ACTION = "wan" or "reboot"
```

**LED control:**
```bash
/etc/easyconfig_leds.user
# Variables: $ACTION = "on" or "off"
```

Make scripts executable:
```bash
chmod +x /etc/easyconfig_watchdog.user
chmod +x /etc/easyconfig_leds.user
```

---

## Troubleshooting

### Cannot Access Web Interface

**Symptoms:** Cannot reach http://192.168.1.1

**Solutions:**
```bash
# Check if uhttpd is running
/etc/init.d/uhttpd status

# Restart uhttpd
/etc/init.d/uhttpd restart

# Check router IP
ip addr show br-lan

# Check firewall
uci show firewall | grep input
```

**Alternative:** Use LuCI at http://192.168.1.1/cgi-bin/luci

### Session Timeout

**Problem:** Logged out every 5 minutes

**Cause:** Idle timeout for security

**Solution:** Increase timeout (not recommended for public routers)

### Modem Not Detected

**Symptoms:** No modem information on Status tab

**Solutions:**
```bash
# Check USB connection
lsusb

# Check kernel messages
dmesg | grep -i usb

# Check device files
ls -l /dev/ttyUSB*
ls -l /dev/cdc-wdm*

# Install mode switch
opkg install usb-modeswitch

# Restart network
/etc/init.d/network restart
```

### Statistics Not Updating

**Symptoms:** Transfer data frozen or zero

**Solutions:**
```bash
# Check cron job
cat /etc/crontabs/root | grep easyconfig

# Run manually
easyconfig_statistics.sh

# Check if interface is correct
uci show network | grep wan

# Check free space
df -h
```

### WiFi Not Visible

**Symptoms:** SSID doesn't appear in scans

**Solutions:**
```bash
# Check if radio is enabled
wifi status

# Enable WiFi
wifi up

# Check configuration
uci show wireless

# Restart WiFi
wifi down
wifi up
```

### VPN Won't Connect

**Symptoms:** VPN connection fails

**OpenVPN solutions:**
```bash
# Check log
logread | grep openvpn

# Test manually
openvpn --config /etc/openvpn/client.conf

# Check if package installed
opkg list-installed | grep openvpn

# Add disable-dco for older servers
# Edit config file and add:
# data-ciphers-fallback AES-256-CBC
# pull-filter ignore "data-ciphers"
```

**WireGuard solutions:**
```bash
# Check interface
wg show

# Check log
logread | grep wireguard

# Verify keys
wg showconf wg0
```

### Client Identification Issues

**Problem:** Devices keep changing in client list

**Cause:** MAC address randomization on modern devices

**Solutions:**
- Assign static IPs to important devices
- Disable MAC randomization on client devices (OS settings)
- Use hostname for identification (less reliable)

### DNS Queries Not Logging

**Problem:** DNS query log is empty

**Solutions:**
```bash
# Enable logging
uci set dhcp.@dnsmasq[0].logqueries='1'
uci commit dhcp
/etc/init.d/dnsmasq restart

# Check if enabled in EasyConfig
# Settings → Local Network → DNS Query Logging: Enabled

# Check log
logread | grep dnsmasq
```

### Transfer Statistics Differ from Operator

**Problem:** Router shows different data usage than carrier

**Explanation:**
- Router counts all data (including overhead)
- Carrier may count only payload
- VPN adds overhead
- Different measurement points

**Not a bug:** Use carrier's measurements for billing

---

## Best Practices

### Security

**1. Set strong password:**
```
Minimum 12 characters
Mix of letters, numbers, symbols
Change default password immediately
```

**2. Use WPA2 or WPA3:**
Never use WEP or open WiFi (except for public hotspots)

**3. Enable guest network isolation:**
Prevent guests from accessing your NAS, printers, etc.

**4. Disable DNS logging when not needed:**
Reduces performance impact and privacy concerns

**5. Use VPN for sensitive connections:**
Especially on cellular networks

### Performance

**1. Choose optimal WiFi channel:**
Use WiFi Networks tab to see congestion
Select channel 1, 6, or 11 for 2.4GHz

**2. Adjust statistics write frequency:**
High traffic: 5-15 minutes
Low traffic: 1 minute

**3. Disable unused features:**
GPS, DNS logging, VPN if not in use

**4. Limit connected clients:**
Too many clients = reduced performance
Use speed limits if needed

### Reliability

**1. Enable connection monitor:**
Auto-reconnect on failures
Reboot threshold: 5+ failures

**2. Schedule automatic reboots:**
Once per week during low-usage hours
Clears memory leaks, refreshes connections

**3. Keep firmware updated:**
Check for OpenWrt updates regularly
Backup configuration before updating

**4. Monitor signal strength:**
Minimum -100 dBm for usable 4G
Position router/antennas for best signal

### Data Management

**1. Set realistic billing period:**
Align with carrier billing cycle

**2. Monitor usage regularly:**
Check projected usage
Adjust behavior if approaching limit

**3. Use WiFi offloading:**
Connect to WiFi when available
Reduces cellular data usage

**4. Block high-bandwidth clients:**
Clients tab → [client] → Block internet
Or set speed limits

### Flash Storage

**1. Increase statistics save interval:**
Reduces flash wear
5-15 minutes on high-traffic networks

**2. Avoid frequent reboots:**
Flash has limited write cycles

**3. Use USB storage for logs:**
If router supports log rotation to USB

### Cellular Modem

**1. Verify APN before connecting:**
Wrong APN = connection failure or charges

**2. Set PIN code for security:**
Protects SIM if modem stolen

**3. Enable band selection carefully:**
Test before deploying
May reduce coverage

**4. Monitor signal quality:**
RSRP, RSRQ, SINR more important than bars

### Networking

**1. Use static IPs for servers:**
NAS, printers, IoT devices
Easier to manage firewall rules

**2. Separate IoT from main network:**
Additional network with isolation
Reduces attack surface

**3. Document your configuration:**
Keep notes on custom settings
Helps with troubleshooting

### Backup

**1. Export configuration regularly:**
System → Backup (if available)
Or manually backup /etc/config/

**2. Save statistics before upgrades:**
Copy /usr/lib/easyconfig/easyconfig_statistics.json.gz

**3. Test restore procedure:**
Ensure you can recover from failures

---

## Quick Reference

### Access URLs

```
Primary: http://192.168.1.1/
Secondary: http://192.168.1.1/easyconfig.html
```

### Common Tasks

**Restart router:**
```
System tab → Restart button
Or: reboot
```

**Restart WiFi:**
```bash
wifi down && wifi up
```

**Restart network:**
```bash
/etc/init.d/network restart
```

**Check modem info:**
```bash
easyconfig_modeminfo.sh
```

**View logs:**
```bash
logread
logread -f  # Follow
```

### Configuration Files

```
/etc/config/easyconfig                               # Main config
/etc/config/network                                  # Network
/etc/config/wireless                                 # WiFi
/usr/lib/easyconfig/easyconfig_statistics.json.gz   # Stats
```

### Support Resources

- **OpenWrt Wiki**: https://openwrt.org/
- **EasyConfig Author**: https://eko.one.pl/?p=easyconfig
- **OpenWrt Forum**: https://forum.openwrt.org/

---

**Document Version:** 1.0
**Last Updated:** 2025-10-25
**Based on:** https://eko.one.pl/?p=easyconfig (Polish original)
**License:** CC BY-SA 4.0
**Interface Language:** Polish (documentation in English)
