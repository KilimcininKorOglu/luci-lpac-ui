# LuCI Web Interface Integration Guide

This guide explains how to integrate `quectel_lpad` with OpenWrt's LuCI web interface for eSIM profile management.

## Overview

`quectel_lpad` is a command-line tool with **text output** (not JSON). To integrate with LuCI, you need to:

1. Execute the binary from LuCI backend (Lua)
2. Parse text output
3. Present results in web UI

## Output Format Analysis

### Application Output: **Human-Readable Text**

**Normal Mode (Debug Off):**

```bash
quectel_lpad -A "activation_code"
```

- ASCII art banner (green)
- Progress bar
- Success/error messages (colored)

**Debug Mode (-D 1):**

```bash
quectel_lpad -D 1 -A "activation_code"
```

- Detailed QMI messages
- HTTP transaction logs
- Payload details
- Timestamped debug output

**Example Output:**

```bash
[DEBUG] [MAIN] Log level         : 1
[DEBUG] [MAIN] ########## Add profile ##########
[DEBUG] [MAIN] SIM slot          : 1
[DEBUG] [MAIN] Activation code   : LPA:1$smdp.example.com$...
[DEBUG] [MAIN] TOKEN ID : 1
[DEBUG] [MAIN] PERCENTAGE: 45
\033[32mThe result of profile installation notifies smdp+ success!\033[0m
```

**Log Levels:**

- `0`: Banner + progress bar only
- `1`: DEBUG - All details (QMI, HTTP, payload)
- `2`: INFO - General information
- `3`: WARN - Warnings
- `4`: ERROR - Errors only

**Success Indicators:**

- Green text: `\033[32mprofile installation.*success\033[0m`
- Pattern match: `"notifies smdp+ success"`
- Pattern match: `"deleted.*success"`

---

## Integration Methods

### Method 1: Shell Exec + Output Parsing (Simplest)

Execute `quectel_lpad` as shell command and parse output.

#### LuCI Controller

**File:** `/usr/lib/lua/luci/controller/esim.lua`

```lua
module("luci.controller.esim", package.seeall)

function index()
    entry({"admin", "network", "esim"}, alias("admin", "network", "esim", "profiles"), _("eSIM"), 60)
    entry({"admin", "network", "esim", "profiles"}, template("esim/profiles"), _("Profiles"), 1)
    entry({"admin", "network", "esim", "add"}, call("action_add_profile"), nil).leaf = true
    entry({"admin", "network", "esim", "delete"}, call("action_delete_profile"), nil).leaf = true
    entry({"admin", "network", "esim", "status"}, call("action_get_status"), nil).leaf = true
end

function action_add_profile()
    local http = require "luci.http"
    local util = require "luci.util"
    local json = require "luci.jsonc"

    local activation_code = http.formvalue("activation_code")
    local confirmation_code = http.formvalue("confirmation_code")

    if not activation_code or activation_code == "" then
        http.prepare_content("application/json")
        http.write_json({
            success = false,
            error = "Activation code required"
        })
        return
    end

    -- Build command
    local cmd = string.format("/usr/bin/quectel_lpad -D 1 -A '%s'",
                              util.shellquote(activation_code))

    if confirmation_code and confirmation_code ~= "" then
        cmd = cmd .. string.format(" -C '%s'", util.shellquote(confirmation_code))
    end

    -- Execute and capture output
    local output = util.exec(cmd .. " 2>&1")

    -- Parse output
    local success = string.match(output, "profile installation.*success") or
                    string.match(output, "notifies smdp%+ success")
    local error_msg = string.match(output, "ERROR[:%s]+(.+)")
    local percentage = string.match(output, "PERCENTAGE:%s*(%d+)")

    http.prepare_content("application/json")
    http.write_json({
        success = success and true or false,
        output = output,
        error = error_msg,
        percentage = tonumber(percentage) or 0
    })
end

function action_delete_profile()
    local http = require "luci.http"
    local util = require "luci.util"

    local profile_id = tonumber(http.formvalue("profile_id"))

    if not profile_id or profile_id < 1 or profile_id > 8 then
        http.prepare_content("application/json")
        http.write_json({
            success = false,
            error = "Invalid profile ID (1-8)"
        })
        return
    end

    local cmd = string.format("/usr/bin/quectel_lpad -D 1 -R %d 2>&1", profile_id)
    local output = util.exec(cmd)

    local success = string.match(output, "deleted.*success")

    http.prepare_content("application/json")
    http.write_json({
        success = success and true or false,
        output = output
    })
end

function action_get_status()
    local http = require "luci.http"
    local util = require "luci.util"

    -- Query modem status using qmicli or AT commands
    local cmd = "qmicli -d /dev/cdc-wdm0 --uim-get-card-status 2>&1"
    local output = util.exec(cmd)

    http.prepare_content("application/json")
    http.write_json({
        status = output
    })
end
```

