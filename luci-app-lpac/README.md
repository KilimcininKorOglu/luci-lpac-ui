# LuCI App LPAC

A LuCI web interface for managing eSIM profiles on OpenWrt routers with Quectel modems.

## Overview

LuCI App LPAC provides a user-friendly web interface for eSIM profile management through the LPAC (Local Profile Assistant Client) binary. It enables administrators to manage eSIM profiles directly from the OpenWrt router's web interface, supporting operations such as adding, deleting, enabling, and disabling profiles.

## Features

- **Add eSIM Profiles**: Install profiles using LPA activation codes
- **Delete Profiles**: Remove installed profiles by ICCID
- **Enable/Disable Profiles**: Switch between profiles dynamically
- **Multi-Driver Support**: AT, AT_CSIM, and MBIM drivers for different modem types
- **Device Detection**: Automatic detection of available modems
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

- Quectel modem with eSIM support (EP06-E, RG500Q, RM500Q, etc.)
- AT serial interface (`/dev/ttyUSB*`) or MBIM interface (`/dev/cdc-wdm*`)
- Internet connectivity (for SM-DP+ server communication)

## Dependencies

### Required Packages

- `luci-base` - LuCI core framework
- `luci-compat` - Backward compatibility layer
- `lpac` - eSIM profile management binary (SGP.22 v2.2.2)
- `curl` or `wget` - HTTP client for SM-DP+ communication
- `libcurl` - HTTP client library (for lpac)

### Optional Packages

- `libmbim-utils` - For MBIM driver support (mbimcli)
- `libqmi-utils` - For QMI utilities (qmicli) if using MBIM driver

### Installation Commands

```bash
opkg update
opkg install luci-base luci-compat libcurl curl
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

1. **Install lpac binary**:

   ```bash
   scp lpac root@192.168.1.1:/usr/bin/
   ssh root@192.168.1.1 chmod +x /usr/bin/lpac
   ```

2. **Configure device settings** (optional - default is AT driver with /dev/ttyUSB2):

   ```bash
   uci set lpac.device.driver='at'
   uci set lpac.device.at_device='/dev/ttyUSB2'
   uci set lpac.device.http_client='curl'
   uci commit lpac
   ```

3. **Restart LuCI**:

   ```bash
   /etc/init.d/uhttpd restart
   ```

4. **Access web interface**:
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

1. Click **Refresh Profiles** to see installed profiles
2. Select profile by **ICCID** from the dropdown
3. Click **Delete Profile**
4. Confirm deletion in popup dialog
5. Profile will be removed from modem

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
├── root/
│   ├── etc/config/lpac               # UCI configuration file
│   └── usr/bin/
│       └── lpac_json                 # Wrapper script (CLI → JSON)
```

### Communication Flow

```bash
Web Browser (JavaScript)
    ↓ XHR.post()
Lua Controller (lpac.lua)
    ↓ exec()
Wrapper Script (lpac_json)
    ↓ shell exec + environment variables
lpac Binary
    ↓ AT/MBIM protocol
Quectel Modem (EP06-E, RG500Q, etc.)
    ↓ HTTP/HTTPS
SM-DP+ Server (Carrier)
```

### API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/admin/network/lpac/add` | POST | Install eSIM profile |
| `/admin/network/lpac/delete` | POST | Delete profile by ICCID |
| `/admin/network/lpac/list` | GET | List installed profiles |
| `/admin/network/lpac/status` | GET | Get modem status |
| `/admin/network/lpac/detect_devices` | GET | Detect available modem devices |
| `/admin/network/lpac/get_settings` | GET | Get current device settings |
| `/admin/network/lpac/save_settings` | POST | Save device settings to UCI |

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

### UCI Configuration

The application stores device settings in UCI configuration file `/etc/config/lpac`:

```uci
config settings 'device'
    option driver 'at'                    # Driver: at, at_csim, or mbim
    option at_device '/dev/ttyUSB2'       # AT serial device
    option mbim_device '/dev/cdc-wdm0'    # MBIM device
    option http_client 'curl'             # HTTP client: curl or wget
```

### Driver Selection

**AT Driver** (default, recommended for EP06-E):
```bash
uci set lpac.device.driver='at'
uci set lpac.device.at_device='/dev/ttyUSB2'
uci commit lpac
```

**AT_CSIM Driver** (faster, may not work on all modems):
```bash
uci set lpac.device.driver='at_csim'
uci set lpac.device.at_device='/dev/ttyUSB2'
uci commit lpac
```

