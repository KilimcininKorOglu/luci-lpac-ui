# OpenWRT Port Knocking (knockd) Security Guide

## Table of Contents
1. [Overview](#overview)
2. [Port Knocking Concepts](#port-knocking-concepts)
3. [Security Considerations](#security-considerations)
4. [Installation](#installation)
5. [Basic Configuration](#basic-configuration)
6. [Advanced Configuration](#advanced-configuration)
7. [Firewall Integration](#firewall-integration)
8. [Client Usage](#client-usage)
9. [Testing and Debugging](#testing-and-debugging)
10. [Real-World Use Cases](#real-world-use-cases)
11. [Security Best Practices](#security-best-practices)
12. [Troubleshooting](#troubleshooting)
13. [Alternatives](#alternatives)

---

## Overview

Port knocking is a security technique that hides network services (like SSH) behind a "secret knock" - a specific sequence of connection attempts to closed ports. Only after the correct sequence is detected will the firewall open access to the protected service.

### What is Port Knocking?

**Traditional access:**
```
[Client] → [SSH Port 22 - OPEN] → [Server]
           ↑
        Visible to attackers
```

**With port knocking:**
```
[Client] → [Knock: 7000, 8000, 9000] → [Server]
           ↓
        [SSH Port 22 - TEMPORARILY OPEN for that IP]
           ↓
        [Client] → [SSH Connection] → [Server]
```

### How It Works

1. **Service is hidden**: SSH port appears closed to port scanners
2. **Client knocks**: Sends connection attempts to specific ports in order
3. **Server detects knock**: knockd daemon recognizes the sequence
4. **Firewall opens**: iptables rule added to allow access from that IP
5. **Client connects**: Can now access SSH (or other service)
6. **Access closes**: After timeout or closing knock sequence

### Benefits

- ✅ **Hides services** from port scanners
- ✅ **Reduces attack surface** (no visible SSH)
- ✅ **Additional security layer** (not replacement for strong auth)
- ✅ **Dynamic firewall rules** (per-IP access)
- ✅ **Logging capability** (track knock attempts)
- ✅ **Flexible actions** (can execute any script)

### Limitations

- ❌ **Not encryption** (packets still visible on network)
- ❌ **Replay attack vulnerable** (without additional measures)
- ❌ **Complexity** (additional step for users)
- ❌ **Not stealth** (packet analysis can reveal pattern)
- ❌ **Firewall dependency** (requires iptables)

---

## Port Knocking Concepts

### Knock Sequence

A knock sequence is an ordered list of ports:

```
Sequence: 7000 → 8000 → 9000
```

**Rules:**
- Must be in exact order
- Must complete within timeout (e.g., 15 seconds)
- Usually uses TCP SYN packets
- Ports should be closed (no service listening)

### Sequence Design

**Good sequence characteristics:**
- High port numbers (> 1024)
- Non-sequential (not 7000, 7001, 7002)
- Easy to remember but hard to guess
- Ports not used by other services

**Examples:**

```
Simple: 7000, 8000, 9000
Random: 3856, 7129, 2487
Memorable: 2468, 1357, 9753
```

### Actions

After detecting knock sequence, knockd can:
- Add firewall rule (allow access)
- Remove firewall rule (close access)
- Execute custom script
- Log event
- Send notification

### Timeout

**seq_timeout**: Maximum time to complete knock sequence
- Too short: Difficult for legitimate users
- Too long: Easier for attackers to guess

**Recommended:** 10-30 seconds

### TCP Flags

**tcpflags**: Which TCP packets to monitor
- `syn`: SYN packets (most common)
- `fin`: FIN packets
- `rst`: RST packets
- `ack`: ACK packets

**Recommended:** `syn` (connection initiation)

---

## Security Considerations

### What Port Knocking IS

✅ **Obscurity layer** - Makes service invisible to casual scanners
✅ **Additional barrier** - Extra step before accessing service
✅ **Dynamic firewall** - IP-specific access control

### What Port Knocking IS NOT

❌ **Not encryption** - SSH still needs strong encryption
❌ **Not authentication** - Still need strong passwords/keys
❌ **Not foolproof** - Can be defeated with packet analysis

### Threat Model

**Port knocking protects against:**
- Casual port scans
- Automated brute-force attacks
- Mass exploitation of known vulnerabilities
- Unauthorized access attempts

**Port knocking does NOT protect against:**
- Sophisticated attackers with packet capture
- Man-in-the-middle attacks
- Replay attacks (without additional measures)
- Compromise of knock sequence

### Best Practices

1. **Use with strong authentication** (SSH keys, not passwords)
2. **Change sequence regularly** (like changing passwords)
3. **Monitor logs** for suspicious knock attempts
4. **Use unpredictable sequences** (not sequential ports)
5. **Implement timeout** to limit exposure
6. **Don't rely solely on port knocking** for security

---

## Installation

### Prerequisites

```bash
# Update package list
opkg update

# Check available space
df -h
# knockd is small (~20KB)
```

### Install knockd

```bash
# Install knockd package
opkg install knockd

# Verify installation
which knockd
# Output: /usr/sbin/knockd

# Check version
knockd -V
```

### Check Installation

```bash
# List installed files
opkg files knockd

# Key files:
# /usr/sbin/knockd - Main daemon
# /etc/knockd.conf - Configuration file
# /etc/init.d/knockd - Init script
```

---

## Basic Configuration

### Default Configuration

Create or edit `/etc/knockd.conf`:

```conf
[options]
    # Log to syslog
    UseSyslog

    # Log file (if not using syslog)
    # logfile = /var/log/knockd.log

[openSSH]
    sequence    = 7000,8000,9000
    seq_timeout = 15
    command     = /usr/sbin/iptables -I INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
    tcpflags    = syn

[closeSSH]
    sequence    = 9000,8000,7000
    seq_timeout = 15
    command     = /usr/sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
    tcpflags    = syn
```

**Configuration explanation:**

**[options] section:**
- `UseSyslog`: Log to system log (logread)
- `logfile`: Alternative log file path

**[openSSH] section:**
- `sequence`: Ports to knock in order (7000 → 8000 → 9000)
- `seq_timeout`: Maximum 15 seconds to complete sequence
- `command`: Execute iptables to allow SSH from source IP
- `tcpflags`: Monitor SYN packets
- `%IP%`: Automatically replaced with source IP address

**[closeSSH] section:**
- Reverse sequence to close access
- Removes the iptables rule

### Protection for Other Services

**HTTP/HTTPS access:**

```conf
[openHTTP]
    sequence    = 5555,6666,7777
    seq_timeout = 20
    command     = /usr/sbin/iptables -I INPUT -s %IP% -p tcp --dport 80 -j ACCEPT
    tcpflags    = syn

[closeHTTP]
    sequence    = 7777,6666,5555
    seq_timeout = 20
    command     = /usr/sbin/iptables -D INPUT -s %IP% -p tcp --dport 80 -j ACCEPT
    tcpflags    = syn
```

**Custom application:**

```conf
[openApp]
    sequence    = 1234,2345,3456
    seq_timeout = 15
    command     = /usr/sbin/iptables -I INPUT -s %IP% -p tcp --dport 8080 -j ACCEPT
    tcpflags    = syn
```

### Start knockd

```bash
# Start manually (testing)
knockd -i eth1 -d

# Options:
# -i eth1 : Interface to monitor (WAN interface)
# -d : Run as daemon

# Check if running
ps | grep knockd
# Output: 12345 root      1234 S    knockd -i eth1 -d
```

**Identify WAN interface:**

```bash
# List network interfaces
ip addr

# Common WAN interfaces:
# eth1 - Ethernet WAN
# eth0.2 - VLAN WAN
# pppoe-wan - PPPoE connection
# wwan0 - Cellular modem
```

### Enable on Boot

```bash
# Enable knockd service
/etc/init.d/knockd enable

# Start service
/etc/init.d/knockd start

# Check status
/etc/init.d/knockd status

# View logs
logread | grep knockd
```

---

## Advanced Configuration

### Multiple Sequences

```conf
[openSSH]
    sequence    = 7000,8000,9000
    seq_timeout = 15
    command     = /usr/sbin/iptables -I INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
    tcpflags    = syn

[closeSSH]
    sequence    = 9000,8000,7000
    seq_timeout = 15
    command     = /usr/sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
    tcpflags    = syn

[openHTTPS]
    sequence    = 1111,2222,3333
    seq_timeout = 20
    command     = /usr/sbin/iptables -I INPUT -s %IP% -p tcp --dport 443 -j ACCEPT
    tcpflags    = syn

[closeHTTPS]
    sequence    = 3333,2222,1111
    seq_timeout = 20
    command     = /usr/sbin/iptables -D INPUT -s %IP% -p tcp --dport 443 -j ACCEPT
    tcpflags    = syn
```

### Timed Access

**Grant access for limited time:**

```conf
[openSSH_timed]
    sequence    = 7000,8000,9000
    seq_timeout = 15
    start_command = /usr/sbin/iptables -I INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
    tcpflags    = syn
    cmd_timeout = 3600  # Close after 1 hour (3600 seconds)
    stop_command = /usr/sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
```

### Custom Scripts

**Execute script on knock:**

```conf
[openSSH_script]
    sequence    = 7000,8000,9000
    seq_timeout = 15
    command     = /root/scripts/open-ssh.sh %IP%
    tcpflags    = syn
```

**Example script** `/root/scripts/open-ssh.sh`:

```bash
#!/bin/sh

IP=$1
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Add firewall rule
iptables -I INPUT -s $IP -p tcp --dport 22 -j ACCEPT

# Log event
echo "[$TIMESTAMP] SSH access granted to $IP" >> /var/log/knockd-access.log

# Send notification (if email configured)
# echo "SSH knock from $IP at $TIMESTAMP" | mail -s "Knock Alert" admin@example.com
```

Make executable:
```bash
chmod +x /root/scripts/open-ssh.sh
```

### UDP Knocking

**Use UDP instead of TCP:**

```conf
[openSSH_udp]
    sequence    = 7000:udp,8000:udp,9000:udp
    seq_timeout = 15
    command     = /usr/sbin/iptables -I INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
```

### One-Time Knock

**Grant access once, then close:**

```conf
[openSSH_once]
    sequence    = 7000,8000,9000
    seq_timeout = 15
    start_command = /usr/sbin/iptables -I INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
    tcpflags    = syn
    cmd_timeout = 60  # Close after 60 seconds
    stop_command = /usr/sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
```

---

## Firewall Integration

### Initial Firewall Setup

**Block SSH from WAN by default:**

```bash
# Ensure SSH is blocked from WAN
uci set firewall.@rule[-1].name='Block-SSH-WAN'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='22'
uci set firewall.@rule[-1].target='REJECT'
uci commit firewall
/etc/init.d/firewall restart
```

### Allow Knock Ports

**IMPORTANT:** Knock ports must be accessible from WAN

```bash
# Allow knock ports through firewall
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-Knock-Ports'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='7000 8000 9000'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart
```

**Or using iptables directly:**

```bash
# Add rules to allow knock ports
iptables -I INPUT -p tcp --dport 7000 -j ACCEPT
iptables -I INPUT -p tcp --dport 8000 -j ACCEPT
iptables -I INPUT -p tcp --dport 9000 -j ACCEPT

# Make persistent (add to /etc/firewall.user)
cat >> /etc/firewall.user << 'EOF'
iptables -I INPUT -p tcp --dport 7000 -j ACCEPT
iptables -I INPUT -p tcp --dport 8000 -j ACCEPT
iptables -I INPUT -p tcp --dport 9000 -j ACCEPT
EOF
```

### Verify Firewall Rules

```bash
# View current iptables rules
iptables -L INPUT -n -v

# Check for knock ports
iptables -L INPUT -n | grep -E "7000|8000|9000"

# Check for SSH rule
iptables -L INPUT -n | grep "22"
```

### Clean Up Stale Rules

**Problem:** Failed close knocks leave firewall rules

**Solution:** Periodic cleanup script

```bash
cat > /root/cleanup-knockd.sh << 'EOF'
#!/bin/sh

# Remove old SSH access rules (older than 24 hours)
# This requires storing timestamps, simplified version:

# List all rules allowing SSH
iptables -L INPUT -n | grep "tcp dpt:22" | awk '{print $5}' | while read IP; do
    # Check if IP has active SSH connection
    if ! netstat -an | grep -q "$IP:22.*ESTABLISHED"; then
        # No active connection, remove rule
        iptables -D INPUT -s $IP -p tcp --dport 22 -j ACCEPT 2>/dev/null
    fi
done
EOF

chmod +x /root/cleanup-knockd.sh

# Add to cron (run every hour)
echo "0 * * * * /root/cleanup-knockd.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

---

## Client Usage

### Using Telnet (Basic)

**Linux/macOS:**

```bash
# Execute knock sequence
telnet 192.168.1.1 7000
# Press Ctrl+] then type 'quit'

telnet 192.168.1.1 8000
# Press Ctrl+] then type 'quit'

telnet 192.168.1.1 9000
# Press Ctrl+] then type 'quit'

# Now SSH should work
ssh root@192.168.1.1
```

### Using Netcat (nc)

```bash
# Knock sequence with nc
nc -z 192.168.1.1 7000
nc -z 192.168.1.1 8000
nc -z 192.168.1.1 9000

# Connect SSH
ssh root@192.168.1.1
```

### Using Nmap

```bash
# Knock with nmap
for port in 7000 8000 9000; do
    nmap -Pn --host-timeout 100ms --max-retries 0 -p $port 192.168.1.1
done

# Connect SSH
ssh root@192.168.1.1
```

### Automated Knock Script

**Create knock client** `/usr/local/bin/knock`:

```bash
#!/bin/bash

HOST=$1
shift
PORTS="$@"

if [ -z "$HOST" ] || [ -z "$PORTS" ]; then
    echo "Usage: knock <host> <port1> <port2> <port3>"
    exit 1
fi

for PORT in $PORTS; do
    echo "Knocking on $HOST:$PORT"
    nc -z -w 1 $HOST $PORT 2>/dev/null
    sleep 0.5
done

echo "Knock sequence complete"
```

Make executable:
```bash
chmod +x /usr/local/bin/knock
```

**Usage:**
```bash
knock 192.168.1.1 7000 8000 9000
ssh root@192.168.1.1
```

### Windows Client

**Using PowerShell:**

```powershell
# Knock function
function Knock-Port {
    param($Host, $Port)
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $tcp.Connect($Host, $Port)
    } catch {}
    $tcp.Close()
}

# Execute knock
Knock-Port 192.168.1.1 7000
Start-Sleep -Milliseconds 500
Knock-Port 192.168.1.1 8000
Start-Sleep -Milliseconds 500
Knock-Port 192.168.1.1 9000

# Connect SSH (using PuTTY or ssh.exe)
ssh root@192.168.1.1
```

### Android/iOS

**Android:**
- Install "Port Knocking" app
- Configure sequence: 7000, 8000, 9000
- Knock, then use SSH client (e.g., JuiceSSH)

**iOS:**
- Install "Port Knock" app
- Configure and knock
- Use SSH client (e.g., Termius)

---

## Testing and Debugging

### Test Knock Sequence

**Method 1: Manual telnet**

```bash
# From client machine
telnet 192.168.1.1 7000
# Should connect briefly, then close
telnet 192.168.1.1 8000
telnet 192.168.1.1 9000

# Test SSH access
ssh root@192.168.1.1
# Should connect successfully
```

**Method 2: Automated test**

```bash
# Test knock and SSH
for port in 7000 8000 9000; do nc -z 192.168.1.1 $port; sleep 0.5; done && ssh -o ConnectTimeout=5 root@192.168.1.1
```

### Monitor knockd Logs

```bash
# View real-time logs
logread -f | grep knockd

# View all knockd logs
logread | grep knockd

# Example output:
# knockd[1234]: 192.168.1.100: openSSH: Stage 1
# knockd[1234]: 192.168.1.100: openSSH: Stage 2
# knockd[1234]: 192.168.1.100: openSSH: Stage 3
# knockd[1234]: 192.168.1.100: openSSH: OPEN SESAME
# knockd[1234]: running command: /usr/sbin/iptables -I INPUT -s 192.168.1.100 -p tcp --dport 22 -j ACCEPT
```

### Debug Mode

```bash
# Stop service
/etc/init.d/knockd stop

# Run in foreground with verbose output
knockd -i eth1 -v -D

# Options:
# -v : Verbose
# -D : Debug (don't fork, stay in foreground)
```

### Check Firewall Rules

```bash
# View INPUT chain
iptables -L INPUT -n -v

# Check for your IP after knocking
iptables -L INPUT -n | grep "192.168.1.100"

# Should show:
# ACCEPT tcp -- 192.168.1.100 0.0.0.0/0 tcp dpt:22
```

### Test from Different Source IP

```bash
# Knock from one machine
nc -z 192.168.1.1 7000 8000 9000

# Try SSH from same machine (should work)
ssh root@192.168.1.1

# Try SSH from different machine (should fail)
ssh root@192.168.1.1
```

### Packet Capture

**Monitor knock packets:**

```bash
# Capture on WAN interface
tcpdump -i eth1 'tcp and (port 7000 or port 8000 or port 9000)'

# Should show SYN packets in sequence
# 12:34:56.123456 IP 192.168.1.100.12345 > 192.168.1.1.7000: Flags [S]
# 12:34:56.678901 IP 192.168.1.100.12346 > 192.168.1.1.8000: Flags [S]
# 12:34:57.234567 IP 192.168.1.100.12347 > 192.168.1.1.9000: Flags [S]
```

---

## Real-World Use Cases

### Use Case 1: Remote Administration

**Scenario:** Secure remote SSH access to router

```conf
[openSSH]
    sequence    = 7000,8000,9000
    seq_timeout = 15
    start_command = /usr/sbin/iptables -I INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
    tcpflags    = syn
    cmd_timeout = 3600  # Close after 1 hour
    stop_command = /usr/sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -j ACCEPT

[closeSSH]
    sequence    = 9000,8000,7000
    seq_timeout = 15
    command     = /usr/sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
    tcpflags    = syn
```

**Workflow:**
1. Admin knocks from home/office
2. SSH access granted for 1 hour
3. Admin performs maintenance
4. Manual close knock or auto-close after timeout

### Use Case 2: VPN Access

**Scenario:** Hide OpenVPN port from scanners

```conf
[openVPN]
    sequence    = 1194,2194,3194
    seq_timeout = 20
    command     = /usr/sbin/iptables -I INPUT -s %IP% -p udp --dport 1194 -j ACCEPT
    tcpflags    = syn

[closeVPN]
    sequence    = 3194,2194,1194
    seq_timeout = 20
    command     = /usr/sbin/iptables -D INPUT -s %IP% -p udp --dport 1194 -j ACCEPT
    tcpflags    = syn
```

### Use Case 3: Web Admin Interface

**Scenario:** Protect LuCI web interface on WAN

```conf
[openLuCI]
    sequence    = 4444,5555,6666
    seq_timeout = 15
    start_command = /usr/sbin/iptables -I INPUT -s %IP% -p tcp --dport 80 -j ACCEPT
    tcpflags    = syn
    cmd_timeout = 600  # 10 minutes
    stop_command = /usr/sbin/iptables -D INPUT -s %IP% -p tcp --dport 80 -j ACCEPT
```

### Use Case 4: Multi-Service Access

**Scenario:** Grant access to multiple services with one knock

```conf
[openAll]
    sequence    = 1111,2222,3333,4444
    seq_timeout = 20
    command     = /root/scripts/open-all-services.sh %IP%
    tcpflags    = syn

[closeAll]
    sequence    = 4444,3333,2222,1111
    seq_timeout = 20
    command     = /root/scripts/close-all-services.sh %IP%
    tcpflags    = syn
```

**Script** `/root/scripts/open-all-services.sh`:

```bash
#!/bin/sh

IP=$1

# Open SSH
iptables -I INPUT -s $IP -p tcp --dport 22 -j ACCEPT

# Open HTTP/HTTPS
iptables -I INPUT -s $IP -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -s $IP -p tcp --dport 443 -j ACCEPT

# Open VPN
iptables -I INPUT -s $IP -p udp --dport 1194 -j ACCEPT

# Log
logger -t knockd "Full access granted to $IP"
```

---

## Security Best Practices

### 1. Use Strong Authentication

**Port knocking is NOT a replacement for:**
- Strong passwords
- SSH key authentication
- Two-factor authentication

**Always use SSH keys:**
```bash
# Generate key
ssh-keygen -t ed25519 -f ~/.ssh/openwrt_key

# Copy to router
ssh-copy-id -i ~/.ssh/openwrt_key.pub root@192.168.1.1

# Disable password auth
uci set dropbear.@dropbear[0].PasswordAuth='off'
uci set dropbear.@dropbear[0].RootPasswordAuth='off'
uci commit dropbear
/etc/init.d/dropbear restart
```

### 2. Change Sequences Regularly

**Rotate knock sequences monthly:**

```bash
# Update knockd.conf with new sequence
vi /etc/knockd.conf
# Change: sequence = 7000,8000,9000
# To: sequence = 3456,7891,2345

# Restart knockd
/etc/init.d/knockd restart

# Update client knock scripts
```

### 3. Monitor Logs

**Watch for suspicious activity:**

```bash
# Failed knock attempts
logread | grep knockd | grep -v "OPEN SESAME"

# Multiple attempts from same IP
logread | grep knockd | awk '{print $4}' | sort | uniq -c | sort -rn
```

**Alert on suspicious activity:**

```bash
# Create monitoring script
cat > /root/monitor-knockd.sh << 'EOF'
#!/bin/sh

LOG_FILE="/var/log/knockd-monitor.log"
THRESHOLD=5

# Count knock attempts per IP
logread | grep knockd | awk '{print $4}' | sort | uniq -c | while read COUNT IP; do
    if [ $COUNT -gt $THRESHOLD ]; then
        echo "[$(date)] WARNING: $IP made $COUNT knock attempts" >> $LOG_FILE
        # Optional: Block IP
        # iptables -I INPUT -s $IP -j DROP
    fi
done
EOF

chmod +x /root/monitor-knockd.sh

# Run hourly
echo "0 * * * * /root/monitor-knockd.sh" >> /etc/crontabs/root
```

### 4. Use Unpredictable Sequences

**Bad sequences:**
- Sequential: 7000, 7001, 7002
- Simple: 1111, 2222, 3333
- Well-known: 80, 443, 22

**Good sequences:**
- Random: 3856, 7129, 2487
- Memorable patterns: 1776, 2024, 3141
- Personal dates: MMDD, YYMM, etc. (but don't share!)

### 5. Limit Exposure Time

**Use cmd_timeout to auto-close:**

```conf
[openSSH]
    sequence    = 7000,8000,9000
    seq_timeout = 15
    start_command = /usr/sbin/iptables -I INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
    tcpflags    = syn
    cmd_timeout = 1800  # Close after 30 minutes
    stop_command = /usr/sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
```

### 6. Combine with Fail2Ban

**Install fail2ban for additional protection:**

```bash
opkg install fail2ban

# Configure fail2ban to monitor SSH
# Even if attacker guesses knock, fail2ban provides brute-force protection
```

### 7. Use VPN for Better Security

**Port knocking + VPN = strong security:**

1. Port knock to open VPN port
2. Connect to VPN
3. Access services through encrypted VPN tunnel

---

## Troubleshooting

### Knock Doesn't Work

**Check knockd is running:**
```bash
ps | grep knockd
/etc/init.d/knockd status
```

**Check interface:**
```bash
# Verify WAN interface name
ip addr

# Restart with correct interface
killall knockd
knockd -i eth1 -d
```

**Check firewall allows knock ports:**
```bash
iptables -L INPUT -n | grep -E "7000|8000|9000"

# If missing, add rules
iptables -I INPUT -p tcp --dport 7000 -j ACCEPT
iptables -I INPUT -p tcp --dport 8000 -j ACCEPT
iptables -I INPUT -p tcp --dport 9000 -j ACCEPT
```

### Sequence Times Out

**Issue:** Can't complete sequence in time

**Solutions:**
1. **Increase timeout:**
   ```conf
   seq_timeout = 30  # Increase to 30 seconds
   ```

2. **Reduce delay between knocks:**
   ```bash
   # Knock faster
   for port in 7000 8000 9000; do nc -z 192.168.1.1 $port; done
   ```

3. **Check network latency:**
   ```bash
   ping 192.168.1.1
   # High latency may cause timeout
   ```

### SSH Still Blocked After Knock

**Check firewall rules added:**
```bash
iptables -L INPUT -n | grep "22"
# Should show: ACCEPT tcp -- YOUR_IP 0.0.0.0/0 tcp dpt:22
```

**Check source IP:**
```bash
# Knock adds rule for source IP
# If behind NAT, public IP may differ

# Check what IP server sees
curl ifconfig.me

# Use that IP in knock test
```

**Test with explicit source IP:**
```bash
# Add rule manually
iptables -I INPUT -s YOUR_PUBLIC_IP -p tcp --dport 22 -j ACCEPT

# Test SSH
ssh root@192.168.1.1
```

### Logs Show Nothing

**Enable logging:**

```conf
# In /etc/knockd.conf
[options]
    UseSyslog
    LogFile = /var/log/knockd.log
```

**Create log file:**
```bash
touch /var/log/knockd.log
chmod 644 /var/log/knockd.log
```

**Restart knockd:**
```bash
/etc/init.d/knockd restart
```

### Rules Not Cleaned Up

**Problem:** Firewall rules accumulate

**Solution 1: Use cmd_timeout**
```conf
cmd_timeout = 3600  # Auto-remove after 1 hour
```

**Solution 2: Manual cleanup**
```bash
# Remove all SSH access rules
iptables -L INPUT -n --line-numbers | grep "tcp dpt:22" | awk '{print $1}' | tac | while read line; do
    iptables -D INPUT $line
done
```

**Solution 3: Periodic cleanup script** (see Advanced Configuration)

---

## Alternatives

### SSH Port Change

**Simple alternative:**
```bash
# Change SSH port to non-standard
uci set dropbear.@dropbear[0].Port='2222'
uci commit dropbear
/etc/init.d/dropbear restart
```

**Pros:** Simple, effective against casual scans
**Cons:** Port still visible, doesn't provide "stealth"

### VPN Only Access

**Most secure approach:**
1. Set up VPN (WireGuard/OpenVPN)
2. Allow only VPN traffic from WAN
3. Access all services through VPN

**Pros:** Encrypted, authenticated, flexible
**Cons:** More complex setup, VPN port still visible

### Single Packet Authorization (SPA)

**More secure than port knocking:**
- Uses cryptographic authentication
- Resistant to replay attacks
- Example: fwknop

```bash
opkg install fwknop
```

**Pros:** Cryptographically secure, single packet
**Cons:** More complex, requires SPA client

### Fail2Ban Only

**Protection through intrusion detection:**
```bash
opkg install fail2ban
```

**Pros:** Automatic blocking of brute-force
**Cons:** Service still visible, reactive not proactive

---

## Conclusion

Port knocking provides an additional security layer by hiding network services from casual attackers and automated scans.

### Summary

✅ **Installation:**
- Install knockd package
- Configure knock sequences
- Set up firewall rules
- Start knockd daemon

✅ **Configuration:**
- Define sequences (7000, 8000, 9000)
- Set appropriate timeouts (10-30 sec)
- Use meaningful actions (iptables rules)
- Monitor specified interface

✅ **Security:**
- NOT a replacement for strong authentication
- Combine with SSH keys
- Change sequences regularly
- Monitor logs for suspicious activity
- Use unpredictable sequences

✅ **Usage:**
- Knock from client (telnet/nc/script)
- Access opened temporarily
- Manual or automatic close

### Best Practices

1. **Layer security** - Use with strong auth (SSH keys)
2. **Rotate sequences** - Change monthly
3. **Limit exposure** - Use timeouts
4. **Monitor activity** - Watch logs
5. **Keep it secret** - Don't share sequences
6. **Consider alternatives** - VPN may be better for high security

### When to Use Port Knocking

**Good fit:**
- Home router remote access
- Small office SSH management
- Additional security layer
- Hide services from scanners

**Not recommended:**
- High-security requirements (use VPN)
- Multiple administrators (complex management)
- Frequent access needed (annoying)
- Public services (defeats purpose)

### Reality Check

Port knocking is **security through obscurity**. It provides:
- ✅ Protection against casual attackers
- ✅ Reduction in automated attacks
- ✅ Stealth from port scanners

It does NOT provide:
- ❌ Protection against sophisticated attackers
- ❌ Encryption or confidentiality
- ❌ Foolproof security

**Bottom line:** Use as one layer in defense-in-depth strategy, not as sole security measure.

---

*Document Version: 1.0*
*Last Updated: 2025*
*Based on: https://eko.one.pl/?p=openwrt-knockd*
*Compatible with: OpenWRT 19.07+*

**Security Notice:**
*Port knocking is security through obscurity. Always use strong authentication (SSH keys, strong passwords) in addition to port knocking. Consider VPN as a more secure alternative for remote access.*