#### LuCI View (HTML/JS)

**File:** `/usr/lib/lua/luci/view/esim/profiles.htm`

```html
<%+header%>

<div class="cbi-map">
    <h2><%:eSIM Profile Management%></h2>

    <div class="cbi-section">
        <h3><%:Add New Profile%></h3>
        <div class="cbi-value">
            <label class="cbi-value-title"><%:Activation Code%></label>
            <div class="cbi-value-field">
                <input type="text" id="activation_code"
                       placeholder="LPA:1$smdp.example.com$..."
                       style="width: 100%; max-width: 500px;"/>
                <br/>
                <small>Format: LPA:1$SM-DP+_ADDRESS$ACTIVATION_CODE</small>
            </div>
        </div>
        <div class="cbi-value">
            <label class="cbi-value-title"><%:Confirmation Code%> (optional)</label>
            <div class="cbi-value-field">
                <input type="text" id="confirmation_code" style="width: 200px;"/>
            </div>
        </div>
        <div class="cbi-value">
            <button class="cbi-button cbi-button-apply" onclick="addProfile()">
                <%:Add Profile%>
            </button>
        </div>
        <div id="add_progress" style="margin-top: 10px; display: none;">
            <div style="width: 100%; max-width: 500px; background: #ddd; border-radius: 3px;">
                <div id="progress_bar" style="width: 0%; height: 25px; background: #4CAF50;
                                              border-radius: 3px; text-align: center;
                                              line-height: 25px; color: white;">
                    0%
                </div>
            </div>
        </div>
        <div id="add_status" style="margin-top: 10px;"></div>
        <div id="add_output" style="margin-top: 10px; padding: 10px;
                                    background: #f5f5f5; font-family: monospace;
                                    white-space: pre-wrap; display: none;
                                    max-height: 300px; overflow-y: auto;">
        </div>
    </div>

    <div class="cbi-section" style="margin-top: 20px;">
        <h3><%:Delete Profile%></h3>
        <div class="cbi-value">
            <label class="cbi-value-title"><%:Profile ID%></label>
            <div class="cbi-value-field">
                <select id="delete_profile_id">
                    <% for i=1,8 do %>
                    <option value="<%=i%>">Profile <%=i%></option>
                    <% end %>
                </select>
            </div>
        </div>
        <div class="cbi-value">
            <button class="cbi-button cbi-button-remove" onclick="deleteProfile()">
                <%:Delete Profile%>
            </button>
        </div>
        <div id="delete_status" style="margin-top: 10px;"></div>
    </div>

    <div class="cbi-section" style="margin-top: 20px;">
        <h3><%:Modem Status%></h3>
        <div class="cbi-value">
            <button class="cbi-button cbi-button-action" onclick="refreshStatus()">
                <%:Refresh Status%>
            </button>
        </div>
        <div id="modem_status" style="margin-top: 10px; padding: 10px;
                                      background: #f5f5f5; font-family: monospace;
                                      white-space: pre-wrap; display: none;">
        </div>
    </div>
</div>

<script>
function addProfile() {
    var activation_code = document.getElementById('activation_code').value;
    var confirmation_code = document.getElementById('confirmation_code').value;
    var statusDiv = document.getElementById('add_status');
    var outputDiv = document.getElementById('add_output');
    var progressDiv = document.getElementById('add_progress');
    var progressBar = document.getElementById('progress_bar');

    if (!activation_code || activation_code.length < 10) {
        statusDiv.innerHTML = '<span style="color: red;">✗ Please enter a valid activation code</span>';
        return;
    }

    statusDiv.innerHTML = '<em>Installing profile, please wait (this may take 30-60 seconds)...</em>';
    outputDiv.style.display = 'none';
    progressDiv.style.display = 'block';
    progressBar.style.width = '0%';
    progressBar.innerHTML = '0%';

    XHR.post('<%=url("admin/network/esim/add")%>', {
        activation_code: activation_code,
        confirmation_code: confirmation_code
    }, function(x, data) {
        progressDiv.style.display = 'none';

        if (data.success) {
            statusDiv.innerHTML = '<span style="color: green; font-weight: bold;">✓ Profile installed successfully!</span>';
            document.getElementById('activation_code').value = '';
            document.getElementById('confirmation_code').value = '';
        } else {
            statusDiv.innerHTML = '<span style="color: red; font-weight: bold;">✗ Installation failed: ' +
                                 (data.error || 'Unknown error') + '</span>';
        }

        if (data.output) {
            outputDiv.innerHTML = data.output;
            outputDiv.style.display = 'block';
        }
    });
}

function deleteProfile() {
    var profile_id = document.getElementById('delete_profile_id').value;
    var statusDiv = document.getElementById('delete_status');

    if (!confirm('Are you sure you want to delete profile ' + profile_id + '?')) {
        return;
    }

    statusDiv.innerHTML = '<em>Deleting profile...</em>';

    XHR.post('<%=url("admin/network/esim/delete")%>', {
        profile_id: profile_id
    }, function(x, data) {
        if (data.success) {
            statusDiv.innerHTML = '<span style="color: green; font-weight: bold;">✓ Profile deleted successfully!</span>';
        } else {
            statusDiv.innerHTML = '<span style="color: red; font-weight: bold;">✗ Deletion failed</span>';
        }
    });
}

function refreshStatus() {
    var statusDiv = document.getElementById('modem_status');
    statusDiv.innerHTML = 'Loading...';
    statusDiv.style.display = 'block';

    XHR.get('<%=url("admin/network/esim/status")%>', null, function(x, data) {
        statusDiv.innerHTML = data.status || 'No status available';
    });
}
</script>

<%+footer%>
```