**MBIM Driver** (for MBIM-capable modems):
```bash
uci set lpac.device.driver='mbim'
uci set lpac.device.mbim_device='/dev/cdc-wdm0'
uci commit lpac
```

### Timeout Settings

Default timeout: 90 seconds

To adjust timeout, edit the wrapper script:

```bash
vi /usr/bin/lpac_json
# Modify line:
TIMEOUT=90
```

## Troubleshooting

### "Modem not accessible" Error

**Problem**: Device not found or inaccessible

**Solutions**:

```bash
# For AT driver - check serial devices
ls -l /dev/ttyUSB*

# Fix permissions
chmod 666 /dev/ttyUSB2

# Test AT communication
echo -e "AT\r\n" > /dev/ttyUSB2

# For MBIM driver - check MBIM devices
ls -l /dev/cdc-wdm*
chmod 666 /dev/cdc-wdm0

# Test MBIM communication
mbimcli -d /dev/cdc-wdm0 --query-device-caps
```

### "lpac binary not found" Error

**Problem**: Binary not installed or not in PATH

**Solutions**:

```bash
# Check if binary exists
which lpac

# Install binary
scp lpac root@192.168.1.1:/usr/bin/
chmod +x /usr/bin/lpac

# Test binary
lpac --version

# Set environment variables
export LPAC_APDU=at
export LPAC_APDU_AT_DEVICE=/dev/ttyUSB2
lpac chip info
```

### Installation Times Out

**Problem**: Profile download takes longer than timeout

**Solutions**:

- Increase timeout in `/usr/bin/lpac_json`
- Check internet connectivity: `ping 8.8.8.8`
- Verify SM-DP+ server is reachable
- Check for device conflicts (ModemManager might lock the device)

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
logread | grep -i lpac
logread | grep -i curl
logread | grep -i ttyUSB  # For AT driver
logread | grep -i mbim    # For MBIM driver

# Check for ModemManager conflicts
/etc/init.d/modemmanager stop
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
# Test with AT driver
/usr/bin/lpac_json -d at -t /dev/ttyUSB2 -h curl status

# Test add profile
/usr/bin/lpac_json -d at -t /dev/ttyUSB2 -h curl add "LPA:1$smdp$code" "1234"

# Test delete profile (by ICCID)
/usr/bin/lpac_json -d at -t /dev/ttyUSB2 -h curl delete "89012345678901234567"

# Test list profiles
/usr/bin/lpac_json -d at -t /dev/ttyUSB2 -h curl list

# Test with MBIM driver
/usr/bin/lpac_json -d mbim -m /dev/cdc-wdm0 -h curl status
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
- ICCIDs validated as strings (numeric, 19-20 digits)
- Driver selection validated (at, at_csim, mbim)
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
opkg list-installed | grep -E "luci|curl|lpac"

# Device status (AT driver)
ls -l /dev/ttyUSB*
echo -e "AT\r\n" > /dev/ttyUSB2

# Device status (MBIM driver)
ls -l /dev/cdc-wdm*
mbimcli -d /dev/cdc-wdm0 --query-device-caps

# Test lpac binary
export LPAC_APDU=at
export LPAC_APDU_AT_DEVICE=/dev/ttyUSB2
lpac chip info

# Test wrapper directly
/usr/bin/lpac_json -d at -t /dev/ttyUSB2 -h curl status

# System logs
logread | tail -100

# LuCI logs
logread | grep luci

# lpac-specific logs
logread | grep -i lpac
```

### Common Issues

See [Troubleshooting](#troubleshooting) section above.

## License

MIT License - Copyright 2025 Kerem

## Credits

- Based on lpac v2.3.0 by estkme-group
- LuCI framework by OpenWrt Project
- GSMA RSP specification (SGP.22 v2.2.2)
- ETSI TS 127 007 specification for AT commands

## Changelog

### v2.0.0 (2025-01-XX)

- **Migration from quectel_lpad to lpac binary**
- Multi-driver support: AT, AT_CSIM, and MBIM
- ICCID-based profile management (replaced Profile ID 1-16)
- UCI configuration for device settings
- Automatic device detection
- Enable/disable profile support
- Device settings management via web UI
- Compatible with OpenWrt 19.07 through 24.10
- Comprehensive JSON wrapper (lpac_json) for CLI integration

### v1.0.0 (2024-12-XX)

- Initial release with quectel_lpad
- Basic profile add/delete operations
- QMI-only driver support
- Profile ID-based management (1-16)
