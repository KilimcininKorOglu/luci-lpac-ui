# OpenWRT APuP (Access Point Micro Peering) Mesh Guide

## Table of Contents
- [Overview](#overview)
- [What is APuP?](#what-is-apup)
- [Technical Background](#technical-background)
- [Advantages Over Traditional Mesh](#advantages-over-traditional-mesh)
- [Prerequisites](#prerequisites)
- [APuP vs Other Mesh Technologies](#apup-vs-other-mesh-technologies)
- [Network Topology](#network-topology)
- [Gateway Configuration](#gateway-configuration)
- [Mesh Node Configuration](#mesh-node-configuration)
- [Bridge Configuration](#bridge-configuration)
- [Multiple Node Setup](#multiple-node-setup)
- [Advanced Configuration](#advanced-configuration)
- [Troubleshooting](#troubleshooting)
- [Hardware Compatibility](#hardware-compatibility)
- [Security Considerations](#security-considerations)
- [Performance Optimization](#performance-optimization)
- [Use Cases](#use-cases)

## Overview

APuP (Access Point Micro Peering) is a new mesh networking approach introduced to OpenWRT's hostapd on August 13, 2024. It provides a simpler alternative to traditional mesh protocols by using standard AP (Access Point) mode with 4-address support.

**What You'll Learn:**
- How to configure APuP mesh networks on OpenWRT
- Setting up gateway and mesh nodes
- Dynamic interface management
- Troubleshooting APuP deployments
- Security considerations for mesh networks

**Key Benefits:**
- Simpler configuration than 802.11s mesh
- No hardcoded bridging in WiFi stack
- Uses standard AP mode (better hardware support)
- Dynamic peer discovery
- Transparent bridging between nodes

## What is APuP?

### Official Description

According to OpenWRT documentation, APuP is described as:

> "A simpler and hopefully more useful successor to Ad Hoc, Wireless Distribution System, 802.11s mesh mode."

### How It Works

**Traditional Mesh Approach:**
- Dedicated mesh protocols (802.11s, BATMAN, etc.)
- Complex configuration and management
- Limited hardware support
- Hardcoded bridging in WiFi stack

**APuP Approach:**
- Uses standard AP mode
- Requires only 4-address support
- Dynamic peer interface creation
- Flexible bridging configuration
- Simpler implementation

### Key Characteristics

1. **AP Mode Based**: Operates in standard Access Point mode
2. **4-Address Support**: Enables proper frame forwarding between nodes
3. **Dynamic Interfaces**: Creates peer interfaces automatically
4. **Same Channel Requirement**: All APs must operate on identical channel
5. **Transparent Bridging**: Seamless layer-2 connectivity
6. **Automatic Discovery**: Nodes detect each other automatically

## Technical Background

### 4-Address Frame Format

**Standard 802.11 Frame (3 addresses):**
```
+----------+----------+----------+
| Address1 | Address2 | Address3 |
| (Dest)   | (Source) | (BSSID)  |
+----------+----------+----------+
```

**4-Address Frame (WDS/APuP):**
```
+----------+----------+----------+----------+
| Address1 | Address2 | Address3 | Address4 |
| (Recv)   | (Trans)  | (Dest)   | (Source) |
+----------+----------+----------+----------+
```

The 4th address allows proper source tracking when frames are forwarded through the mesh.

### Interface Creation Mechanism

**At Boot Time:**
- Main AP interface created (e.g., wlan0)
- APuP enabled but no peer interfaces exist yet

**During Operation:**
- APs discover each other via beacon frames
- One interface created per detected peer
- Interfaces named with configured prefix (e.g., apup1, apup2)
- Interfaces automatically added to bridge
- Dynamic creation means 0 interfaces at startup

**Example Evolution:**
```
Time 0s:  wlan0 (only main AP)
Time 30s: wlan0, apup1 (first peer detected)
Time 60s: wlan0, apup1, apup2 (second peer detected)
Time 90s: wlan0, apup1, apup2, apup3 (third peer)
```

### Channel Synchronization

**Critical Requirement:**
All APuP nodes must operate on the **exact same channel**. This includes:
- Same frequency band (2.4GHz or 5GHz)
- Same channel number (e.g., channel 36)
- Same channel width (20MHz, 40MHz, 80MHz)
- Same regulatory domain

**Why?**
- WiFi radios can only listen on one channel at a time
- Peer detection requires receiving beacon frames
- Different channels = no visibility = no peering

## Advantages Over Traditional Mesh

### Comparison Matrix

| Feature | APuP | 802.11s Mesh | WDS | Ad-Hoc |
|---------|------|--------------|-----|--------|
| Configuration | Simple | Complex | Medium | Simple |
| Hardware Support | Wide (AP mode) | Limited | Medium | Declining |
| Auto Discovery | Yes | Yes | No | Limited |
| Bridging Flexibility | High | Low | Medium | Low |
| Client Access | Yes (AP mode) | Yes | Yes | Limited |
| Multi-hop | Yes | Yes | Yes | Limited |
| Security | WPA2/WPA3 | SAE | WPA2 | WEP/Open |
| Dynamic Routing | No (L2 only) | Optional | No | No |
| Encryption between nodes | Varies | Yes | Yes | Limited |

### Why Choose APuP?

**Over 802.11s Mesh:**
- Simpler configuration (standard UCI)
- No hardcoded bridging restrictions
- Better hardware compatibility
- Easier troubleshooting

**Over WDS:**
- Automatic peer discovery
- No need to configure MAC addresses
- Dynamic interface creation
- More flexible topology

**Over Ad-Hoc:**
- Better client support
- Standard AP features available
- Improved security options
- Active development

## Prerequisites

### OpenWRT Version

**Required:**
- OpenWRT development snapshot (as of August 2024)
- Hostapd with APuP support (post-August 13, 2024)

**Check Version:**
```bash
# Check OpenWRT version
cat /etc/openwrt_release

# Check hostapd version
hostapd -v

# Verify APuP support
hostapd --help 2>&1 | grep -i apup || echo "APuP support check via config"
```

### Hardware Requirements

**Minimum:**
- WiFi hardware with AP mode support
- 4-address frame support
- OpenWRT compatible chipset

**Recommended:**
- Modern WiFi chipset (802.11ac or newer)
- Sufficient RAM (64MB minimum, 128MB+ recommended)
- Multiple Ethernet ports for gateway node
- 5GHz support for better performance

**Tested Chipsets:**
- Qualcomm Atheros (ath9k, ath10k)
- MediaTek (mt76)
- Broadcom (limited testing)

### Software Requirements

```bash
# Essential packages
opkg update
opkg install hostapd wpad-openssl

# Recommended packages
opkg install bridge-utils ethtool wireless-tools

# Optional monitoring tools
opkg install iw tcpdump
```

## APuP vs Other Mesh Technologies

### Detailed Comparison

#### 802.11s Mesh Mode

**How it works:**
- IEEE standard mesh protocol
- Built-in path selection (HWMP)
- Mesh peering management frames
- Encryption via SAE (WPA3)

**Advantages:**
- Industry standard
- Built-in routing
- Strong security (SAE)
- Multi-hop optimization

**Disadvantages:**
- Complex configuration
- Limited hardware support
- Hardcoded kernel bridging
- Difficult to customize

**When to use:** Enterprise deployments with supported hardware

#### WDS (Wireless Distribution System)

**How it works:**
- Point-to-point 4-address links
- Manual MAC address configuration
- Static topology

**Advantages:**
- Wide hardware support
- Simple concept
- Good performance

**Disadvantages:**
- Manual configuration required
- No automatic discovery
- Fixed topology
- Scalability issues

**When to use:** Fixed point-to-point links between known devices

#### BATMAN-adv

**How it works:**
- Layer 2 routing daemon
- Runs on top of WiFi interfaces
- Proactive routing protocol

**Advantages:**
- Excellent multi-hop routing
- Self-healing
- Very flexible
- Active development

**Disadvantages:**
- Additional software layer
- More CPU overhead
- Complex troubleshooting
- Requires separate package

**When to use:** Large-scale community networks with many hops

#### APuP

**How it works:**
- AP mode with 4-address support
- Automatic peer discovery
- Dynamic interface creation
- Bridge-based forwarding

**Advantages:**
- Very simple configuration
- Good hardware compatibility
- Flexible bridging
- Easy troubleshooting

**Disadvantages:**
- No built-in routing (L2 only)
- Same channel requirement
- Newer (less tested)
- Security concerns (encryption between nodes)

**When to use:** Small to medium deployments, extending existing networks, simpler mesh needs

## Network Topology

### Basic Topology

```
                    Internet
                       |
                   [Gateway]
                    (wlan0)
                       |
        APuP Mesh Network (same channel)
                       |
        +--------------+---------------+
        |              |               |
    [Node 1]       [Node 2]        [Node 3]
    (wlan0)        (wlan0)         (wlan0)
       |              |               |
   apup1 ←→ mesh ←→ apup1         apup1
       |              |               |
    Clients        Clients         Clients
```

### Multi-Node Topology

```
                    [Gateway]
                    192.168.1.1
                    /    |    \
                   /     |     \
              apup1   apup2   apup3
                /       |       \
               /        |        \
          [Node A]  [Node B]  [Node C]
          .2         .3         .4
           |          |          |
        apup1      apup1      apup1
           |          |          |
        Clients    Clients    Clients
```

### Extended Topology (Multi-Hop)

```
    [Gateway] ←→ [Node A] ←→ [Node B] ←→ [Node C]
        |           |           |           |
    Internet    Clients     Clients     Clients
```

Note: APuP supports multi-hop, but relies on standard bridging/STP for loop prevention.

## Gateway Configuration

The gateway node provides internet access and DHCP services for the entire mesh network.

### Basic Gateway Setup

```bash
# Enable WiFi radio
uci set wireless.radio0.disabled=0

# Configure SSID and encryption
uci set wireless.default_radio0.ssid='MeshNetwork'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='YourSecurePassword123'

# Enable APuP
uci set wireless.default_radio0.apup=1
uci set wireless.default_radio0.apup_peer_ifname_prefix='apup'

# Add APuP interfaces to bridge (pre-configure for multiple peers)
uci add_list network.@device[0].ports='apup1'
uci add_list network.@device[0].ports='apup2'
uci add_list network.@device[0].ports='apup3'
uci add_list network.@device[0].ports='apup4'
uci add_list network.@device[0].ports='apup5'

# Commit changes
uci commit

# Reboot to apply
reboot
```

### Complete Gateway Configuration

```bash
#!/bin/sh
# APuP Gateway Configuration Script

echo "Configuring APuP Gateway..."

# Wireless Configuration
uci set wireless.radio0.disabled=0
uci set wireless.radio0.channel='36'           # Must match all nodes
uci set wireless.radio0.htmode='VHT80'        # 5GHz, 80MHz width
uci set wireless.radio0.country='US'

# AP Interface Settings
uci set wireless.default_radio0.mode='ap'
uci set wireless.default_radio0.ssid='MeshNetwork'
uci set wireless.default_radio0.encryption='psk2+ccmp'
uci set wireless.default_radio0.key='YourSecurePassword123'
uci set wireless.default_radio0.network='lan'

# APuP Settings
uci set wireless.default_radio0.apup=1
uci set wireless.default_radio0.apup_peer_ifname_prefix='apup'

# Network Bridge Configuration
uci set network.@device[0].name='br-lan'
uci set network.@device[0].type='bridge'

# Add interfaces to bridge
uci del_list network.@device[0].ports='apup1' 2>/dev/null
uci del_list network.@device[0].ports='apup2' 2>/dev/null
uci del_list network.@device[0].ports='apup3' 2>/dev/null
uci del_list network.@device[0].ports='apup4' 2>/dev/null
uci del_list network.@device[0].ports='apup5' 2>/dev/null
uci del_list network.@device[0].ports='apup6' 2>/dev/null
uci del_list network.@device[0].ports='apup7' 2>/dev/null
uci del_list network.@device[0].ports='apup8' 2>/dev/null
uci del_list network.@device[0].ports='apup9' 2>/dev/null
uci del_list network.@device[0].ports='apup10' 2>/dev/null

uci add_list network.@device[0].ports='apup1'
uci add_list network.@device[0].ports='apup2'
uci add_list network.@device[0].ports='apup3'
uci add_list network.@device[0].ports='apup4'
uci add_list network.@device[0].ports='apup5'
uci add_list network.@device[0].ports='apup6'
uci add_list network.@device[0].ports='apup7'
uci add_list network.@device[0].ports='apup8'
uci add_list network.@device[0].ports='apup9'
uci add_list network.@device[0].ports='apup10'

# LAN Settings (Gateway)
uci set network.lan.ipaddr='192.168.1.1'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.proto='static'

# DHCP Configuration
uci set dhcp.lan.ignore='0'
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'

# DNS Settings
uci set dhcp.@dnsmasq[0].domain='mesh.local'
uci add_list dhcp.@dnsmasq[0].server='8.8.8.8'
uci add_list dhcp.@dnsmasq[0].server='8.8.4.4'

# Firewall (assuming WAN on eth0)
uci set firewall.@zone[0].name='lan'
uci set firewall.@zone[0].network='lan'
uci set firewall.@zone[0].input='ACCEPT'
uci set firewall.@zone[0].output='ACCEPT'
uci set firewall.@zone[0].forward='ACCEPT'

# Commit all changes
uci commit

echo "Gateway configuration complete. Rebooting..."
reboot
```

### Verify Gateway Configuration

```bash
# Check wireless configuration
uci show wireless

# Verify bridge configuration
uci show network.@device[0]

# Check DHCP settings
uci show dhcp.lan

# After reboot, verify interfaces
brctl show
ip link show
iw dev
```

## Mesh Node Configuration

Mesh nodes extend the network coverage and connect clients to the mesh.

### Basic Node Setup

```bash
# Enable WiFi radio
uci set wireless.radio0.disabled=0

# Configure SSID and encryption (MUST match gateway)
uci set wireless.default_radio0.ssid='MeshNetwork'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='YourSecurePassword123'

# Enable APuP
uci set wireless.default_radio0.apup=1
uci set wireless.default_radio0.apup_peer_ifname_prefix='apup'

# Add APuP interfaces to bridge
uci add_list network.@device[0].ports='apup1'
uci add_list network.@device[0].ports='apup2'
uci add_list network.@device[0].ports='apup3'
uci add_list network.@device[0].ports='apup4'
uci add_list network.@device[0].ports='apup5'

# Configure as mesh node (not gateway)
uci set network.lan.ipaddr='192.168.1.2'        # Unique IP per node
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway='192.168.1.1'       # Gateway IP
uci set network.lan.dns='192.168.1.1'           # Use gateway for DNS
uci set network.lan.proto='static'

# Disable DHCP server on nodes
uci set dhcp.lan.ignore='1'

# Commit changes
uci commit

# Reboot to apply
reboot
```

### Complete Node Configuration

```bash
#!/bin/sh
# APuP Mesh Node Configuration Script
# Usage: Set NODE_IP before running (e.g., NODE_IP=192.168.1.3)

NODE_IP=${NODE_IP:-192.168.1.2}  # Default to .2 if not set
GATEWAY_IP='192.168.1.1'
MESH_SSID='MeshNetwork'
MESH_KEY='YourSecurePassword123'

echo "Configuring APuP Mesh Node with IP: $NODE_IP"

# Wireless Configuration
uci set wireless.radio0.disabled=0
uci set wireless.radio0.channel='36'           # Must match gateway
uci set wireless.radio0.htmode='VHT80'
uci set wireless.radio0.country='US'

# AP Interface Settings
uci set wireless.default_radio0.mode='ap'
uci set wireless.default_radio0.ssid="$MESH_SSID"
uci set wireless.default_radio0.encryption='psk2+ccmp'
uci set wireless.default_radio0.key="$MESH_KEY"
uci set wireless.default_radio0.network='lan'

# APuP Settings
uci set wireless.default_radio0.apup=1
uci set wireless.default_radio0.apup_peer_ifname_prefix='apup'

# Network Bridge Configuration
uci set network.@device[0].name='br-lan'
uci set network.@device[0].type='bridge'

# Add APuP interfaces to bridge (prepare for up to 10 peers)
for i in $(seq 1 10); do
    uci del_list network.@device[0].ports="apup$i" 2>/dev/null
    uci add_list network.@device[0].ports="apup$i"
done

# LAN Settings (Mesh Node)
uci set network.lan.proto='static'
uci set network.lan.ipaddr="$NODE_IP"
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway="$GATEWAY_IP"
uci set network.lan.dns="$GATEWAY_IP"

# Disable DHCP Server (gateway handles this)
uci set dhcp.lan.ignore='1'

# Optional: Disable DHCPv6
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ra='disabled'

# Firewall Configuration
uci set firewall.@zone[0].name='lan'
uci set firewall.@zone[0].network='lan'
uci set firewall.@zone[0].input='ACCEPT'
uci set firewall.@zone[0].output='ACCEPT'
uci set firewall.@zone[0].forward='ACCEPT'

# Commit all changes
uci commit

echo "Node configuration complete. IP: $NODE_IP, Gateway: $GATEWAY_IP"
echo "Rebooting..."
reboot
```

### Multiple Node Deployment Script

```bash
#!/bin/sh
# Deploy multiple nodes with sequential IPs

GATEWAY_IP='192.168.1.1'
START_IP=2
NUM_NODES=5

for i in $(seq $START_IP $(($START_IP + $NUM_NODES - 1))); do
    NODE_IP="192.168.1.$i"

    echo "=== Configuring Node $i (IP: $NODE_IP) ==="

    # Here you would SSH to each node and run the config
    # For example:
    # scp node_config.sh root@current_node_ip:/tmp/
    # ssh root@current_node_ip "NODE_IP=$NODE_IP /tmp/node_config.sh"

    echo "Node $i configuration would be deployed here"
done
```

## Bridge Configuration

### Understanding Bridge Setup

APuP requires pre-configuring the bridge with peer interfaces even though they don't exist at boot time.

**Why Pre-configure?**
- APuP interfaces are created dynamically when peers are detected
- Bridge must be ready to accept these interfaces
- Pre-configuring avoids manual intervention

**Example Bridge Evolution:**
```
Boot Time:
br-lan: wlan0, eth0

After 30s (1 peer detected):
br-lan: wlan0, eth0, apup1

After 60s (2 peers detected):
br-lan: wlan0, eth0, apup1, apup2

After 90s (3 peers detected):
br-lan: wlan0, eth0, apup1, apup2, apup3
```

### Bridge Configuration Methods

#### Method 1: UCI Command Line

```bash
# Create bridge device
uci set network.@device[0].name='br-lan'
uci set network.@device[0].type='bridge'

# Add base interfaces
uci add_list network.@device[0].ports='eth0'
uci add_list network.@device[0].ports='wlan0'

# Add APuP peer interfaces (up to 10)
for i in $(seq 1 10); do
    uci add_list network.@device[0].ports="apup$i"
done

uci commit network
```

#### Method 2: Direct File Edit

Edit `/etc/config/network`:

```
config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'eth0'
	list ports 'wlan0'
	list ports 'apup1'
	list ports 'apup2'
	list ports 'apup3'
	list ports 'apup4'
	list ports 'apup5'
	list ports 'apup6'
	list ports 'apup7'
	list ports 'apup8'
	list ports 'apup9'
	list ports 'apup10'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	option ipaddr '192.168.1.1'
	option netmask '255.255.255.0'
```

### Bridge Monitoring

```bash
# View bridge status
brctl show

# Expected output:
# bridge name     bridge id               STP enabled     interfaces
# br-lan          8000.aabbccddeeff       no              eth0
#                                                         wlan0
#                                                         apup1
#                                                         apup2

# View bridge details
ip link show type bridge

# Check bridge ports
ls -la /sys/class/net/br-lan/brif/

# Monitor bridge learning
brctl showmacs br-lan
```

### STP (Spanning Tree Protocol)

```bash
# Enable STP to prevent loops in complex topologies
uci set network.@device[0].stp='1'
uci commit network
/etc/init.d/network restart

# Check STP status
brctl show br-lan
brctl showstp br-lan

# Disable STP (if simple topology)
uci set network.@device[0].stp='0'
uci commit network
/etc/init.d/network restart
```

## Multiple Node Setup

### Planning Your Deployment

**IP Address Scheme:**
```
Gateway:  192.168.1.1
Node A:   192.168.1.2
Node B:   192.168.1.3
Node C:   192.168.1.4
Node D:   192.168.1.5
DHCP Range: 192.168.1.100-250
```

**Channel Planning:**
```
All nodes: Channel 36 (5GHz)
Width: 80MHz (VHT80)
Band: 5GHz for better performance
```

### Step-by-Step Multi-Node Deployment

#### Step 1: Configure Gateway

```bash
# On Gateway Node
uci set wireless.radio0.disabled=0
uci set wireless.radio0.channel='36'
uci set wireless.radio0.htmode='VHT80'
uci set wireless.default_radio0.ssid='MeshNetwork'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='SecurePass123'
uci set wireless.default_radio0.apup=1
uci set wireless.default_radio0.apup_peer_ifname_prefix='apup'

# Add bridge ports
for i in $(seq 1 10); do
    uci add_list network.@device[0].ports="apup$i"
done

uci set network.lan.ipaddr='192.168.1.1'
uci set dhcp.lan.ignore='0'
uci commit
reboot
```

#### Step 2: Configure Node A

```bash
# On Node A
uci set wireless.radio0.disabled=0
uci set wireless.radio0.channel='36'
uci set wireless.radio0.htmode='VHT80'
uci set wireless.default_radio0.ssid='MeshNetwork'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='SecurePass123'
uci set wireless.default_radio0.apup=1
uci set wireless.default_radio0.apup_peer_ifname_prefix='apup'

for i in $(seq 1 10); do
    uci add_list network.@device[0].ports="apup$i"
done

uci set network.lan.ipaddr='192.168.1.2'
uci set network.lan.gateway='192.168.1.1'
uci set network.lan.dns='192.168.1.1'
uci set dhcp.lan.ignore='1'
uci commit
reboot
```

#### Step 3: Configure Node B

```bash
# On Node B (same as Node A but different IP)
# ... (same wireless config)

uci set network.lan.ipaddr='192.168.1.3'
uci set network.lan.gateway='192.168.1.1'
uci set network.lan.dns='192.168.1.1'
uci set dhcp.lan.ignore='1'
uci commit
reboot
```

#### Step 4: Verify Mesh Formation

```bash
# On Gateway, check for APuP interfaces
ip link show | grep apup

# Expected output:
# apup1: <BROADCAST,MULTICAST,UP,LOWER_UP>
# apup2: <BROADCAST,MULTICAST,UP,LOWER_UP>
# apup3: <BROADCAST,MULTICAST,UP,LOWER_UP>

# Check bridge membership
brctl show br-lan

# Verify connectivity from each node
ping -c 3 192.168.1.1  # From any node to gateway
ping -c 3 192.168.1.2  # From gateway to Node A
ping -c 3 192.168.1.3  # From gateway to Node B

# Check wireless associations
iw dev wlan0 station dump
```

### Automated Deployment Script

```bash
#!/bin/sh
# Mass APuP Deployment Script
# Run from central management system

NODES="192.168.1.101 192.168.1.102 192.168.1.103"  # Temporary IPs
GATEWAY_IP="192.168.1.1"
MESH_SSID="MeshNetwork"
MESH_KEY="SecurePass123"
CHANNEL="36"

NODE_COUNTER=2

for CURRENT_NODE in $NODES; do
    NODE_IP="192.168.1.$NODE_COUNTER"

    echo "=== Deploying Node $NODE_COUNTER (Current IP: $CURRENT_NODE, New IP: $NODE_IP) ==="

    # Create configuration script
    cat > /tmp/apup_deploy_$NODE_COUNTER.sh <<EOF
#!/bin/sh
uci set wireless.radio0.disabled=0
uci set wireless.radio0.channel='$CHANNEL'
uci set wireless.radio0.htmode='VHT80'
uci set wireless.default_radio0.ssid='$MESH_SSID'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='$MESH_KEY'
uci set wireless.default_radio0.apup=1
uci set wireless.default_radio0.apup_peer_ifname_prefix='apup'

for i in \$(seq 1 10); do
    uci add_list network.@device[0].ports="apup\$i"
done

uci set network.lan.ipaddr='$NODE_IP'
uci set network.lan.gateway='$GATEWAY_IP'
uci set network.lan.dns='$GATEWAY_IP'
uci set dhcp.lan.ignore='1'
uci commit
reboot
EOF

    # Deploy to node
    scp /tmp/apup_deploy_$NODE_COUNTER.sh root@$CURRENT_NODE:/tmp/
    ssh root@$CURRENT_NODE "chmod +x /tmp/apup_deploy_$NODE_COUNTER.sh && /tmp/apup_deploy_$NODE_COUNTER.sh"

    NODE_COUNTER=$((NODE_COUNTER + 1))

    echo "Waiting 60s for node to reboot..."
    sleep 60
done

echo "Deployment complete!"
```

## Advanced Configuration

### Custom Interface Naming

```bash
# Use custom prefix instead of 'apup'
uci set wireless.default_radio0.apup_peer_ifname_prefix='mesh'

# Results in interfaces: mesh1, mesh2, mesh3, etc.
# Update bridge configuration accordingly:
for i in $(seq 1 10); do
    uci add_list network.@device[0].ports="mesh$i"
done
```

### VLAN Configuration

```bash
# Create VLANs over APuP mesh
# VLAN 10 for guests, VLAN 20 for management

# On gateway
uci set network.guest='interface'
uci set network.guest.type='bridge'
uci set network.guest.proto='static'
uci set network.guest.ipaddr='192.168.10.1'
uci set network.guest.netmask='255.255.255.0'

# VLAN tagging on bridge
uci set network.@bridge-vlan[0]=bridge-vlan
uci set network.@bridge-vlan[0].device='br-lan'
uci set network.@bridge-vlan[0].vlan='10'
uci add_list network.@bridge-vlan[0].ports='wlan0:t'
uci add_list network.@bridge-vlan[0].ports='apup1:t'
uci add_list network.@bridge-vlan[0].ports='apup2:t'

uci commit network
/etc/init.d/network restart
```

### QoS Configuration

```bash
# Install QoS packages
opkg update
opkg install luci-app-qos qos-scripts

# Configure QoS on gateway
uci set qos.wan.enabled='1'
uci set qos.wan.classgroup='Default'
uci set qos.wan.overhead='1'
uci set qos.wan.upload='5000'    # 5 Mbps upstream
uci set qos.wan.download='20000' # 20 Mbps downstream

# Prioritize mesh control traffic
uci add qos rule
uci set qos.@rule[-1].proto='tcp'
uci set qos.@rule[-1].ports='22,80,443'
uci set qos.@rule[-1].target='Priority'

uci commit qos
/etc/init.d/qos restart
```

### Monitoring and Logging

```bash
# Enable wireless logging
uci set system.@system[0].log_size='512'
uci set system.@system[0].log_proto='udp'
uci set system.@system[0].log_ip='192.168.1.1'
uci commit system
/etc/init.d/log restart

# Monitor APuP interface creation
logread -f | grep -i apup

# Create monitoring script
cat > /root/monitor_apup.sh <<'EOF'
#!/bin/sh
while true; do
    echo "=== APuP Status at $(date) ==="
    echo "Active APuP interfaces:"
    ip link show | grep apup | awk '{print $2}'

    echo -e "\nBridge members:"
    brctl show br-lan | grep apup

    echo -e "\nWireless stations:"
    iw dev wlan0 station dump | grep Station

    echo "================================"
    sleep 30
done
EOF

chmod +x /root/monitor_apup.sh

# Run in background
/root/monitor_apup.sh > /tmp/apup_monitor.log 2>&1 &
```

### Backup and Restore

```bash
# Backup APuP configuration
cat > /root/backup_apup.sh <<'EOF'
#!/bin/sh
BACKUP_DIR="/root/apup_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

uci export wireless > $BACKUP_DIR/wireless
uci export network > $BACKUP_DIR/network
uci export dhcp > $BACKUP_DIR/dhcp
uci export firewall > $BACKUP_DIR/firewall

tar czf $BACKUP_DIR.tar.gz $BACKUP_DIR
rm -rf $BACKUP_DIR

echo "Backup saved to $BACKUP_DIR.tar.gz"
EOF

# Restore APuP configuration
cat > /root/restore_apup.sh <<'EOF'
#!/bin/sh
if [ -z "$1" ]; then
    echo "Usage: $0 <backup_file.tar.gz>"
    exit 1
fi

TEMP_DIR="/tmp/apup_restore_$$"
mkdir -p $TEMP_DIR
tar xzf $1 -C $TEMP_DIR

BACKUP_DIR=$(ls -d $TEMP_DIR/apup_backup_* | head -1)

uci import wireless < $BACKUP_DIR/wireless
uci import network < $BACKUP_DIR/network
uci import dhcp < $BACKUP_DIR/dhcp
uci import firewall < $BACKUP_DIR/firewall

uci commit

rm -rf $TEMP_DIR

echo "Configuration restored. Reboot required."
EOF

chmod +x /root/backup_apup.sh /root/restore_apup.sh
```

## Troubleshooting

### Common Issues

#### Issue 1: APuP Interfaces Not Created

**Symptoms:**
- No apup1, apup2 interfaces appear
- Nodes can't see each other

**Diagnosis:**
```bash
# Check if APuP is enabled
uci show wireless | grep apup

# Check wireless status
iw dev wlan0 info

# Check channel
iw dev wlan0 info | grep channel

# Check for errors
logread | grep -i apup
logread | grep -i hostapd
```

**Solutions:**
```bash
# Verify all nodes on same channel
uci set wireless.radio0.channel='36'
uci commit wireless
wifi

# Ensure APuP is enabled
uci set wireless.default_radio0.apup=1
uci commit wireless
wifi

# Check hostapd version
hostapd -v

# Restart wireless completely
wifi down && sleep 2 && wifi up

# Force reload
/etc/init.d/network restart
```

#### Issue 2: Nodes on Different Channels

**Symptoms:**
- Some nodes visible, others not
- Intermittent connectivity

**Diagnosis:**
```bash
# On each node, check channel
iw dev wlan0 info | grep channel

# Scan for other APs
iw dev wlan0 scan | grep -E "SSID|freq|channel"
```

**Solutions:**
```bash
# Set identical channel on ALL nodes
# Gateway:
uci set wireless.radio0.channel='36'
uci commit wireless

# All Nodes:
uci set wireless.radio0.channel='36'
uci commit wireless

# Restart all nodes
wifi
```

#### Issue 3: Bridge Not Working

**Symptoms:**
- APuP interfaces created but not in bridge
- No connectivity between nodes

**Diagnosis:**
```bash
# Check bridge status
brctl show

# Check if apup interfaces exist
ip link show | grep apup

# Check bridge ports
ls /sys/class/net/br-lan/brif/
```

**Solutions:**
```bash
# Verify bridge configuration
uci show network.@device[0]

# Manually add interfaces
brctl addif br-lan apup1
brctl addif br-lan apup2

# Or reconfigure
for i in $(seq 1 10); do
    uci del_list network.@device[0].ports="apup$i" 2>/dev/null
    uci add_list network.@device[0].ports="apup$i"
done
uci commit network
/etc/init.d/network restart
```

#### Issue 4: DHCP Not Working on Clients

**Symptoms:**
- Clients connect but get no IP address
- Clients get APIPA addresses (169.254.x.x)

**Diagnosis:**
```bash
# On gateway, check DHCP status
/etc/init.d/dnsmasq status

# Check DHCP leases
cat /tmp/dhcp.leases

# Check DHCP configuration
uci show dhcp.lan
```

**Solutions:**
```bash
# Ensure DHCP only on gateway
# Gateway:
uci set dhcp.lan.ignore='0'
uci commit dhcp
/etc/init.d/dnsmasq restart

# All Nodes:
uci set dhcp.lan.ignore='1'
uci commit dhcp
/etc/init.d/dnsmasq restart

# Check firewall
uci show firewall | grep -A 5 "zone.*lan"
```

#### Issue 5: Encryption Mismatch

**Symptoms:**
- Authentication failures
- Nodes can't connect

**Diagnosis:**
```bash
# Check encryption settings
uci show wireless.default_radio0 | grep -E "encryption|key"

# Check hostapd logs
logread | grep hostapd | grep -i auth
```

**Solutions:**
```bash
# Ensure identical settings on all nodes
SSID='MeshNetwork'
KEY='YourPassword123'

# On all nodes:
uci set wireless.default_radio0.ssid="$SSID"
uci set wireless.default_radio0.encryption='psk2+ccmp'
uci set wireless.default_radio0.key="$KEY"
uci commit wireless
wifi
```

### Diagnostic Commands

```bash
# Complete diagnostic script
cat > /root/apup_diagnostic.sh <<'EOF'
#!/bin/sh

echo "=== OpenWRT APuP Diagnostic ==="
echo "Date: $(date)"
echo ""

echo "=== System Info ==="
cat /etc/openwrt_release
echo ""

echo "=== Wireless Configuration ==="
uci show wireless | grep -E "radio0|default_radio0|apup"
echo ""

echo "=== Network Configuration ==="
uci show network | grep -E "device\[0\]|lan"
echo ""

echo "=== DHCP Configuration ==="
uci show dhcp.lan
echo ""

echo "=== Interface Status ==="
iw dev
echo ""

echo "=== APuP Interfaces ==="
ip link show | grep apup
echo ""

echo "=== Bridge Status ==="
brctl show
echo ""

echo "=== Bridge Ports ==="
ls -la /sys/class/net/br-lan/brif/
echo ""

echo "=== Wireless Stations ==="
iw dev wlan0 station dump
echo ""

echo "=== Routing Table ==="
ip route
echo ""

echo "=== Recent Logs ==="
logread | grep -iE "apup|hostapd|wireless" | tail -30
echo ""

echo "=== Diagnostic Complete ==="
EOF

chmod +x /root/apup_diagnostic.sh
/root/apup_diagnostic.sh
```

### Performance Testing

```bash
# Install iperf3
opkg update
opkg install iperf3

# On gateway (server)
iperf3 -s

# On node (client)
iperf3 -c 192.168.1.1 -t 30

# Bidirectional test
iperf3 -c 192.168.1.1 -t 30 -d

# Multiple streams
iperf3 -c 192.168.1.1 -t 30 -P 4

# UDP test
iperf3 -c 192.168.1.1 -t 30 -u -b 50M
```

## Hardware Compatibility

### Tested Chipsets

#### Qualcomm Atheros

**ath9k (802.11n):**
- ✅ AR9280, AR9380, AR9390
- ✅ Good APuP support
- ✅ Open source driver
- ⚠️ 2.4GHz and 5GHz models available

**ath10k (802.11ac):**
- ✅ QCA988x, QCA9880, QCA9984
- ✅ Excellent APuP support
- ✅ Wave 1 and Wave 2 hardware
- ✅ 5GHz recommended for mesh

#### MediaTek

**mt76 (802.11ac/ax):**
- ✅ MT7620, MT7621, MT7628
- ✅ MT7612, MT7615, MT7915
- ✅ Good driver support
- ✅ Budget-friendly options

#### Broadcom

**brcmfmac:**
- ⚠️ Limited testing
- ⚠️ Proprietary driver issues
- ❌ Not recommended for APuP

### Device Examples

**Confirmed Working:**
- TP-Link Archer C7 (ath10k)
- Netgear R7800 (ath10k)
- Linksys WRT1900ACS (mwlwifi)
- GL.iNet GL-AR750S (ath9k/ath10k)
- Ubiquiti EdgeRouter X-SFP + USB WiFi (ath9k)

**Reported Issues:**
- Some older b/g/n-only devices
- Broadcom-based devices
- Devices with outdated hostapd

### Compatibility Check

```bash
# Check WiFi chipset
dmesg | grep -iE "ath|mt76|brcm"

# Check driver
lsmod | grep -E "ath9k|ath10k|mt76"

# Check hostapd features
hostapd -v

# Check 4-address support
iw list | grep -i "4addr"

# Expected output should include:
# * AP mode
# * 4-address support
```

## Security Considerations

### Critical Security Issue: Inter-Node Encryption

**Important Warning:** According to user reports in the original forum discussion:

> One user noted that inter-AP traffic may be **unencrypted** regardless of configured encryption settings.

**What This Means:**
- Client ↔ AP traffic: Encrypted (WPA2/WPA3)
- AP ↔ AP traffic: Potentially unencrypted
- Data passing through mesh: May be visible to anyone

**Mitigation Strategies:**

#### 1. VPN Overlay

```bash
# Install WireGuard
opkg update
opkg install luci-app-wireguard wireguard-tools

# Configure mesh-wide VPN
# All nodes connect to gateway VPN server
# Encrypts all inter-node traffic
```

#### 2. IPsec Tunnel

```bash
# Install strongSwan
opkg install strongswan-full

# Create IPsec tunnels between nodes
# More complex but provides encryption
```

#### 3. Physical Security

- Deploy mesh in trusted environments only
- Use in private property
- Avoid public spaces for sensitive data
- Consider wired backhaul for critical segments

#### 4. Application-Level Encryption

- Use HTTPS for all web traffic
- Enable SSH instead of Telnet
- Use encrypted protocols (IMAPS, POP3S, SMTPS)
- Deploy VPN for clients

### Access Control

```bash
# MAC address filtering on gateway
uci add wireless wifi-iface
uci set wireless.@wifi-iface[-1].macfilter='allow'
uci add_list wireless.@wifi-iface[-1].maclist='AA:BB:CC:DD:EE:FF'
uci add_list wireless.@wifi-iface[-1].maclist='11:22:33:44:55:66'
uci commit wireless
wifi

# Firewall rules for node access
uci add firewall rule
uci set firewall.@rule[-1].name='Allow_Mesh_Nodes'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].src_ip='192.168.1.2-192.168.1.10'
uci set firewall.@rule[-1].dest='lan'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart
```

### Node Authentication

```bash
# Use strong WPA2 PSK
STRONG_KEY=$(openssl rand -base64 24)
echo "Generated key: $STRONG_KEY"

uci set wireless.default_radio0.key="$STRONG_KEY"
uci commit wireless
wifi

# Or use WPA3 (if supported)
uci set wireless.default_radio0.encryption='sae'
uci set wireless.default_radio0.key="$STRONG_KEY"
uci commit wireless
wifi
```

### Monitoring for Rogue Nodes

```bash
# Monitor connected stations
cat > /root/monitor_stations.sh <<'EOF'
#!/bin/sh
KNOWN_NODES="aa:bb:cc:dd:ee:f1 aa:bb:cc:dd:ee:f2 aa:bb:cc:dd:ee:f3"
ALERT_EMAIL="admin@example.com"

while true; do
    CURRENT_STATIONS=$(iw dev wlan0 station dump | grep Station | awk '{print $2}')

    for station in $CURRENT_STATIONS; do
        if ! echo "$KNOWN_NODES" | grep -q "$station"; then
            echo "Unknown station detected: $station" | \
                mail -s "APuP Security Alert" $ALERT_EMAIL
        fi
    done

    sleep 60
done
EOF

chmod +x /root/monitor_stations.sh
# Run in background or as cron job
```

## Performance Optimization

### Channel Selection

```bash
# Scan for least congested channel
iw dev wlan0 scan | grep -E "freq|signal|SSID" | less

# 5GHz channels (less congested):
# 36, 40, 44, 48 (UNII-1)
# 149, 153, 157, 161, 165 (UNII-3)

# Set optimal channel
uci set wireless.radio0.channel='149'  # Often less crowded
uci set wireless.radio0.htmode='VHT80'
uci commit wireless
wifi
```

### Transmit Power Optimization

```bash
# Check current power
iw dev wlan0 info | grep txpower

# Set transmit power (in dBm)
# Lower for dense deployments, higher for coverage
uci set wireless.radio0.txpower='20'  # 20 dBm = 100mW
uci commit wireless
wifi

# Find maximum
iw list | grep -A 10 "Frequencies"
```

### Bandwidth Management

```bash
# Limit per-client bandwidth
opkg install tc kmod-sched

# Create traffic shaping script
cat > /etc/hotplug.d/iface/99-qos <<'EOF'
#!/bin/sh

[ "$ACTION" = "ifup" ] || exit 0

# Limit each APuP interface to 50 Mbps
for iface in /sys/class/net/apup*; do
    if [ -e "$iface" ]; then
        IFACE=$(basename $iface)
        tc qdisc add dev $IFACE root tbf rate 50mbit burst 32kbit latency 400ms
    fi
done
EOF

chmod +x /etc/hotplug.d/iface/99-qos
```

### WiFi Settings Optimization

```bash
# Optimize for mesh performance
uci set wireless.radio0.country='US'
uci set wireless.radio0.channel='149'
uci set wireless.radio0.htmode='VHT80'
uci set wireless.radio0.txpower='20'

# Advanced settings
uci set wireless.radio0.noscan='1'          # Don't scan, fixed channel
uci set wireless.radio0.distance='1000'     # Distance in meters
uci set wireless.default_radio0.disassoc_low_ack='0'  # Keep weak stations
uci set wireless.default_radio0.max_inactivity='86400'  # 24h timeout

uci commit wireless
wifi
```

## Use Cases

### 1. Home Network Extension

**Scenario:** Large house with thick walls, WiFi doesn't reach all rooms

```
Setup:
- Gateway: Central location with internet
- Node A: Opposite end of house
- Node B: Upstairs
- Node C: Basement

Configuration:
- Single SSID (roaming)
- Clients seamlessly move between nodes
- Unified network (192.168.1.0/24)
```

### 2. Small Business/Cafe

**Scenario:** Multi-floor cafe with separate areas

```
Setup:
- Gateway: Ground floor (near internet)
- Node A: First floor
- Node B: Outdoor seating
- Separate guest network

Configuration:
- Main SSID for staff
- Guest SSID (isolated)
- QoS for staff priority
- Bandwidth limits on guest
```

### 3. Campus/School

**Scenario:** Multiple buildings requiring coverage

```
Setup:
- Gateway: Main building
- Nodes: Each classroom/building
- Centralized authentication

Configuration:
- Single SSID across campus
- RADIUS authentication (future)
- Per-node traffic monitoring
- Guest access in common areas
```

### 4. Warehouse/Factory

**Scenario:** Large industrial space with IoT devices

```
Setup:
- Gateway: Office area
- Nodes: Throughout warehouse
- Separate IoT network

Configuration:
- Main network for staff/devices
- IoT network (isolated VLAN)
- Fixed IP assignments for devices
- Monitoring for equipment
```

### 5. Outdoor Event

**Scenario:** Temporary WiFi for festival/market

```
Setup:
- Gateway: Control tent
- Nodes: Distributed around venue
- Battery/solar powered nodes

Configuration:
- Single guest network
- Bandwidth limits
- Captive portal (optional)
- Easy teardown after event
```

### 6. Rural Property

**Scenario:** Farm or large property requiring coverage

```
Setup:
- Gateway: Main house
- Nodes: Barn, greenhouse, workshop
- Long distances between nodes

Configuration:
- High transmit power
- Directional antennas (optional)
- Weather-resistant enclosures
- 5GHz for better range
```

## Conclusion

APuP (Access Point Micro Peering) provides a simpler approach to mesh networking on OpenWRT compared to traditional protocols. While still in development, it offers significant advantages for small to medium deployments.

**Key Takeaways:**

✅ **Advantages:**
- Simple configuration via UCI
- Good hardware compatibility
- Automatic peer discovery
- Flexible bridging
- Standard AP mode features

⚠️ **Limitations:**
- Development branch only (as of Aug 2024)
- Same channel requirement
- Potential encryption issues between nodes
- Layer 2 only (no routing)
- Limited production testing

🔐 **Security:**
- Verify inter-node encryption
- Consider VPN overlay for sensitive data
- Use strong WPA2/WPA3 keys
- Deploy in trusted environments

📊 **Best Practices:**
- Pre-configure bridge with multiple apup ports
- Use static IPs for nodes
- Same channel on all devices
- Document your topology
- Test thoroughly before production

**When to Use APuP:**
- Home network extension
- Small business WiFi
- Temporary events
- Simple mesh needs
- Testing/development

**When to Use Alternatives:**
- Large-scale deployments → 802.11s or BATMAN
- Security-critical → 802.11s with SAE
- Complex routing → BATMAN-adv
- Fixed topology → WDS

**Future Development:**
- LuCI web interface support
- Enhanced encryption between nodes
- Better documentation
- Wider hardware testing
- Stable release integration

For more information:
- OpenWRT Wiki: https://openwrt.org/
- Hostapd Documentation: https://w1.fi/hostapd/
- Community Forums: https://forum.openwrt.org/

---

**Document Version:** 1.0
**Last Updated:** Based on forum discussion from 2024
**OpenWRT Version:** Development snapshot (post-August 2024)