**Pros:**

- ✅ Simple implementation
- ✅ No C code changes
- ✅ Easy to debug

**Cons:**

- ❌ No real-time progress updates
- ❌ Blocking operation (30-60s wait)
- ❌ Text parsing fragile

---

### Method 2: Wrapper Script + JSON Output (Recommended)

Create a wrapper script that converts text output to JSON.

#### Wrapper Script

**File:** `/usr/bin/quectel_lpad_json`

```bash
#!/bin/sh
# quectel_lpad JSON wrapper for LuCI integration

ACTION="$1"
shift

OUTPUT_FILE="/tmp/quectel_lpad_output.$$"
EXIT_CODE=0

case "$ACTION" in
    add)
        ACTIVATION_CODE="$1"
        CONFIRMATION_CODE="$2"

        if [ -z "$ACTIVATION_CODE" ]; then
            echo '{"success":false,"error":"Activation code required"}'
            exit 1
        fi

        if [ -z "$CONFIRMATION_CODE" ]; then
            /usr/bin/quectel_lpad -D 1 -A "$ACTIVATION_CODE" > "$OUTPUT_FILE" 2>&1
        else
            /usr/bin/quectel_lpad -D 1 -A "$ACTIVATION_CODE" -C "$CONFIRMATION_CODE" > "$OUTPUT_FILE" 2>&1
        fi
        EXIT_CODE=$?
        ;;

    delete)
        PROFILE_ID="$1"

        if [ -z "$PROFILE_ID" ] || [ "$PROFILE_ID" -lt 1 ] || [ "$PROFILE_ID" -gt 8 ]; then
            echo '{"success":false,"error":"Invalid profile ID (1-8)"}'
            exit 1
        fi

        /usr/bin/quectel_lpad -D 1 -R "$PROFILE_ID" > "$OUTPUT_FILE" 2>&1
        EXIT_CODE=$?
        ;;

    status)
        # Query modem using qmicli
        qmicli -d /dev/cdc-wdm0 --uim-get-card-status > "$OUTPUT_FILE" 2>&1
        EXIT_CODE=$?
        ;;

    *)
        echo '{"success":false,"error":"Invalid action. Use: add, delete, status"}'
        exit 1
        ;;
esac

# Parse output
OUTPUT=$(cat "$OUTPUT_FILE" | sed 's/\x1b\[[0-9;]*m//g')  # Strip ANSI colors
SUCCESS=false

# Check for success patterns
if echo "$OUTPUT" | grep -qi "success"; then
    SUCCESS=true
fi

# Extract error message
ERROR=$(echo "$OUTPUT" | grep -i "ERROR" | head -1 | sed 's/.*ERROR[: ]*//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

# Extract percentage
PERCENTAGE=$(echo "$OUTPUT" | grep "PERCENTAGE:" | tail -1 | sed 's/.*PERCENTAGE:[[:space:]]*//')

# Extract profile info (for status queries)
SLOT=$(echo "$OUTPUT" | grep "SLOT" | head -1 | sed 's/.*SLOT[: ]*//')

# Escape output for JSON
OUTPUT_ESCAPED=$(echo "$OUTPUT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}')

# Generate JSON output
cat <<EOF
{
    "success": $SUCCESS,
    "exit_code": $EXIT_CODE,
    "error": ${ERROR:+\"$ERROR\"},
    "percentage": ${PERCENTAGE:-0},
    "slot": ${SLOT:-null},
    "output": "$OUTPUT_ESCAPED"
}
EOF

rm -f "$OUTPUT_FILE"
exit $EXIT_CODE
```

