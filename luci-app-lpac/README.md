# LuCI App for LPAC (eSIM Profile Management)

Web interface for managing eSIM profiles on Quectel modems via OpenWrt's LuCI.

## Overview

`luci-app-lpac` provides a user-friendly web interface for the `quectel_lpad` command-line tool, enabling eSIM profile installation and management directly from the OpenWrt router's admin panel.

## Features

- **Add eSIM Profiles**: Install profiles using LPA activation codes
- **Delete Profiles**: Remove installed profiles by ID (1-16)
- **Modem Status**: View current modem and eSIM status
- **Progress Tracking**: Visual feedback during profile installation
- **Error Handling**: Clear error messages and debug output
- **Universal Compatibility**: Single package works across OpenWrt 19.07 through 24.10

## Compatibility

### OpenWrt Versions

- ✅ OpenWrt 19.07.x
- ✅ OpenWrt 21.02.x
- ✅ OpenWrt 22.03.x
- ✅ OpenWrt 23.05.x
- ✅ OpenWrt 24.10.x

### Hardware Requirements

- Quectel modem with eSIM support (RG500Q, RM500Q, etc.)
- QMI interface accessible at `/dev/cdc-wdm0`
- Internet connectivity (for SM-DP+ server communication)

## Dependencies

### Required Packages

- `luci-base` - LuCI core framework
- `luci-compat` - Backward compatibility layer
- `quectel_lpad` - eSIM profile management binary
- `qmicli` - QMI device communication tool (from libqmi-utils)
- `libcurl` - HTTP client library

### Installation Commands

```bash
opkg update
opkg install luci-base luci-compat libqmi-utils libcurl
```

## Installation

### Method 1: Pre-built IPK Package

```bash
# Transfer package to router
scp luci-app-lpac_*.ipk root@192.168.1.1:/tmp/

# Install on router
ssh root@192.168.1.1
opkg install /tmp/luci-app-lpac_*.ipk
```

### Method 2: Build from Source

```bash
# Copy package to OpenWrt SDK feeds
cp -r luci-app-lpac ~/openwrt-sdk/package/

# Build package
cd ~/openwrt-sdk
make package/luci-app-lpac/compile V=s

# Find built package
ls bin/packages/*/base/luci-app-lpac_*.ipk
```

### Post-Installation

1. **Install quectel_lpad binary**:

   ```bash
   scp quectel_lpad root@192.168.1.1:/usr/bin/
   ssh root@192.168.1.1 chmod +x /usr/bin/quectel_lpad
   ```

2. **Restart LuCI**:

   ```bash
   /etc/init.d/uhttpd restart
   ```

3. **Access web interface**:
   - Navigate to: **Network → eSIM (LPAC) → Profile Management**

## Usage

### Adding an eSIM Profile

1. Navigate to **Network → eSIM (LPAC)** in LuCI
2. Enter the **Activation Code** in format:

   ```bash
   LPA:1$smdp.example.com$ACTIVATION_CODE
   ```

3. Optionally enter **Confirmation Code** (if required by carrier)
4. Click **Install Profile**
5. Wait 30-60 seconds for installation (progress bar shows status)

### Deleting a Profile

1. Select **Profile ID** (1-16) from dropdown
2. Click **Delete Profile**
3. Confirm deletion in popup dialog
4. Profile will be removed from modem

### Checking Modem Status

1. Click **Refresh Status** button
2. View current modem information including:
   - Card status
   - Installed profiles
   - Active profile
   - ICCID information

## Architecture

### Component Overview

```bash
luci-app-lpac/
├── Makefile                           # OpenWrt package definition
├── luasrc/
│   ├── controller/lpac.lua           # Backend Lua controller (JSON API)
│   └── view/lpac/profiles.htm        # Frontend HTML/CSS/JS
└── root/usr/bin/
    └── quectel_lpad_json             # Wrapper script (CLI → JSON)
```

### Communication Flow

```bash
Web Browser (JavaScript)
    ↓ XHR.post()
Lua Controller (lpac.lua)
    ↓ exec()
Wrapper Script (quectel_lpad_json)
    ↓ shell exec
quectel_lpad Binary
    ↓ QMI protocol
Quectel Modem
    ↓ HTTP/HTTPS
SM-DP+ Server (Carrier)
```

### API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/admin/network/lpac/add` | POST | Install eSIM profile |
| `/admin/network/lpac/delete` | POST | Delete profile by ID |
| `/admin/network/lpac/list` | GET | List installed profiles |
| `/admin/network/lpac/status` | GET | Get modem status |

### JSON Response Format

```json
{
  "success": true/false,
  "message": "Human-readable status message",
  "error": "Error description if failure",
  "output": "Raw command output for debugging"
}
```

## Configuration

### QMI Device Path

Default device: `/dev/cdc-wdm0`

To use a different device, edit the wrapper script:

```bash
vi /usr/bin/quectel_lpad_json
# Modify line:
QMI_DEVICE="/dev/cdc-wdm0"
```

