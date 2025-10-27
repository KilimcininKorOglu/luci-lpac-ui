# OpenWRT UCI (Unified Configuration Interface) Complete Guide

## Table of Contents
1. [Overview](#overview)
2. [What is UCI](#what-is-uci)
3. [UCI vs Legacy Configuration](#uci-vs-legacy-configuration)
4. [Configuration File Structure](#configuration-file-structure)
5. [UCI Syntax and Data Types](#uci-syntax-and-data-types)
6. [Reading Configuration](#reading-configuration)
7. [Modifying Configuration](#modifying-configuration)
8. [Advanced Operations](#advanced-operations)
9. [Configuration Files Reference](#configuration-files-reference)
10. [UCI Commands Reference](#uci-commands-reference)
11. [Practical Examples](#practical-examples)
12. [Scripting with UCI](#scripting-with-uci)
13. [Best Practices](#best-practices)
14. [Troubleshooting](#troubleshooting)
15. [References](#references)

---

## Overview

UCI (Unified Configuration Interface) is OpenWRT's centralized system configuration framework. It provides a standardized method for configuring all aspects of the router, from network settings to firewall rules, through both command-line interface and web interface (LuCI).

**Key Features:**
- Unified syntax across all configuration files
- Atomic commits for configuration changes
- Automatic backup of previous configurations
- Integration with system services
- Scriptable and automation-friendly
- Human-readable text format

**Advantages:**
- Reduced flash memory usage compared to legacy nvram
- Works with standard filesystems (ext2, ext3, ext4, JFFS2, UBIFS)
- Version control friendly
- Easy to backup and restore
- Consistent across OpenWRT versions

---

## What is UCI

### Architecture

UCI consists of:

1. **Configuration Files:** Located in `/etc/config/`
2. **UCI Command-Line Tool:** `/sbin/uci` binary
3. **UCI Libraries:** C library (libuci) and shell functions
4. **LuCI Integration:** Web interface uses UCI backend

### How It Works

```
User/Script
    ↓
UCI Command/API
    ↓
Configuration Files (/etc/config/)
    ↓
System Services (network, firewall, dhcp, etc.)
    ↓
System Configuration Applied
```

**Workflow:**
1. User modifies configuration using `uci` commands
2. Changes stored in memory (uncommitted)
3. User commits changes with `uci commit`
4. Configuration written to `/etc/config/` files
5. Relevant services reload configuration
6. System applies new settings

### Components

**Core Components:**
- `/sbin/uci` - Command-line interface
- `/lib/config/uci.sh` - Shell script functions
- `/usr/lib/lua/luci/model/uci.lua` - Lua bindings for LuCI
- `/etc/config/` - Configuration storage directory

---

## UCI vs Legacy Configuration

### Legacy nvram System

**Characteristics:**
- Used in older embedded systems (WRT54G, etc.)
- Stored in dedicated flash partition
- Limited space (typically 32-64KB)
- Proprietary format
- Not human-editable

**Example:**
```bash
nvram get wan_ifname
nvram set wan_proto=dhcp
nvram commit
```

### UCI System

**Characteristics:**
- Uses standard filesystem
- Plain text files (human-readable)
- Unlimited size (filesystem-dependent)
- Standardized format
- Version control compatible

**Example:**
```bash
uci get network.wan.ifname
uci set network.wan.proto='dhcp'
uci commit network
```

### Comparison

| Feature | nvram | UCI |
|---------|-------|-----|
| Storage | Dedicated partition | Filesystem (/etc/config) |
| Format | Binary | Plain text |
| Size limit | 32-64KB | Filesystem limit |
| Editability | No | Yes |
| Backup | Special tools | Standard file copy |
| Version control | No | Yes |
| Flash wear | Higher | Lower |

---

## Configuration File Structure

### File Location

All UCI configuration files are located in:
```bash
/etc/config/
```

**Common configuration files:**
```bash
ls -la /etc/config/
# network - Network interfaces, routes, switches
# wireless - WiFi configuration
# firewall - Firewall rules and zones
# dhcp - DHCP and DNS settings
# system - System settings (hostname, timezone, etc.)
# dropbear - SSH server configuration
# uhttpd - Web server configuration
```

### Basic Syntax

UCI files use a structured text format:

```
config <type> '<name>'
    option <key> '<value>'
    option <key> '<value>'
    list <collection> '<item>'
    list <collection> '<item>'
```

**Components:**
- `config`: Defines a configuration section
- `type`: Section type (e.g., interface, rule, zone)
- `name`: Section name (optional, can be anonymous)
- `option`: Single-value parameter
- `list`: Multi-value parameter

### Example Configuration File

**File: /etc/config/network**
```
config interface 'loopback'
    option ifname 'lo'
    option proto 'static'
    option ipaddr '127.0.0.1'
    option netmask '255.0.0.0'

config interface 'lan'
    option type 'bridge'
    option ifname 'eth0.1'
    option proto 'static'
    option ipaddr '192.168.1.1'
    option netmask '255.255.255.0'
    option ip6assign '60'

config interface 'wan'
    option ifname 'eth0.2'
    option proto 'dhcp'

config interface 'wan6'
    option ifname 'eth0.2'
    option proto 'dhcpv6'
```

### Section Types

**Named Sections:**
```
config interface 'lan'
    option proto 'static'
```
- Section has explicit name: `lan`
- Referenced directly: `network.lan`

**Anonymous Sections:**
```
config rule
    option src 'wan'
    option target 'DROP'
```
- Section has no name
- Referenced by index: `firewall.@rule[0]`
- Order matters

---

## UCI Syntax and Data Types

### Access Notation

UCI uses dot notation to access configuration:

```
<config>.<section>.<option>
```

**Examples:**
```bash
network.lan.ipaddr           # Named section
network.@interface[0].ipaddr # Anonymous section (first)
network.@interface[-1].ipaddr # Anonymous section (last)
```

### Data Types

#### 1. String (option)

Single value:
```
config interface 'lan'
    option proto 'static'
    option ipaddr '192.168.1.1'
```

Access:
```bash
uci get network.lan.proto    # Returns: static
```

#### 2. List

Multiple values:
```
config rule
    option name 'Allow-DHCP'
    list proto 'udp'
    list dest_port '67'
    list dest_port '68'
```

Access:
```bash
uci get firewall.@rule[0].proto        # Returns: udp
uci get firewall.@rule[0].dest_port    # Returns: 67 68
```

#### 3. Boolean

True/false values (stored as '0' or '1'):
```
config interface 'wan'
    option proto 'dhcp'
    option auto '1'              # enabled
    option defaultroute '1'      # true
```

### Naming Rules

**Valid option names:**
- Alphanumeric characters
- Underscores
- **Cannot contain hyphens (-)**

**Valid:**
```
option ip_addr '192.168.1.1'
option wan_proto 'dhcp'
```

**Invalid:**
```
option ip-addr '192.168.1.1'    # Error: hyphens not allowed
```

### Quoting Rules

**Values with spaces require quotes:**
```
option ssid 'My WiFi Network'    # Correct
option ssid My WiFi Network      # Incorrect - syntax error
```

**Simple values can be unquoted:**
```
option proto static    # Works
option proto 'static'  # Also works (recommended)
```

**Best practice:** Always use quotes for consistency.

---

## Reading Configuration

### Display Entire Configuration

```bash
# Show all configurations
uci show

# Output example:
# network.loopback=interface
# network.loopback.ifname='lo'
# network.loopback.proto='static'
# ...
```

### Display Specific Configuration File

```bash
# Show entire network configuration
uci show network

# Show entire firewall configuration
uci show firewall

# Show wireless configuration
uci show wireless
```

### Display Specific Section

```bash
# Show named section
uci show network.lan

# Output:
# network.lan=interface
# network.lan.type='bridge'
# network.lan.proto='static'
# network.lan.ipaddr='192.168.1.1'
# network.lan.netmask='255.255.255.0'

# Show anonymous section (first)
uci show firewall.@rule[0]

# Show anonymous section (last)
uci show firewall.@rule[-1]
```

### Get Specific Option Value

```bash
# Get single option
uci get network.lan.ipaddr
# Output: 192.168.1.1

# Get option from anonymous section
uci get firewall.@rule[0].name
# Output: Allow-DHCP-Renew

# Get list values
uci get firewall.@rule[0].dest_port
# Output: 67 68
```

### Quiet Mode

Suppress errors when option doesn't exist:

```bash
# Normal mode (shows error if not found)
uci get network.wan.nonexistent
# Error: Entry not found

# Quiet mode (no error, just empty output)
uci -q get network.wan.nonexistent
# (no output)
```

**Use in scripts:**
```bash
IP=$(uci -q get network.lan.ipaddr)
if [ -n "$IP" ]; then
    echo "LAN IP: $IP"
else
    echo "LAN IP not configured"
fi
```

### Export Configuration

```bash
# Export entire configuration in UCI format
uci export network

# Export specific section
uci export network.lan

# Save to file
uci export network > /tmp/network_backup.uci
```

---

## Modifying Configuration

### Set Option Value

**Named section:**
```bash
# Set LAN IP address
uci set network.lan.ipaddr='192.168.2.1'

# Set WiFi SSID
uci set wireless.@wifi-iface[0].ssid='MyNetwork'

# Set firewall rule name
uci set firewall.@rule[0].name='Custom Rule'
```

**Anonymous section (by index):**
```bash
# Modify first rule
uci set firewall.@rule[0].target='ACCEPT'

# Modify last rule
uci set firewall.@rule[-1].enabled='1'
```

### Create New Named Section

```bash
# Create new interface named 'guest'
uci set network.guest=interface
uci set network.guest.proto='static'
uci set network.guest.ipaddr='192.168.3.1'
uci set network.guest.netmask='255.255.255.0'
```

### Add Anonymous Section

```bash
# Add new firewall rule
uci add firewall rule

# This returns: cfg0123ab (auto-generated ID)
# Configure the newly added rule (last one)
uci set firewall.@rule[-1].name='Block WAN SSH'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='22'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='DROP'
```

### Add List Items

```bash
# Add to existing list
uci add_list firewall.@rule[0].dest_port='80'
uci add_list firewall.@rule[0].dest_port='443'

# Create list if it doesn't exist
uci add_list network.lan.dns='8.8.8.8'
uci add_list network.lan.dns='8.8.4.4'
```

### Delete Option

```bash
# Delete single option
uci delete network.lan.ip6assign

# Delete from anonymous section
uci delete firewall.@rule[0].name
```

### Delete List Item

```bash
# Delete specific list item
uci del_list network.lan.dns='8.8.8.8'

# Delete entire list
uci delete network.lan.dns
```

### Delete Section

```bash
# Delete named section
uci delete network.guest

# Delete anonymous section by index
uci delete firewall.@rule[2]

# Delete last section
uci delete firewall.@rule[-1]
```

### Rename Section

```bash
# Rename section
uci rename network.lan=internal_network

# Now accessible as:
uci get network.internal_network.ipaddr
```

### View Uncommitted Changes

```bash
# Show all pending changes
uci changes

# Show changes for specific config
uci changes network
uci changes firewall

# Output example:
# network.lan.ipaddr='192.168.2.1'
# -firewall.@rule[2]
# +firewall.@rule[-1].name='Custom Rule'
```

### Commit Changes

**Commit makes changes permanent:**

```bash
# Commit specific config file
uci commit network

# Commit all changes
uci commit

# After commit, changes are written to /etc/config/
```

**Important:** Changes are NOT applied until commit!

### Revert Changes

**Discard uncommitted changes:**

```bash
# Revert specific config
uci revert network

# Revert all changes
uci revert

# Revert specific option
uci revert network.lan.ipaddr
```

---

## Advanced Operations

### Batch Operations

Execute multiple UCI commands at once:

```bash
uci batch << EOF
set network.lan.ipaddr='192.168.2.1'
set network.lan.netmask='255.255.255.0'
delete network.guest
add firewall rule
set firewall.@rule[-1].name='Test'
commit network
commit firewall
EOF
```

**Advantages:**
- Faster than individual commands
- Atomic operations
- Better for scripts

### Import Configuration

```bash
# Import UCI configuration from file
uci import network < /tmp/network_backup.uci

# Import and overwrite existing
uci import -f network < /tmp/network_backup.uci
```

### Configuration Backup and Restore

**Backup:**
```bash
# Backup single config
uci export network > /tmp/backup_network.uci

# Backup all configs
tar -czf /tmp/uci_backup.tar.gz /etc/config/
```

**Restore:**
```bash
# Restore single config
uci import network < /tmp/backup_network.uci
uci commit network

# Restore all configs
tar -xzf /tmp/uci_backup.tar.gz -C /
```

### Configuration Templates

Create reusable configuration templates:

```bash
# Template: guest network
cat > /tmp/guest_network_template.uci << 'EOF'
set network.guest=interface
set network.guest.proto='static'
set network.guest.ipaddr='172.16.0.1'
set network.guest.netmask='255.255.255.0'
set network.guest.device='br-guest'
set firewall.guest_zone=zone
set firewall.guest_zone.name='guest'
set firewall.guest_zone.input='REJECT'
set firewall.guest_zone.forward='REJECT'
set firewall.guest_zone.output='ACCEPT'
add_list firewall.guest_zone.network='guest'
EOF

# Apply template
uci batch < /tmp/guest_network_template.uci
uci commit
```

### Conditional Configuration

```bash
# Set option only if not already set
if ! uci -q get network.lan.ipaddr > /dev/null; then
    uci set network.lan.ipaddr='192.168.1.1'
    uci commit network
fi

# Change option only if different
CURRENT_IP=$(uci -q get network.lan.ipaddr)
NEW_IP='192.168.2.1'

if [ "$CURRENT_IP" != "$NEW_IP" ]; then
    uci set network.lan.ipaddr="$NEW_IP"
    uci commit network
    /etc/init.d/network reload
fi
```

### Loop Through Sections

```bash
# Count sections of specific type
count=0
while uci -q get firewall.@rule[$count] > /dev/null; do
    count=$((count + 1))
done
echo "Total firewall rules: $count"

# Process each section
i=0
while uci -q get firewall.@rule[$i] > /dev/null; do
    name=$(uci -q get firewall.@rule[$i].name)
    echo "Rule $i: $name"
    i=$((i + 1))
done
```

---

## Configuration Files Reference

### network

**Purpose:** Network interfaces, routes, switches, VLANs

**Common sections:**
```bash
# Show all interfaces
uci show network | grep "=interface"

# Get interface list
uci show network | grep "^network\\..*=interface" | cut -d. -f2 | cut -d= -f1
```

**Example configuration:**
```bash
uci set network.lan.ipaddr='192.168.1.1'
uci set network.wan.proto='dhcp'
uci add_list network.lan.dns='8.8.8.8'
```

### wireless

**Purpose:** WiFi configuration (radios and interfaces)

**Common operations:**
```bash
# Show all wireless interfaces
uci show wireless | grep "=wifi-iface"

# Enable WiFi
uci set wireless.radio0.disabled='0'

# Set SSID
uci set wireless.@wifi-iface[0].ssid='MyNetwork'

# Set encryption
uci set wireless.@wifi-iface[0].encryption='psk2'
uci set wireless.@wifi-iface[0].key='mypassword'
```

### firewall

**Purpose:** Firewall zones, rules, forwarding, NAT

**Common operations:**
```bash
# List all rules
uci show firewall | grep "=rule"

# Add port forwarding
uci add firewall redirect
uci set firewall.@redirect[-1].name='SSH Forward'
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].src_dport='2222'
uci set firewall.@redirect[-1].dest='lan'
uci set firewall.@redirect[-1].dest_ip='192.168.1.100'
uci set firewall.@redirect[-1].dest_port='22'
uci set firewall.@redirect[-1].proto='tcp'
```

### dhcp

**Purpose:** DHCP server and DNS forwarder (dnsmasq)

**Common operations:**
```bash
# Show DHCP configuration
uci show dhcp

# Configure DHCP pool
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'

# Add static lease
uci add dhcp host
uci set dhcp.@host[-1].name='server'
uci set dhcp.@host[-1].mac='aa:bb:cc:dd:ee:ff'
uci set dhcp.@host[-1].ip='192.168.1.100'
```

### system

**Purpose:** System settings (hostname, timezone, LED configuration)

**Common operations:**
```bash
# Show system configuration
uci show system

# Set hostname
uci set system.@system[0].hostname='MyRouter'

# Set timezone
uci set system.@system[0].timezone='UTC'
uci set system.@system[0].zonename='UTC'

# Configure NTP servers
uci del_list system.ntp.server='0.openwrt.pool.ntp.org'
uci add_list system.ntp.server='pool.ntp.org'
```

### dropbear

**Purpose:** SSH server configuration

**Common operations:**
```bash
# Show SSH configuration
uci show dropbear

# Change SSH port
uci set dropbear.@dropbear[0].Port='2222'

# Disable password authentication
uci set dropbear.@dropbear[0].PasswordAuth='off'

# Disable root login
uci set dropbear.@dropbear[0].RootPasswordAuth='off'
```

---

## UCI Commands Reference

### Complete Command List

| Command | Purpose | Example |
|---------|---------|---------|
| `uci show` | Display configuration | `uci show network` |
| `uci get` | Get option value | `uci get network.lan.ipaddr` |
| `uci set` | Set option value | `uci set network.lan.ipaddr='192.168.2.1'` |
| `uci add` | Add anonymous section | `uci add firewall rule` |
| `uci add_list` | Add list item | `uci add_list network.lan.dns='8.8.8.8'` |
| `uci del_list` | Delete list item | `uci del_list network.lan.dns='8.8.8.8'` |
| `uci delete` | Delete option/section | `uci delete network.guest` |
| `uci rename` | Rename section | `uci rename network.lan=internal` |
| `uci commit` | Save changes | `uci commit network` |
| `uci revert` | Discard changes | `uci revert network` |
| `uci changes` | Show pending changes | `uci changes` |
| `uci export` | Export configuration | `uci export network` |
| `uci import` | Import configuration | `uci import network < file` |
| `uci batch` | Execute multiple commands | `uci batch < commands.txt` |

### Command Options

| Option | Purpose |
|--------|---------|
| `-q` | Quiet mode (suppress errors) |
| `-c DIR` | Use custom config directory |
| `-p DIR` | Add search path for config files |
| `-P DIR` | Use as save directory |
| `-f FILE` | Use specific file instead of /etc/config/ |
| `-m` | Show package metadata |
| `-n` | Don't commit changes to persistent storage |

---

## Practical Examples

### Example 1: Change LAN IP Address

```bash
# View current configuration
uci get network.lan.ipaddr

# Change LAN IP
uci set network.lan.ipaddr='192.168.10.1'

# Commit changes
uci commit network

# Reload network service
/etc/init.d/network reload
```

### Example 2: Configure WiFi Network

```bash
# Enable WiFi radio
uci set wireless.radio0.disabled='0'

# Set 2.4GHz WiFi SSID and password
uci set wireless.@wifi-iface[0].ssid='MyHomeNetwork'
uci set wireless.@wifi-iface[0].encryption='psk2'
uci set wireless.@wifi-iface[0].key='MySecurePassword123'

# Commit and reload
uci commit wireless
wifi reload
```

### Example 3: Add Firewall Rule to Allow Port

```bash
# Add new firewall rule
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-HTTP'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='80'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'

# Commit and reload
uci commit firewall
/etc/init.d/firewall reload
```

### Example 4: Configure Static DHCP Lease

```bash
# Add static lease for a device
uci add dhcp host
uci set dhcp.@host[-1].name='Printer'
uci set dhcp.@host[-1].mac='aa:bb:cc:dd:ee:ff'
uci set dhcp.@host[-1].ip='192.168.1.50'

# Commit and restart DHCP
uci commit dhcp
/etc/init.d/dnsmasq restart
```

### Example 5: Port Forwarding Configuration

```bash
# Forward external port 8080 to internal server port 80
uci add firewall redirect
uci set firewall.@redirect[-1].name='Web Server Forward'
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].src_dport='8080'
uci set firewall.@redirect[-1].dest='lan'
uci set firewall.@redirect[-1].dest_ip='192.168.1.100'
uci set firewall.@redirect[-1].dest_port='80'
uci set firewall.@redirect[-1].proto='tcp'

# Commit and reload
uci commit firewall
/etc/init.d/firewall reload
```

### Example 6: Guest Network Setup

```bash
# Create guest interface
uci set network.guest=interface
uci set network.guest.proto='static'
uci set network.guest.ipaddr='192.168.5.1'
uci set network.guest.netmask='255.255.255.0'

# Create guest WiFi
uci add wireless wifi-iface
uci set wireless.@wifi-iface[-1].device='radio0'
uci set wireless.@wifi-iface[-1].mode='ap'
uci set wireless.@wifi-iface[-1].network='guest'
uci set wireless.@wifi-iface[-1].ssid='GuestNetwork'
uci set wireless.@wifi-iface[-1].encryption='psk2'
uci set wireless.@wifi-iface[-1].key='guestpass123'
uci set wireless.@wifi-iface[-1].isolate='1'

# Create firewall zone for guest
uci add firewall zone
uci set firewall.@zone[-1].name='guest'
uci set firewall.@zone[-1].input='REJECT'
uci set firewall.@zone[-1].forward='REJECT'
uci set firewall.@zone[-1].output='ACCEPT'
uci add_list firewall.@zone[-1].network='guest'

# Allow guest to access WAN
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='guest'
uci set firewall.@forwarding[-1].dest='wan'

# Configure DHCP for guest
uci set dhcp.guest=dhcp
uci set dhcp.guest.interface='guest'
uci set dhcp.guest.start='100'
uci set dhcp.guest.limit='150'
uci set dhcp.guest.leasetime='1h'

# Commit all changes
uci commit
/etc/init.d/network reload
/etc/init.d/firewall reload
wifi reload
/etc/init.d/dnsmasq reload
```

---

## Scripting with UCI

### Shell Script Integration

```bash
#!/bin/sh
# Configure LAN network from script

# Get current configuration
CURRENT_IP=$(uci get network.lan.ipaddr)
echo "Current LAN IP: $CURRENT_IP"

# Set new configuration
NEW_IP="192.168.100.1"
uci set network.lan.ipaddr="$NEW_IP"
uci set network.lan.netmask="255.255.255.0"

# Add DNS servers
uci del_list network.lan.dns  # Clear existing
uci add_list network.lan.dns='8.8.8.8'
uci add_list network.lan.dns='1.1.1.1'

# Commit and reload
uci commit network
/etc/init.d/network reload

echo "LAN IP changed to: $NEW_IP"
```

### Error Handling

```bash
#!/bin/sh

# Check if option exists
if uci -q get network.lan.ipaddr > /dev/null; then
    echo "LAN IP is configured"
else
    echo "LAN IP not configured, setting default"
    uci set network.lan.ipaddr='192.168.1.1'
    uci commit network
fi

# Validate changes before committing
NEW_IP="192.168.2.1"
if echo "$NEW_IP" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    uci set network.lan.ipaddr="$NEW_IP"
    uci commit network
else
    echo "Error: Invalid IP address format"
    exit 1
fi
```

### Configuration Automation Script

```bash
#!/bin/sh
# Automated router setup script

setup_router() {
    echo "Starting router configuration..."

    # System settings
    uci set system.@system[0].hostname='MyRouter'
    uci set system.@system[0].timezone='EST5EDT,M3.2.0,M11.1.0'
    uci commit system

    # Network settings
    uci set network.lan.ipaddr='192.168.1.1'
    uci set network.lan.netmask='255.255.255.0'
    uci commit network

    # WiFi settings
    uci set wireless.radio0.disabled='0'
    uci set wireless.radio0.channel='6'
    uci set wireless.radio0.htmode='HT40'

    uci set wireless.@wifi-iface[0].ssid='MyNetwork'
    uci set wireless.@wifi-iface[0].encryption='psk2+ccmp'
    uci set wireless.@wifi-iface[0].key='SecurePassword123'
    uci commit wireless

    # DHCP settings
    uci set dhcp.lan.start='100'
    uci set dhcp.lan.limit='150'
    uci set dhcp.lan.leasetime='12h'
    uci commit dhcp

    # Firewall settings
    uci set firewall.@defaults[0].syn_flood='1'
    uci set firewall.@defaults[0].input='ACCEPT'
    uci set firewall.@defaults[0].output='ACCEPT'
    uci set firewall.@defaults[0].forward='REJECT'
    uci commit firewall

    # Apply all changes
    /etc/init.d/network reload
    /etc/init.d/firewall reload
    wifi reload
    /etc/init.d/dnsmasq reload

    echo "Router configuration completed!"
}

setup_router
```

### UCI Function Library

```bash
#!/bin/sh
# /lib/functions/uci_helpers.sh

# Check if section exists
uci_section_exists() {
    uci -q get "$1" > /dev/null
    return $?
}

# Get section count
uci_section_count() {
    local config="$1"
    local type="$2"
    local count=0

    while uci -q get "${config}.@${type}[${count}]" > /dev/null; do
        count=$((count + 1))
    done

    echo "$count"
}

# Find section by option value
uci_find_section() {
    local config="$1"
    local type="$2"
    local option="$3"
    local value="$4"
    local i=0

    while uci -q get "${config}.@${type}[${i}]" > /dev/null; do
        local current=$(uci -q get "${config}.@${type}[${i}].${option}")
        if [ "$current" = "$value" ]; then
            echo "$i"
            return 0
        fi
        i=$((i + 1))
    done

    return 1
}

# Usage examples:
# if uci_section_exists network.lan; then
#     echo "LAN section exists"
# fi
#
# rule_count=$(uci_section_count firewall rule)
# echo "Total firewall rules: $rule_count"
#
# idx=$(uci_find_section wireless wifi-iface ssid "MyNetwork")
# echo "SSID 'MyNetwork' found at index: $idx"
```

---

## Best Practices

### 1. Always Commit After Changes

```bash
# Bad: Forgot to commit
uci set network.lan.ipaddr='192.168.2.1'
/etc/init.d/network reload  # Changes not saved!

# Good: Commit before reload
uci set network.lan.ipaddr='192.168.2.1'
uci commit network
/etc/init.d/network reload
```

### 2. Check Changes Before Committing

```bash
# Make changes
uci set network.lan.ipaddr='192.168.2.1'
uci set network.lan.netmask='255.255.255.0'

# Review changes
uci changes network

# If correct, commit
uci commit network

# If incorrect, revert
uci revert network
```

### 3. Use Quiet Mode in Scripts

```bash
# Get value with error handling
IP=$(uci -q get network.lan.ipaddr)
if [ -z "$IP" ]; then
    echo "Error: LAN IP not configured"
    IP="192.168.1.1"  # Default
fi
```

### 4. Backup Before Major Changes

```bash
# Backup configuration
uci export network > /tmp/network_backup_$(date +%Y%m%d).uci

# Make changes
uci set network.lan.ipaddr='192.168.2.1'
uci commit network

# If something goes wrong, restore:
# uci import network < /tmp/network_backup_YYYYMMDD.uci
# uci commit network
```

### 5. Validate Input

```bash
# Validate IP address before setting
validate_ip() {
    echo "$1" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
}

NEW_IP="192.168.2.1"
if validate_ip "$NEW_IP"; then
    uci set network.lan.ipaddr="$NEW_IP"
    uci commit network
else
    echo "Invalid IP address: $NEW_IP"
    exit 1
fi
```

### 6. Use Batch for Multiple Changes

```bash
# Instead of:
uci set network.lan.ipaddr='192.168.2.1'
uci set network.lan.netmask='255.255.255.0'
uci add_list network.lan.dns='8.8.8.8'
uci add_list network.lan.dns='1.1.1.1'
uci commit network

# Use batch:
uci batch << EOF
set network.lan.ipaddr='192.168.2.1'
set network.lan.netmask='255.255.255.0'
add_list network.lan.dns='8.8.8.8'
add_list network.lan.dns='1.1.1.1'
commit network
EOF
```

### 7. Comment Your Changes

```bash
# Document what you're doing
echo "# Changing LAN to 192.168.2.0/24 network" >> /etc/config/network.notes
uci set network.lan.ipaddr='192.168.2.1'
uci commit network
```

### 8. Test Before Production

```bash
# Test on a separate config directory
UCI_TEST_DIR="/tmp/uci_test"
mkdir -p "$UCI_TEST_DIR"
cp -r /etc/config/* "$UCI_TEST_DIR/"

# Make changes to test directory
uci -c "$UCI_TEST_DIR" set network.lan.ipaddr='192.168.2.1'
uci -c "$UCI_TEST_DIR" commit network

# Verify
uci -c "$UCI_TEST_DIR" show network.lan

# If good, apply to production
uci set network.lan.ipaddr='192.168.2.1'
uci commit network
```

---

## Troubleshooting

### Problem: Changes Not Persisting After Reboot

**Cause:** Forgot to commit changes.

**Solution:**
```bash
# Always commit after making changes
uci set network.lan.ipaddr='192.168.2.1'
uci commit network  # Critical!
```

### Problem: "Entry not found" Error

**Cause:** Section or option doesn't exist.

**Solution:**
```bash
# Check if section exists
uci show network.lan

# Use quiet mode in scripts
IP=$(uci -q get network.lan.ipaddr)
if [ -z "$IP" ]; then
    echo "IP not configured"
fi
```

### Problem: Syntax Error in Configuration File

**Cause:** Manual editing broke syntax.

**Solution:**
```bash
# Validate configuration
uci show network

# If errors, restore from backup
cp /rom/etc/config/network /etc/config/network
# Or restore from /etc/backup/

# Recommit
uci commit network
```

### Problem: Can't Access Router After Network Change

**Cause:** Changed LAN IP but still trying old IP.

**Solution:**
```bash
# Before changing IP, note the new IP
# Access router at new IP address
# Example: Changed from 192.168.1.1 to 192.168.2.1
# Access: http://192.168.2.1

# Or use failsafe mode to reset:
# 1. Reboot router
# 2. Press reset button during boot
# 3. Telnet to 192.168.1.1
# 4. mount_root
# 5. Fix configuration
```

### Problem: Changes Reverted After Service Reload

**Cause:** Some services regenerate config from other sources.

**Solution:**
```bash
# Always use UCI, not manual editing
# Don't edit /var/run/ files (they're regenerated)
# Edit /etc/config/ files using UCI
```

### Problem: "Configuration file not found"

**Cause:** Config file missing or typo in name.

**Solution:**
```bash
# List available config files
ls /etc/config/

# Check exact name (case-sensitive)
uci show network  # Correct
uci show Network  # Wrong (case matters)
```

### Problem: List Values Not Working as Expected

**Cause:** Using `set` instead of `add_list`.

**Solution:**
```bash
# Wrong: This overwrites the list
uci set network.lan.dns='8.8.8.8'
uci set network.lan.dns='1.1.1.1'  # Overwrites previous!

# Correct: Use add_list
uci add_list network.lan.dns='8.8.8.8'
uci add_list network.lan.dns='1.1.1.1'  # Adds to list
```

### Problem: Anonymous Section Index Changed

**Cause:** Sections reordered after delete/add operations.

**Solution:**
```bash
# Use named sections for important config
uci set firewall.allow_ssh=rule
uci set firewall.allow_ssh.name='Allow-SSH'
# Now always accessible as firewall.allow_ssh

# Or find by option value before modifying
idx=$(uci_find_section firewall rule name "Allow-SSH")
uci set firewall.@rule[$idx].target='ACCEPT'
```

---

## References

### Official Documentation
- **OpenWRT UCI Documentation:** https://openwrt.org/docs/guide-user/base-system/uci
- **UCI Technical Reference:** https://openwrt.org/docs/techref/uci
- **LuCI (Web Interface):** https://openwrt.org/docs/guide-user/luci/start

### Related Pages
- **eko.one.pl UCI Guide:** https://eko.one.pl/?p=openwrt-uci
- **UCI Configuration Files:** https://openwrt.org/docs/guide-user/base-system/basic-networking

### Tools and Libraries
- **uci:** Command-line interface
- **libuci:** C library
- **luci.model.uci:** Lua bindings

### Community Resources
- **OpenWRT Forum:** https://forum.openwrt.org/
- **OpenWRT Wiki:** https://openwrt.org/

---

## Summary

UCI (Unified Configuration Interface) is OpenWRT's powerful configuration system:

**Key Concepts:**
- Centralized configuration in `/etc/config/`
- Dot notation access: `config.section.option`
- Named and anonymous sections
- Atomic commits for changes
- Integration with system services

**Basic Workflow:**
```bash
# 1. View current configuration
uci show network.lan

# 2. Make changes
uci set network.lan.ipaddr='192.168.2.1'

# 3. Review changes
uci changes network

# 4. Commit changes
uci commit network

# 5. Reload service
/etc/init.d/network reload
```

**Essential Commands:**
- `uci show` - Display configuration
- `uci get` - Retrieve value
- `uci set` - Modify value
- `uci commit` - Save changes
- `uci revert` - Discard changes

**Best Practices:**
- Always commit after changes
- Use quiet mode (`-q`) in scripts
- Backup before major changes
- Validate input data
- Use batch for multiple operations
- Test before production deployment

**Advantages Over Legacy Systems:**
- Human-readable text format
- Version control friendly
- Reduced flash wear
- Standard filesystem compatible
- Consistent syntax across all configs

UCI provides a robust, scriptable, and user-friendly way to manage all aspects of OpenWRT router configuration.

---

*This guide is based on the eko.one.pl UCI documentation and official OpenWRT UCI reference materials.*