Make it executable:

```bash
chmod +x /usr/bin/quectel_lpad_json
```

#### LuCI Controller (Simplified)

```lua
function action_add_profile()
    local http = require "luci.http"
    local util = require "luci.util"
    local json = require "luci.jsonc"

    local activation_code = http.formvalue("activation_code")
    local confirmation_code = http.formvalue("confirmation_code") or ""

    local cmd = string.format("/usr/bin/quectel_lpad_json add '%s' '%s'",
                              util.shellquote(activation_code),
                              util.shellquote(confirmation_code))

    local output = util.exec(cmd)
    local result = json.parse(output)

    http.prepare_content("application/json")
    http.write_json(result or {success = false, error = "Failed to parse response"})
end

function action_delete_profile()
    local http = require "luci.http"
    local util = require "luci.util"
    local json = require "luci.jsonc"

    local profile_id = http.formvalue("profile_id")

    local cmd = string.format("/usr/bin/quectel_lpad_json delete '%s'",
                              util.shellquote(profile_id))

    local output = util.exec(cmd)
    local result = json.parse(output)

    http.prepare_content("application/json")
    http.write_json(result or {success = false, error = "Failed to parse response"})
end
```

**Pros:**

- ✅ Clean JSON API
- ✅ No C code changes
- ✅ Easy error handling
- ✅ Maintainable
- ✅ Testable independently

**Cons:**

- ❌ Still no real-time updates
- ❌ Extra wrapper layer

**Testing:**

```bash
# Test add profile
/usr/bin/quectel_lpad_json add "LPA:1\$smdp.example.com\$CODE"

# Test delete profile
/usr/bin/quectel_lpad_json delete 1

# Test status
/usr/bin/quectel_lpad_json status
```

---

### Method 3: UBUS Integration (OpenWrt Native)

Use OpenWrt's native IPC mechanism (UBUS).

#### UBUS Service Script

**File:** `/usr/libexec/rpcd/esim`

