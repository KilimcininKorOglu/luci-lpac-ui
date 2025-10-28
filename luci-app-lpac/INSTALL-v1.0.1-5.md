# Installation Instructions - luci-app-lpac v1.0.1-5

## What's New in v1.0.1-5

**🔧 Critical Fix:** Resolves "timeout: not found" error on OpenWrt 19.07.10

This version fixes compatibility issues with older OpenWrt versions that don't have the `timeout` command installed.

### Changes:
- ✅ Added `run_with_timeout()` wrapper function for backward compatibility
- ✅ All lpac operations now work on OpenWrt 19.07.10 and newer versions
- ✅ Better error messages with `raw_output` field for debugging
- ✅ Fixed device check for qmi_qrtr driver

## Installation on GL-XE300 (OpenWrt 19.07.10)

### Method 1: Web Interface (LuCI)

1. **Download the package:**
   - Package: `luci-app-lpac_1.0.1-5_all.ipk` (32KB)

2. **Upload via LuCI:**
   ```
   System → Software → Upload Package
   → Select luci-app-lpac_1.0.1-5_all.ipk
   → Click "Upload"
   ```

3. **Access the interface:**
   ```
   Network → eSIM (LPAC)
   ```

### Method 2: Command Line (SSH)

1. **Copy package to router:**
   ```bash
   scp luci-app-lpac_1.0.1-5_all.ipk root@192.168.1.1:/tmp/
   ```

2. **SSH to router:**
   ```bash
   ssh root@192.168.1.1
   ```

3. **Remove old version (if installed):**
   ```bash
   opkg remove luci-app-lpac
   ```

4. **Install new version:**
   ```bash
   opkg install /tmp/luci-app-lpac_1.0.1-5_all.ipk
   ```

5. **Verify installation:**
   ```bash
   /usr/bin/lpac_json -d at -t /dev/ttyUSB2 -h curl list
   ```

   **Expected output (if no profiles):**
   ```json
   {
     "success": true,
     "profiles": [],
     "message": "No profiles installed"
   }
   ```

## Configuration

### Default Settings

The package is pre-configured for Quectel EP06-E modems:

- **Driver:** AT (default)
- **AT Device:** `/dev/ttyUSB2`
- **HTTP Client:** curl

### Changing Settings

1. **Via LuCI Web Interface:**
   ```
   Network → eSIM (LPAC) → Settings (gear icon)
   ```

2. **Via UCI (command line):**
   ```bash
   uci set lpac.device.driver='at'
   uci set lpac.device.at_device='/dev/ttyUSB2'
   uci set lpac.device.http_client='curl'
   uci commit lpac
   ```

### Driver Options

- **at** - AT commands via serial (Quectel modems) ← **Recommended for GL-XE300**
- **at_csim** - AT+CSIM commands
- **mbim** - MBIM protocol (requires mbimcli)
- **qmi** - QMI protocol (requires qmicli)
- **qmi_qrtr** - QMI QRTR (Qualcomm IPC Router)

## Troubleshooting

### 1. Check if device exists

```bash
ls -l /dev/ttyUSB*
```

Expected output:
```
crw-rw---- 1 root dialout 188, 0 Oct 28 09:00 /dev/ttyUSB0
crw-rw---- 1 root dialout 188, 1 Oct 28 09:00 /dev/ttyUSB1
crw-rw---- 1 root dialout 188, 2 Oct 28 09:00 /dev/ttyUSB2  ← Use this
crw-rw---- 1 root dialout 188, 3 Oct 28 09:00 /dev/ttyUSB3
```

### 2. Test modem AT port

```bash
# Send AT command
echo -e "AT\r" > /dev/ttyUSB2
cat /dev/ttyUSB2 &
sleep 1
killall cat
```

Expected response: `OK`

### 3. Fix device permissions

```bash
chmod 666 /dev/ttyUSB2
```

### 4. Test lpac binary directly

```bash
export LPAC_APDU=at
export LPAC_APDU_AT_DEVICE=/dev/ttyUSB2
export LPAC_HTTP=curl
/usr/lib/lpac profile list
```

### 5. Check lpac_json wrapper

```bash
/usr/bin/lpac_json -d at -t /dev/ttyUSB2 -h curl list
```

If you still see errors, the response will now include a `raw_output` field showing the exact error from lpac.

## Dependencies

The following packages will be automatically installed:

- **libcurl** - HTTP client library
- **libpthread** - POSIX threads library
- **libc** - Standard C library
- **luci-base** - LuCI web framework

## Package Contents

- `/usr/lib/lua/luci/controller/lpac.lua` - LuCI controller
- `/usr/lib/lua/luci/view/lpac/profiles.htm` - Web UI template
- `/usr/bin/lpac_json` - Wrapper script (with timeout fix)
- `/etc/config/lpac` - UCI configuration file

## Web Interface Usage

After installation, access the web interface at:

```
http://192.168.1.1/cgi-bin/luci/admin/network/lpac
```

**Features:**
- 📋 List installed eSIM profiles
- ➕ Download new profiles (via activation code)
- ✅ Enable/disable profiles
- 🗑️ Delete profiles
- ⚙️ Configure modem settings
- 🔍 Auto-detect modem devices

## Related Packages

You also need to install the lpac binary:

```bash
opkg install lpac_2.3.0-19_mips_24kc.ipk
```

See `xe300-19.07.10/output/` for the lpac binary package.

## Support

- **Documentation:** See `FIX-PROFILE-LIST-ERROR.md` for troubleshooting
- **Build Notes:** See `BUILD-FIX-NOTES.md` for OpenWrt 19.07.10 build issues
- **lpac GitHub:** https://github.com/estkme-group/lpac

## Changelog

### v1.0.1-5 (2025-10-28)
- 🔧 **Fixed:** Missing `timeout` command on OpenWrt 19.07.10
- 🔧 **Added:** `run_with_timeout()` wrapper for compatibility
- 📝 **Improved:** Better error messages with raw output debugging

### v1.0.1-4 (2025-10-28)
- 🔧 **Fixed:** Device existence check for qmi_qrtr driver
- 📝 **Improved:** Error handling with detailed debugging info

### v1.0.1-3 (2025-10-27)
- 🎉 Initial release
