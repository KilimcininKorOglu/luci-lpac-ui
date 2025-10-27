# OpenWRT SSH Tunnel & Reverse SSH Guide

## Table of Contents
- [Overview](#overview)
- [What is SSH Tunneling?](#what-is-ssh-tunneling)
- [Use Cases](#use-cases)
- [Prerequisites](#prerequisites)
- [Understanding Reverse SSH Tunnels](#understanding-reverse-ssh-tunnels)
- [Basic Setup](#basic-setup)
- [Key-Based Authentication](#key-based-authentication)
- [Automation and Persistence](#automation-and-persistence)
- [Using sshtunnel Package](#using-sshtunnel-package)
- [Advanced Tunneling](#advanced-tunneling)
- [Port Forwarding Types](#port-forwarding-types)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [Performance Optimization](#performance-optimization)
- [Real-World Examples](#real-world-examples)

## Overview

This guide explains how to establish SSH tunnels from OpenWRT routers to remote servers, with a focus on reverse SSH tunnels for accessing devices behind NAT without public IP addresses.

**What You'll Learn:**
- Creating reverse SSH tunnels for remote access
- Setting up key-based authentication with Dropbear
- Automating tunnel maintenance with scripts and cron
- Using the sshtunnel package for managed tunneling
- Advanced tunneling scenarios and security

**Key Benefits:**
- Access devices behind NAT/firewall
- No public IP address required
- Secure encrypted connections
- Automated reconnection
- Multiple tunnel types supported

## What is SSH Tunneling?

### SSH Tunnel Types

**1. Local Port Forwarding (-L)**
```
[Local Client] → SSH → [Remote Server] → [Target Service]
Access remote service as if it's local
```

**2. Remote Port Forwarding (-R)**
```
[Remote Server] ← SSH ← [Local Client Behind NAT]
Remote server can access local service
```

**3. Dynamic Port Forwarding (-D)**
```
[Local Client] → SSH → [Remote Server] → [Internet]
SOCKS proxy through SSH tunnel
```

### How Reverse SSH Works

**Problem:** OpenWRT router behind NAT, no public IP

```
                    Internet
                       |
                  [Firewall/NAT]
                       |
                  [OpenWRT Router]  ← Can't access directly!
                  192.168.1.1
```

**Solution:** Reverse SSH tunnel

```
Step 1: OpenWRT initiates connection to server
[OpenWRT] --SSH--> [Public Server]

Step 2: Server creates tunnel back to OpenWRT
[OpenWRT] <--Port 1234 tunnel-- [Public Server]

Step 3: Access OpenWRT through server
[Admin] → [Public Server]:1234 → [OpenWRT]:22
```

## Use Cases

### 1. Remote Router Management
- Manage home router while traveling
- Access router behind ISP NAT
- No need for port forwarding
- Secure encrypted access

### 2. IoT Device Access
- Access IP cameras behind firewall
- Monitor sensors remotely
- Control home automation
- Secure device management

### 3. Bypass Firewall Restrictions
- Access internal services
- Circumvent restrictive networks
- Create VPN alternatives
- Secure data transmission

### 4. Multi-Site Network Management
- Manage multiple remote locations
- Centralized router administration
- Automated monitoring
- Log aggregation

### 5. Development and Testing
- Test devices remotely
- Debug network issues
- Remote firmware updates
- Configuration management

## Prerequisites

### On OpenWRT Router

**Required Packages:**
```bash
# Update package list
opkg update

# Install SSH client (usually pre-installed)
opkg install openssh-client

# Alternative: Use built-in dropbear client
# (usually already available)

# Optional: sshtunnel package for managed tunneling
opkg install sshtunnel
```

**System Requirements:**
- SSH client (dropbear or openssh)
- Persistent storage for keys
- Cron support for automation
- Network connectivity to public server

### On Remote Server

**Required:**
- Public IP address or dynamic DNS
- SSH server running (OpenSSH)
- User account for tunnel
- Firewall allowing SSH (port 22)

**Server Setup:**
```bash
# On Ubuntu/Debian server
sudo apt update
sudo apt install openssh-server

# Start SSH service
sudo systemctl start ssh
sudo systemctl enable ssh

# Check status
sudo systemctl status ssh

# Allow SSH through firewall
sudo ufw allow ssh
```

### Network Requirements

**OpenWRT Side:**
- Internet connectivity
- Outbound SSH allowed (port 22)
- DNS resolution working

**Server Side:**
- Public IP or DDNS hostname
- SSH port accessible (default 22)
- Sufficient bandwidth for tunnels

## Understanding Reverse SSH Tunnels

### Basic Concept

**Standard SSH Connection:**
```bash
# Admin connects TO router (requires public IP)
ssh root@router_public_ip
```

**Reverse SSH Tunnel:**
```bash
# Router connects TO server (router initiates)
# Server can then connect back to router
ssh -R 1234:localhost:22 user@public_server
```

### Port Mapping Explained

**Command:** `ssh -R 1234:localhost:22 user@server`

**Breakdown:**
- `-R`: Reverse tunnel (remote port forwarding)
- `1234`: Port on remote server
- `localhost:22`: Local service to tunnel (SSH on router)
- `user@server`: Server credentials

**Result:**
```
Server Port 1234 → Router Port 22

Access from server:
ssh -p 1234 root@localhost
(connects to router's SSH)
```

### Tunnel Parameters

**Common SSH Options:**
```bash
-f  # Background mode (fork)
-N  # No command execution (tunnel only)
-T  # No pseudo-terminal allocation
-R  # Reverse tunnel
-L  # Local tunnel
-D  # Dynamic tunnel (SOCKS proxy)
-i  # Identity file (private key)
-o  # Set options
```

## Basic Setup

### Step 1: Test Basic Connection

**From OpenWRT Router:**
```bash
# Test connection to server
ssh user@your_server.com

# Enter password when prompted
# Type 'exit' to disconnect
```

**Verify:**
- Connection succeeds
- Password authentication works
- No firewall blocking

### Step 2: Create Basic Reverse Tunnel

**From OpenWRT Router:**
```bash
# Create reverse tunnel
# Port 1234 on server → Port 22 on router
ssh -R 1234:localhost:22 user@your_server.com

# Keep this terminal open!
```

**From Server:**
```bash
# Connect to router through tunnel
ssh -p 1234 root@localhost

# You're now connected to the router!
```

### Step 3: Background Tunnel

**From OpenWRT Router:**
```bash
# Create tunnel in background
ssh -f -N -T -R 1234:localhost:22 user@your_server.com

# -f: Fork to background
# -N: No command execution
# -T: No terminal
```

**Verify Tunnel:**
```bash
# Check if tunnel is running
ps | grep ssh

# Expected output:
# 1234 root     ssh -f -N -T -R 1234:localhost:22 user@server
```

### Step 4: Manual Testing

**Complete Test Procedure:**
```bash
# On OpenWRT:
# 1. Create tunnel
ssh -f -N -T -R 1234:localhost:22 user@your_server.com
# (enter password)

# 2. Check process
ps | grep ssh

# On Server:
# 3. Connect through tunnel
ssh -p 1234 root@localhost

# 4. Verify you're on router
uname -a
# Should show OpenWRT info

# 5. Exit
exit

# On OpenWRT:
# 6. Kill tunnel when done
killall ssh
```

## Key-Based Authentication

### Why Use SSH Keys?

**Advantages:**
- No password prompts
- More secure than passwords
- Enables automation
- Supports restrictions

**Dropbear vs OpenSSH:**
- OpenWRT uses Dropbear (lightweight)
- Different key format than OpenSSH
- Compatible but requires conversion

### Generate SSH Keys on OpenWRT

#### Using Dropbear

**Step 1: Generate Private Key**
```bash
# Create directory for keys
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Generate RSA key
dropbearkey -t rsa -f /root/.ssh/id_rsa -s 2048

# Output shows public key:
# Public key portion is:
# ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... root@OpenWrt
```

**Step 2: Extract Public Key**
```bash
# Extract public key to file
dropbearkey -y -f /root/.ssh/id_rsa | grep "^ssh-" > /root/.ssh/id_rsa.pub

# View public key
cat /root/.ssh/id_rsa.pub
```

**Step 3: Copy to Server**
```bash
# Display public key
cat /root/.ssh/id_rsa.pub

# Copy the output (ssh-rsa AAA...)
# On server, add to authorized_keys:
# (Do this step on the server)
```

#### Using OpenSSH Client (if installed)

```bash
# Install openssh-client
opkg install openssh-client openssh-keygen

# Generate key
ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N ""

# Copy to server
ssh-copy-id user@your_server.com
```

### Configure Server for Key Authentication

**On Remote Server:**

**Step 1: Create SSH Directory**
```bash
# Login to server
ssh user@your_server.com

# Create .ssh directory
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

**Step 2: Add Public Key**
```bash
# Create/edit authorized_keys file
nano ~/.ssh/authorized_keys

# Paste the public key from router
# (the long ssh-rsa AAA... string)

# Save and exit (Ctrl+O, Ctrl+X in nano)

# Set permissions
chmod 600 ~/.ssh/authorized_keys
```

**Step 3: Test Key Authentication**
```bash
# From OpenWRT, test connection
ssh -i /root/.ssh/id_rsa user@your_server.com

# Should connect without password!
```

### Passwordless Reverse Tunnel

**Create Tunnel with Key:**
```bash
# From OpenWRT router
ssh -f -N -T -R 1234:localhost:22 -i /root/.ssh/id_rsa user@your_server.com

# No password prompt!
# Tunnel runs in background
```

**Verify:**
```bash
# Check process
ps | grep ssh

# From server
ssh -p 1234 root@localhost
```

## Automation and Persistence

### Create Tunnel Script

**Script: `/root/tunnel.sh`**
```bash
#!/bin/sh
# Reverse SSH Tunnel Maintenance Script

# Configuration
REMOTE_USER="user"
REMOTE_HOST="your_server.com"
REMOTE_PORT="1234"
LOCAL_PORT="22"
SSH_KEY="/root/.ssh/id_rsa"
TUNNEL_NAME="reverse_tunnel"

# Check if tunnel is already running
TUNNEL_PID=$(ps | grep "ssh.*-R.*${REMOTE_PORT}" | grep -v grep | awk '{print $1}')

if [ -n "$TUNNEL_PID" ]; then
    echo "Tunnel already running (PID: $TUNNEL_PID)"
    exit 0
fi

# Start tunnel
echo "Starting reverse SSH tunnel..."
ssh -f -N -T \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    -o ExitOnForwardFailure=yes \
    -o StrictHostKeyChecking=no \
    -R ${REMOTE_PORT}:localhost:${LOCAL_PORT} \
    -i ${SSH_KEY} \
    ${REMOTE_USER}@${REMOTE_HOST}

# Check if successful
sleep 2
TUNNEL_PID=$(ps | grep "ssh.*-R.*${REMOTE_PORT}" | grep -v grep | awk '{print $1}')

if [ -n "$TUNNEL_PID" ]; then
    echo "Tunnel started successfully (PID: $TUNNEL_PID)"
    logger -t ${TUNNEL_NAME} "Tunnel started successfully"
else
    echo "Failed to start tunnel"
    logger -t ${TUNNEL_NAME} "Failed to start tunnel"
    exit 1
fi
```

**Make Executable:**
```bash
chmod +x /root/tunnel.sh
```

**Test Script:**
```bash
# Run manually
/root/tunnel.sh

# Check output
# Should say "Tunnel started successfully"

# Verify
ps | grep ssh
```

### Automate with Cron

**Add Cron Job:**
```bash
# Edit crontab
crontab -e

# Add line to check every 5 minutes
*/5 * * * * /root/tunnel.sh > /dev/null 2>&1

# Save and exit
```

**Alternative: Direct Cron Edit**
```bash
# Edit cron file directly
cat >> /etc/crontabs/root <<EOF
# Check reverse SSH tunnel every 5 minutes
*/5 * * * * /root/tunnel.sh > /dev/null 2>&1
EOF

# Restart cron
/etc/init.d/cron restart
```

**Verify Cron:**
```bash
# List cron jobs
crontab -l

# Check cron status
/etc/init.d/cron status

# View cron logs
logread | grep cron
```

### Start on Boot

**Method 1: Local Startup Script**
```bash
# Create startup script
cat > /etc/rc.local <<'EOF'
#!/bin/sh
# Start reverse SSH tunnel on boot
sleep 30  # Wait for network
/root/tunnel.sh &
exit 0
EOF

# Make executable
chmod +x /etc/rc.local
```

**Method 2: Init Script**
```bash
# Create init script
cat > /etc/init.d/sshtunnel <<'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10

start() {
    echo "Starting SSH tunnel..."
    /root/tunnel.sh
}

stop() {
    echo "Stopping SSH tunnel..."
    killall ssh
}

restart() {
    stop
    sleep 2
    start
}
EOF

# Make executable
chmod +x /etc/init.d/sshtunnel

# Enable on boot
/etc/init.d/sshtunnel enable

# Start now
/etc/init.d/sshtunnel start
```

**Test Boot Startup:**
```bash
# Reboot router
reboot

# After reboot, check
ps | grep ssh

# Should see tunnel running
```

### Enhanced Monitoring Script

```bash
#!/bin/sh
# Advanced tunnel monitoring with logging

REMOTE_USER="user"
REMOTE_HOST="your_server.com"
REMOTE_PORT="1234"
LOCAL_PORT="22"
SSH_KEY="/root/.ssh/id_rsa"
LOG_FILE="/var/log/tunnel.log"
MAX_LOG_SIZE=102400  # 100KB

# Rotate log if too large
if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
fi

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    logger -t sshtunnel "$1"
}

# Check network connectivity
ping -c 1 -W 5 "$REMOTE_HOST" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    log_message "Cannot reach remote host: $REMOTE_HOST"
    exit 1
fi

# Check if tunnel is running
TUNNEL_PID=$(ps | grep "ssh.*-R.*${REMOTE_PORT}" | grep -v grep | awk '{print $1}')

if [ -n "$TUNNEL_PID" ]; then
    # Tunnel exists, verify it's working
    # Try to connect through tunnel (from server side check)
    log_message "Tunnel already running (PID: $TUNNEL_PID)"
else
    # Start tunnel
    log_message "Starting reverse SSH tunnel to ${REMOTE_HOST}:${REMOTE_PORT}"

    ssh -f -N -T \
        -o ServerAliveInterval=60 \
        -o ServerAliveCountMax=3 \
        -o ExitOnForwardFailure=yes \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=30 \
        -R ${REMOTE_PORT}:localhost:${LOCAL_PORT} \
        -i ${SSH_KEY} \
        ${REMOTE_USER}@${REMOTE_HOST}

    sleep 3

    TUNNEL_PID=$(ps | grep "ssh.*-R.*${REMOTE_PORT}" | grep -v grep | awk '{print $1}')

    if [ -n "$TUNNEL_PID" ]; then
        log_message "Tunnel started successfully (PID: $TUNNEL_PID)"
    else
        log_message "ERROR: Failed to start tunnel"
    fi
fi
```

## Using sshtunnel Package

The `sshtunnel` package provides a managed way to configure SSH tunnels through UCI.

### Installation

```bash
# Update package list
opkg update

# Install sshtunnel
opkg install sshtunnel

# Check installed
opkg list-installed | grep sshtunnel
```

### UCI Configuration

**Basic Reverse Tunnel:**
```bash
# Create tunnel configuration
uci set sshtunnel.@tunnel[0]=tunnel
uci set sshtunnel.@tunnel[0].server='your_server.com'
uci set sshtunnel.@tunnel[0].port='22'
uci set sshtunnel.@tunnel[0].user='username'
uci set sshtunnel.@tunnel[0].IdentityFile='/root/.ssh/id_rsa'
uci set sshtunnel.@tunnel[0].remoteforward='1234:localhost:22'
uci set sshtunnel.@tunnel[0].ServerAliveInterval='60'
uci set sshtunnel.@tunnel[0].ServerAliveCountMax='3'
uci set sshtunnel.@tunnel[0].StrictHostKeyChecking='no'

# Commit configuration
uci commit sshtunnel
```

**View Configuration:**
```bash
# Show all settings
uci show sshtunnel

# Example output:
# sshtunnel.@tunnel[0]=tunnel
# sshtunnel.@tunnel[0].server='your_server.com'
# sshtunnel.@tunnel[0].port='22'
# sshtunnel.@tunnel[0].user='username'
# ...
```

**Edit Configuration File:**
```bash
# Direct file edit
vi /etc/config/sshtunnel
```

Example `/etc/config/sshtunnel`:
```
config tunnel
	option server 'your_server.com'
	option port '22'
	option user 'username'
	option IdentityFile '/root/.ssh/id_rsa'
	option remoteforward '1234:localhost:22'
	option ServerAliveInterval '60'
	option ServerAliveCountMax '3'
	option StrictHostKeyChecking 'no'
	option CheckHostIP 'no'
	option Compression 'yes'
```

### Manage sshtunnel Service

```bash
# Start tunnel
/etc/init.d/sshtunnel start

# Stop tunnel
/etc/init.d/sshtunnel stop

# Restart tunnel
/etc/init.d/sshtunnel restart

# Check status
/etc/init.d/sshtunnel status

# Enable on boot
/etc/init.d/sshtunnel enable

# Disable on boot
/etc/init.d/sshtunnel disable
```

### Multiple Tunnels

```bash
# Add second tunnel
uci add sshtunnel tunnel
uci set sshtunnel.@tunnel[1].server='second_server.com'
uci set sshtunnel.@tunnel[1].port='22'
uci set sshtunnel.@tunnel[1].user='user2'
uci set sshtunnel.@tunnel[1].IdentityFile='/root/.ssh/id_rsa2'
uci set sshtunnel.@tunnel[1].remoteforward='5678:localhost:80'

# Commit
uci commit sshtunnel

# Restart to apply
/etc/init.d/sshtunnel restart
```

### Advanced sshtunnel Options

```bash
# Local port forwarding
uci set sshtunnel.@tunnel[0].localforward='8080:remote_host:80'

# Dynamic forwarding (SOCKS proxy)
uci set sshtunnel.@tunnel[0].dynamicforward='1080'

# Compression
uci set sshtunnel.@tunnel[0].Compression='yes'

# Keep alive settings
uci set sshtunnel.@tunnel[0].ServerAliveInterval='30'
uci set sshtunnel.@tunnel[0].ServerAliveCountMax='5'

# Connection timeout
uci set sshtunnel.@tunnel[0].ConnectTimeout='30'

# Exit on forward failure
uci set sshtunnel.@tunnel[0].ExitOnForwardFailure='yes'

# Commit all changes
uci commit sshtunnel
/etc/init.d/sshtunnel restart
```

## Advanced Tunneling

### Multiple Services Through One Tunnel

**Forward Multiple Ports:**
```bash
# HTTP (80), HTTPS (443), SSH (22)
ssh -f -N -T \
    -R 1234:localhost:22 \
    -R 8080:localhost:80 \
    -R 8443:localhost:443 \
    -i /root/.ssh/id_rsa \
    user@your_server.com

# Access from server:
# SSH: ssh -p 1234 root@localhost
# HTTP: curl http://localhost:8080
# HTTPS: curl https://localhost:8443
```

**UCI Configuration:**
```bash
uci set sshtunnel.@tunnel[0].remoteforward='1234:localhost:22 8080:localhost:80 8443:localhost:443'
uci commit sshtunnel
```

### Tunneling to Other Devices

**Access Device on Router's Network:**
```bash
# Forward port to device at 192.168.1.100
ssh -f -N -T \
    -R 5900:192.168.1.100:5900 \
    -i /root/.ssh/id_rsa \
    user@your_server.com

# From server, access device:
# VNC to router's client
vncviewer localhost:5900
```

### Dynamic SOCKS Proxy

**Create SOCKS Proxy:**
```bash
# Create SOCKS proxy on server port 1080
ssh -f -N -T \
    -D 1080 \
    -i /root/.ssh/id_rsa \
    user@your_server.com

# Configure browser to use SOCKS proxy:
# Host: localhost
# Port: 1080
# Type: SOCKS5
```

### VPN-Like Tunnel

**Forward All Traffic:**
```bash
# Create TUN/TAP tunnel (requires root on both sides)
# Install packages
opkg install kmod-tun

# Create VPN tunnel
ssh -f -N -T \
    -w 0:0 \
    -o Tunnel=ethernet \
    -i /root/.ssh/id_rsa \
    user@your_server.com

# Configure interfaces (on both sides)
# Router:
ip addr add 10.0.0.1/30 dev tun0
ip link set tun0 up

# Server:
ip addr add 10.0.0.2/30 dev tun0
ip link set tun0 up
```

### Chained Tunnels

**Router → Server1 → Server2:**
```bash
# First tunnel: Router to Server1
ssh -f -N -T -R 1234:localhost:22 user@server1.com

# From Server1 to Server2
ssh -f -N -T -L 5678:localhost:1234 user@server2.com

# Access router from Server2
ssh -p 5678 root@localhost
```

## Port Forwarding Types

### Local Port Forwarding (-L)

**Concept:**
Access remote service through local port

**Syntax:**
```bash
ssh -L [local_port]:[destination]:[destination_port] user@server
```

**Example: Access Remote Web Server**
```bash
# Forward local port 8080 to web server
ssh -f -N -T -L 8080:internal_server:80 user@gateway.com

# Access in browser: http://localhost:8080
```

**Use Cases:**
- Access internal services
- Bypass firewall restrictions
- Secure database connections
- Encrypted web browsing

### Remote Port Forwarding (-R)

**Concept:**
Expose local service through remote port

**Syntax:**
```bash
ssh -R [remote_port]:[destination]:[destination_port] user@server
```

**Example: Expose Router SSH**
```bash
# Expose router SSH on server port 1234
ssh -f -N -T -R 1234:localhost:22 user@server.com

# From server: ssh -p 1234 root@localhost
```

**Use Cases:**
- Access behind NAT/firewall
- Share local services
- Remote management
- Demo/testing

### Dynamic Port Forwarding (-D)

**Concept:**
Create SOCKS proxy for dynamic routing

**Syntax:**
```bash
ssh -D [local_port] user@server
```

**Example: SOCKS Proxy**
```bash
# Create SOCKS5 proxy on port 1080
ssh -f -N -T -D 1080 user@server.com

# Configure application:
# SOCKS Host: localhost
# SOCKS Port: 1080
```

**Use Cases:**
- Secure browsing
- Bypass geo-restrictions
- Dynamic routing
- Testing from different IPs

### Comparison Table

| Type | Direction | Use Case | Command |
|------|-----------|----------|---------|
| Local (-L) | Remote→Local | Access remote service | `ssh -L 8080:target:80 user@server` |
| Remote (-R) | Local→Remote | Expose local service | `ssh -R 1234:localhost:22 user@server` |
| Dynamic (-D) | Any | SOCKS proxy | `ssh -D 1080 user@server` |

## Security Considerations

### GatewayPorts Configuration

**Problem:** By default, remote forwarded ports only listen on localhost

**Server Configuration:**
```bash
# Edit SSH server config
sudo nano /etc/ssh/sshd_config

# Add or modify:
GatewayPorts yes
# Or for more control:
GatewayPorts clientspecified

# Restart SSH
sudo systemctl restart sshd
```

**Options:**
- `no`: Only localhost (default, most secure)
- `yes`: All interfaces (less secure)
- `clientspecified`: Client chooses (flexible)

**Security Impact:**
```bash
# GatewayPorts no (default):
# Only accessible from server itself
ssh -p 1234 root@localhost

# GatewayPorts yes:
# Accessible from anywhere
ssh -p 1234 root@server_public_ip
```

### SSH Key Security

**Protect Private Keys:**
```bash
# Proper permissions
chmod 700 /root/.ssh
chmod 600 /root/.ssh/id_rsa
chmod 644 /root/.ssh/id_rsa.pub

# Check permissions
ls -la /root/.ssh
```

**Use Passphrase (Optional):**
```bash
# Generate key with passphrase
dropbearkey -t rsa -f /root/.ssh/id_rsa_protected

# Note: Requires entering passphrase (limits automation)
```

**Restrict Key Usage:**
On server in `~/.ssh/authorized_keys`:
```bash
# Restrict to specific command
command="/usr/bin/echo 'Access denied'" ssh-rsa AAA...

# Restrict to specific IP
from="203.0.113.1" ssh-rsa AAA...

# Allow only port forwarding
no-pty,no-X11-forwarding,command="/bin/false" ssh-rsa AAA...
```

### Firewall Configuration

**On OpenWRT:**
```bash
# Allow outbound SSH (usually allowed by default)
# No special config needed for outbound

# If using custom firewall rules:
uci add firewall rule
uci set firewall.@rule[-1].name='Allow_SSH_Out'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='22'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart
```

**On Server:**
```bash
# Ubuntu/Debian with UFW
sudo ufw allow ssh
sudo ufw enable

# Or specific port
sudo ufw allow 22/tcp

# Check status
sudo ufw status
```

### Limit Tunnel Exposure

**Bind to Localhost Only:**
```bash
# On server, edit sshd_config
GatewayPorts no

# Tunnel only accessible from server itself
# More secure for most use cases
```

**Use Jump Host:**
```bash
# Instead of exposing tunnel port, use as jump host
ssh -J user@server.com root@tunneled_device

# ProxyJump configuration
# ~/.ssh/config on client:
Host router
    HostName localhost
    Port 1234
    ProxyJump user@server.com
```

### Monitor Tunnel Activity

```bash
# On server, monitor connections
sudo netstat -tnlp | grep :1234

# Check who's connected
sudo ss -tnp | grep :1234

# Log all SSH connections
# In /etc/ssh/sshd_config:
LogLevel VERBOSE

# View logs
sudo tail -f /var/log/auth.log
```

### Regular Security Audits

```bash
# Check for unauthorized keys
cat ~/.ssh/authorized_keys

# Check active SSH sessions
who
w

# Check SSH logs for anomalies
grep sshd /var/log/auth.log | grep -i failed

# Audit tunnel processes
ps aux | grep ssh
```

## Troubleshooting

### Common Issues

#### Issue 1: Connection Refused

**Symptoms:**
```
ssh: connect to host server.com port 22: Connection refused
```

**Diagnosis:**
```bash
# Test connectivity
ping server.com

# Test SSH port
nc -zv server.com 22

# Check DNS
nslookup server.com
```

**Solutions:**
```bash
# Verify server SSH is running
# (on server)
sudo systemctl status sshd

# Check firewall
sudo ufw status

# Try different port
ssh -p 2222 user@server.com
```

#### Issue 2: Permission Denied (publickey)

**Symptoms:**
```
Permission denied (publickey).
```

**Diagnosis:**
```bash
# Check key file exists
ls -la /root/.ssh/id_rsa

# Verify key permissions
stat /root/.ssh/id_rsa

# Test with verbose output
ssh -vvv -i /root/.ssh/id_rsa user@server.com
```

**Solutions:**
```bash
# Fix permissions
chmod 600 /root/.ssh/id_rsa

# Re-copy public key to server
cat /root/.ssh/id_rsa.pub
# Paste to server's ~/.ssh/authorized_keys

# Check server permissions
# (on server)
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

#### Issue 3: Tunnel Drops Frequently

**Symptoms:**
- Tunnel disconnects after idle time
- Need to restart frequently

**Solutions:**
```bash
# Add keep-alive settings
ssh -f -N -T \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    -R 1234:localhost:22 \
    -i /root/.ssh/id_rsa \
    user@server.com

# Server-side keep-alive
# In /etc/ssh/sshd_config:
ClientAliveInterval 60
ClientAliveCountMax 3
```

#### Issue 4: Port Already in Use

**Symptoms:**
```
bind: Address already in use
```

**Diagnosis:**
```bash
# On server, check port usage
sudo netstat -tnlp | grep :1234
sudo ss -tnlp | grep :1234

# Find process
sudo lsof -i :1234
```

**Solutions:**
```bash
# Kill existing tunnel
killall ssh

# Or specific PID
kill 1234

# Use different port
ssh -R 5678:localhost:22 user@server.com
```

#### Issue 5: Script Not Running

**Symptoms:**
- Cron job doesn't execute
- Tunnel not starting on boot

**Diagnosis:**
```bash
# Check cron status
/etc/init.d/cron status

# View cron logs
logread | grep cron

# Test script manually
/root/tunnel.sh
```

**Solutions:**
```bash
# Fix script permissions
chmod +x /root/tunnel.sh

# Check for errors
sh -x /root/tunnel.sh

# Verify cron syntax
crontab -l

# Enable cron
/etc/init.d/cron enable
/etc/init.d/cron start
```

### Debugging Commands

```bash
# Verbose SSH connection
ssh -vvv -i /root/.ssh/id_rsa user@server.com

# Check routing
ip route get server.com

# DNS lookup
nslookup server.com

# Test port connectivity
nc -zv server.com 22

# Monitor tunnel in real-time
watch -n 5 'ps | grep ssh'

# Check system logs
logread -f | grep ssh

# Network statistics
netstat -s | grep -i error
```

### Complete Diagnostic Script

```bash
#!/bin/sh
# SSH Tunnel Diagnostic Tool

echo "=== SSH Tunnel Diagnostics ==="
echo ""

echo "1. Network Connectivity"
ping -c 3 server.com

echo ""
echo "2. DNS Resolution"
nslookup server.com

echo ""
echo "3. SSH Port Test"
nc -zv server.com 22

echo ""
echo "4. Key Files"
ls -la /root/.ssh/

echo ""
echo "5. Running Tunnels"
ps | grep ssh

echo ""
echo "6. Listening Ports"
netstat -tnl

echo ""
echo "7. Recent Logs"
logread | grep -i ssh | tail -20

echo ""
echo "8. Cron Jobs"
crontab -l

echo ""
echo "9. System Time"
date

echo ""
echo "=== End Diagnostics ==="
```

## Performance Optimization

### Compression

```bash
# Enable compression for slow links
ssh -C -R 1234:localhost:22 user@server.com

# Or in UCI
uci set sshtunnel.@tunnel[0].Compression='yes'
```

### Cipher Selection

```bash
# Use faster cipher (less secure but faster)
ssh -c aes128-ctr -R 1234:localhost:22 user@server.com

# Or strongest available
ssh -c aes256-gcm@openssh.com -R 1234:localhost:22 user@server.com

# List available ciphers
ssh -Q cipher
```

### Connection Multiplexing

**On client, create `~/.ssh/config`:**
```bash
cat > /root/.ssh/config <<EOF
Host myserver
    HostName server.com
    User username
    IdentityFile /root/.ssh/id_rsa
    ControlMaster auto
    ControlPath /tmp/ssh-%r@%h:%p
    ControlPersist 10m
EOF

chmod 600 /root/.ssh/config

# First connection creates master
ssh myserver

# Subsequent connections reuse
ssh myserver  # Much faster!
```

### Bandwidth Limiting

```bash
# Limit bandwidth (useful for QoS)
# Install tc (traffic control)
opkg install tc

# Limit SSH traffic
tc qdisc add dev eth0 root tbf rate 1mbit burst 32kbit latency 400ms
```

### Keep-Alive Tuning

```bash
# Aggressive keep-alive (for unstable connections)
ssh -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=5 \
    -R 1234:localhost:22 \
    user@server.com

# Conservative (for stable connections)
ssh -o ServerAliveInterval=120 \
    -o ServerAliveCountMax=2 \
    -R 1234:localhost:22 \
    user@server.com
```

## Real-World Examples

### Example 1: Home Router Access

**Scenario:** Access home router while traveling

```bash
# Setup (one-time)
# 1. Generate key on router
dropbearkey -t rsa -f /root/.ssh/id_rsa

# 2. Copy key to VPS
dropbearkey -y -f /root/.ssh/id_rsa | grep "^ssh-"
# Add to VPS ~/.ssh/authorized_keys

# 3. Create tunnel script
cat > /root/home_tunnel.sh <<'EOF'
#!/bin/sh
TUNNEL_PID=$(ps | grep "ssh.*-R.*1234" | grep -v grep | awk '{print $1}')
if [ -z "$TUNNEL_PID" ]; then
    ssh -f -N -T \
        -o ServerAliveInterval=60 \
        -o ServerAliveCountMax=3 \
        -R 1234:localhost:22 \
        -R 8080:localhost:80 \
        -i /root/.ssh/id_rsa \
        user@my-vps.com
fi
EOF

chmod +x /root/home_tunnel.sh

# 4. Add to cron
echo "*/5 * * * * /root/home_tunnel.sh" | crontab -

# Usage (from anywhere)
# SSH to VPS
ssh user@my-vps.com

# Access router
ssh -p 1234 root@localhost

# Access LuCI
ssh -L 8080:localhost:8080 user@my-vps.com
# Browser: http://localhost:8080
```

### Example 2: IP Camera Access

**Scenario:** View IP cameras remotely

```bash
# Camera at 192.168.1.50:80
ssh -f -N -T \
    -R 8050:192.168.1.50:80 \
    -i /root/.ssh/id_rsa \
    user@my-vps.com

# Access camera
# From VPS: http://localhost:8050
# Or forward to laptop:
ssh -L 8050:localhost:8050 user@my-vps.com
# Browser: http://localhost:8050
```

### Example 3: Remote Site Management

**Scenario:** Manage multiple remote locations

```bash
# Site A: Port 2001
# Site B: Port 2002
# Site C: Port 2003

# On each router
# Site A:
ssh -R 2001:localhost:22 -i /root/.ssh/id_rsa manager@central-vps.com

# Site B:
ssh -R 2002:localhost:22 -i /root/.ssh/id_rsa manager@central-vps.com

# Site C:
ssh -R 2003:localhost:22 -i /root/.ssh/id_rsa manager@central-vps.com

# From central VPS
ssh -p 2001 root@localhost  # Site A
ssh -p 2002 root@localhost  # Site B
ssh -p 2003 root@localhost  # Site C
```

### Example 4: Development/Testing

**Scenario:** Test web application on router

```bash
# Forward web server port
ssh -f -N -T \
    -R 3000:localhost:3000 \
    -i /root/.ssh/id_rsa \
    user@my-vps.com

# Test from anywhere
curl http://my-vps.com:3000

# Or with custom domain
# nginx on VPS:
# server {
#     server_name test.example.com;
#     location / {
#         proxy_pass http://localhost:3000;
#     }
# }
```

### Example 5: Secure Database Access

**Scenario:** Access database on router's network

```bash
# MySQL on 192.168.1.100:3306
ssh -f -N -T \
    -R 3306:192.168.1.100:3306 \
    -i /root/.ssh/id_rsa \
    user@my-vps.com

# Connect from laptop via VPS
ssh -L 3306:localhost:3306 user@my-vps.com

# Use database client
mysql -h localhost -P 3306 -u user -p
```

## Conclusion

SSH tunneling provides powerful remote access capabilities for OpenWRT devices behind NAT or firewalls. Reverse SSH tunnels enable secure management without public IP addresses.

**Key Takeaways:**

✅ **Setup:**
- Key-based authentication for automation
- Persistent tunnels with monitoring scripts
- Cron-based maintenance
- Boot-time initialization

🔧 **Methods:**
- Manual SSH commands for testing
- Custom scripts for flexibility
- sshtunnel package for UCI integration
- Multiple tunnel types for different needs

🔐 **Security:**
- Protect private keys (chmod 600)
- Use GatewayPorts cautiously
- Monitor tunnel activity
- Regular security audits
- Restrict key permissions on server

📊 **Best Practices:**
- Keep-alive settings for stability
- Compression for slow links
- Unique ports per tunnel
- Logging for troubleshooting
- Regular testing and monitoring

**When to Use:**
- Remote router management
- IoT device access
- Multi-site administration
- Development/testing
- Bypass NAT/firewall restrictions

**Alternatives:**
- VPN (WireGuard, OpenVPN) for full network access
- Dynamic DNS + port forwarding (requires router control)
- Cloud management platforms
- Tailscale/ZeroTier for mesh networks

For more information:
- OpenWRT SSH: https://openwrt.org/docs/guide-user/security/dropbear
- SSH Tunneling: https://www.ssh.com/academy/ssh/tunneling
- Dropbear: https://matt.ucc.asn.au/dropbear/dropbear.html

---

**Document Version:** 1.0
**Last Updated:** Based on eko.one.pl guide
**Tested on:** OpenWRT 22.03+