```sh
#!/bin/sh

. /usr/share/libubox/jshn.sh

case "$1" in
    list)
        cat <<EOF
{
    "add_profile": {
        "activation_code": "string",
        "confirmation_code": "string"
    },
    "delete_profile": {
        "profile_id": "integer"
    },
    "get_status": {}
}
EOF
        ;;

    call)
        case "$2" in
            add_profile)
                read -r INPUT
                json_load "$INPUT"
                json_get_var ACTIVATION_CODE activation_code
                json_get_var CONFIRMATION_CODE confirmation_code

                # Use wrapper script
                if [ -n "$CONFIRMATION_CODE" ]; then
                    RESULT=$(/usr/bin/quectel_lpad_json add "$ACTIVATION_CODE" "$CONFIRMATION_CODE")
                else
                    RESULT=$(/usr/bin/quectel_lpad_json add "$ACTIVATION_CODE")
                fi

                echo "$RESULT"
                ;;

            delete_profile)
                read -r INPUT
                json_load "$INPUT"
                json_get_var PROFILE_ID profile_id

                RESULT=$(/usr/bin/quectel_lpad_json delete "$PROFILE_ID")
                echo "$RESULT"
                ;;

            get_status)
                RESULT=$(/usr/bin/quectel_lpad_json status)
                echo "$RESULT"
                ;;
        esac
        ;;
esac
```

Make it executable:

```bash
chmod +x /usr/libexec/rpcd/esim
```

Restart rpcd:

```bash
/etc/init.d/rpcd restart
```

#### LuCI Controller (UBUS)

```lua
function action_add_profile()
    local http = require "luci.http"
    local ubus = require "ubus"

    local conn = ubus.connect()
    if not conn then
        http.prepare_content("application/json")
        http.write_json({success = false, error = "UBUS connection failed"})
        return
    end

    local result = conn:call("esim", "add_profile", {
        activation_code = http.formvalue("activation_code"),
        confirmation_code = http.formvalue("confirmation_code") or ""
    })

    conn:close()

    http.prepare_content("application/json")
    http.write_json(result)
end

function action_delete_profile()
    local http = require "luci.http"
    local ubus = require "ubus"

    local conn = ubus.connect()
    if not conn then
        http.prepare_content("application/json")
        http.write_json({success = false, error = "UBUS connection failed"})
        return
    end

    local result = conn:call("esim", "delete_profile", {
        profile_id = tonumber(http.formvalue("profile_id"))
    })

    conn:close()

    http.prepare_content("application/json")
    http.write_json(result)
end
```

**Testing UBUS:**

```bash
# List methods
ubus list esim

# Call add_profile
ubus call esim add_profile '{"activation_code":"LPA:1$smdp.example.com$CODE"}'

# Call delete_profile
ubus call esim delete_profile '{"profile_id":1}'

# Call get_status
ubus call esim get_status
```

**Pros:**

- ✅ OpenWrt native
- ✅ Secure IPC
- ✅ Standard approach
- ✅ Well documented

**Cons:**

- ❌ More complex setup
- ❌ Still wrapper-based

---

### Method 4: Background Daemon + Unix Socket (Advanced)

**Note:** This requires modifying the C code to run as a daemon.

#### Architecture

```bash
LuCI (Lua) → Unix Socket (/tmp/quectel_lpad.sock) → quectel_lpad_daemon (C)
                                                              ↓
                                                    QMI Messages → Modem
```

#### Daemon Features

- Long-running process
- Unix socket listener
- JSON-RPC protocol
- Real-time progress updates
- State management

#### Example Protocol

**Request:**

```json
{
    "id": 1,
    "method": "add_profile",
    "params": {
        "activation_code": "LPA:1$smdp.example.com$CODE",
        "confirmation_code": "1234"
    }
}
```

**Response (Progress):**

```json
{
    "id": 1,
    "status": "in_progress",
    "percentage": 45
}
```

**Response (Success):**

```json
{
    "id": 1,
    "status": "success",
    "result": {
        "profile_id": 2,
        "iccid": "89012345678901234567"
    }
}
```

**Pros:**

- ✅ Real-time progress
- ✅ Concurrent operations
- ✅ Professional architecture

**Cons:**

- ❌ Major C code changes required
- ❌ Complex implementation
- ❌ Daemon management overhead

---

## Recommended Approach

### For Production: **Method 2 (Wrapper Script + JSON)**

**Why:**

1. ✅ No C code changes
2. ✅ Clean JSON API
3. ✅ Easy error handling
4. ✅ Maintainable
5. ✅ Testable
6. ✅ Works with existing binary

### For Quick Prototype: **Method 1 (Shell Exec)**

