# OpenWRT WireGuard VPN Setup with mikr.us FROG Server

## Table of Contents
- [Overview](#overview)
- [What is WireGuard?](#what-is-wireguard)
- [mikr.us FROG Server Introduction](#mikrus-frog-server-introduction)
- [Network Architecture](#network-architecture)
- [Prerequisites](#prerequisites)
- [FROG Server Setup](#frog-server-setup)
- [WireGuard Key Generation](#wireguard-key-generation)
- [FROG WireGuard Configuration](#frog-wireguard-configuration)
- [OpenWRT Client Setup](#openwrt-client-setup)
- [Windows Client Setup](#windows-client-setup)
- [Firewall Configuration](#firewall-configuration)
- [Port Forwarding](#port-forwarding)
- [Testing and Verification](#testing-and-verification)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)
- [Advanced Scenarios](#advanced-scenarios)
- [Performance Optimization](#performance-optimization)
- [Limitations and Workarounds](#limitations-and-workarounds)

## Overview

This guide demonstrates how to establish a WireGuard VPN connection to access an OpenWRT router located behind NAT without a public IP address, using a budget FROG VPS from mikr.us as an intermediary server.

**What You'll Learn:**
- Setting up WireGuard VPN server on mikr.us FROG
- Connecting OpenWRT router as VPN client
- Accessing LAN devices through VPN tunnel
- Port forwarding through FROG server
- Multi-client VPN configuration

**Key Benefits:**
- Access home network without public IP
- Very low cost (5 PLN registration + minimal annual fees)
- Secure WireGuard encryption
- IPv4 and IPv6 support
- Multiple forwarding ports available

## What is WireGuard?

### WireGuard Overview

**WireGuard Characteristics:**
- Modern VPN protocol (merged into Linux kernel 5.6)
- Extremely fast performance
- Simple configuration
- Strong cryptography (Curve25519, ChaCha20, Poly1305)
- Small codebase (~4,000 lines vs OpenVPN's 100,000+)
- Low overhead and latency

### WireGuard vs Other VPN Protocols

| Feature | WireGuard | OpenVPN | IPsec |
|---------|-----------|---------|-------|
| Configuration | Very Simple | Complex | Very Complex |
| Performance | Excellent | Good | Good |
| Codebase Size | ~4K lines | ~100K lines | Very Large |
| Encryption | ChaCha20 | AES/ChaCha20 | AES |
| Roaming Support | Excellent | Limited | Poor |
| Battery Impact | Very Low | Medium | High |
| Setup Time | Minutes | Hours | Days |

### How WireGuard Works

**Key Concepts:**
- **Interface-based**: Each VPN connection is a network interface (wg0, wg1)
- **Peer-to-peer**: No client/server distinction at protocol level
- **Public key authentication**: Each peer identified by public key
- **Silent**: No response to unauthorized packets
- **Roaming**: Seamlessly handles IP address changes

**Connection Process:**
```
1. Peer A sends encrypted packet to Peer B
2. Peer B verifies signature with Peer A's public key
3. If valid, Peer B responds
4. Connection established, bidirectional tunnel active
```

## mikr.us FROG Server Introduction

### What is FROG?

**FROG (Free Routed OpenVZ/LXC):**
- Budget VPS service from mikr.us (Polish provider)
- LXC container on Alpine Linux
- Limited resources but sufficient for VPN
- Minimal cost with prepaid model

### FROG Specifications

**Infrastructure:**
- **OS**: Alpine Linux (LXC container)
- **RAM**: Typically 128-256 MB
- **Disk**: 512 MB - 1 GB
- **Network**: Shared bandwidth
- **IPv4**: 4 configurable ports
- **IPv6**: Full subnet included
- **Internal Network**: 192.168.7.0/24

**Port Allocation:**
- Each FROG gets 4 public IPv4 ports (10xxx range)
- One port dedicated to SSH (e.g., 10100)
- Three ports available for services (20xxx, 30xxx, 40xxx)
- Ports mapped via NAT to container

**Example Port Mapping:**
```
Public IP:10100 → 192.168.7.x:22 (SSH)
Public IP:20100 → 192.168.7.x:20100 (WireGuard)
Public IP:30100 → 192.168.7.x:30100 (HTTP forward)
Public IP:40100 → 192.168.7.x:40100 (Additional service)
```

### Cost Structure

**Pricing (as of guide creation):**
- Registration: ~5 PLN (one-time)
- Annual fee: Minimal (a few PLN)
- Total first year: ~5-10 PLN (~1-2 EUR/USD)

**Note:** Pricing may change. Check https://mikr.us for current rates.

### FROG Limitations

**Critical Limitations:**
1. **Fixed Internal Network**: 192.168.1.x gateway cannot be changed
2. **Port Limit**: Only 4 IPv4 ports (1 for SSH, 3 usable)
3. **Resource Constraints**: Limited RAM/CPU/disk
4. **No Root in LXC**: Some operations restricted
5. **Shared Infrastructure**: Performance varies

**Workaround for 192.168.1.x Conflict:**
- OpenWRT LAN must use different subnet (e.g., 192.168.11.0/24)
- Cannot simultaneously access FROG's 192.168.1.x and route it
- VPN tunnel uses separate addressing (e.g., 10.9.0.0/24)

## Network Architecture

### Overall Topology

```
                          Internet
                              |
                              |
                    +---------+---------+
                    |                   |
                    |   FROG Server     |
                    |  (mikr.us VPS)    |
                    |  Public IP        |
                    |  Ports: 10100-40100|
                    +---------+---------+
                              |
                      WireGuard Tunnel
                       (10.9.0.0/24)
                              |
            +-----------------+------------------+
            |                                    |
    +-------+--------+                  +--------+-------+
    |                |                  |                |
    |  OpenWRT       |                  |  Windows PC    |
    |  10.9.0.2      |                  |  10.9.0.3      |
    |  LAN:          |                  |                |
    |  192.168.11.0  |                  |                |
    +----------------+                  +----------------+
            |
         LAN Devices
      (192.168.11.x)
```

### IP Addressing Scheme

**FROG Server:**
- Internal: 192.168.7.x (assigned by mikr.us)
- WireGuard: 10.9.0.1/24
- Gateway: 192.168.1.1 (mikr.us infrastructure)

**OpenWRT Router:**
- WAN: DHCP or PPPoE (ISP provided)
- LAN: 192.168.11.0/24 (must avoid 192.168.1.x)
- WireGuard: 10.9.0.2/32

**Windows Client:**
- LAN: 192.168.x.x (local network)
- WireGuard: 10.9.0.3/32

### Traffic Flow Examples

**Scenario 1: Windows → OpenWRT LAN Device**
```
Windows PC (10.9.0.3)
    ↓ [WireGuard tunnel]
FROG Server (10.9.0.1)
    ↓ [WireGuard tunnel]
OpenWRT (10.9.0.2)
    ↓ [Routing]
LAN Device (192.168.11.50)
```

**Scenario 2: Internet → OpenWRT LuCI**
```
Internet User
    ↓ [HTTP to frog01.mikr.us:30100]
FROG Server (NAT forward)
    ↓ [Port forward via WireGuard]
OpenWRT (10.9.0.2:80)
    ↓
LuCI Web Interface
```

## Prerequisites

### FROG Server Requirements

**Account Setup:**
1. Register at https://mikr.us
2. Order FROG service
3. Receive credentials (SSH port, IP, password)
4. Note your 4 allocated ports

**Software Packages:**
```bash
# Update Alpine package manager
apk update

# Install WireGuard
apk add wireguard-tools

# Install iptables (usually pre-installed)
apk add iptables

# Optional: text editor
apk add nano
```

### OpenWRT Router Requirements

**Minimum OpenWRT Version:**
- OpenWRT 19.07 or newer recommended
- WireGuard kernel module support

**Required Packages:**
```bash
opkg update
opkg install kmod-wireguard wireguard-tools luci-proto-wireguard
```

**Network Configuration:**
- LAN subnet NOT 192.168.1.0/24 (use 192.168.11.0/24 or similar)
- Working internet connection
- SSH access to router

### Windows Client Requirements

**WireGuard Client:**
- Download from: https://www.wireguard.com/install/
- Windows 7 or newer
- Administrator privileges for installation

### General Requirements

**Tools Needed:**
- SSH client (PuTTY, OpenSSH, etc.)
- Text editor
- Basic understanding of networking concepts

## FROG Server Setup

### Initial Login

**Connect to FROG:**
```bash
# Use your assigned SSH port and FROG hostname
ssh root@frog01.mikr.us -p 10100

# Replace:
# - frog01.mikr.us with your FROG hostname
# - 10100 with your SSH port

# Enter password when prompted
```

**First Steps:**
```bash
# Change default password
passwd

# Update system
apk update
apk upgrade

# Install WireGuard
apk add wireguard-tools iptables

# Verify installation
wg --version
```

### Enable IP Forwarding

**Temporary (until reboot):**
```bash
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1
```

**Permanent:**
```bash
# Edit sysctl configuration
cat >> /etc/sysctl.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

# Apply settings
sysctl -p
```

**Verify:**
```bash
sysctl net.ipv4.ip_forward
# Should return: net.ipv4.ip_forward = 1
```

### Create WireGuard Directory

```bash
# Create configuration directory
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

# Navigate to directory
cd /etc/wireguard
```

## WireGuard Key Generation

### Generate Server Keys (FROG)

```bash
# On FROG server
cd /etc/wireguard

# Generate server private key
wg genkey | tee frog.privatekey | wg pubkey > frog.publickey

# Set permissions
chmod 600 frog.privatekey
chmod 644 frog.publickey

# Display keys
echo "FROG Private Key:"
cat frog.privatekey
echo ""
echo "FROG Public Key:"
cat frog.publickey
```

**Save these keys!** You'll need them for configuration.

### Generate OpenWRT Keys

**Option 1: Generate on FROG, transfer to OpenWRT**
```bash
# On FROG server
cd /etc/wireguard

# Generate OpenWRT keys
wg genkey | tee openwrt.privatekey | wg pubkey > openwrt.publickey

# Display keys
echo "OpenWRT Private Key:"
cat openwrt.privatekey
echo ""
echo "OpenWRT Public Key:"
cat openwrt.publickey

# Copy private key to OpenWRT later
# Keep public key on FROG for configuration
```

**Option 2: Generate directly on OpenWRT**
```bash
# On OpenWRT router (after installing wireguard-tools)
ssh root@192.168.11.1

# Generate keys
wg genkey | tee /etc/wireguard/openwrt.privatekey | wg pubkey > /etc/wireguard/openwrt.publickey

# Display keys
cat /etc/wireguard/openwrt.privatekey
cat /etc/wireguard/openwrt.publickey

# Copy public key to FROG configuration
```

### Generate Windows Client Keys

**Option 1: Generate on FROG**
```bash
# On FROG server
cd /etc/wireguard

# Generate Windows keys
wg genkey | tee windows.privatekey | wg pubkey > windows.publickey

# Display keys
echo "Windows Private Key:"
cat windows.privatekey
echo ""
echo "Windows Public Key:"
cat windows.publickey
```

**Option 2: Generate in WireGuard Windows App**
- WireGuard app can auto-generate keys when creating new tunnel
- Export public key to add to FROG configuration

### Key Management Summary

**Keys to Generate:**
```
FROG:    frog.privatekey    → Keep on FROG
         frog.publickey     → Share with all clients

OpenWRT: openwrt.privatekey → Keep on OpenWRT
         openwrt.publickey  → Share with FROG

Windows: windows.privatekey → Keep on Windows PC
         windows.publickey  → Share with FROG
```

**Security Note:**
- **NEVER** share private keys
- Keep private keys secure and backed up
- Each peer should have unique key pair
- Public keys can be freely shared

## FROG WireGuard Configuration

### Create WireGuard Config File

```bash
# On FROG server
nano /etc/wireguard/wg0.conf
```

### Basic Configuration

**File: `/etc/wireguard/wg0.conf`**
```ini
[Interface]
# FROG server private key
PrivateKey = YOUR_FROG_PRIVATE_KEY_HERE
# WireGuard tunnel IP address
Address = 10.9.0.1/24
# Listen on assigned WireGuard port (use your 20xxx port)
ListenPort = 20100

# OpenWRT peer
[Peer]
# OpenWRT public key
PublicKey = OPENWRT_PUBLIC_KEY_HERE
# Allow traffic from OpenWRT and its LAN
AllowedIPs = 10.9.0.2/32, 192.168.11.0/24
# Keep connection alive
PersistentKeepalive = 25

# Windows peer
[Peer]
# Windows public key
PublicKey = WINDOWS_PUBLIC_KEY_HERE
# Allow traffic from Windows client
AllowedIPs = 10.9.0.3/32
# Keep connection alive
PersistentKeepalive = 25
```

### Detailed Configuration Explanation

**[Interface] Section:**
```ini
[Interface]
PrivateKey = YOUR_FROG_PRIVATE_KEY_HERE
  # Server's private key (from frog.privatekey)

Address = 10.9.0.1/24
  # Server's VPN IP address
  # /24 means entire 10.9.0.0/24 subnet belongs to this VPN

ListenPort = 20100
  # UDP port for WireGuard
  # Must be one of your assigned mikr.us ports
  # Use 20xxx, 30xxx, or 40xxx (NOT your SSH port 10xxx)
```

**[Peer] Sections:**
```ini
[Peer]
PublicKey = PEER_PUBLIC_KEY
  # Peer's public key (not private!)

AllowedIPs = 10.9.0.2/32, 192.168.11.0/24
  # IP addresses this peer is allowed to use as source
  # Also defines routes: traffic to these IPs goes through this peer
  # /32 = single IP, /24 = entire subnet

PersistentKeepalive = 25
  # Send keepalive packet every 25 seconds
  # Essential for NAT traversal
  # Keeps connection alive through firewalls
```

### Example Complete Configuration

```ini
[Interface]
PrivateKey = eG93dXJfZnJvZ19wcml2YXRlX2tleV9oZXJl
Address = 10.9.0.1/24
ListenPort = 20100

[Peer]
# OpenWRT Router
PublicKey = b3BlbndydF9wdWJsaWNfa2V5X2hlcmU=
AllowedIPs = 10.9.0.2/32, 192.168.11.0/24
PersistentKeepalive = 25

[Peer]
# Windows Laptop
PublicKey = d2luZG93c19wdWJsaWNfa2V5X2hlcmU=
AllowedIPs = 10.9.0.3/32
PersistentKeepalive = 25

[Peer]
# Windows Desktop
PublicKey = ZGVza3RvcF9wdWJsaWNfa2V5X2hlcmU=
AllowedIPs = 10.9.0.4/32
PersistentKeepalive = 25
```

**Save and set permissions:**
```bash
chmod 600 /etc/wireguard/wg0.conf
```

### Enable WireGuard on Boot

**Method 1: Using wg-quick (Recommended)**

```bash
# Edit network interfaces file
nano /etc/network/interfaces
```

Add to the end of the `eth0` interface section:
```
auto eth0
iface eth0 inet dhcp
    post-up wg-quick up /etc/wireguard/wg0.conf
    pre-down wg-quick down /etc/wireguard/wg0.conf
```

**Complete example:**
```
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
    hostname frog01
    post-up wg-quick up /etc/wireguard/wg0.conf
    pre-down wg-quick down /etc/wireguard/wg0.conf
```

**Method 2: OpenRC Service (Alternative)**

```bash
# Enable WireGuard service
rc-update add wg-quick default

# Create service link
ln -s /etc/init.d/wg-quick /etc/init.d/wg-quick.wg0
rc-update add wg-quick.wg0 default
```

### Start WireGuard

```bash
# Start WireGuard interface
wg-quick up wg0

# Or if using service:
rc-service wg-quick.wg0 start
```

### Verify WireGuard Status

```bash
# Check WireGuard status
wg show

# Expected output:
# interface: wg0
#   public key: [your frog public key]
#   private key: (hidden)
#   listening port: 20100
#
# peer: [openwrt public key]
#   allowed ips: 10.9.0.2/32, 192.168.11.0/24
#   persistent keepalive: every 25 seconds
#
# peer: [windows public key]
#   allowed ips: 10.9.0.3/32
#   persistent keepalive: every 25 seconds

# Check interface
ip addr show wg0

# Expected output:
# wg0: <POINTOPOINT,NOARP,UP,LOWER_UP>
#     inet 10.9.0.1/24 scope global wg0
```

## OpenWRT Client Setup

### Install WireGuard Packages

```bash
# SSH to OpenWRT
ssh root@192.168.11.1

# Update package list
opkg update

# Install WireGuard packages
opkg install kmod-wireguard wireguard-tools

# Optional: LuCI interface for WireGuard
opkg install luci-proto-wireguard luci-app-wireguard
```

### Configure via UCI (Recommended)

**Step 1: Create WireGuard Interface**
```bash
# Create WireGuard interface
uci set network.wg0=interface
uci set network.wg0.proto='wireguard'
uci set network.wg0.private_key='YOUR_OPENWRT_PRIVATE_KEY_HERE'
uci add_list network.wg0.addresses='10.9.0.2/32'

# Optional: Listen port (if OpenWRT is also server)
# uci set network.wg0.listen_port='51820'
```

**Step 2: Add FROG as Peer**
```bash
# Add peer configuration
uci add network wireguard_wg0
uci set network.@wireguard_wg0[-1].public_key='FROG_PUBLIC_KEY_HERE'
uci set network.@wireguard_wg0[-1].endpoint_host='frog01.mikr.us'
uci set network.@wireguard_wg0[-1].endpoint_port='20100'
uci set network.@wireguard_wg0[-1].route_allowed_ips='1'
uci add_list network.@wireguard_wg0[-1].allowed_ips='10.9.0.0/24'
uci set network.@wireguard_wg0[-1].persistent_keepalive='25'
```

**Step 3: Commit and Apply**
```bash
# Commit configuration
uci commit network

# Restart network
/etc/init.d/network restart

# Or reload specific interface
ifup wg0
```

### Complete UCI Configuration Example

```bash
#!/bin/sh
# OpenWRT WireGuard Setup Script

# Replace these with your actual keys and endpoints
OPENWRT_PRIVATE_KEY="your_openwrt_private_key_here"
FROG_PUBLIC_KEY="your_frog_public_key_here"
FROG_ENDPOINT="frog01.mikr.us"
FROG_PORT="20100"

# Create WireGuard interface
uci set network.wg0=interface
uci set network.wg0.proto='wireguard'
uci set network.wg0.private_key="${OPENWRT_PRIVATE_KEY}"
uci add_list network.wg0.addresses='10.9.0.2/32'

# Add FROG server as peer
uci add network wireguard_wg0
uci set network.@wireguard_wg0[-1].public_key="${FROG_PUBLIC_KEY}"
uci set network.@wireguard_wg0[-1].endpoint_host="${FROG_ENDPOINT}"
uci set network.@wireguard_wg0[-1].endpoint_port="${FROG_PORT}"
uci set network.@wireguard_wg0[-1].route_allowed_ips='1'
uci add_list network.@wireguard_wg0[-1].allowed_ips='10.9.0.0/24'
uci set network.@wireguard_wg0[-1].persistent_keepalive='25'

# Commit and apply
uci commit network
/etc/init.d/network restart

echo "WireGuard configuration completed!"
```

### Alternative: Manual Configuration File

**Create config file:**
```bash
mkdir -p /etc/wireguard
nano /etc/wireguard/wg0.conf
```

**File content:**
```ini
[Interface]
PrivateKey = YOUR_OPENWRT_PRIVATE_KEY_HERE
Address = 10.9.0.2/32

[Peer]
PublicKey = FROG_PUBLIC_KEY_HERE
Endpoint = frog01.mikr.us:20100
AllowedIPs = 10.9.0.0/24
PersistentKeepalive = 25
```

**Start manually:**
```bash
wg-quick up wg0
```

### Verify OpenWRT Connection

```bash
# Check WireGuard status
wg show

# Expected to see:
# - Latest handshake time (should be recent)
# - Transfer data (rx/tx)

# Check interface
ip addr show wg0

# Ping FROG server
ping -c 4 10.9.0.1

# Expected: replies from 10.9.0.1
```

## Windows Client Setup

### Install WireGuard

**Download and Install:**
1. Visit https://www.wireguard.com/install/
2. Download Windows installer
3. Run installer (requires admin rights)
4. Launch WireGuard application

### Create Tunnel Configuration

**Method 1: Manual Configuration**

1. Open WireGuard app
2. Click "Add Tunnel" → "Add empty tunnel..."
3. App auto-generates private/public key pair
4. Copy the public key (you'll add it to FROG)
5. Configure as follows:

```ini
[Interface]
PrivateKey = YOUR_WINDOWS_PRIVATE_KEY_HERE
Address = 10.9.0.3/24

[Peer]
PublicKey = FROG_PUBLIC_KEY_HERE
Endpoint = frog01.mikr.us:20100
AllowedIPs = 10.9.0.0/24, 192.168.11.0/24
PersistentKeepalive = 25
```

6. Save with a name (e.g., "FROG VPN")

**Method 2: Import Configuration File**

Create file `frog-vpn.conf`:
```ini
[Interface]
PrivateKey = YOUR_WINDOWS_PRIVATE_KEY_HERE
Address = 10.9.0.3/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = FROG_PUBLIC_KEY_HERE
Endpoint = frog01.mikr.us:20100
AllowedIPs = 10.9.0.0/24, 192.168.11.0/24
PersistentKeepalive = 25
```

Import in WireGuard app: "Add Tunnel" → "Import tunnel(s) from file"

### Configuration Explanation

**[Interface] Section:**
```ini
PrivateKey = ...
  # Your Windows client's private key

Address = 10.9.0.3/24
  # VPN IP for this Windows machine
  # Each client should have unique IP

DNS = 1.1.1.1, 8.8.8.8
  # (Optional) DNS servers to use when VPN active
```

**[Peer] Section:**
```ini
PublicKey = FROG_PUBLIC_KEY_HERE
  # FROG server's public key

Endpoint = frog01.mikr.us:20100
  # FROG hostname:port
  # Replace with your actual FROG details

AllowedIPs = 10.9.0.0/24, 192.168.11.0/24
  # Routes through VPN:
  # - 10.9.0.0/24: VPN network
  # - 192.168.11.0/24: OpenWRT LAN network
  # To route ALL traffic: 0.0.0.0/0

PersistentKeepalive = 25
  # Send keepalive every 25 seconds
```

### Add Windows Peer to FROG

**On FROG server:**
```bash
# Stop WireGuard
wg-quick down wg0

# Edit configuration
nano /etc/wireguard/wg0.conf

# Add Windows peer section
```

Add to config:
```ini
[Peer]
# Windows PC
PublicKey = WINDOWS_PUBLIC_KEY_FROM_APP
AllowedIPs = 10.9.0.3/32
PersistentKeepalive = 25
```

**Restart WireGuard:**
```bash
wg-quick up wg0
```

### Connect from Windows

1. Open WireGuard app
2. Select your tunnel
3. Click "Activate"
4. Status should show "Active" with latest handshake time

### Verify Windows Connection

**In WireGuard app:**
- Check "Latest Handshake" (should be recent)
- Check "Transfer" (should show rx/tx data)

**In Command Prompt:**
```cmd
# Check WireGuard interface
ipconfig | findstr /C:"10.9.0"

# Ping FROG server
ping 10.9.0.1

# Ping OpenWRT router
ping 10.9.0.2

# Ping OpenWRT LAN device (if accessible)
ping 192.168.11.1
```

## Firewall Configuration

### OpenWRT Firewall Rules

**Create WireGuard Zone:**
```bash
# Add WireGuard firewall zone
uci add firewall zone
uci set firewall.@zone[-1].name='wg'
uci set firewall.@zone[-1].input='ACCEPT'
uci set firewall.@zone[-1].forward='ACCEPT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].masq='1'
uci add_list firewall.@zone[-1].network='wg0'
```

**Add Forwarding Rules:**
```bash
# Allow WG → WAN
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='wg'
uci set firewall.@forwarding[-1].dest='wan'

# Allow WAN → WG
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='wan'
uci set firewall.@forwarding[-1].dest='wg'

# Allow WG → LAN
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='wg'
uci set firewall.@forwarding[-1].dest='lan'

# Allow LAN → WG
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='lan'
uci set firewall.@forwarding[-1].dest='wg'
```

**Commit and Apply:**
```bash
uci commit firewall
/etc/init.d/firewall restart
```

### Complete Firewall Script

```bash
#!/bin/sh
# OpenWRT WireGuard Firewall Configuration

echo "Configuring WireGuard firewall..."

# Create WireGuard zone
uci add firewall zone
uci set firewall.@zone[-1].name='wg'
uci set firewall.@zone[-1].input='ACCEPT'
uci set firewall.@zone[-1].forward='ACCEPT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].masq='1'
uci add_list firewall.@zone[-1].network='wg0'

# WG → WAN forwarding
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='wg'
uci set firewall.@forwarding[-1].dest='wan'

# WAN → WG forwarding
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='wan'
uci set firewall.@forwarding[-1].dest='wg'

# WG → LAN forwarding
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='wg'
uci set firewall.@forwarding[-1].dest='lan'

# LAN → WG forwarding
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='lan'
uci set firewall.@forwarding[-1].dest='wg'

# Commit changes
uci commit firewall

# Restart firewall
/etc/init.d/firewall restart

echo "Firewall configuration complete!"
```

### FROG Server Firewall (iptables)

**Allow WireGuard Port:**
```bash
# Allow UDP traffic on WireGuard port
iptables -A INPUT -p udp --dport 20100 -j ACCEPT

# Allow WireGuard interface
iptables -A INPUT -i wg0 -j ACCEPT
iptables -A FORWARD -i wg0 -j ACCEPT
```

**Enable NAT/Masquerading:**
```bash
# Enable masquerading for VPN clients
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

**Make Rules Persistent:**
```bash
# Save current rules
/etc/init.d/iptables save

# Or manually save
iptables-save > /etc/iptables/rules-save
```

**Auto-load on Boot:**
```bash
# Edit /etc/network/interfaces
nano /etc/network/interfaces
```

Add:
```
auto eth0
iface eth0 inet dhcp
    post-up iptables-restore < /etc/iptables/rules-save
    post-up wg-quick up /etc/wireguard/wg0.conf
    pre-down wg-quick down /etc/wireguard/wg0.conf
```

## Port Forwarding

### FROG NAT Port Forwarding

Port forwarding allows external access to services behind the VPN.

**Example: Expose OpenWRT LuCI (port 80)**

```bash
# On FROG server
# Forward public port 30100 → OpenWRT 10.9.0.2:80

# DNAT rule (incoming)
iptables -t nat -A PREROUTING -p tcp -i eth0 --dport 30100 \
  -j DNAT --to-destination 10.9.0.2:80

# Masquerade (return traffic)
iptables -t nat -A POSTROUTING -p tcp -d 10.9.0.2 --dport 80 \
  -j MASQUERADE

# Allow forwarding
iptables -A FORWARD -p tcp -d 10.9.0.2 --dport 80 -j ACCEPT
```

**Access:**
- External: `http://frog01.mikr.us:30100`
- Goes to: OpenWRT LuCI at 10.9.0.2:80

### Multiple Port Forwards

**OpenWRT SSH (22) via port 30100:**
```bash
iptables -t nat -A PREROUTING -p tcp -i eth0 --dport 30100 \
  -j DNAT --to-destination 10.9.0.2:22
iptables -t nat -A POSTROUTING -p tcp -d 10.9.0.2 --dport 22 \
  -j MASQUERADE
iptables -A FORWARD -p tcp -d 10.9.0.2 --dport 22 -j ACCEPT
```

**LAN Web Server (192.168.11.100:80) via port 40100:**
```bash
iptables -t nat -A PREROUTING -p tcp -i eth0 --dport 40100 \
  -j DNAT --to-destination 10.9.0.2:80
iptables -t nat -A POSTROUTING -p tcp -d 10.9.0.2 --dport 80 \
  -j MASQUERADE
iptables -A FORWARD -p tcp -d 10.9.0.2 --dport 80 -j ACCEPT

# On OpenWRT, add port forward from WG to LAN device
# (configure in LuCI or via UCI)
```

### OpenWRT Port Forward to LAN

**Forward from WireGuard to LAN device:**

```bash
# Forward port 8080 on OpenWRT → 192.168.11.100:80
uci add firewall redirect
uci set firewall.@redirect[-1].name='WG_to_LAN_HTTP'
uci set firewall.@redirect[-1].src='wg'
uci set firewall.@redirect[-1].src_dport='8080'
uci set firewall.@redirect[-1].dest='lan'
uci set firewall.@redirect[-1].dest_ip='192.168.11.100'
uci set firewall.@redirect[-1].dest_port='80'
uci set firewall.@redirect[-1].proto='tcp'
uci set firewall.@redirect[-1].target='DNAT'

uci commit firewall
/etc/init.d/firewall restart
```

**Complete chain:**
```
Internet → frog01.mikr.us:40100
    ↓ FROG DNAT
10.9.0.2:8080 (OpenWRT via VPN)
    ↓ OpenWRT DNAT
192.168.11.100:80 (LAN device)
```

### Persistent Port Forwarding Script

**Create script on FROG:**
```bash
nano /etc/local.d/port-forwards.start
```

**Content:**
```bash
#!/bin/sh
# FROG Port Forwarding Rules

# Forward 30100 → OpenWRT LuCI (80)
iptables -t nat -A PREROUTING -p tcp -i eth0 --dport 30100 \
  -j DNAT --to-destination 10.9.0.2:80
iptables -t nat -A POSTROUTING -p tcp -d 10.9.0.2 --dport 80 \
  -j MASQUERADE
iptables -A FORWARD -p tcp -d 10.9.0.2 --dport 80 -j ACCEPT

# Forward 40100 → OpenWRT SSH (22)
iptables -t nat -A PREROUTING -p tcp -i eth0 --dport 40100 \
  -j DNAT --to-destination 10.9.0.2:22
iptables -t nat -A POSTROUTING -p tcp -d 10.9.0.2 --dport 22 \
  -j MASQUERADE
iptables -A FORWARD -p tcp -d 10.9.0.2 --dport 22 -j ACCEPT
```

**Make executable:**
```bash
chmod +x /etc/local.d/port-forwards.start
rc-update add local
```

## Testing and Verification

### Connectivity Tests

**From FROG Server:**
```bash
# Ping OpenWRT
ping -c 4 10.9.0.2

# Ping OpenWRT LAN gateway
ping -c 4 192.168.11.1

# SSH to OpenWRT via VPN
ssh root@10.9.0.2

# Check WireGuard peers
wg show
# Should show "latest handshake" for each peer
```

**From OpenWRT Router:**
```bash
# Ping FROG
ping -c 4 10.9.0.1

# Traceroute to internet via VPN
traceroute -n 8.8.8.8

# Check WireGuard status
wg show

# Check routes
ip route | grep wg0
```

**From Windows Client:**
```cmd
# Ping FROG
ping 10.9.0.1

# Ping OpenWRT
ping 10.9.0.2

# Ping OpenWRT LAN
ping 192.168.11.1

# Access OpenWRT LuCI
# Browser: http://10.9.0.2
```

### Handshake Verification

**Check Latest Handshake:**
```bash
# On any peer
wg show

# Look for:
# latest handshake: X seconds ago
# If > 3 minutes, connection may be down
# If "handshake never received", peer not connecting
```

**Successful handshake indicators:**
- Latest handshake < 2 minutes
- Transfer rx/tx showing data
- Endpoint showing peer IP (on server side)

### Traffic Flow Testing

**Test 1: VPN Tunnel Traffic**
```bash
# From Windows, ping OpenWRT continuously
ping -t 10.9.0.2

# On FROG, watch WireGuard traffic
watch -n 1 wg show

# Should see transfer bytes increasing
```

**Test 2: LAN Access**
```bash
# From Windows, access LAN device
ping 192.168.11.100

# SSH to LAN device (if SSH server running)
ssh user@192.168.11.100
```

**Test 3: Port Forwarding**
```bash
# From external internet (not connected to VPN)
curl http://frog01.mikr.us:30100

# Should return OpenWRT LuCI page
# Or use browser
```

### Diagnostic Commands

**FROG Server:**
```bash
# Check WireGuard
wg show

# Check interface
ip addr show wg0

# Check routes
ip route | grep wg0

# Check firewall
iptables -L -n -v
iptables -t nat -L -n -v

# Check port listening
netstat -tulpn | grep 20100
```

**OpenWRT:**
```bash
# Check WireGuard
wg show

# Check interface
ifconfig wg0

# Check routes
route -n

# Check firewall
iptables -L -v -n
```

**Windows:**
```cmd
# Check route table
route print

# Check interface
ipconfig /all

# Check connections
netstat -an | findstr 20100
```

## Troubleshooting

### No Handshake Between Peers

**Symptoms:**
- `wg show` shows "handshake never received"
- No transfer data

**Diagnosis:**
```bash
# On FROG, check if listening
netstat -ulpn | grep 20100

# On OpenWRT, check if endpoint resolves
nslookup frog01.mikr.us

# Test UDP connectivity
nc -u frog01.mikr.us 20100
```

**Solutions:**
```bash
# 1. Verify public keys match
# On FROG:
wg show wg0 | grep peer

# On OpenWRT:
wg show wg0 | grep peer

# 2. Check firewall allows UDP 20100
# On FROG:
iptables -L -n | grep 20100

# 3. Restart WireGuard on both sides
# FROG:
wg-quick down wg0 && wg-quick up wg0

# OpenWRT:
ifdown wg0 && ifup wg0

# 4. Check PersistentKeepalive set on client
uci show network.@wireguard_wg0[-1].persistent_keepalive
# Should be 25
```

### Cannot Ping LAN Devices

**Symptoms:**
- Can ping 10.9.0.x (VPN IPs)
- Cannot ping 192.168.11.x (LAN IPs)

**Diagnosis:**
```bash
# On FROG, check AllowedIPs includes LAN subnet
wg show wg0

# Should show:
# allowed ips: 10.9.0.2/32, 192.168.11.0/24

# On OpenWRT, check firewall zones
uci show firewall | grep -A 5 "zone.*wg"
```

**Solutions:**
```bash
# 1. Add LAN subnet to FROG AllowedIPs
# Edit /etc/wireguard/wg0.conf:
AllowedIPs = 10.9.0.2/32, 192.168.11.0/24

# Restart WireGuard
wg-quick down wg0 && wg-quick up wg0

# 2. Add firewall forwarding on OpenWRT
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='wg'
uci set firewall.@forwarding[-1].dest='lan'
uci commit firewall
/etc/init.d/firewall restart

# 3. Check masquerading enabled
uci show firewall | grep masq
```

### Port Forwarding Not Working

**Symptoms:**
- Cannot access service via frog01.mikr.us:port
- Connection timeout or refused

**Diagnosis:**
```bash
# On FROG, check NAT rules
iptables -t nat -L -n -v | grep 30100

# Check if port is your assigned port
# (mikr.us only forwards your 4 ports)

# Test locally on FROG
curl http://10.9.0.2:80
# Should work if OpenWRT is accessible
```

**Solutions:**
```bash
# 1. Verify using correct mikr.us assigned port
# Check your mikr.us panel for assigned ports

# 2. Add iptables rules
iptables -t nat -A PREROUTING -p tcp -i eth0 --dport 30100 \
  -j DNAT --to-destination 10.9.0.2:80
iptables -t nat -A POSTROUTING -p tcp -d 10.9.0.2 --dport 80 \
  -j MASQUERADE

# 3. Save rules
iptables-save > /etc/iptables/rules-save

# 4. Check service actually running on target
# On OpenWRT:
netstat -tlpn | grep :80
```

### OpenWRT Cannot Connect to FROG

**Symptoms:**
- OpenWRT shows no handshake
- Cannot ping FROG from OpenWRT

**Diagnosis:**
```bash
# On OpenWRT, check configuration
uci show network.wg0
uci show network.@wireguard_wg0[-1]

# Test DNS resolution
nslookup frog01.mikr.us

# Check interface status
ifstatus wg0
```

**Solutions:**
```bash
# 1. Verify endpoint configuration
uci set network.@wireguard_wg0[-1].endpoint_host='frog01.mikr.us'
uci set network.@wireguard_wg0[-1].endpoint_port='20100'
uci commit network
ifup wg0

# 2. Check private key configured
uci get network.wg0.private_key
# Should return your private key (not empty)

# 3. Restart network service
/etc/init.d/network restart

# 4. Check logs
logread | grep -i wireguard
```

### Windows Client Connection Issues

**Symptoms:**
- Cannot activate tunnel
- "Unable to create IPC pipe" error
- No handshake received

**Solutions:**
```
1. Run WireGuard app as Administrator
2. Check Windows Firewall allows WireGuard
3. Verify endpoint accessible:
   - Open cmd
   - ping frog01.mikr.us
   - Should get response
4. Regenerate keys if corrupted
5. Check no antivirus blocking
6. Verify config file syntax correct
7. Check Windows date/time correct
```

### Performance Issues

**Symptoms:**
- Very slow speeds through VPN
- High latency
- Packet loss

**Diagnosis:**
```bash
# Check MTU settings
ip link show wg0

# Test with ping
ping -M do -s 1400 10.9.0.1
# If fails, try smaller size

# Check CPU usage on FROG
top

# Monitor WireGuard
watch -n 1 wg show
```

**Solutions:**
```bash
# 1. Adjust MTU
# On OpenWRT:
uci set network.wg0.mtu='1420'
uci commit network
ifup wg0

# 2. Disable compression if enabled
# (WireGuard doesn't use compression by default)

# 3. Check FROG resource limits
# mikr.us FROG has limited CPU/RAM

# 4. Optimize keepalive
# Increase if too frequent
uci set network.@wireguard_wg0[-1].persistent_keepalive='60'
```

## Security Considerations

### Key Management

**Best Practices:**
- **Unique Keys**: Each peer should have unique key pair
- **Secure Storage**: Never commit private keys to git/public repos
- **Backup**: Keep encrypted backups of private keys
- **Rotation**: Periodically regenerate keys (every 6-12 months)

**Key Rotation Process:**
```bash
# Generate new keys
wg genkey | tee new.privatekey | wg pubkey > new.publickey

# Update configuration with new keys
# Update all peers with new public key
# Test before removing old keys
# Remove old key after confirming new works
```

### Access Control

**Limit AllowedIPs:**
```ini
# Bad: Allow all traffic
AllowedIPs = 0.0.0.0/0

# Good: Only specific networks
AllowedIPs = 10.9.0.0/24, 192.168.11.0/24
```

**FROG Firewall:**
```bash
# Only allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Only allow WireGuard port
iptables -A INPUT -p udp --dport 20100 -j ACCEPT

# Drop everything else
iptables -A INPUT -j DROP
```

### Monitoring and Logging

**Monitor Connections:**
```bash
# Create monitoring script
cat > /root/monitor_wg.sh <<'EOF'
#!/bin/sh
while true; do
    echo "=== WireGuard Status $(date) ==="
    wg show
    echo ""
    sleep 300  # Every 5 minutes
done
EOF

chmod +x /root/monitor_wg.sh

# Run in background
/root/monitor_wg.sh >> /var/log/wireguard.log 2>&1 &
```

**Alert on Unusual Activity:**
```bash
# Check for unknown peers
wg show wg0 | grep -v "known_peer_key"
```

### Hardening FROG Server

**Change SSH Port:**
```bash
# Edit SSH config
nano /etc/ssh/sshd_config

# Change port (must be one of your assigned ports)
Port 10100

# Disable root password login
PermitRootLogin prohibit-password

# Restart SSH
rc-service sshd restart
```

**Disable Unnecessary Services:**
```bash
# List running services
rc-status

# Disable unwanted services
rc-update del service_name
```

**Regular Updates:**
```bash
# Update Alpine packages
apk update && apk upgrade
```

### Windows Client Security

**Firewall Rules:**
- Configure Windows Firewall to only allow VPN traffic when needed
- Don't allow all traffic through VPN unless necessary

**DNS Leaks:**
- Configure DNS in WireGuard config to prevent leaks
- Test at https://dnsleaktest.com

## Advanced Scenarios

### Multiple OpenWRT Routers

**Scenario:** Connect multiple remote sites

**FROG Configuration:**
```ini
[Interface]
PrivateKey = FROG_PRIVATE_KEY
Address = 10.9.0.1/24
ListenPort = 20100

[Peer]
# Site A Router
PublicKey = SITE_A_PUBLIC_KEY
AllowedIPs = 10.9.0.2/32, 192.168.11.0/24

[Peer]
# Site B Router
PublicKey = SITE_B_PUBLIC_KEY
AllowedIPs = 10.9.0.3/32, 192.168.12.0/24

[Peer]
# Site C Router
PublicKey = SITE_C_PUBLIC_KEY
AllowedIPs = 10.9.0.4/32, 192.168.13.0/24
```

**Result:** All sites can access each other through FROG

### Split Tunneling

**Route only specific traffic through VPN:**

**Windows Configuration:**
```ini
[Interface]
PrivateKey = WINDOWS_PRIVATE_KEY
Address = 10.9.0.3/32

[Peer]
PublicKey = FROG_PUBLIC_KEY
Endpoint = frog01.mikr.us:20100
# Only route VPN network and OpenWRT LAN, not all traffic
AllowedIPs = 10.9.0.0/24, 192.168.11.0/24
PersistentKeepalive = 25
```

**Result:** Internet traffic goes direct, only VPN/LAN through tunnel

### Site-to-Site VPN

**Connect two LANs:**

**Site A (OpenWRT):**
```bash
uci set network.wg0.private_key='SITE_A_PRIVATE_KEY'
uci add_list network.wg0.addresses='10.9.0.2/32'
uci add network wireguard_wg0
uci set network.@wireguard_wg0[-1].public_key='FROG_PUBLIC_KEY'
uci set network.@wireguard_wg0[-1].endpoint_host='frog01.mikr.us'
uci set network.@wireguard_wg0[-1].endpoint_port='20100'
uci add_list network.@wireguard_wg0[-1].allowed_ips='10.9.0.0/24'
uci add_list network.@wireguard_wg0[-1].allowed_ips='192.168.12.0/24'
```

**Site B (OpenWRT):**
```bash
# Similar config with different IPs
uci add_list network.wg0.addresses='10.9.0.3/32'
uci add_list network.@wireguard_wg0[-1].allowed_ips='192.168.11.0/24'
```

**Result:** Devices on Site A LAN can access Site B LAN and vice versa

## Performance Optimization

### MTU Optimization

**Find Optimal MTU:**
```bash
# Test with different packet sizes
ping -M do -s 1472 10.9.0.1  # Ethernet MTU 1500
ping -M do -s 1452 10.9.0.1  # Ethernet MTU 1500 - overhead
ping -M do -s 1420 10.9.0.1  # WireGuard recommended
ping -M do -s 1400 10.9.0.1  # Conservative

# Use largest size that doesn't fragment
```

**Set MTU on OpenWRT:**
```bash
uci set network.wg0.mtu='1420'
uci commit network
ifup wg0
```

**Set MTU on Windows:**
```ini
[Interface]
PrivateKey = ...
Address = 10.9.0.3/32
MTU = 1420
```

### CPU and Bandwidth

**Monitor Usage:**
```bash
# On FROG
top
# Watch wireguard-go or kernel module CPU usage

# Check bandwidth
iftop -i wg0
```

**Optimize:**
- Use hardware with AES-NI for better crypto performance
- Consider reducing keepalive frequency if bandwidth limited
- Disable unnecessary firewall logging

### Connection Keepalive Tuning

**Adjust based on network:**
```bash
# Unstable connection (frequent NAT timeout)
PersistentKeepalive = 15

# Stable connection (reduce overhead)
PersistentKeepalive = 60

# Very stable (minimal overhead)
PersistentKeepalive = 120
```

## Limitations and Workarounds

### mikr.us FROG Limitations

**1. Fixed Internal Network (192.168.1.x)**

**Problem:** FROG uses 192.168.1.1 gateway, can't be changed

**Workaround:**
- Use different subnet for OpenWRT LAN (192.168.11.0/24)
- Use VPN addressing (10.9.0.0/24) for tunneled traffic
- Don't try to route 192.168.1.x through VPN

**2. Limited Ports (4 IPv4 ports)**

**Problem:** Only 3 ports available after SSH (10xxx)

**Workaround:**
- Use port forwarding to multiplex services
- Use IPv6 (unlimited ports)
- Use SNI-based routing for HTTPS (advanced)

**3. Resource Constraints**

**Problem:** Limited RAM/CPU/disk

**Workaround:**
- Keep configuration minimal
- Don't run heavy services on FROG
- Use as VPN endpoint only, not as application server
- Monitor resource usage regularly

### Windows Firewall Issues

**Problem:** Windows Defender blocks ICMP through VPN

**Workaround:**
```
1. Open Windows Defender Firewall
2. Advanced Settings
3. Inbound Rules
4. Find "File and Printer Sharing (Echo Request - ICMPv4-In)"
5. Enable for Private/Public profiles
6. Or create new rule allowing ICMP from 10.9.0.0/24
```

### AllowedIPs Routing

**Problem:** Conflicting routes when using 0.0.0.0/0

**Workaround:**
- Use split tunneling with specific subnets
- Only route necessary networks through VPN
- Use separate VPN for "route all traffic" scenario

## Conclusion

WireGuard VPN with mikr.us FROG provides an excellent low-cost solution for accessing devices behind NAT without public IP addresses.

**Key Takeaways:**

✅ **Setup:**
- Generate unique key pairs for all peers
- Configure FROG as WireGuard server
- Connect OpenWRT and clients to FROG
- Configure firewall zones and forwarding

🔧 **Configuration:**
- Use 10.9.0.0/24 for VPN addressing
- Avoid 192.168.1.x on OpenWRT (conflicts with FROG)
- Set PersistentKeepalive=25 on clients
- Enable IP forwarding on FROG

🔐 **Security:**
- Protect private keys
- Use unique keys per peer
- Limit AllowedIPs to necessary networks
- Monitor connections regularly
- Harden FROG server

📊 **Best Practices:**
- Test connectivity at each step
- Monitor handshake status
- Optimize MTU for performance
- Use split tunneling when possible
- Document your configuration

**When to Use:**
- Remote access without public IP
- Budget VPN solution
- Learning WireGuard
- Small-scale site-to-site VPN

**Alternatives:**
- Full VPS with root access (more expensive but more flexible)
- Tailscale/ZeroTier (easier but less control)
- Dynamic DNS + port forwarding (requires ISP cooperation)
- Commercial VPN services (subscription cost)

For more information:
- WireGuard: https://www.wireguard.com
- mikr.us: https://mikr.us
- OpenWRT WireGuard: https://openwrt.org/docs/guide-user/services/vpn/wireguard

---

**Document Version:** 1.0
**Last Updated:** Based on eko.one.pl forum discussion
**Cost:** ~5-10 PLN/year (~1-2 EUR/USD)
**Tested on:** OpenWRT 22.03, Alpine Linux, Windows 10/11