### Timeout Settings

Default timeout: 90 seconds

To adjust timeout, edit the wrapper script:

```bash
vi /usr/bin/quectel_lpad_json
# Modify line:
TIMEOUT=90
```

## Troubleshooting

### "Modem not accessible" Error

**Problem**: QMI device not found or inaccessible

**Solutions**:

```bash
# Check device exists
ls -l /dev/cdc-wdm*

# Load QMI kernel module
modprobe qmi_wwan

# Fix permissions
chmod 666 /dev/cdc-wdm0

# Verify modem communication
qmicli -d /dev/cdc-wdm0 --uim-get-card-status
```

### "quectel_lpad binary not found" Error

**Problem**: Binary not installed or not in PATH

**Solutions**:

```bash
# Check if binary exists
which quectel_lpad

# Install binary
scp quectel_lpad root@192.168.1.1:/usr/bin/
chmod +x /usr/bin/quectel_lpad

# Test binary
quectel_lpad -h
```

### Installation Times Out

**Problem**: Profile download takes longer than timeout

**Solutions**:

- Increase timeout in `/usr/bin/quectel_lpad_json`
- Check internet connectivity: `ping 8.8.8.8`
- Verify SM-DP+ server is reachable
- Check for QMI device conflicts

### "Operation timed out after 90s" Error

**Problem**: Network issue or SM-DP+ server unreachable

**Solutions**:

```bash
# Test internet connectivity
ping -c 4 8.8.8.8

# Check DNS resolution
nslookup smdp.example.com

# Check firewall rules
iptables -L -n | grep REJECT

# Review system logs
logread | grep -i qmi
logread | grep -i curl
```

### Profile Installation Fails with "Invalid activation code"

**Problem**: Malformed or incorrect activation code

**Solutions**:

- Verify activation code format: `LPA:1$SERVER$CODE`
- Check for extra spaces or special characters
- Request new activation code from carrier
- Test with confirmation code if required

### Web Interface Not Showing in Menu

**Problem**: LuCI cache not refreshed

**Solutions**:

```bash
# Restart web server
/etc/init.d/uhttpd restart

# Clear browser cache
# Clear LuCI cache
rm -rf /tmp/luci-*

# Verify package installed
opkg list-installed | grep luci-app-lpac
```

## Development

### Testing Wrapper Script

Test the JSON wrapper independently:

```bash
# Test add profile
/usr/bin/quectel_lpad_json add "LPA:1$smdp$code" "1234"

# Test delete profile
/usr/bin/quectel_lpad_json delete 1

# Test status
/usr/bin/quectel_lpad_json status
```

### Debugging Lua Controller

Enable LuCI debugging:

```bash
# Edit /etc/config/luci
uci set luci.main.debug=1
uci commit luci
/etc/init.d/uhttpd restart

# View logs
logread -f | grep luci
```

### Inspecting JavaScript Console

Open browser developer tools (F12) and check:

- Network tab for XHR requests/responses
- Console tab for JavaScript errors
- Response JSON format

## Security Considerations

### Input Validation

- Activation codes validated for minimum length (10 characters)
- Profile IDs restricted to range 1-16
- Shell arguments properly quoted with `util.shellquote()`
- JSON parsing with error handling

### Authentication

- LuCI's built-in authentication required
- All endpoints protected by session management
- No anonymous access permitted

### Error Messages

- Sensitive information filtered from error messages
- Debug output only shown when explicitly enabled
- Raw command output sanitized of ANSI codes

## Performance

### Resource Usage

- **Memory**: ~1-2MB during operation
- **Storage**: ~20KB package size (excluding dependencies)
- **Network**: Depends on profile size (typically 1-5MB download from SM-DP+)

### Operation Times

- Profile installation: 30-60 seconds
- Profile deletion: 5-10 seconds
- Status query: 1-2 seconds

## Limitations

- No real-time progress updates (simulated progress bar)
- Cannot list profile contents (modem limitation)
- Requires internet connectivity for SM-DP+ access
- Single profile operation at a time

## Support

### Log Collection

For bug reports, collect the following:

```bash
# System info
uname -a
opkg list-installed | grep -E "luci|qmi|curl"

# Modem status
qmicli -d /dev/cdc-wdm0 --uim-get-card-status

# Test wrapper directly
/usr/bin/quectel_lpad_json status

# System logs
logread | tail -100

# LuCI logs
logread | grep luci
```

### Common Issues

See [Troubleshooting](#troubleshooting) section above.

## License

MIT License - Copyright 2025 Kerem

## Credits

- Based on Quectel LPAD v1.0.7
- LuCI framework by OpenWrt Project
- GSMA RSP specification

## Changelog

### v1.0.0 (2025-01-XX)

- Initial release
- Support for profile add/delete operations
- Modem status display
- Compatible with OpenWrt 19.07 through 24.10
- JSON wrapper for CLI integration
