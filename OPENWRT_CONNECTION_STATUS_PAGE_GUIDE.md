# OpenWRT Connection Status Page Guide

## Table of Contents
1. [Overview](#overview)
2. [Purpose and Use Cases](#purpose-and-use-cases)
3. [Prerequisites](#prerequisites)
4. [Architecture Overview](#architecture-overview)
5. [Web Server Configuration](#web-server-configuration)
6. [Directory Structure Setup](#directory-structure-setup)
7. [Creating the Status Page](#creating-the-status-page)
8. [Creating the Status Script](#creating-the-status-script)
9. [Advanced Status Script Features](#advanced-status-script-features)
10. [Multiple Status Checks](#multiple-status-checks)
11. [Styling and Customization](#styling-and-customization)
12. [Security Considerations](#security-considerations)
13. [Troubleshooting](#troubleshooting)
14. [Alternative Implementations](#alternative-implementations)
15. [References](#references)

---

## Overview

This guide demonstrates how to create a simple connection status page for OpenWRT routers using BusyBox's built-in HTTP server. The status page displays real-time WAN connection status and IP address information, accessible via a web browser.

**Key Features:**
- Real-time connection status monitoring
- WAN IP address display
- Simple CGI-based implementation
- Minimal resource usage
- No dependencies beyond BusyBox
- Automatic refresh capability

**Implementation:**
- Custom web server on port 80
- CGI shell script for status checks
- HTML redirect page
- Ping-based connectivity testing

---

## Purpose and Use Cases

### Primary Use Cases

1. **Quick Status Check**
   - View WAN connection status at a glance
   - Check public IP address
   - Verify internet connectivity

2. **Captive Portal Alternative**
   - Simple landing page for guest networks
   - Connection verification for users
   - Public WiFi status display

3. **Monitoring Dashboard**
   - Basic router health check
   - Network diagnostics
   - Troubleshooting tool

4. **Kiosk/Public Display**
   - Display connection status on shared networks
   - Public WiFi information screen
   - Network status for offices

### Advantages

- **Lightweight:** Minimal resource usage
- **Simple:** Easy to implement and maintain
- **Fast:** Instant status updates
- **Customizable:** Easy to modify and extend
- **No Dependencies:** Uses built-in BusyBox tools

---

## Prerequisites

### Software Requirements

**Required packages:**
- OpenWRT with BusyBox (default installation)
- `httpd` (BusyBox HTTP server) or `uhttpd` (OpenWRT web server)

**Optional packages:**
```bash
# For enhanced styling
opkg install coreutils-base64

# For additional network tools
opkg install iputils-ping
opkg install curl
```

### Network Requirements

- Router accessible via LAN or WiFi
- WAN interface configured
- Internet connectivity for testing

### Storage Requirements

- Minimal: ~10KB for HTML and scripts
- Available in `/www` or custom directory

---

## Architecture Overview

### Component Structure

```
┌─────────────────────────────────────────┐
│         Web Browser                      │
│         http://192.168.1.1               │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│    BusyBox httpd (Port 80)               │
│    /www1/index.html                      │
└──────────────┬──────────────────────────┘
               │ Meta Refresh
               ▼
┌─────────────────────────────────────────┐
│    CGI Script                            │
│    /www1/cgi-bin/status.sh               │
│    - Ping test                           │
│    - IP detection                        │
│    - HTML generation                     │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│    HTML Output                           │
│    - Connection status                   │
│    - IP address                          │
│    - Styling                             │
└─────────────────────────────────────────┘
```

### Workflow

1. User accesses router IP in browser
2. HTTP server serves `/www1/index.html`
3. Meta refresh redirects to CGI script
4. Script performs connectivity test
5. Script generates HTML with status
6. Browser displays formatted status

---

## Web Server Configuration

### Option 1: Using httpd (BusyBox)

**Move LuCI to port 8080 and use port 80 for status page:**

```bash
# Configure first httpd instance for LuCI (port 8080)
uci set httpd.@httpd[0].port=8080

# Add second httpd instance for status page (port 80)
uci add httpd httpd
uci set httpd.@httpd[-1].port=80
uci set httpd.@httpd[-1].home=/www1

# Commit changes
uci commit httpd

# Restart HTTP server
/etc/init.d/httpd restart
```

**Note:** This configuration may vary depending on OpenWRT version. The `httpd` package uses BusyBox's lightweight HTTP server.

### Option 2: Using uhttpd (Recommended for Modern OpenWRT)

**Configure uhttpd for dual-port setup:**

```bash
# Create backup of current config
uci export uhttpd > /tmp/uhttpd_backup.uci

# Move LuCI to port 8080
uci set uhttpd.main.listen_http='0.0.0.0:8080'

# Create new uhttpd instance for status page
uci set uhttpd.status=uhttpd
uci set uhttpd.status.listen_http='0.0.0.0:80'
uci set uhttpd.status.home='/www1'
uci set uhttpd.status.cgi_prefix='/cgi-bin'
uci set uhttpd.status.script_timeout=60
uci set uhttpd.status.network_timeout=30

# Commit and restart
uci commit uhttpd
/etc/init.d/uhttpd restart
```

### Verify Configuration

```bash
# Check listening ports
netstat -tulpn | grep httpd
# or
netstat -tulpn | grep uhttpd

# Expected output:
# tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      1234/uhttpd
# tcp        0      0 0.0.0.0:8080            0.0.0.0:*               LISTEN      1234/uhttpd

# Test access
curl http://127.0.0.1:80
curl http://127.0.0.1:8080
```

### Firewall Configuration

Ensure firewall allows HTTP access:

```bash
# Allow HTTP from LAN
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-HTTP-LAN'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest_port='80'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'

uci commit firewall
/etc/init.d/firewall reload
```

---

## Directory Structure Setup

### Create Directory Structure

```bash
# Create main web directory
mkdir -p /www1

# Create CGI directory
mkdir -p /www1/cgi-bin

# Set permissions
chmod 755 /www1
chmod 755 /www1/cgi-bin
```

### Verify Structure

```bash
ls -la /www1/
# Expected:
# drwxr-xr-x    3 root     root          1024 Oct 15 14:00 .
# drwxr-xr-x    5 root     root          1024 Oct 15 14:00 ..
# drwxr-xr-x    2 root     root          1024 Oct 15 14:00 cgi-bin
```

---

## Creating the Status Page

### Basic HTML Redirect Page

**File: `/www1/index.html`**

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="0; URL=cgi-bin/status.sh" />
    <title>Connection Status</title>
</head>
<body>
    <p>Redirecting to status page...</p>
</body>
</html>
```

**Key elements:**
- `meta refresh`: Automatically redirects to CGI script
- `content="0; URL=..."`: Immediate redirect (0 seconds)
- Fallback message if JavaScript disabled

### Create the File

```bash
cat > /www1/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="0; URL=cgi-bin/status.sh" />
    <title>Connection Status</title>
</head>
<body>
    <p>Redirecting to status page...</p>
</body>
</html>
EOF

chmod 644 /www1/index.html
```

---

## Creating the Status Script

### Basic Status Script

**File: `/www1/cgi-bin/status.sh`**

```bash
#!/bin/sh

# Output HTTP header
echo "Content-type: text/html"
echo ""

# Start HTML
cat << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="5" />
    <title>Connection Status</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            margin-top: 50px;
            background-color: #f0f0f0;
        }
        .status {
            font-size: 48px;
            font-weight: bold;
            margin: 20px;
        }
        .connected {
            color: green;
        }
        .disconnected {
            color: red;
        }
        .info {
            font-size: 24px;
            margin: 10px;
        }
    </style>
</head>
<body>
EOF

# Get WAN interface name
WAN_IFACE=$(uci get network.wan.ifname)

# Test connectivity by pinging google.com
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    # Connected
    echo '<div class="status connected">Connected</div>'

    # Get WAN IP address
    WAN_IP=$(ifconfig $WAN_IFACE 2>/dev/null | awk '/inet addr/ {print $2}' | cut -d: -f2)

    # If no IP from ifconfig, try ip command
    if [ -z "$WAN_IP" ]; then
        WAN_IP=$(ip addr show $WAN_IFACE 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
    fi

    echo "<div class=\"info\">WAN IP: $WAN_IP</div>"
else
    # Disconnected
    echo '<div class="status disconnected">No Connection</div>'
fi

# Close HTML
cat << 'EOF'
</body>
</html>
EOF
```

### Create and Set Permissions

```bash
cat > /www1/cgi-bin/status.sh << 'SCRIPT'
#!/bin/sh

# Output HTTP header
echo "Content-type: text/html"
echo ""

# Start HTML
cat << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="5" />
    <title>Connection Status</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            margin-top: 50px;
            background-color: #f0f0f0;
        }
        .status {
            font-size: 48px;
            font-weight: bold;
            margin: 20px;
        }
        .connected {
            color: green;
        }
        .disconnected {
            color: red;
        }
        .info {
            font-size: 24px;
            margin: 10px;
        }
    </style>
</head>
<body>
EOF

# Get WAN interface name
WAN_IFACE=$(uci get network.wan.ifname)

# Test connectivity by pinging Google DNS
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    # Connected
    echo '<div class="status connected">Connected</div>'

    # Get WAN IP address
    WAN_IP=$(ip addr show $WAN_IFACE 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)

    echo "<div class=\"info\">WAN IP: $WAN_IP</div>"
else
    # Disconnected
    echo '<div class="status disconnected">No Connection</div>'
fi

# Close HTML
cat << 'EOF'
</body>
</html>
EOF
SCRIPT

# Make executable
chmod +x /www1/cgi-bin/status.sh
```

### Test the Script

```bash
# Test directly
/www1/cgi-bin/status.sh

# Should output HTML with HTTP header
```

---

## Advanced Status Script Features

### Enhanced Status Script with Multiple Checks

**File: `/www1/cgi-bin/status.sh` (enhanced version)**

```bash
#!/bin/sh

# Output HTTP header
echo "Content-type: text/html"
echo ""

# Get WAN interface information
WAN_IFACE=$(uci -q get network.wan.device)
[ -z "$WAN_IFACE" ] && WAN_IFACE=$(uci -q get network.wan.ifname)

# Get WAN protocol
WAN_PROTO=$(uci -q get network.wan.proto)

# Test connectivity
PING_TEST=0
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    PING_TEST=1
fi

# Get IP addresses
WAN_IP=$(ip addr show $WAN_IFACE 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
WAN_IP6=$(ip addr show $WAN_IFACE 2>/dev/null | awk '/inet6.*global/ {print $2}' | cut -d/ -f1 | head -1)

# Get public IP (if connected)
if [ $PING_TEST -eq 1 ]; then
    PUBLIC_IP=$(wget -qO- http://ipinfo.io/ip 2>/dev/null || curl -s http://ipinfo.io/ip 2>/dev/null || echo "N/A")
else
    PUBLIC_IP="N/A"
fi

# Get DNS servers
DNS_SERVERS=$(uci -q get network.wan.dns)
[ -z "$DNS_SERVERS" ] && DNS_SERVERS=$(cat /tmp/resolv.conf.auto 2>/dev/null | grep nameserver | awk '{print $2}' | tr '\n' ' ')

# Get gateway
GATEWAY=$(ip route | awk '/default/ {print $3; exit}')

# Get uptime
UPTIME=$(uptime | awk '{print $3 $4}' | sed 's/,//')

# Generate HTML
cat << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="10" />
    <title>Router Connection Status</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            margin: 0;
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            padding: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
        }
        h1 {
            text-align: center;
            color: #333;
            margin-bottom: 30px;
        }
        .status-box {
            text-align: center;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 30px;
        }
        .status-connected {
            background-color: #d4edda;
            border: 2px solid #28a745;
        }
        .status-disconnected {
            background-color: #f8d7da;
            border: 2px solid #dc3545;
        }
        .status-text {
            font-size: 36px;
            font-weight: bold;
            margin: 0;
        }
        .status-connected .status-text {
            color: #28a745;
        }
        .status-disconnected .status-text {
            color: #dc3545;
        }
        .info-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 15px;
        }
        .info-item {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            border-left: 4px solid #667eea;
        }
        .info-label {
            font-weight: bold;
            color: #555;
            font-size: 14px;
            margin-bottom: 5px;
        }
        .info-value {
            color: #333;
            font-size: 16px;
            word-break: break-all;
        }
        .footer {
            text-align: center;
            margin-top: 20px;
            color: #666;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Router Connection Status</h1>
EOF

# Status box
if [ $PING_TEST -eq 1 ]; then
    cat << EOF
        <div class="status-box status-connected">
            <p class="status-text">✓ Connected</p>
        </div>
EOF
else
    cat << EOF
        <div class="status-box status-disconnected">
            <p class="status-text">✗ No Connection</p>
        </div>
EOF
fi

# Information grid
cat << EOF
        <div class="info-grid">
            <div class="info-item">
                <div class="info-label">WAN Interface</div>
                <div class="info-value">$WAN_IFACE</div>
            </div>
            <div class="info-item">
                <div class="info-label">Connection Type</div>
                <div class="info-value">$WAN_PROTO</div>
            </div>
            <div class="info-item">
                <div class="info-label">WAN IP Address</div>
                <div class="info-value">${WAN_IP:-N/A}</div>
            </div>
            <div class="info-item">
                <div class="info-label">Public IP Address</div>
                <div class="info-value">$PUBLIC_IP</div>
            </div>
            <div class="info-item">
                <div class="info-label">IPv6 Address</div>
                <div class="info-value">${WAN_IP6:-N/A}</div>
            </div>
            <div class="info-item">
                <div class="info-label">Gateway</div>
                <div class="info-value">${GATEWAY:-N/A}</div>
            </div>
            <div class="info-item">
                <div class="info-label">DNS Servers</div>
                <div class="info-value">${DNS_SERVERS:-N/A}</div>
            </div>
            <div class="info-item">
                <div class="info-label">Router Uptime</div>
                <div class="info-value">$UPTIME</div>
            </div>
        </div>

        <div class="footer">
            <p>Auto-refresh every 10 seconds | $(date)</p>
        </div>
    </div>
</body>
</html>
EOF
```

### Create Enhanced Script

```bash
chmod +x /www1/cgi-bin/status.sh
```

---

## Multiple Status Checks

### Comprehensive Connectivity Testing

```bash
#!/bin/sh
# Advanced connectivity testing

# Test multiple targets
test_connectivity() {
    local targets="8.8.8.8 1.1.1.1 208.67.222.222"
    local success=0
    local total=0

    for target in $targets; do
        total=$((total + 1))
        if ping -c 1 -W 2 $target > /dev/null 2>&1; then
            success=$((success + 1))
        fi
    done

    # Return success if at least 2 out of 3 succeed
    if [ $success -ge 2 ]; then
        return 0
    else
        return 1
    fi
}

# Test DNS resolution
test_dns() {
    if nslookup google.com > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Test HTTP connectivity
test_http() {
    if wget -qO- --timeout=5 http://www.google.com > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}
```

---

## Styling and Customization

### Mobile-Responsive Design

```css
@media screen and (max-width: 768px) {
    .info-grid {
        grid-template-columns: 1fr;
    }
    .status-text {
        font-size: 24px;
    }
}
```

### Dark Mode Support

```css
@media (prefers-color-scheme: dark) {
    body {
        background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
    }
    .container {
        background: #2d2d44;
        color: #e0e0e0;
    }
    .info-item {
        background: #3a3a52;
    }
    .info-label, .info-value {
        color: #e0e0e0;
    }
}
```

---

## Security Considerations

### 1. Limit Access

```bash
# Only allow from LAN
uci set uhttpd.status.listen_http='192.168.1.1:80'
uci commit uhttpd
```

### 2. Rate Limiting

```bash
# Add to firewall
uci add firewall rule
uci set firewall.@rule[-1].name='HTTP-Rate-Limit'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='80'
uci set firewall.@rule[-1].limit='10/minute'
uci set firewall.@rule[-1].target='ACCEPT'
```

### 3. Input Validation

```bash
# Validate WAN interface
WAN_IFACE=$(uci get network.wan.ifname | sed 's/[^a-zA-Z0-9.-]//g')
```

---

## Troubleshooting

### Problem: Page Not Loading

**Solutions:**

1. Check web server status:
   ```bash
   /etc/init.d/uhttpd status
   /etc/init.d/uhttpd restart
   ```

2. Verify listening ports:
   ```bash
   netstat -tulpn | grep :80
   ```

3. Check file permissions:
   ```bash
   ls -la /www1/cgi-bin/status.sh
   chmod +x /www1/cgi-bin/status.sh
   ```

### Problem: CGI Script Not Executing

**Solutions:**

1. Verify shebang:
   ```bash
   head -1 /www1/cgi-bin/status.sh
   # Should be: #!/bin/sh
   ```

2. Check CGI prefix:
   ```bash
   uci get uhttpd.status.cgi_prefix
   # Should be: /cgi-bin
   ```

3. Test script manually:
   ```bash
   /www1/cgi-bin/status.sh
   ```

### Problem: Connection Always Shows Disconnected

**Solutions:**

1. Test ping manually:
   ```bash
   ping -c 1 8.8.8.8
   ```

2. Check WAN interface:
   ```bash
   uci get network.wan.ifname
   ip addr show
   ```

3. Verify firewall allows outbound:
   ```bash
   uci show firewall | grep wan
   ```

---

## Alternative Implementations

### PHP Version

```php
<?php
header('Content-Type: text/html; charset=utf-8');

// Test connectivity
$connected = @fsockopen("www.google.com", 80, $errno, $errstr, 5);

if ($connected) {
    fclose($connected);
    $status = "Connected";
    $class = "connected";

    // Get IP
    $wan_ip = shell_exec("ip addr show eth0.2 | awk '/inet / {print $2}' | cut -d/ -f1");
} else {
    $status = "No Connection";
    $class = "disconnected";
    $wan_ip = "N/A";
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>Status</title>
    <meta http-equiv="refresh" content="5" />
</head>
<body>
    <div class="status <?php echo $class; ?>">
        <?php echo $status; ?>
    </div>
    <div class="info">IP: <?php echo trim($wan_ip); ?></div>
</body>
</html>
```

### Using Lua (for uhttpd)

```lua
#!/usr/bin/env lua

print("Content-type: text/html\n")

local uci = require("luci.model.uci").cursor()
local sys = require("luci.sys")

-- Test connectivity
local connected = (os.execute("ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1") == 0)

-- Get WAN IP
local wan_iface = uci:get("network", "wan", "ifname")
local wan_ip = sys.exec("ip addr show " .. wan_iface .. " | awk '/inet / {print $2}' | cut -d/ -f1"):gsub("\n", "")

print([[
<!DOCTYPE html>
<html>
<body>
]])

if connected then
    print('<div class="status connected">Connected</div>')
    print('<div class="info">WAN IP: ' .. wan_ip .. '</div>')
else
    print('<div class="status disconnected">No Connection</div>')
end

print([[
</body>
</html>
]])
```

---

## References

### Official Documentation
- **OpenWRT Web Server:** https://openwrt.org/docs/guide-user/services/webserver/uhttpd
- **CGI on OpenWRT:** https://openwrt.org/docs/guide-user/services/webserver/http.cgi

### Related Pages
- **eko.one.pl Status Page:** https://eko.one.pl/?p=openwrt-statuspolaczenia
- **BusyBox httpd:** https://busybox.net/

### Tools
- **uhttpd**: OpenWRT web server
- **BusyBox httpd**: Lightweight HTTP server
- **CGI**: Common Gateway Interface

---

## Summary

Creating a connection status page on OpenWRT provides:

**Key Benefits:**
- Quick visual status check
- Real-time connection monitoring
- Minimal resource usage
- Easy customization

**Implementation Steps:**
1. Configure web server (port 80 for status, 8080 for LuCI)
2. Create directory structure (`/www1/`, `/www1/cgi-bin/`)
3. Create redirect page (`index.html`)
4. Create status script (`status.sh`)
5. Set proper permissions
6. Access via browser

**Basic Configuration:**
```bash
# Web server
uci set uhttpd.status.listen_http='0.0.0.0:80'
uci set uhttpd.status.home='/www1'
uci commit uhttpd

# Status script
chmod +x /www1/cgi-bin/status.sh
```

**Key Features:**
- Auto-refresh every 5-10 seconds
- Ping-based connectivity testing
- WAN IP address display
- Responsive design
- Customizable styling

This simple yet effective solution provides at-a-glance connection status monitoring for OpenWRT routers.

---

*This guide is based on the eko.one.pl connection status page tutorial and standard OpenWRT web server practices.*
