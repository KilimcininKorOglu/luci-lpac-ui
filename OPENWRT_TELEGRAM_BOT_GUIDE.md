# OpenWRT Telegram Bot Remote Control Guide

## Table of Contents
1. [Overview](#overview)
2. [What is Telegram Bot Control](#what-is-telegram-bot-control)
3. [Use Cases](#use-cases)
4. [Prerequisites](#prerequisites)
5. [Creating a Telegram Bot](#creating-a-telegram-bot)
6. [Installation](#installation)
7. [Configuration](#configuration)
8. [Built-in Commands](#built-in-commands)
9. [Plugin System](#plugin-system)
10. [Custom Command Examples](#custom-command-examples)
11. [Advanced Features](#advanced-features)
12. [Security Considerations](#security-considerations)
13. [Troubleshooting](#troubleshooting)
14. [Alternative Implementations](#alternative-implementations)
15. [Best Practices](#best-practices)
16. [References](#references)

---

## Overview

This guide demonstrates how to set up a Telegram bot for remote control and monitoring of OpenWRT routers. By integrating Telegram's messaging platform, you can execute commands, check router status, and receive notifications directly from your smartphone anywhere in the world.

**Key Features:**
- Remote command execution via Telegram
- Real-time router monitoring
- Custom plugin support
- Secure authentication
- No port forwarding required
- Works from anywhere with internet

**Common Operations:**
- Check WAN IP address
- View connected devices
- Restart router remotely
- Wake-on-LAN for networked devices
- Monitor DHCP leases
- Execute custom scripts

---

## What is Telegram Bot Control

### How It Works

```
User (Telegram App)
       ↓
Telegram Servers (API)
       ↓
OpenWRT Router (telegrambot daemon)
       ↓
Execute Command
       ↓
Send Response
       ↓
User Receives Message
```

**Process Flow:**
1. User sends command to bot via Telegram
2. Telegram delivers message to OpenWRT via bot API
3. telegrambot daemon processes command
4. Command executes on router
5. Output sent back to user via Telegram

### Advantages

- **No Port Forwarding:** Uses outbound HTTPS connections
- **Secure:** Telegram's encryption + bot token authentication
- **Convenient:** Control from any device with Telegram
- **Global Access:** Works from anywhere with internet
- **Real-time:** Instant command execution and responses
- **Multi-device:** Access from phone, tablet, desktop simultaneously

---

## Use Cases

### Network Management

- Check connected devices
- View DHCP leases
- Monitor bandwidth usage
- Check WAN IP address changes
- View WiFi client list

### Remote Administration

- Reboot router remotely
- Restart specific services
- Check system status
- Monitor resource usage (CPU, RAM, storage)
- View system logs

### Automation and Notifications

- Receive alerts on new device connections
- Get notified when specific devices connect/disconnect
- Monitor internet connection status
- Scheduled status reports
- Wake-on-LAN for home devices

### Troubleshooting

- Execute diagnostic commands
- Check connectivity
- View interface status
- Test DNS resolution
- Ping hosts

### Smart Home Integration

- Trigger home automation scripts
- Control IoT devices
- Monitor smart home sensors
- Integrate with home assistant

---

## Prerequisites

### Router Requirements

**Software:**
- OpenWRT 19.07 or newer (21.02+ recommended)
- Internet connectivity
- Sufficient storage for package (~100KB)

**Hardware:**
- Any OpenWRT-compatible router
- Active internet connection
- Minimum 32MB RAM

### Telegram Requirements

**You need:**
1. Telegram account
2. Telegram app (smartphone, desktop, or web)
3. Access to create bots via @BotFather

**Optional:**
- SSL certificates for webhook mode (polling mode works without)

---

## Creating a Telegram Bot

### Step 1: Contact BotFather

**BotFather** is Telegram's official bot for creating and managing bots.

1. Open Telegram app
2. Search for `@BotFather`
3. Start conversation

### Step 2: Create New Bot

Send command to BotFather:
```
/newbot
```

**BotFather will ask:**
1. **Bot name** - Display name (can be anything)
   - Example: "My OpenWRT Router"

2. **Bot username** - Must be unique and end with "bot"
   - Example: "MyHomeRouter_bot"
   - Valid: "home_router_bot", "openwrt123bot"
   - Invalid: "myrouter", "router_admin"

### Step 3: Get Bot Token

After successful creation, BotFather provides:

```
Done! Congratulations on your new bot. You will find it at t.me/MyHomeRouter_bot.
You can now add a description, about section and profile picture for your bot.

Use this token to access the HTTP API:
1234567890:ABCdefGHIjklMNOpqrsTUVwxyz1234567890

Keep your token secure and store it safely, it can be used by anyone to control your bot.
```

**Save this token!** You'll need it for configuration.

### Step 4: Get Your Chat ID

Your chat ID identifies you as the bot administrator.

**Method 1: Use @get_id_bot**
1. Search for `@get_id_bot` in Telegram
2. Start conversation
3. Bot replies with your chat_id
   - Example: `Your chat_id: 123456789`

**Method 2: Use @userinfobot**
1. Search for `@userinfobot`
2. Start conversation
3. Note the "Id" field

**Method 3: Manual method**
1. Send any message to your new bot
2. Visit in browser:
   ```
   https://api.telegram.org/bot<BOT_TOKEN>/getUpdates
   ```
   Replace `<BOT_TOKEN>` with your actual token

3. Find `"chat":{"id":123456789}` in JSON response

### Step 5: Test Bot

1. Search for your bot in Telegram (by username)
2. Start conversation with `/start`
3. Bot won't respond yet (not configured on router)

**Important Notes:**
- Keep bot token secret (like a password)
- Only share chat_id with authorized users
- Bot token can be regenerated if compromised via @BotFather

---

## Installation

### Method 1: Install from Repository (Recommended)

**For architectures with prebuilt packages:**

```bash
opkg update
opkg install telegrambot
```

**Note:** Package may not be in default repositories. If not found, use Method 2.

### Method 2: Install from External Repository

**From 132lan.ru repository:**

```bash
# Install package directly
opkg update
opkg install http://openwrt.132lan.ru/packages/packages-19.07/mipsel_24kc/packages/telegrambot_0.0.3-1_all.ipk
```

**Note:** Package is architecture-independent (`_all.ipk`) and works on all platforms.

### Method 3: Install from GitHub (Alternative Implementation)

```bash
# Clone repository
opkg install git
git clone https://github.com/ixiumu/openwrt-telegram-bot.git /tmp/telegram-bot

# Install dependencies
opkg install bash curl jq

# Copy files
cp /tmp/telegram-bot/telegrambot.sh /usr/bin/
chmod +x /usr/bin/telegrambot.sh

# Create init script
cp /tmp/telegram-bot/telegrambot.init /etc/init.d/telegrambot
chmod +x /etc/init.d/telegrambot
```

### Verify Installation

```bash
# Check if package installed
opkg list-installed | grep telegram

# Check if init script exists
ls -l /etc/init.d/telegrambot

# Check if service can start
/etc/init.d/telegrambot status
```

---

## Configuration

### Stop the Service

```bash
/etc/init.d/telegrambot stop
```

### Configure Bot Token and Chat ID

**Using UCI (recommended):**

```bash
# Set bot token
uci set telegrambot.config.bot_token='1234567890:ABCdefGHIjklMNOpqrsTUVwxyz1234567890'

# Set your chat ID
uci set telegrambot.config.chat_id='123456789'

# Commit changes
uci commit telegrambot
```

**Configuration file location:** `/etc/config/telegrambot`

### Manual Configuration File Edit

Edit `/etc/config/telegrambot`:

```bash
vi /etc/config/telegrambot
```

**Configuration structure:**

```
config telegrambot 'config'
    option bot_token '1234567890:ABCdefGHIjklMNOpqrsTUVwxyz1234567890'
    option chat_id '123456789'
    option enabled '1'
    option update_interval '2'
```

**Options explained:**
- `bot_token` - Your bot's API token from BotFather
- `chat_id` - Your Telegram user ID (admin)
- `enabled` - Enable (1) or disable (0) the bot
- `update_interval` - Polling interval in seconds (default: 2)

### Multiple Authorized Users

**To allow multiple users to control the bot:**

```bash
# Add multiple chat IDs (space-separated)
uci set telegrambot.config.chat_id='123456789 987654321 456789123'
uci commit telegrambot
```

### Start the Service

```bash
# Start bot
/etc/init.d/telegrambot start

# Enable on boot
/etc/init.d/telegrambot enable

# Check status
/etc/init.d/telegrambot status
```

### Verify Bot is Working

1. Open Telegram
2. Find your bot
3. Send: `/plugins`
4. Bot should respond with list of available commands

**If no response:**
- Check bot is running: `ps | grep telegram`
- Check logs: `logread | grep telegram`
- Verify token and chat_id are correct

---

## Built-in Commands

### Basic Commands

#### /plugins
**Description:** List all available commands and plugins

**Usage:**
```
/plugins
```

**Response:**
```
Available commands:
/memory - Show memory usage
/leases - Show DHCP leases
/wifi_list - Show WiFi clients
/reboot - Reboot router
/wol <mac> - Wake-on-LAN
/wanip - Show WAN IP address
/plugins - This help message
```

#### /memory
**Description:** Display RAM usage information

**Usage:**
```
/memory
```

**Response:**
```
Memory:
Total: 128 MB
Used: 45 MB
Free: 83 MB
Buffers: 5 MB
```

#### /leases
**Description:** Show active DHCP leases

**Usage:**
```
/leases
```

**Response:**
```
DHCP Leases:
192.168.1.100 - AA:BB:CC:DD:EE:FF - Johns-iPhone
192.168.1.101 - 11:22:33:44:55:66 - Desktop-PC
192.168.1.102 - 99:88:77:66:55:44 - Smart-TV
```

#### /wifi_list
**Description:** Show connected WiFi clients

**Usage:**
```
/wifi_list
```

**Response:**
```
WiFi Clients (2.4GHz):
AA:BB:CC:DD:EE:FF - Signal: -45 dBm
11:22:33:44:55:66 - Signal: -67 dBm

WiFi Clients (5GHz):
99:88:77:66:55:44 - Signal: -52 dBm
```

#### /wanip
**Description:** Show current WAN IP address

**Usage:**
```
/wanip
```

**Response:**
```
WAN IP: 203.0.113.45
```

#### /reboot
**Description:** Reboot the router

**Usage:**
```
/reboot
```

**Response:**
```
Router is rebooting...
```

**Warning:** Router will restart and briefly lose connectivity.

#### /wol
**Description:** Wake-on-LAN for network devices

**Usage:**
```
/wol AA:BB:CC:DD:EE:FF
```

**Response:**
```
Wake-on-LAN packet sent to AA:BB:CC:DD:EE:FF
```

**Requirements:**
- Target device supports Wake-on-LAN
- Target device is on same network
- WOL enabled in device BIOS/settings

---

## Plugin System

### Plugin Directory

**Location:** `/usr/lib/telegrambot/plugins/`

Each plugin is a shell script that handles a specific command.

### Plugin Structure

**Basic plugin template:**

```bash
#!/bin/sh
# Plugin: example
# Description: Example plugin

COMMAND="$1"
ARGS="$2"

case "$COMMAND" in
    example)
        echo "This is an example plugin"
        echo "Arguments: $ARGS"
        ;;
    *)
        exit 1
        ;;
esac
```

### List Existing Plugins

```bash
ls -la /usr/lib/telegrambot/plugins/
```

**Default plugins:**
- `memory` - Memory information
- `leases` - DHCP leases
- `wifi_list` - WiFi clients
- `wanip` - WAN IP
- `reboot` - System reboot
- `wol` - Wake-on-LAN

---

## Custom Command Examples

### Example 1: Check Internet Connectivity

**Create plugin:** `/usr/lib/telegrambot/plugins/ping`

```bash
#!/bin/sh
# Plugin: ping
# Description: Ping test to check internet connectivity

cat << 'EOF'
#!/bin/sh

if [ "$1" = "ping" ]; then
    TARGET="${2:-8.8.8.8}"

    if ping -c 3 -W 2 "$TARGET" > /dev/null 2>&1; then
        echo "✓ Internet connection OK"
        echo "Ping to $TARGET successful"
    else
        echo "✗ Internet connection FAILED"
        echo "Cannot reach $TARGET"
    fi
fi
EOF
```

**Make executable:**
```bash
chmod +x /usr/lib/telegrambot/plugins/ping
```

**Restart bot:**
```bash
/etc/init.d/telegrambot restart
```

**Usage:**
```
/ping
/ping 1.1.1.1
```

### Example 2: System Uptime

**Create plugin:** `/usr/lib/telegrambot/plugins/uptime`

```bash
#!/bin/sh
# Plugin: uptime
# Description: Show system uptime

if [ "$1" = "uptime" ]; then
    UPTIME=$(uptime | awk '{print $3 $4}' | sed 's/,//')
    LOAD=$(uptime | awk -F'load average:' '{print $2}')

    echo "📊 System Uptime: $UPTIME"
    echo "Load Average: $LOAD"
fi
```

**Make executable and restart:**
```bash
chmod +x /usr/lib/telegrambot/plugins/uptime
/etc/init.d/telegrambot restart
```

### Example 3: Connected Devices Count

**Create plugin:** `/usr/lib/telegrambot/plugins/devicecount`

```bash
#!/bin/sh
# Plugin: devicecount
# Description: Count connected devices

if [ "$1" = "devicecount" ]; then
    DHCP_COUNT=$(cat /tmp/dhcp.leases | wc -l)
    WIFI_COUNT=$(iw dev wlan0 station dump | grep Station | wc -l)

    echo "📱 Connected Devices:"
    echo "DHCP Leases: $DHCP_COUNT"
    echo "WiFi Clients: $WIFI_COUNT"
fi
```

### Example 4: Disk Space

**Create plugin:** `/usr/lib/telegrambot/plugins/disk`

```bash
#!/bin/sh
# Plugin: disk
# Description: Show disk usage

if [ "$1" = "disk" ]; then
    echo "💾 Disk Usage:"
    df -h | grep -E '^/dev/' | while read line; do
        echo "$line"
    done
fi
```

### Example 5: Public IP with Geolocation

**Create plugin:** `/usr/lib/telegrambot/plugins/ipinfo`

```bash
#!/bin/sh
# Plugin: ipinfo
# Description: Get public IP with location info

if [ "$1" = "ipinfo" ]; then
    # Requires curl
    INFO=$(curl -s https://ipinfo.io/json)

    IP=$(echo "$INFO" | jsonfilter -e '@.ip')
    CITY=$(echo "$INFO" | jsonfilter -e '@.city')
    REGION=$(echo "$INFO" | jsonfilter -e '@.region')
    COUNTRY=$(echo "$INFO" | jsonfilter -e '@.country')
    ORG=$(echo "$INFO" | jsonfilter -e '@.org')

    echo "🌐 Public IP Information:"
    echo "IP: $IP"
    echo "Location: $CITY, $REGION, $COUNTRY"
    echo "ISP: $ORG"
fi
```

**Install dependencies:**
```bash
opkg install curl jsonfilter
```

### Example 6: Service Restart

**Create plugin:** `/usr/lib/telegrambot/plugins/restart_service`

```bash
#!/bin/sh
# Plugin: restart_service
# Description: Restart specific services

if [ "$1" = "restart" ]; then
    SERVICE="$2"

    case "$SERVICE" in
        network)
            /etc/init.d/network restart
            echo "✓ Network service restarted"
            ;;
        firewall)
            /etc/init.d/firewall restart
            echo "✓ Firewall service restarted"
            ;;
        wifi)
            wifi reload
            echo "✓ WiFi reloaded"
            ;;
        *)
            echo "Unknown service: $SERVICE"
            echo "Available: network, firewall, wifi"
            ;;
    esac
fi
```

**Usage:**
```
/restart network
/restart wifi
/restart firewall
```

### Example 7: Speed Test

**Create plugin:** `/usr/lib/telegrambot/plugins/speedtest`

```bash
#!/bin/sh
# Plugin: speedtest
# Description: Simple download speed test

if [ "$1" = "speedtest" ]; then
    echo "⏳ Running speed test..."

    TIME_START=$(date +%s)
    wget -O /dev/null http://speedtest.ftp.otenet.gr/files/test10Mb.db 2>&1 | tail -2
    TIME_END=$(date +%s)

    DURATION=$((TIME_END - TIME_START))
    echo "Test completed in ${DURATION}s"
fi
```

---

## Advanced Features

### Automatic Notifications

**Monitor new DHCP leases:**

```bash
cat > /usr/bin/monitor-leases.sh << 'EOF'
#!/bin/sh
# Monitor DHCP leases and notify via Telegram

LEASE_FILE="/tmp/dhcp.leases"
LAST_COUNT_FILE="/tmp/lease_count"

# Get current lease count
CURRENT_COUNT=$(wc -l < "$LEASE_FILE")

# Get previous count
if [ -f "$LAST_COUNT_FILE" ]; then
    LAST_COUNT=$(cat "$LAST_COUNT_FILE")
else
    LAST_COUNT=0
fi

# If count increased, new device connected
if [ "$CURRENT_COUNT" -gt "$LAST_COUNT" ]; then
    # Get newest lease
    NEW_DEVICE=$(tail -1 "$LEASE_FILE" | awk '{print $2, $3, $4}')

    # Send notification (requires telegram-send or custom function)
    /usr/bin/telegram-send.sh "🔔 New device connected: $NEW_DEVICE"
fi

# Update count
echo "$CURRENT_COUNT" > "$LAST_COUNT_FILE"
EOF

chmod +x /usr/bin/monitor-leases.sh

# Add to cron (check every minute)
echo "* * * * * /usr/bin/monitor-leases.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

### WAN IP Change Notification

```bash
cat > /usr/bin/monitor-wanip.sh << 'EOF'
#!/bin/sh
# Monitor WAN IP changes

IP_FILE="/tmp/last_wan_ip"

# Get current WAN IP
CURRENT_IP=$(wget -qO- http://ipinfo.io/ip)

# Get previous IP
if [ -f "$IP_FILE" ]; then
    LAST_IP=$(cat "$IP_FILE")
else
    LAST_IP=""
fi

# If IP changed, send notification
if [ "$CURRENT_IP" != "$LAST_IP" ]; then
    /usr/bin/telegram-send.sh "🌐 WAN IP changed: $LAST_IP → $CURRENT_IP"
    echo "$CURRENT_IP" > "$IP_FILE"
fi
EOF

chmod +x /usr/bin/monitor-wanip.sh

# Check every 5 minutes
echo "*/5 * * * * /usr/bin/monitor-wanip.sh" >> /etc/crontabs/root
```

### Command with Parameters

**Example: Ping custom host**

```bash
#!/bin/sh
# Plugin: ping_host

if [ "$1" = "ping_host" ]; then
    HOST="$2"

    if [ -z "$HOST" ]; then
        echo "Usage: /ping_host <hostname or IP>"
        exit 1
    fi

    if ping -c 3 "$HOST" > /dev/null 2>&1; then
        echo "✓ $HOST is reachable"
    else
        echo "✗ $HOST is unreachable"
    fi
fi
```

---

## Security Considerations

### 1. Protect Bot Token

```bash
# Never share bot token publicly
# Regenerate if compromised via @BotFather

# Secure configuration file
chmod 600 /etc/config/telegrambot
```

### 2. Limit Authorized Users

```bash
# Only add trusted chat IDs
uci set telegrambot.config.chat_id='123456789'  # Single user

# Multiple users
uci set telegrambot.config.chat_id='123456789 987654321'
uci commit telegrambot
```

### 3. Restrict Dangerous Commands

```bash
# Add confirmation for critical commands
# Example: Reboot plugin with confirmation

#!/bin/sh
if [ "$1" = "reboot_confirm" ]; then
    if [ "$2" = "YES" ]; then
        reboot
    else
        echo "To reboot, send: /reboot_confirm YES"
    fi
fi
```

### 4. Rate Limiting

```bash
# Prevent command spam
# Implement cooldown in plugins

LAST_CMD_FILE="/tmp/telegram_last_cmd"
COOLDOWN=5  # seconds

if [ -f "$LAST_CMD_FILE" ]; then
    LAST_TIME=$(cat "$LAST_CMD_FILE")
    CURRENT_TIME=$(date +%s)
    DIFF=$((CURRENT_TIME - LAST_TIME))

    if [ "$DIFF" -lt "$COOLDOWN" ]; then
        echo "Please wait $((COOLDOWN - DIFF)) seconds"
        exit 1
    fi
fi

date +%s > "$LAST_CMD_FILE"
```

### 5. Log Commands

```bash
# Log all bot commands for audit
logger -t telegram-bot "Command: $1 from chat_id: $CHAT_ID"
```

### 6. Firewall Considerations

**No inbound ports needed:**
- Bot uses outbound HTTPS (polling)
- No port forwarding required
- Firewall-friendly

---

## Troubleshooting

### Bot Not Responding

**Problem:** Bot doesn't reply to commands.

**Solutions:**

1. **Check service status:**
   ```bash
   /etc/init.d/telegrambot status
   ps | grep telegram
   ```

2. **Verify configuration:**
   ```bash
   cat /etc/config/telegrambot
   # Check bot_token and chat_id are correct
   ```

3. **Check logs:**
   ```bash
   logread | grep telegram
   dmesg | grep telegram
   ```

4. **Restart service:**
   ```bash
   /etc/init.d/telegrambot restart
   ```

5. **Test bot token manually:**
   ```bash
   curl "https://api.telegram.org/bot<BOT_TOKEN>/getMe"
   # Should return bot information
   ```

### Wrong Chat ID

**Problem:** Bot works for others but not you.

**Solution:**
```bash
# Get your chat_id from @get_id_bot
# Update configuration
uci set telegrambot.config.chat_id='YOUR_CHAT_ID'
uci commit telegrambot
/etc/init.d/telegrambot restart
```

### Internet Connectivity Issues

**Problem:** Bot can't reach Telegram servers.

**Solutions:**

1. **Test internet:**
   ```bash
   ping 8.8.8.8
   ping api.telegram.org
   ```

2. **Check DNS:**
   ```bash
   nslookup api.telegram.org
   ```

3. **Check firewall:**
   ```bash
   # Ensure outbound HTTPS allowed
   uci show firewall | grep wan
   ```

### Plugin Not Working

**Problem:** Custom plugin doesn't respond.

**Solutions:**

1. **Check permissions:**
   ```bash
   ls -la /usr/lib/telegrambot/plugins/
   chmod +x /usr/lib/telegrambot/plugins/yourplugin
   ```

2. **Test plugin manually:**
   ```bash
   /usr/lib/telegrambot/plugins/yourplugin yourcommand
   ```

3. **Check syntax:**
   ```bash
   sh -n /usr/lib/telegrambot/plugins/yourplugin
   # Should show no errors
   ```

4. **Restart bot after adding plugins:**
   ```bash
   /etc/init.d/telegrambot restart
   ```

---

## Alternative Implementations

### Option 1: ixiumu's openwrt-telegram-bot

**GitHub:** https://github.com/ixiumu/openwrt-telegram-bot

**Features:**
- Bash-based implementation
- Simple plugin system
- Easy to customize

**Installation:**
```bash
git clone https://github.com/ixiumu/openwrt-telegram-bot.git
cd openwrt-telegram-bot
./install.sh
```

### Option 2: alexwbaule's telegramopenwrt

**GitHub:** https://github.com/alexwbaule/telegramopenwrt

**Features:**
- Python-based
- Advanced features
- Webhook support

**Installation:**
```bash
opkg install python3 python3-pip
pip3 install python-telegram-bot
git clone https://github.com/alexwbaule/telegramopenwrt.git
```

### Option 3: Custom Script

**Minimal implementation:**

```bash
#!/bin/sh
# Simple Telegram bot poller

BOT_TOKEN="YOUR_BOT_TOKEN"
CHAT_ID="YOUR_CHAT_ID"
API="https://api.telegram.org/bot$BOT_TOKEN"
OFFSET=0

while true; do
    # Get updates
    UPDATES=$(wget -qO- "$API/getUpdates?offset=$OFFSET&timeout=30")

    # Parse commands
    TEXT=$(echo "$UPDATES" | jsonfilter -e '@.result[0].message.text')
    UPDATE_ID=$(echo "$UPDATES" | jsonfilter -e '@.result[0].update_id')

    if [ -n "$TEXT" ]; then
        # Process command
        case "$TEXT" in
            /ping)
                RESPONSE="Pong!"
                ;;
            /ip)
                RESPONSE="WAN IP: $(wget -qO- http://ipinfo.io/ip)"
                ;;
            *)
                RESPONSE="Unknown command"
                ;;
        esac

        # Send response
        wget -qO- "$API/sendMessage?chat_id=$CHAT_ID&text=$RESPONSE"

        # Update offset
        OFFSET=$((UPDATE_ID + 1))
    fi

    sleep 2
done
```

---

## Best Practices

### 1. Keep Bot Token Secret

```bash
# Never commit to git
# Never share publicly
# Regenerate if compromised
```

### 2. Implement Error Handling

```bash
#!/bin/sh
# Example plugin with error handling

if [ "$1" = "mycommand" ]; then
    if ! command -v somecommand > /dev/null; then
        echo "Error: Required command 'somecommand' not found"
        exit 1
    fi

    OUTPUT=$(somecommand 2>&1)
    if [ $? -ne 0 ]; then
        echo "Error executing command: $OUTPUT"
        exit 1
    fi

    echo "$OUTPUT"
fi
```

### 3. Provide Help Messages

```bash
# Add usage information
if [ -z "$2" ]; then
    echo "Usage: /mycommand <parameter>"
    echo "Example: /mycommand 192.168.1.1"
    exit 0
fi
```

### 4. Use Emojis for Clarity

```bash
echo "✓ Success"
echo "✗ Failed"
echo "⚠️ Warning"
echo "ℹ️ Information"
echo "🔄 Processing..."
```

### 5. Regular Updates

```bash
# Keep telegrambot package updated
opkg update
opkg upgrade telegrambot
```

---

## References

### Official Documentation
- **Telegram Bot API:** https://core.telegram.org/bots/api
- **BotFather:** https://core.telegram.org/bots#botfather

### Community Implementations
- **openwrt-telegram-bot:** https://github.com/ixiumu/openwrt-telegram-bot
- **telegramopenwrt:** https://github.com/alexwbaule/telegramopenwrt
- **132lan.ru packages:** http://openwrt.132lan.ru/

### Related Resources
- **eko.one.pl Forum:** https://eko.one.pl/forum/viewtopic.php?id=21129
- **OpenWRT Forum:** https://forum.openwrt.org/

---

## Summary

Telegram bot integration provides powerful remote control for OpenWRT routers:

**Key Benefits:**
- Remote router management from anywhere
- No port forwarding required
- Secure, encrypted communication
- Extensible plugin system
- Multi-device support

**Quick Setup:**
1. Create bot with @BotFather → get token
2. Get chat_id from @get_id_bot
3. Install telegrambot package
4. Configure token and chat_id
5. Start service

**Basic Configuration:**
```bash
opkg install telegrambot
uci set telegrambot.config.bot_token='YOUR_TOKEN'
uci set telegrambot.config.chat_id='YOUR_CHAT_ID'
uci commit telegrambot
/etc/init.d/telegrambot enable
/etc/init.d/telegrambot start
```

**Available Commands:**
- `/plugins` - List commands
- `/memory` - RAM usage
- `/leases` - DHCP leases
- `/wifi_list` - Connected WiFi clients
- `/wanip` - WAN IP address
- `/reboot` - Restart router
- `/wol <mac>` - Wake-on-LAN

**Custom Plugins:**
Add scripts to `/usr/lib/telegrambot/plugins/` for custom commands and automation.

This solution provides convenient, secure remote access to your OpenWRT router through Telegram's familiar messaging interface.

---

*This guide is based on the eko.one.pl forum discussion and community Telegram bot implementations for OpenWRT.*