### For OpenWrt Integration: **Method 3 (UBUS)**

### For Enterprise: **Method 4 (Daemon)** - if willing to modify C code

---

## Installation Steps

### Method 2 (Recommended)

1. **Copy files to router:**

```bash
scp quectel_lpad root@192.168.8.1:/usr/bin/
scp quectel_lpad_json root@192.168.8.1:/usr/bin/
chmod +x /usr/bin/quectel_lpad_json
```

2. **Create LuCI controller:**

```bash
scp esim.lua root@192.168.8.1:/usr/lib/lua/luci/controller/
```

3. **Create LuCI view:**

```bash
mkdir -p /usr/lib/lua/luci/view/esim
scp profiles.htm root@192.168.8.1:/usr/lib/lua/luci/view/esim/
```

4. **Clear LuCI cache:**

```bash
ssh root@192.168.8.1
rm -rf /tmp/luci-*
/etc/init.d/uhttpd restart
```

5. **Access web interface:**

```bash
http://192.168.8.1/cgi-bin/luci/admin/network/esim
```

---

## Security Considerations

1. **Input Validation:**
   - Sanitize activation codes
   - Validate profile IDs (1-8)
   - Use `util.shellquote()` for shell escaping

2. **Authentication:**
   - LuCI handles authentication
   - Ensure only admin users can access eSIM management

3. **Rate Limiting:**
   - Prevent multiple concurrent operations
   - Add cooldown between requests

4. **Error Messages:**
   - Don't expose system paths
   - Sanitize debug output

---

## Testing

### Manual Testing

```bash
# Test wrapper script
/usr/bin/quectel_lpad_json add "LPA:1\$smdp.example.com\$CODE"

# Test with invalid input
/usr/bin/quectel_lpad_json add ""

# Test delete
/usr/bin/quectel_lpad_json delete 1
```

### LuCI Testing

1. Open browser developer console
2. Monitor XHR requests
3. Check JSON responses
4. Verify error handling

### End-to-End Testing

1. Add profile with valid activation code
2. Add profile with invalid code
3. Delete existing profile
4. Delete non-existent profile
5. Check modem status

---

## Troubleshooting

### Common Issues

**1. "Command not found"**

```bash
# Check binary exists
ls -l /usr/bin/quectel_lpad
ls -l /usr/bin/quectel_lpad_json

# Check permissions
chmod +x /usr/bin/quectel_lpad
chmod +x /usr/bin/quectel_lpad_json
```

**2. "QMI device not found"**

```bash
# Check modem
ls -l /dev/cdc-wdm0
lsusb | grep Quectel

# Load kernel module
modprobe qmi_wwan
```

**3. "JSON parse error"**

```bash
# Test wrapper directly
/usr/bin/quectel_lpad_json add "test_code" | jq .

# Check for ANSI codes
/usr/bin/quectel_lpad_json add "test_code" | cat -A
```

**4. "Timeout"**

```bash
# Increase timeout in LuCI
# Default: 30s, eSIM operations may take 60s
XHR.timeout = 90000;  # 90 seconds
```

---

## Future Enhancements

1. **Real-time Progress:**
   - WebSocket integration
   - Server-Sent Events (SSE)
   - Polling mechanism

2. **Profile Management:**
   - List installed profiles
   - Enable/disable profiles
   - Set default profile

3. **Monitoring:**
   - Installation history
   - Error logs
   - Usage statistics

4. **Advanced Features:**
   - QR code scanner for activation codes
   - Bulk profile management
   - Profile templates

---

## References

- [LuCI Documentation](https://openwrt.org/docs/guide-developer/luci)
- [UBUS Documentation](https://openwrt.org/docs/techref/ubus)
- [OpenWrt SDK](https://openwrt.org/docs/guide-developer/toolchain/using_the_sdk)
- [GSMA RSP Specification](https://www.gsma.com/esim/remote-sim-provisioning/)

---

## Support

For issues and questions:

- Check `CLAUDE.md` for application architecture
- OpenWrt Forum: <https://forum.openwrt.com/>
- GL.iNet Forum: <https://forum.gl-inet.com/>
- Quectel Forum: <https://forums.quectel.com/>
