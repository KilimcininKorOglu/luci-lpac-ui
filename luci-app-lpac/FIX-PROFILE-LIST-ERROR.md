# Fix for "Failed to list profiles" Error

## Problem

When accessing the LuCI web interface at `http://192.168.1.1/cgi-bin/luci/admin/network/lpac/list`, the profile list was returning an error:

```json
{
  "error": "Failed to list profiles",
  "success": false,
  "profiles": []
}
```

## Root Causes Identified

### ⚠️ CRITICAL: Missing `timeout` command (OpenWrt 19.07.10)

**Issue:** The `timeout` command is not available in OpenWrt 19.07.10:

```bash
root@OpenWRT-19:~# /usr/bin/lpac_json -d at -t /dev/ttyUSB2 -h curl list
{
  "success": false,
  "profiles": [],
  "error": "Failed to parse lpac response",
  "raw_output": "/usr/bin/lpac_json: line 291: timeout: not found "
}
```

**Fix:** Created `run_with_timeout()` wrapper function that:
- Checks if `timeout` command exists
- Falls back to running command directly if `timeout` is not available
- Maintains compatibility with newer OpenWrt versions that have `timeout`

```sh
run_with_timeout() {
    local timeout_duration="$1"
    shift

    # Check if timeout command exists
    if command -v timeout >/dev/null 2>&1; then
        timeout "$timeout_duration" "$@"
        return $?
    fi

    # Fallback: Run without timeout on OpenWrt 19.07.10
    "$@"
    return $?
}
```

All `timeout` calls replaced with `run_with_timeout` wrapper.

## Original Root Causes

### 1. Device Check Bug (Line 160)

**Issue:** The device existence check didn't handle the case where `DEVICE_TO_CHECK` is empty (for `qmi_qrtr` driver):

```sh
# Old code - FAILS when DEVICE_TO_CHECK is empty
if [ ! -e "$DEVICE_TO_CHECK" ]; then
    echo "{\"success\": false, \"error\": \"Device not found at $DEVICE_TO_CHECK\"}"
    exit 1
fi
```

**Fix:** Added check to skip device validation when `DEVICE_TO_CHECK` is empty:

```sh
# New code - Skips check for qmi_qrtr
if [ -n "$DEVICE_TO_CHECK" ] && [ ! -e "$DEVICE_TO_CHECK" ]; then
    echo "{\"success\": false, \"error\": \"Device not found at $DEVICE_TO_CHECK\"}"
    exit 1
fi
```

### 2. Poor Error Handling in extract_profiles() (Line 91-100)

**Issue:** When lpac fails to return valid JSON or returns an empty response, the `code` variable becomes empty, but the error handling didn't check for this case. This resulted in cryptic "Failed to list profiles" messages without any debugging information.

**Fix:** Added better error handling with raw output for debugging:

```sh
# Extract code from payload
local code=$(echo "$lpac_output" | grep -o '"code"[[:space:]]*:[[:space:]]*[0-9-]*' | head -1 | grep -o '[0-9-]*$')

# If no code found or code is empty, return raw error
if [ -z "$code" ]; then
    echo "{"
    echo "  \"success\": false,"
    echo "  \"profiles\": [],"
    echo "  \"error\": \"Failed to parse lpac response\","
    echo "  \"raw_output\": \"$(echo "$lpac_output" | sed 's/"/\\"/g' | tr '\n' ' ')\""
    echo "}"
    return
fi

if [ "$code" != "0" ]; then
    local message=$(echo "$lpac_output" | grep -o '"message"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
    echo "{"
    echo "  \"success\": false,"
    echo "  \"profiles\": [],"
    echo "  \"error\": \"${message:-Failed to list profiles} (code: $code)\","
    echo "  \"raw_output\": \"$(echo "$lpac_output" | sed 's/"/\\"/g' | tr '\n' ' ')\""
    echo "}"
    return
fi
```

## Files Modified

- `root/usr/bin/lpac_json`:
  - **Lines 15-30**: Added `run_with_timeout()` wrapper function for OpenWrt 19.07.10 compatibility
  - **Line 160**: Fixed device check to handle empty `DEVICE_TO_CHECK`
  - **Lines 91-113**: Added better error handling with raw output logging
  - **Lines 225, 251, 273, 294, 308, 323, 337**: Replaced all `timeout` calls with `run_with_timeout`

## Version History

- **v1.0.1-5** (2025-10-28): Fixed missing `timeout` command issue on OpenWrt 19.07.10
- **v1.0.1-4** (2025-10-28): Added better error handling and device check fix
- **v1.0.1-3** (2025-10-27): Initial release

## Testing

After applying the fixes, test the profile list endpoint:

```bash
# SSH to router
ssh root@192.168.1.1

# Test lpac_json directly
/usr/bin/lpac_json -d at -t /dev/ttyUSB2 -h curl list

# Expected output (if no profiles):
{
  "success": true,
  "profiles": [],
  "message": "No profiles installed"
}

# If still failing, check raw_output field for debugging
```

## Debugging Steps

If the error persists after applying these fixes:

1. **Check if device exists:**
   ```bash
   ls -l /dev/ttyUSB2
   # Should show: crw-rw---- 1 root dialout ...
   ```

2. **Check device permissions:**
   ```bash
   chmod 666 /dev/ttyUSB2
   ```

3. **Test lpac binary directly:**
   ```bash
   export LPAC_APDU=at
   export LPAC_APDU_AT_DEVICE=/dev/ttyUSB2
   export LPAC_HTTP=curl
   /usr/lib/lpac profile list
   ```

4. **Check modem AT port:**
   ```bash
   # Send AT command to modem
   echo -e "AT\r" > /dev/ttyUSB2
   cat /dev/ttyUSB2
   # Should respond with "OK"
   ```

5. **Check if correct AT port:**
   - Quectel modems typically have 3 ports:
     - `/dev/ttyUSB0` - DM (Diagnostic)
     - `/dev/ttyUSB1` - NMEA (GPS)
     - `/dev/ttyUSB2` - AT (Commands) ← **Use this one**
     - `/dev/ttyUSB3` - Modem

## Installation

Install the fixed package:

```bash
# Copy to router
scp luci-app-lpac_1.0.1-4_all.ipk root@192.168.1.1:/tmp/

# SSH to router
ssh root@192.168.1.1

# Install (will upgrade existing version)
opkg remove luci-app-lpac
opkg install /tmp/luci-app-lpac_1.0.1-4_all.ipk

# Clear browser cache and reload
```

## Related Issues

- Issue with OpenWrt 19.07.10 curl compilation: See `xe300-19.07.10/BUILD-FIX-NOTES.md`
- Driver compatibility: Ensure correct driver is selected (AT for Quectel modems)
