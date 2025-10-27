# OpenWrt Failover and Multi-WAN Guide

Comprehensive guide for configuring internet failover and multi-WAN setups on OpenWrt routers, including Simple Failover and mwan3 solutions.

**Based on:** https://eko.one.pl/?p=openwrt-simplefailover
**Target Audience:** Network administrators, system integrators, OpenWrt users
**OpenWrt Versions:** Compatible with OpenWrt 15.05 through current releases

---

## Table of Contents

1. [Introduction to Failover](#introduction-to-failover)
2. [Failover Solutions Comparison](#failover-solutions-comparison)
3. [Simple Failover Setup](#simple-failover-setup)
4. [mwan3 Advanced Multi-WAN](#mwan3-advanced-multi-wan)
5. [Multiple WAN Interface Configuration](#multiple-wan-interface-configuration)
6. [Load Balancing](#load-balancing)
7. [Monitoring and Testing](#monitoring-and-testing)
8. [Troubleshooting](#troubleshooting)
9. [Real-World Scenarios](#real-world-scenarios)
10. [Best Practices](#best-practices)

---

## Introduction to Failover

### What is Internet Failover?

**Failover** is the automatic switching from a primary internet connection to a backup connection when the primary fails. This ensures continuous internet connectivity for critical applications.

**Common use cases:**
- **Business continuity** - Offices requiring 24/7 internet access
- **Remote locations** - Areas with unreliable primary connections
- **Cost optimization** - Use cheap unlimited primary + expensive metered backup
- **Mobile routers** - Cellular backup for cable/fiber primary
- **IoT/M2M** - Critical sensors and monitoring systems

### Failover vs Load Balancing

| Feature | Failover | Load Balancing |
|---------|----------|----------------|
| **Purpose** | Backup when primary fails | Distribute traffic across links |
| **Active links** | One at a time | Multiple simultaneously |
| **Bandwidth** | Single link speed | Combined link speeds |
| **Complexity** | Simple | Complex |
| **Cost** | Lower (backup idle) | Higher (all links active) |
| **Use case** | Reliability | Performance + reliability |

### How Failover Works

```
┌─────────────┐
│   Router    │
└─────┬───┬───┘
      │   │
  WAN │   │ WAN2 (Backup)
      │   │
   [ISP1] [ISP2/4G]
      │   │
      ▼   ▼
   Internet
```

**Normal operation:**
1. All traffic uses WAN (primary)
2. Router periodically tests WAN connectivity (ping/HTTP)
3. WAN2 (backup) is idle or disconnected

**When primary fails:**
1. Connectivity test fails (timeout/packet loss)
2. Router activates WAN2 (backup)
3. Default route switches to WAN2
4. All traffic flows through backup

**When primary recovers:**
1. Connectivity test succeeds
2. Router switches back to WAN (primary)
3. WAN2 becomes idle again

---

## Failover Solutions Comparison

### 1. Simple Failover

**Package:** `simplefailover`
**Complexity:** Low
**Best for:** Basic failover with minimal configuration

**Advantages:**
- ✅ Very simple to configure
- ✅ Lightweight (minimal resources)
- ✅ Backup only activates when needed (saves data/costs)
- ✅ Ideal for metered backup connections (3G/4G)
- ✅ Fast to set up

**Disadvantages:**
- ❌ No load balancing
- ❌ No advanced policies
- ❌ Switching takes 5-30 seconds
- ❌ Doesn't work with interfaces that disappear (PPPoE, some modems)
- ❌ Limited monitoring options

**Typical scenario:** Cable primary + USB 3G modem backup

### 2. mwan3 (Multi-WAN Manager)

**Package:** `mwan3`
**Complexity:** Medium-High
**Best for:** Advanced multi-WAN with load balancing

**Advantages:**
- ✅ Full load balancing support
- ✅ Advanced routing policies
- ✅ Per-IP/per-service routing
- ✅ Multiple failover tiers (primary → backup1 → backup2)
- ✅ Comprehensive monitoring
- ✅ Works with all interface types
- ✅ LuCI web interface available

**Disadvantages:**
- ❌ More complex configuration
- ❌ Higher resource usage
- ❌ All links must be active (costs more on metered connections)
- ❌ Steeper learning curve

**Typical scenario:** Dual ISP with load balancing, business networks

### 3. Custom Scripts

**Package:** Custom shell scripts
**Complexity:** Variable
**Best for:** Specific requirements not met by existing solutions

**Advantages:**
- ✅ Full customization
- ✅ Can handle edge cases
- ✅ No package dependencies

**Disadvantages:**
- ❌ Requires scripting knowledge
- ❌ Maintenance burden
- ❌ Potential for bugs

---

## Simple Failover Setup

### Installation

```bash
# Update package list
opkg update

# Install Simple Failover
opkg install simplefailover
```

**Note:** If not available in official repository, download from community repositories.

### Configuration File

**Location:** `/etc/config/simplefailover`

**Default configuration:**
```bash
config simplefailover
    option wan_main 'wan'
    option wan_backup 'wan2'
    option host '8.8.4.4'
    option interval '5'
```

### Configuration Options

| Option | Description | Default | Example |
|--------|-------------|---------|---------|
| `wan_main` | Primary WAN interface name | `wan` | `wan`, `eth1`, `pppoe-wan` |
| `wan_backup` | Backup WAN interface name | `wan2` | `wan2`, `3g`, `wwan0` |
| `host` | Target host for connectivity tests | `8.8.4.4` | `8.8.8.8`, `1.1.1.1` |
| `interval` | Check interval in seconds | `5` | `5`, `10`, `30` |

### Basic Configuration Examples

#### Example 1: Cable Primary + 3G Backup

```bash
# Configure backup interface (3G modem)
uci set network.wan2=interface
uci set network.wan2.proto='3g'
uci set network.wan2.device='/dev/ttyUSB0'
uci set network.wan2.service='umts'
uci set network.wan2.apn='internet'
uci set network.wan2.username=''
uci set network.wan2.password=''
uci set network.wan2.defaultroute='1'
uci set network.wan2.auto='0'  # Don't start automatically
uci commit network

# Add backup to firewall WAN zone
uci set firewall.@zone[1].network='wan wan2'
uci commit firewall

# Configure Simple Failover
uci set simplefailover.@simplefailover[0].wan_main='wan'
uci set simplefailover.@simplefailover[0].wan_backup='wan2'
uci set simplefailover.@simplefailover[0].host='8.8.8.8'
uci set simplefailover.@simplefailover[0].interval='10'
uci commit simplefailover

# Enable and start service
/etc/init.d/simplefailover enable
/etc/init.d/simplefailover start

# Restart network
/etc/init.d/network restart
/etc/init.d/firewall restart
```

#### Example 2: Cable Primary + 4G LTE Backup

```bash
# Configure 4G backup (using QMI protocol)
uci set network.wan2=interface
uci set network.wan2.proto='qmi'
uci set network.wan2.device='/dev/cdc-wdm0'
uci set network.wan2.apn='internet'
uci set network.wan2.pdptype='ipv4'
uci set network.wan2.defaultroute='1'
uci set network.wan2.auto='0'
uci commit network

# Add to firewall
uci set firewall.@zone[1].network='wan wan2'
uci commit firewall

# Configure Simple Failover
uci set simplefailover.@simplefailover[0].wan_backup='wan2'
uci commit simplefailover

# Enable service
/etc/init.d/simplefailover enable
/etc/init.d/simplefailover start
```

#### Example 3: Dual Ethernet ISPs

```bash
# Configure second ethernet WAN
uci set network.wan2=interface
uci set network.wan2.proto='dhcp'
uci set network.wan2.ifname='eth1'  # Or appropriate interface
uci set network.wan2.defaultroute='1'
uci set network.wan2.auto='0'
uci commit network

# Add to firewall
uci set firewall.@zone[1].network='wan wan2'
uci commit firewall

# Configure Simple Failover
uci set simplefailover.@simplefailover[0].wan_backup='wan2'
uci commit simplefailover

# Enable service
/etc/init.d/simplefailover enable
/etc/init.d/simplefailover start
```

### Modify Configuration

```bash
# Change backup interface name
uci set simplefailover.@simplefailover[0].wan_backup='3g'
uci commit simplefailover
/etc/init.d/simplefailover restart

# Change ping target (use Cloudflare DNS)
uci set simplefailover.@simplefailover[0].host='1.1.1.1'
uci commit simplefailover
/etc/init.d/simplefailover restart

# Change check interval to 30 seconds
uci set simplefailover.@simplefailover[0].interval='30'
uci commit simplefailover
/etc/init.d/simplefailover restart
```

### View Configuration

```bash
# Show current configuration
uci show simplefailover

# Check service status
/etc/init.d/simplefailover status

# View logs
logread | grep simplefailover
```

---

## mwan3 Advanced Multi-WAN

### Installation

```bash
# Update package list
opkg update

# Install mwan3 and LuCI interface
opkg install mwan3 luci-app-mwan3

# Restart web interface
/etc/init.d/uhttpd restart
```

**Access web interface:** `Network → Load Balancing` in LuCI

### mwan3 Configuration Structure

mwan3 uses four main configuration sections:

1. **Interfaces** - Define WAN connections
2. **Members** - Interface + metric + weight
3. **Policies** - How to use members (failover, load balance)
4. **Rules** - Which traffic uses which policy

### Basic mwan3 Configuration

#### 1. Define Interfaces

```bash
# WAN1 (primary)
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

# WAN2 (backup)
uci set mwan3.wan2=interface
uci set mwan3.wan2.enabled='1'
uci set mwan3.wan2.initial_state='online'
uci set mwan3.wan2.family='ipv4'
uci set mwan3.wan2.track_method='ping'
uci set mwan3.wan2.track_hosts='8.8.8.8'
uci set mwan3.wan2.reliability='1'
uci set mwan3.wan2.count='1'
uci set mwan3.wan2.timeout='2'
uci set mwan3.wan2.interval='10'
uci set mwan3.wan2.down='3'
uci set mwan3.wan2.up='3'

uci commit mwan3
```

**Key options:**
- `track_hosts`: IPs to ping for connectivity test
- `down`: Failed pings before marking down
- `up`: Successful pings before marking up
- `interval`: Seconds between checks

#### 2. Define Members

```bash
# WAN1 member (metric 1 = highest priority)
uci set mwan3.wan_m1_w1=member
uci set mwan3.wan_m1_w1.interface='wan'
uci set mwan3.wan_m1_w1.metric='1'
uci set mwan3.wan_m1_w1.weight='1'

# WAN2 member (metric 2 = lower priority)
uci set mwan3.wan2_m2_w1=member
uci set mwan3.wan2_m2_w1.interface='wan2'
uci set mwan3.wan2_m2_w1.metric='2'
uci set mwan3.wan2_m2_w1.weight='1'

uci commit mwan3
```

**Metric:** Lower = higher priority (1 is best)
**Weight:** For load balancing within same metric

#### 3. Define Policies

**Failover policy (primary → backup):**
```bash
uci set mwan3.failover_policy=policy
uci set mwan3.failover_policy.last_resort='unreachable'
uci add_list mwan3.failover_policy.use_member='wan_m1_w1'
uci add_list mwan3.failover_policy.use_member='wan2_m2_w1'
uci commit mwan3
```

**Load balance policy (50/50 split):**
```bash
uci set mwan3.balanced_policy=policy
uci set mwan3.balanced_policy.last_resort='default'
uci add_list mwan3.balanced_policy.use_member='wan_m1_w1'
uci add_list mwan3.balanced_policy.use_member='wan2_m1_w1'  # Same metric for balance
uci commit mwan3
```

#### 4. Define Rules

**Default rule (all traffic uses failover policy):**
```bash
uci set mwan3.default_rule=rule
uci set mwan3.default_rule.dest_ip='0.0.0.0/0'
uci set mwan3.default_rule.proto='all'
uci set mwan3.default_rule.use_policy='failover_policy'
uci commit mwan3
```

**Apply configuration:**
```bash
/etc/init.d/mwan3 restart
```

### Advanced mwan3 Policies

#### Three-Tier Failover

```bash
# Primary: Cable (metric 1)
uci set mwan3.wan_m1=member
uci set mwan3.wan_m1.interface='wan'
uci set mwan3.wan_m1.metric='1'
uci set mwan3.wan_m1.weight='1'

# Backup 1: 4G (metric 2)
uci set mwan3.wan2_m2=member
uci set mwan3.wan2_m2.interface='wan2'
uci set mwan3.wan2_m2.metric='2'
uci set mwan3.wan2_m2.weight='1'

# Backup 2: 3G (metric 3)
uci set mwan3.wan3_m3=member
uci set mwan3.wan3_m3.interface='wan3'
uci set mwan3.wan3_m3.metric='3'
uci set mwan3.wan3_m3.weight='1'

# Policy
uci set mwan3.three_tier=policy
uci add_list mwan3.three_tier.use_member='wan_m1'
uci add_list mwan3.three_tier.use_member='wan2_m2'
uci add_list mwan3.three_tier.use_member='wan3_m3'
uci commit mwan3
```

#### Load Balancing with Failover

```bash
# WAN1 weight 3 (75% traffic)
uci set mwan3.wan_balanced=member
uci set mwan3.wan_balanced.interface='wan'
uci set mwan3.wan_balanced.metric='1'
uci set mwan3.wan_balanced.weight='3'

# WAN2 weight 1 (25% traffic)
uci set mwan3.wan2_balanced=member
uci set mwan3.wan2_balanced.interface='wan2'
uci set mwan3.wan2_balanced.metric='1'
uci set mwan3.wan2_balanced.weight='1'

# WAN3 backup (only if both fail)
uci set mwan3.wan3_backup=member
uci set mwan3.wan3_backup.interface='wan3'
uci set mwan3.wan3_backup.metric='2'
uci set mwan3.wan3_backup.weight='1'

# Policy
uci set mwan3.lb_with_backup=policy
uci add_list mwan3.lb_with_backup.use_member='wan_balanced'
uci add_list mwan3.lb_with_backup.use_member='wan2_balanced'
uci add_list mwan3.lb_with_backup.use_member='wan3_backup'
uci commit mwan3
```

### Per-Service Routing

**Route specific services through specific WANs:**

```bash
# HTTPS traffic through WAN1 only
uci set mwan3.https_rule=rule
uci set mwan3.https_rule.proto='tcp'
uci set mwan3.https_rule.dest_port='443'
uci set mwan3.https_rule.use_policy='wan_only'
uci commit mwan3

# BitTorrent through WAN2 only
uci set mwan3.torrent_rule=rule
uci set mwan3.torrent_rule.proto='tcp'
uci set mwan3.torrent_rule.dest_port='6881:6889'
uci set mwan3.torrent_rule.use_policy='wan2_only'
uci commit mwan3
```

### Per-IP Routing

**Route specific devices through specific WANs:**

```bash
# PC (192.168.1.100) uses WAN1
uci set mwan3.pc_rule=rule
uci set mwan3.pc_rule.src_ip='192.168.1.100'
uci set mwan3.pc_rule.use_policy='wan_only'

# Security camera (192.168.1.200) uses WAN2
uci set mwan3.camera_rule=rule
uci set mwan3.camera_rule.src_ip='192.168.1.200'
uci set mwan3.camera_rule.use_policy='wan2_only'

uci commit mwan3
/etc/init.d/mwan3 restart
```

---

## Multiple WAN Interface Configuration

### WAN Interface Types

#### 1. DHCP (Cable/Ethernet)

```bash
uci set network.wan2=interface
uci set network.wan2.proto='dhcp'
uci set network.wan2.ifname='eth1'
uci set network.wan2.metric='10'
uci commit network
```

#### 2. Static IP

```bash
uci set network.wan2=interface
uci set network.wan2.proto='static'
uci set network.wan2.ifname='eth1'
uci set network.wan2.ipaddr='203.0.113.10'
uci set network.wan2.netmask='255.255.255.0'
uci set network.wan2.gateway='203.0.113.1'
uci set network.wan2.dns='8.8.8.8 8.8.4.4'
uci set network.wan2.metric='10'
uci commit network
```

#### 3. PPPoE (DSL)

```bash
uci set network.wan2=interface
uci set network.wan2.proto='pppoe'
uci set network.wan2.ifname='eth1'
uci set network.wan2.username='user@isp.com'
uci set network.wan2.password='password123'
uci set network.wan2.metric='10'
uci commit network
```

#### 4. 3G/UMTS

```bash
uci set network.wan2=interface
uci set network.wan2.proto='3g'
uci set network.wan2.device='/dev/ttyUSB0'
uci set network.wan2.service='umts'
uci set network.wan2.apn='internet'
uci set network.wan2.username=''
uci set network.wan2.password=''
uci set network.wan2.metric='20'
uci commit network
```

#### 5. QMI (4G LTE)

```bash
uci set network.wan2=interface
uci set network.wan2.proto='qmi'
uci set network.wan2.device='/dev/cdc-wdm0'
uci set network.wan2.apn='internet'
uci set network.wan2.pdptype='ipv4'
uci set network.wan2.metric='20'
uci commit network
```

#### 6. MBIM (4G LTE)

```bash
uci set network.wan2=interface
uci set network.wan2.proto='mbim'
uci set network.wan2.device='/dev/cdc-wdm0'
uci set network.wan2.apn='internet'
uci set network.wan2.pdptype='ipv4'
uci set network.wan2.metric='20'
uci commit network
```

#### 7. WireGuard VPN

```bash
uci set network.wan2=interface
uci set network.wan2.proto='wireguard'
uci set network.wan2.private_key='<private_key>'
uci set network.wan2.listen_port='51820'
uci set network.wan2.addresses='10.0.0.2/24'
uci set network.wan2.metric='30'

# Add peer
uci add network wireguard_wan2
uci set network.@wireguard_wan2[-1].public_key='<peer_public_key>'
uci set network.@wireguard_wan2[-1].endpoint_host='vpn.example.com'
uci set network.@wireguard_wan2[-1].endpoint_port='51820'
uci set network.@wireguard_wan2[-1].allowed_ips='0.0.0.0/0'
uci set network.@wireguard_wan2[-1].persistent_keepalive='25'

uci commit network
```

### Metric Values

**Interface metric** determines routing priority:
- **Lower metric = higher priority**
- Primary WAN: `metric='10'`
- Backup WAN: `metric='20'` or `metric='30'`

```bash
# Set metrics
uci set network.wan.metric='10'   # Primary
uci set network.wan2.metric='20'  # Backup
uci set network.wan3.metric='30'  # Second backup
uci commit network
```

### Firewall Configuration

**Add all WAN interfaces to firewall WAN zone:**

```bash
# Method 1: Edit existing zone
uci set firewall.@zone[1].network='wan wan2 wan3'
uci commit firewall

# Method 2: Show and modify
uci show firewall | grep "zone.*wan"
# Find the correct zone index, then:
uci set firewall.@zone[X].network='wan wan2 wan3'
uci commit firewall

# Restart firewall
/etc/init.d/firewall restart
```

---

## Load Balancing

### Load Balancing Methods

#### 1. Round-Robin (Equal Distribution)

```bash
# Equal weight for both interfaces
uci set mwan3.wan_lb=member
uci set mwan3.wan_lb.interface='wan'
uci set mwan3.wan_lb.metric='1'
uci set mwan3.wan_lb.weight='1'

uci set mwan3.wan2_lb=member
uci set mwan3.wan2_lb.interface='wan2'
uci set mwan3.wan2_lb.metric='1'
uci set mwan3.wan2_lb.weight='1'

uci set mwan3.balanced=policy
uci add_list mwan3.balanced.use_member='wan_lb'
uci add_list mwan3.balanced.use_member='wan2_lb'
uci commit mwan3
```

#### 2. Weighted Distribution

**Example: 75% WAN1, 25% WAN2**

```bash
uci set mwan3.wan_lb.weight='3'   # 75%
uci set mwan3.wan2_lb.weight='1'  # 25%
uci commit mwan3
```

#### 3. Session-Based Load Balancing

mwan3 uses **session-based** load balancing by default:
- Each connection sticks to one interface
- Prevents issues with session-based protocols (HTTP, SSH)
- Better compatibility than packet-based balancing

### Load Balancing + Failover Combo

```bash
# WAN1 and WAN2 for load balancing (metric 1)
uci set mwan3.wan_m1_w2=member
uci set mwan3.wan_m1_w2.interface='wan'
uci set mwan3.wan_m1_w2.metric='1'
uci set mwan3.wan_m1_w2.weight='2'

uci set mwan3.wan2_m1_w1=member
uci set mwan3.wan2_m1_w1.interface='wan2'
uci set mwan3.wan2_m1_w1.metric='1'
uci set mwan3.wan2_m1_w1.weight='1'

# WAN3 as backup (metric 2)
uci set mwan3.wan3_m2_w1=member
uci set mwan3.wan3_m2_w1.interface='wan3'
uci set mwan3.wan3_m2_w1.metric='2'
uci set mwan3.wan3_m2_w1.weight='1'

# Policy
uci set mwan3.lb_failover=policy
uci add_list mwan3.lb_failover.use_member='wan_m1_w2'
uci add_list mwan3.lb_failover.use_member='wan2_m1_w1'
uci add_list mwan3.lb_failover.use_member='wan3_m2_w1'
uci commit mwan3
```

**Behavior:**
- Normal: 67% WAN1, 33% WAN2
- WAN1 down: 100% WAN2
- WAN1+WAN2 down: 100% WAN3

---

## Monitoring and Testing

### Simple Failover Monitoring

```bash
# Check service status
/etc/init.d/simplefailover status

# View logs
logread | grep simplefailover

# Follow logs in real-time
logread -f | grep simplefailover

# Check current default route
ip route show default

# Test connectivity on each interface
ping -I wan -c 4 8.8.8.8
ping -I wan2 -c 4 8.8.8.8
```

### mwan3 Monitoring

```bash
# Check interface status
mwan3 status

# Detailed interface information
mwan3 interfaces

# Policy status
mwan3 policies

# Connected interfaces
mwan3 connected

# View routing tables
mwan3 routes
```

**Example output:**
```
interface wan is online and tracking is active
interface wan2 is offline and tracking is active
```

### Test Failover

#### Method 1: Disconnect Primary Cable

1. Note current IP: `curl ifconfig.me`
2. Disconnect primary WAN cable
3. Wait 10-30 seconds
4. Check new IP: `curl ifconfig.me` (should be different)
5. Reconnect cable
6. Wait for automatic switchback

#### Method 2: Disable Interface

```bash
# Disable primary WAN
ifdown wan

# Check backup activation
sleep 10
ip route show default

# Re-enable primary
ifup wan

# Check switchback
sleep 10
ip route show default
```

#### Method 3: Block ICMP (Simulate Failure)

```bash
# Block ping on WAN (simulates connectivity loss)
iptables -I OUTPUT -o wan -p icmp -j DROP

# Wait and check
sleep 15
mwan3 status

# Remove block
iptables -D OUTPUT -o wan -p icmp -j DROP

# Check recovery
sleep 15
mwan3 status
```

### Performance Testing

**Test each WAN independently:**

```bash
# Install speedtest-cli
opkg update
opkg install python3-light python3-pip
pip3 install speedtest-cli

# Test WAN1
ifdown wan2
speedtest-cli

# Test WAN2
ifup wan2
ifdown wan
speedtest-cli

# Restore
ifup wan
```

**Test load balancing:**

```bash
# Run multiple downloads simultaneously
for i in {1..10}; do
    wget http://speedtest.tele2.net/10MB.zip -O /dev/null &
done

# Watch connection distribution
watch -n 1 'mwan3 status'
```

---

## Troubleshooting

### Common Issues

#### 1. Backup Doesn't Activate

**Symptoms:** Primary fails but backup doesn't activate

**Possible causes:**
- Backup interface not configured correctly
- Firewall blocking backup
- Service not running
- Interface configured with `auto='1'` (should be `auto='0'` for Simple Failover)

**Solutions:**
```bash
# Check service status
/etc/init.d/simplefailover status

# Verify backup works independently
ifdown wan
ifup wan2
ping -c 4 8.8.8.8

# Check firewall
uci show firewall | grep wan2

# View logs
logread | tail -50
```

#### 2. Switchback Doesn't Occur

**Symptoms:** Stays on backup even after primary recovers

**Possible causes:**
- Ping target unreachable via primary
- Routing issue
- Primary interface not fully up

**Solutions:**
```bash
# Manually test primary connectivity
ping -I wan -c 4 8.8.8.8

# Check routing
ip route show

# Restart service
/etc/init.d/simplefailover restart

# Check logs
logread -f
```

#### 3. Simple Failover Doesn't Work with PPPoE

**Problem:** "simplefailover won't work if primary interface disappears during disconnection"

**Limitation:** Simple Failover requires interface to stay up even when link is down. PPPoE interfaces typically disappear.

**Solution:** Use mwan3 instead:
```bash
opkg install mwan3
# Configure as shown in mwan3 section
```

#### 4. Both Interfaces Active Simultaneously

**Symptoms:** Traffic splits between WAN and WAN2

**Cause:** Both interfaces have `defaultroute='1'` and similar metrics

**Solution:**
```bash
# For Simple Failover, backup should have auto='0'
uci set network.wan2.auto='0'
uci commit network

# Or use different metrics
uci set network.wan.metric='10'
uci set network.wan2.metric='20'
uci commit network
```

#### 5. mwan3 Interface Stuck Offline

**Symptoms:** mwan3 shows interface offline even when working

**Solutions:**
```bash
# Check tracking hosts are reachable
ping 8.8.8.8

# Restart mwan3
/etc/init.d/mwan3 restart

# Check interface config
uci show mwan3 | grep wan

# View detailed status
mwan3 interfaces
logread | grep mwan3
```

#### 6. DNS Issues After Failover

**Symptoms:** Can ping IPs but can't resolve domains

**Solutions:**
```bash
# Use public DNS in /etc/config/network
uci set network.wan.dns='8.8.8.8 1.1.1.1'
uci set network.wan2.dns='8.8.8.8 1.1.1.1'
uci commit network

# Or configure in /etc/config/dhcp
uci set dhcp.@dnsmasq[0].noresolv='1'
uci add_list dhcp.@dnsmasq[0].server='8.8.8.8'
uci add_list dhcp.@dnsmasq[0].server='1.1.1.1'
uci commit dhcp

# Restart services
/etc/init.d/network restart
/etc/init.d/dnsmasq restart
```

---

## Real-World Scenarios

### Scenario 1: Home Office with 4G Backup

**Setup:** Cable primary (unlimited) + 4G USB modem backup (5GB/month data cap)

**Solution:** Simple Failover

```bash
# WAN1: Cable (DHCP)
# Already configured as wan

# WAN2: 4G modem
uci set network.wan2=interface
uci set network.wan2.proto='qmi'
uci set network.wan2.device='/dev/cdc-wdm0'
uci set network.wan2.apn='internet'
uci set network.wan2.auto='0'
uci commit network

# Firewall
uci set firewall.@zone[1].network='wan wan2'
uci commit firewall

# Simple Failover (check every 10 seconds)
opkg install simplefailover
uci set simplefailover.@simplefailover[0].interval='10'
uci commit simplefailover
/etc/init.d/simplefailover enable
/etc/init.d/simplefailover start
```

**Benefits:**
- 4G only activates when cable fails
- Saves mobile data (important with cap)
- Automatic switchback when cable recovers

### Scenario 2: Small Business with Dual ISPs

**Setup:** Two cable ISPs (both unlimited)

**Solution:** mwan3 with load balancing + failover

```bash
# WAN1 and WAN2 already configured

# Install mwan3
opkg install mwan3 luci-app-mwan3

# Configure members (equal weight)
uci set mwan3.wan_m1=member
uci set mwan3.wan_m1.interface='wan'
uci set mwan3.wan_m1.metric='1'
uci set mwan3.wan_m1.weight='1'

uci set mwan3.wan2_m1=member
uci set mwan3.wan2_m1.interface='wan2'
uci set mwan3.wan2_m1.metric='1'
uci set mwan3.wan2_m1.weight='1'

# Load balance policy
uci set mwan3.balanced=policy
uci add_list mwan3.balanced.use_member='wan_m1'
uci add_list mwan3.balanced.use_member='wan2_m1'

# Default rule
uci set mwan3.default_rule=rule
uci set mwan3.default_rule.dest_ip='0.0.0.0/0'
uci set mwan3.default_rule.use_policy='balanced'

uci commit mwan3
/etc/init.d/mwan3 restart
```

**Benefits:**
- Combined bandwidth (50/50 split)
- Automatic failover if one ISP fails
- Better utilization of both connections

### Scenario 3: Remote Site with Unreliable Primary

**Setup:** Wireless ISP (unreliable) + 4G (reliable but expensive)

**Solution:** mwan3 with aggressive failover

```bash
# Configure interfaces with frequent checks
uci set mwan3.wan.interval='3'  # Check every 3 seconds
uci set mwan3.wan.down='2'      # Mark down after 2 failures
uci set mwan3.wan.up='3'        # Mark up after 3 successes

# WAN1 (wireless, metric 1)
uci set mwan3.wan_primary=member
uci set mwan3.wan_primary.interface='wan'
uci set mwan3.wan_primary.metric='1'

# WAN2 (4G, metric 2)
uci set mwan3.wan2_backup=member
uci set mwan3.wan2_backup.interface='wan2'
uci set mwan3.wan2_backup.metric='2'

# Quick failover policy
uci set mwan3.quick_failover=policy
uci add_list mwan3.quick_failover.use_member='wan_primary'
uci add_list mwan3.quick_failover.use_member='wan2_backup'

uci commit mwan3
```

**Benefits:**
- Fast detection of failures (6 seconds)
- Automatic failover to reliable backup
- Returns to cheaper primary when recovered

### Scenario 4: IoT/M2M Device

**Setup:** Primary connection for data + backup for critical alerts

**Solution:** mwan3 with per-service routing

```bash
# Critical services (monitoring, alerts) through both WANs
uci set mwan3.critical_rule=rule
uci set mwan3.critical_rule.dest_port='443,8883'  # HTTPS, MQTT
uci set mwan3.critical_rule.proto='tcp'
uci set mwan3.critical_rule.use_policy='failover_policy'

# Bulk data through primary only
uci set mwan3.bulk_rule=rule
uci set mwan3.bulk_rule.dest_port='8080'  # Data upload
uci set mwan3.bulk_rule.proto='tcp'
uci set mwan3.bulk_rule.use_policy='wan_only_policy'

uci commit mwan3
```

---

## Best Practices

### 1. Test Each WAN Independently First

**Before enabling failover:**
```bash
# Test WAN1
ifdown wan2
ping -c 10 8.8.8.8
curl ifconfig.me

# Test WAN2
ifup wan2
ifdown wan
ping -c 10 8.8.8.8
curl ifconfig.me

# Both working? Enable failover
ifup wan
```

### 2. Use Reliable Ping Targets

**Good choices:**
- `8.8.8.8` - Google DNS
- `1.1.1.1` - Cloudflare DNS
- `9.9.9.9` - Quad9 DNS

**Avoid:**
- ISP DNS servers (may respond even if internet is down)
- Single target (use multiple for redundancy)
- Hosts that may block ICMP

**mwan3 best practice:**
```bash
uci set mwan3.wan.track_hosts='8.8.8.8 1.1.1.1'
```

### 3. Set Appropriate Check Intervals

**Guidelines:**
- **Simple Failover:** 5-10 seconds for most uses
- **mwan3:** 5-10 seconds for standard, 3 seconds for critical
- **Slower for metered:** 30-60 seconds to reduce data usage

```bash
# Standard
uci set simplefailover.@simplefailover[0].interval='10'

# Critical application
uci set mwan3.wan.interval='3'

# Metered connection
uci set mwan3.wan2.interval='60'
```

### 4. Configure Firewall Properly

**Always include all WANs in firewall zone:**
```bash
uci set firewall.@zone[1].network='wan wan2 wan3'
uci commit firewall
/etc/init.d/firewall restart
```

### 5. Monitor Logs During Initial Setup

```bash
# Terminal 1: Watch failover activity
logread -f | grep -E "simplefailover|mwan3"

# Terminal 2: Test failover
ifdown wan
# Wait, observe
ifup wan
```

### 6. Document Your Configuration

Create a configuration file documenting your setup:

```bash
cat > /root/failover-config.txt << 'EOF'
# Failover Configuration
# Date: 2025-10-25

WAN1 (Primary): Cable ISP, DHCP, eth0.2
WAN2 (Backup): 4G LTE, QMI, /dev/cdc-wdm0, APN: internet

Failover: Simple Failover
Check interval: 10 seconds
Ping target: 8.8.8.8

Notes:
- WAN2 has 5GB monthly data cap
- Backup only activates when primary fails
- Average failover time: 15 seconds
EOF
```

### 7. Use Metrics for Priority

```bash
# Lower metric = higher priority
uci set network.wan.metric='10'   # Primary
uci set network.wan2.metric='20'  # Backup
uci set network.wan3.metric='30'  # Last resort
```

### 8. Regular Testing

**Schedule monthly failover tests:**
```bash
# Create test script
cat > /usr/bin/test-failover.sh << 'EOF'
#!/bin/sh
logger -t failover-test "Starting failover test"
ifdown wan
sleep 60
ifup wan
logger -t failover-test "Failover test complete"
EOF

chmod +x /usr/bin/test-failover.sh

# Schedule monthly (first Sunday, 3 AM)
echo "0 3 1-7 * 0 /usr/bin/test-failover.sh" >> /etc/crontabs/root
```

### 9. Keep Backups of Configuration

```bash
# Backup before changes
sysupgrade -b /tmp/backup-before-failover-$(date +%Y%m%d).tar.gz

# Document changes
echo "$(date): Enabled failover, WAN2 = 4G" >> /root/config-changelog.txt
```

### 10. Avoid These Common Mistakes

❌ **Don't:** Set `auto='1'` on backup for Simple Failover
✅ **Do:** Set `auto='0'` so backup doesn't start automatically

❌ **Don't:** Use same metric for all WANs
✅ **Do:** Use different metrics for priority

❌ **Don't:** Forget to add WANs to firewall zone
✅ **Do:** Always update firewall configuration

❌ **Don't:** Use only one ping target
✅ **Do:** Use multiple reliable targets

❌ **Don't:** Set very short intervals on metered connections
✅ **Do:** Balance responsiveness vs. data usage

---

## Quick Reference

### Simple Failover Commands

```bash
# Install
opkg install simplefailover

# Configure
uci set simplefailover.@simplefailover[0].wan_backup='wan2'
uci set simplefailover.@simplefailover[0].host='8.8.8.8'
uci set simplefailover.@simplefailover[0].interval='10'
uci commit simplefailover

# Enable/start
/etc/init.d/simplefailover enable
/etc/init.d/simplefailover start

# Monitor
logread -f | grep simplefailover
```

### mwan3 Commands

```bash
# Install
opkg install mwan3 luci-app-mwan3

# Status
mwan3 status
mwan3 interfaces
mwan3 policies

# Restart
/etc/init.d/mwan3 restart

# Reload config
mwan3 restart
```

### Testing Commands

```bash
# Check default route
ip route show default

# Test interface
ping -I wan -c 4 8.8.8.8
ping -I wan2 -c 4 8.8.8.8

# Disable interface
ifdown wan

# Enable interface
ifup wan

# Check current IP
curl ifconfig.me
```

---

## Additional Resources

- **OpenWrt Multi-WAN**: https://openwrt.org/docs/guide-user/network/wan/multiwan/start
- **mwan3 Documentation**: https://openwrt.org/docs/guide-user/network/wan/multiwan/mwan3
- **Simple Failover**: Community packages repository
- **Network Configuration**: https://openwrt.org/docs/guide-user/network/start

---

**Document Version:** 1.0
**Last Updated:** 2025-10-25
**Based on:** https://eko.one.pl/?p=openwrt-simplefailover (Polish original)
**License:** CC BY-SA 4.0
