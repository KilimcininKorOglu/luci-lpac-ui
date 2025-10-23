# LuCI-app-lpac - Detailed Implementation Plan

## Project Overview

**Project Name:** luci-app-lpac
**Package Name:** luci-app-lpac
**Purpose:** Web-based LuCI interface for lpac eSIM management on OpenWrt
**Target OpenWrt Version:** 23.05 and above
**Language:** English (initial release)
**License:** GPL-3.0

## Executive Summary

luci-app-lpac will provide a user-friendly web interface for managing eSIM profiles on OpenWrt routers using the lpac command-line tool. This will enable users to:

- View eUICC chip information
- List, enable, disable, and delete eSIM profiles
- Download new profiles via activation codes
- Manage notifications
- Configure lpac settings (APDU/HTTP drivers, custom AID, etc.)

## System Requirements

### Dependencies

**Required Packages:**

- `lpac` (core functionality)
- `luci-base` (>= 23.05)
- `luci-lib-jsonc` (JSON parsing)
- `libuci-lua` (UCI configuration)
- `kmod-usb-serial` (for USB card readers - optional)
- `pcscd` (PC/SC daemon - optional)

**Optional Packages:**

- `qmi-utils` (Qualcomm modem support)
- `libmbim` (MBIM modem support)

### Hardware Support

**Supported eUICC Interfaces:**

- PC/SC compatible USB card readers
- Qualcomm QMI modems (built-in LTE modems)
- MBIM modems
- AT command-based modems

### Target Devices

- OpenWrt routers with USB ports (for USB readers)
- LTE routers with built-in modems (QMI/MBIM)
- x86 devices with card reader support

## Features and Functionality

### Phase 1: Core Features (MVP)

#### 1.1 Dashboard

- **eUICC Status Card**
  - Connection status (Connected/Disconnected)
  - EID display
  - Free memory information
  - Firmware version

- **Quick Actions**
  - Refresh profiles
  - Download profile
  - Settings

#### 1.2 Chip Information

- **Display Fields:**
  - EID (with copy button)
  - Default SM-DP+ address
  - Root SM-DS address
  - Profile version
  - SGP.22 version
  - Firmware version
  - Free non-volatile memory (KB)
  - Free volatile memory (KB)
  - Supported capabilities

- **Actions:**
  - Set default SM-DP+ address
  - Factory reset (with confirmation dialog)

#### 1.3 Profile Management

- **Profile List View**
  - Table/Card view toggle
  - Columns: ICCID (masked), Nickname, Provider, Profile Name, State, Class, Actions
  - Status indicators: Active (green), Inactive (gray)
  - Filter by state: All, Enabled, Disabled
  - Search by nickname/provider

- **Profile Actions:**
  - Enable profile (with refresh option)
  - Disable profile (with refresh option)
  - Delete profile (with confirmation)
  - Set/Edit nickname
  - View details (modal popup)

- **Profile Details Modal:**
  - Full ICCID
  - ISD-P AID
  - Service provider name
  - Profile name
  - Profile class
  - Icon (if available)
  - State

#### 1.4 Profile Download

- **Input Methods:**
  - Activation code (LPA:1$...) - text input
  - Manual entry fields:
    - SM-DP+ address
    - Matching ID
    - Confirmation code (optional)
    - Custom IMEI (optional)

- **Download Process:**
  - Real-time progress bar
  - Status messages (es10b_*, es9p_* steps)
  - Success/error notification
  - Auto-refresh profile list on success

- **Post-Download:**
  - Automatic notification processing option (checkbox)
  - Manual notification handling

#### 1.5 Notification Management

- **Notification List:**
  - Table: Sequence Number, Operation, Address, ICCID (masked), Actions
  - Operation types: Install, Enable, Disable, Delete

- **Actions:**
  - Process notification (with remove option)
  - Process all notifications
  - Remove notification

#### 1.6 Settings

- **APDU Driver Configuration:**
  - Driver selection: auto, pcsc, qmi, qmi_qrtr, mbim, at
  - Driver-specific settings:
    - QMI: Slot selection (1 or 2)
    - PC/SC: Reader name (auto-detect available readers)
    - AT: Device path

- **HTTP Driver Configuration:**
  - Driver selection: curl, stdio (testing)

- **Advanced Settings:**
  - Custom ISD-R AID
    - Preset: Default, 5ber, esim.me, xesim
    - Custom input field
  - ES10x Maximum Segment Size (6-255, default: 60)
  - Debug logging (enable/disable)

- **Auto-Notification Processing:**
  - Enable/disable automatic notification processing after downloads
  - Remove notifications after processing (checkbox)

#### 1.7 About

- **Application Information:**
  - luci-app-lpac version
  - lpac version (detected)
  - License information (GPL-3.0)
  - Project repository link

- **System Information:**
  - OpenWrt version
  - LuCI version
  - Detected hardware (reader/modem)

- **Credits:**
  - lpac project link and acknowledgment
  - Contributors
  - Support links (documentation, GitHub issues)

### Phase 2: Enhanced Features

#### 2.1 Profile Discovery (SM-DS)

- Discover available profiles from SM-DS server
- Display discovered profiles with provider info
- One-click download from discovery results

#### 2.2 Multi-SIM Support

- Support for multiple eUICC slots/readers
- Slot/reader selector in header
- Per-slot configuration

#### 2.3 Profile Import/Export

- Export profile list as JSON/CSV
- Import profiles from backup (if supported by hardware)

#### 2.4 Scheduled Operations

- Schedule profile switching based on:
  - Time of day
  - Day of week
  - Network availability

#### 2.5 Notifications

- Web notifications for profile events
- Email notifications (optional)

#### 2.6 Internationalization

- Multi-language support
- Initially: English
- Future: Chinese, Turkish, German, French, Spanish

### Phase 3: Advanced Features

#### 3.1 QR Code Support

- QR code scanning via uploaded image
- QR code generation for sharing profiles (if allowed by operator)

#### 3.2 Profile Analytics

- Data usage tracking per profile (if modem supports)
- Connection history
- Signal strength monitoring

#### 3.3 Backup and Restore

- Configuration backup
- Profile list export
- Settings migration between devices

## Technical Architecture

### Architecture Overview

```
┌─────────────────────────────────────────────────┐
│         Web Browser (User Interface)            │
│  HTML5 + CSS3 + JavaScript (LuCI Framework)     │
└───────────────────┬─────────────────────────────┘
                    │ HTTP/HTTPS
                    ▼
┌─────────────────────────────────────────────────┐
│              uhttpd (Web Server)                │
└───────────────────┬─────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│        LuCI Application (Lua Backend)           │
│  ┌──────────────────────────────────────────┐   │
│  │  Controller (lpac.lua)                   │   │
│  │  - Route handling                        │   │
│  │  - Authentication                        │   │
│  │  - Request validation                    │   │
│  └──────────────┬───────────────────────────┘   │
│                 │                                │
│  ┌──────────────▼───────────────────────────┐   │
│  │  Model Layer (lpac_model.lua)           │   │
│  │  - Business logic                        │   │
│  │  - Data transformation                   │   │
│  │  - Error handling                        │   │
│  └──────────────┬───────────────────────────┘   │
│                 │                                │
│  ┌──────────────▼───────────────────────────┐   │
│  │  lpac Interface (lpac_interface.lua)    │   │
│  │  - Command execution                     │   │
│  │  - JSON parsing                          │   │
│  │  - Stream handling                       │   │
│  └──────────────┬───────────────────────────┘   │
└─────────────────┼───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│         UCI Configuration System                │
│         /etc/config/lpac                        │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│         lpac CLI (Binary Executable)            │
│         Environment Variables + Arguments        │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│              Hardware Interface                 │
│  PC/SC Reader | QMI Modem | MBIM Modem         │
└─────────────────────────────────────────────────┘
```

### Directory Structure

```
luci-app-lpac/
├── Makefile                          # OpenWrt package Makefile
├── README.md                         # Project documentation
├── LICENSE                           # GPL-3.0 license
│
├── htdocs/
│   └── luci-static/
│       └── resources/
│           └── view/
│               └── lpac/
│                   ├── dashboard.js      # Dashboard view
│                   ├── chip.js          # Chip information view
│                   ├── profiles.js      # Profile management view
│                   ├── download.js      # Profile download view
│                   ├── notifications.js # Notification management view
│                   ├── settings.js      # Settings view
│                   └── about.js         # About/Info view
│
├── luasrc/
│   ├── controller/
│   │   └── lpac.lua                 # Main controller (routes)
│   │
│   ├── model/
│   │   └── lpac/
│   │       ├── lpac_interface.lua  # lpac CLI interface
│   │       ├── lpac_model.lua      # Business logic
│   │       └── lpac_util.lua       # Utility functions
│   │
│   └── view/
│       └── lpac/
│           └── (legacy views if needed)
│
├── root/
│   ├── etc/
│   │   ├── config/
│   │   │   └── lpac                # Default UCI configuration
│   │   │
│   │   └── uci-defaults/
│   │       └── 90-luci-lpac        # Post-installation script
│   │
│   └── usr/
│       └── share/
│           └── rpcd/
│               └── acl.d/
│                   └── luci-app-lpac.json  # RPC ACL permissions
│
└── po/                              # Translations (future)
    └── templates/
        └── lpac.pot
```

### File Descriptions

#### 1. Controller (`luasrc/controller/lpac.lua`)

**Purpose:** Define routes and handle HTTP requests

```lua
module("luci.controller.lpac", package.seeall)

function index()
    entry({"admin", "services", "lpac"},
          alias("admin", "services", "lpac", "dashboard"),
          _("eSIM Management"), 60)

    entry({"admin", "services", "lpac", "dashboard"},
          view("lpac/dashboard"),
          _("Dashboard"), 1)

    entry({"admin", "services", "lpac", "chip"},
          view("lpac/chip"),
          _("Chip Info"), 2)

    entry({"admin", "services", "lpac", "profiles"},
          view("lpac/profiles"),
          _("Profiles"), 3)

    entry({"admin", "services", "lpac", "download"},
          view("lpac/download"),
          _("Download"), 4)

    entry({"admin", "services", "lpac", "notifications"},
          view("lpac/notifications"),
          _("Notifications"), 5)

    entry({"admin", "services", "lpac", "settings"},
          view("lpac/settings"),
          _("Settings"), 6)

    entry({"admin", "services", "lpac", "about"},
          view("lpac/about"),
          _("About"), 7)

    -- API endpoints
    entry({"admin", "services", "lpac", "api", "chip_info"},
          call("action_chip_info")).leaf = true

    entry({"admin", "services", "lpac", "api", "get_version"},
          call("action_get_version")).leaf = true

    entry({"admin", "services", "lpac", "api", "list_profiles"},
          call("action_list_profiles")).leaf = true

    entry({"admin", "services", "lpac", "api", "enable_profile"},
          call("action_enable_profile")).leaf = true

    entry({"admin", "services", "lpac", "api", "download_profile"},
          call("action_download_profile")).leaf = true

    -- ... more API endpoints
end

function action_chip_info()
    local lpac = require "luci.model.lpac.lpac_interface"
    local result = lpac.get_chip_info()
    luci.http.prepare_content("application/json")
    luci.http.write_json(result)
end

function action_get_version()
    local lpac = require "luci.model.lpac.lpac_interface"
    local util = require "luci.util"
    local fs = require "nixio.fs"

    local result = {
        luci_app_lpac = "1.0.0",  -- Read from constant or file
        lpac = lpac.get_version(),
        openwrt = util.exec("cat /etc/openwrt_release | grep DISTRIB_RELEASE | cut -d= -f2 | tr -d \"'\""),
        luci = _VERSION or "unknown"
    }

    luci.http.prepare_content("application/json")
    luci.http.write_json(result)
end

-- ... more action handlers
```

#### 2. lpac Interface (`luasrc/model/lpac/lpac_interface.lua`)

**Purpose:** Wrap lpac CLI commands and parse JSON output

```lua
local json = require "luci.jsonc"
local util = require "luci.util"
local uci = require "luci.model.uci".cursor()

local M = {}

-- Execute lpac command with environment variables
function M.exec_lpac(args, env)
    env = env or {}

    -- Read configuration
    local apdu_driver = uci:get("lpac", "config", "apdu_driver") or "pcsc"
    local http_driver = uci:get("lpac", "config", "http_driver") or "curl"
    local custom_aid = uci:get("lpac", "config", "custom_aid") or ""
    local es10x_mss = uci:get("lpac", "config", "es10x_mss") or ""

    -- Build environment
    local env_str = string.format(
        "LPAC_APDU=%s LPAC_HTTP=%s %s %s",
        apdu_driver,
        http_driver,
        custom_aid ~= "" and "LPAC_CUSTOM_ISD_R_AID=" .. custom_aid or "",
        es10x_mss ~= "" and "LPAC_ES10X_MSS=" .. es10x_mss or ""
    )

    -- Execute command
    local cmd = string.format("%s lpac %s", env_str, table.concat(args, " "))
    local output = util.exec(cmd)

    -- Parse JSON
    local result = json.parse(output)
    return result
end

-- Get chip information
function M.get_chip_info()
    return M.exec_lpac({"chip", "info"})
end

-- List profiles
function M.list_profiles()
    return M.exec_lpac({"profile", "list"})
end

-- Enable profile
function M.enable_profile(iccid, refresh)
    refresh = refresh == nil and "1" or (refresh and "1" or "0")
    return M.exec_lpac({"profile", "enable", iccid, refresh})
end

-- Disable profile
function M.disable_profile(iccid, refresh)
    refresh = refresh == nil and "1" or (refresh and "1" or "0")
    return M.exec_lpac({"profile", "disable", iccid, refresh})
end

-- Delete profile
function M.delete_profile(iccid)
    return M.exec_lpac({"profile", "delete", iccid})
end

-- Download profile
function M.download_profile(opts)
    local args = {"profile", "download"}

    if opts.activation_code then
        table.insert(args, "-a")
        table.insert(args, opts.activation_code)
    else
        if opts.smdp then
            table.insert(args, "-s")
            table.insert(args, opts.smdp)
        end
        if opts.matching_id then
            table.insert(args, "-m")
            table.insert(args, opts.matching_id)
        end
    end

    if opts.confirmation_code then
        table.insert(args, "-c")
        table.insert(args, opts.confirmation_code)
    end

    if opts.imei then
        table.insert(args, "-i")
        table.insert(args, opts.imei)
    end

    return M.exec_lpac(args)
end

-- List notifications
function M.list_notifications()
    return M.exec_lpac({"notification", "list"})
end

-- Process notification
function M.process_notification(seq_number, remove)
    local args = {"notification", "process"}
    if remove then
        table.insert(args, "-r")
    end
    table.insert(args, tostring(seq_number))
    return M.exec_lpac(args)
end

-- List APDU drivers
function M.list_apdu_drivers()
    return M.exec_lpac({"driver", "apdu", "list"})
end

-- Get lpac version
function M.get_version()
    local result = M.exec_lpac({"version"})
    if result and result.payload and result.payload.data then
        return result.payload.data
    end
    return "unknown"
end

return M
```

#### 3. Frontend JavaScript (`htdocs/luci-static/resources/view/lpac/profiles.js`)

**Purpose:** Modern client-side view with reactive UI

```javascript
'use strict';
'require view';
'require rpc';
'require form';
'require ui';

var callChipInfo = rpc.declare({
    object: 'luci.lpac',
    method: 'chip_info',
    expect: { result: {} }
});

var callListProfiles = rpc.declare({
    object: 'luci.lpac',
    method: 'list_profiles',
    expect: { result: [] }
});

var callEnableProfile = rpc.declare({
    object: 'luci.lpac',
    method: 'enable_profile',
    params: ['iccid', 'refresh'],
    expect: { result: {} }
});

return view.extend({
    load: function() {
        return Promise.all([
            callListProfiles()
        ]);
    },

    render: function(data) {
        var profiles = data[0] || [];

        var m, s, o;

        m = new form.Map('lpac', _('Profile Management'));

        s = m.section(form.GridSection, 'profiles');
        s.anonymous = true;
        s.addremove = false;

        // Render profile table
        var table = E('div', { 'class': 'table cbi-section-table' }, [
            E('div', { 'class': 'tr cbi-section-table-titles' }, [
                E('div', { 'class': 'th' }, _('ICCID')),
                E('div', { 'class': 'th' }, _('Nickname')),
                E('div', { 'class': 'th' }, _('Provider')),
                E('div', { 'class': 'th' }, _('State')),
                E('div', { 'class': 'th' }, _('Actions'))
            ])
        ]);

        profiles.forEach(function(profile) {
            var row = E('div', { 'class': 'tr' }, [
                E('div', { 'class': 'td' }, profile.iccid.substr(0, 10) + '***'),
                E('div', { 'class': 'td' }, profile.profileNickname || '-'),
                E('div', { 'class': 'td' }, profile.serviceProviderName),
                E('div', { 'class': 'td' }, [
                    E('span', {
                        'class': profile.profileState === 'enabled'
                            ? 'badge badge-success'
                            : 'badge badge-secondary'
                    }, _(profile.profileState))
                ]),
                E('div', { 'class': 'td' }, [
                    E('button', {
                        'class': 'btn cbi-button cbi-button-apply',
                        'click': ui.createHandlerFn(this, function() {
                            return this.handleEnableProfile(profile.iccid);
                        })
                    }, profile.profileState === 'enabled' ? _('Disable') : _('Enable')),
                    E('button', {
                        'class': 'btn cbi-button cbi-button-remove',
                        'click': ui.createHandlerFn(this, function() {
                            return this.handleDeleteProfile(profile.iccid);
                        })
                    }, _('Delete'))
                ])
            ]);
            table.appendChild(row);
        }, this);

        return E('div', { 'class': 'cbi-map' }, [
            E('h2', {}, _('eSIM Profiles')),
            E('div', { 'class': 'cbi-section' }, [
                table
            ])
        ]);
    },

    handleEnableProfile: function(iccid) {
        ui.showModal(_('Enabling Profile'), [
            E('p', { 'class': 'spinning' }, _('Please wait...'))
        ]);

        return callEnableProfile(iccid, true).then(function(result) {
            ui.hideModal();
            if (result.payload && result.payload.code === 0) {
                ui.addNotification(null, E('p', _('Profile enabled successfully')));
                window.location.reload();
            } else {
                ui.addNotification(null, E('p', _('Failed to enable profile')), 'error');
            }
        });
    },

    handleDeleteProfile: function(iccid) {
        return ui.showModal(_('Confirm Delete'), [
            E('p', {}, _('Are you sure you want to delete this profile?')),
            E('div', { 'class': 'right' }, [
                E('button', {
                    'class': 'btn cbi-button-neutral',
                    'click': ui.hideModal
                }, _('Cancel')),
                E('button', {
                    'class': 'btn cbi-button-negative',
                    'click': ui.createHandlerFn(this, function() {
                        ui.hideModal();
                        return this.doDeleteProfile(iccid);
                    })
                }, _('Delete'))
            ])
        ]);
    }
});
```

#### 4. Frontend JavaScript - About Page (`htdocs/luci-static/resources/view/lpac/about.js`)

**Purpose:** Display application information, versions, and credits

```javascript
'use strict';
'require view';
'require rpc';
'require ui';

var callGetVersion = rpc.declare({
    object: 'luci.lpac',
    method: 'get_version',
    expect: { result: {} }
});

return view.extend({
    load: function() {
        return Promise.all([
            callGetVersion()
        ]);
    },

    render: function(data) {
        var versions = data[0] || {};

        return E('div', { 'class': 'cbi-map' }, [
            E('h2', {}, _('About luci-app-lpac')),

            // Application Information
            E('div', { 'class': 'cbi-section' }, [
                E('h3', {}, _('Application Information')),
                E('table', { 'class': 'table' }, [
                    E('tr', {}, [
                        E('td', { 'style': 'width: 30%; font-weight: bold' }, _('Application')),
                        E('td', {}, 'luci-app-lpac')
                    ]),
                    E('tr', {}, [
                        E('td', { 'style': 'font-weight: bold' }, _('Version')),
                        E('td', {}, versions.luci_app_lpac || 'unknown')
                    ]),
                    E('tr', {}, [
                        E('td', { 'style': 'font-weight: bold' }, _('lpac Version')),
                        E('td', {}, versions.lpac || 'unknown')
                    ]),
                    E('tr', {}, [
                        E('td', { 'style': 'font-weight: bold' }, _('License')),
                        E('td', {}, 'GPL-3.0')
                    ]),
                    E('tr', {}, [
                        E('td', { 'style': 'font-weight: bold' }, _('Repository')),
                        E('td', {}, E('a', {
                            'href': 'https://github.com/YOUR_USERNAME/luci-app-lpac',
                            'target': '_blank'
                        }, 'GitHub'))
                    ])
                ])
            ]),

            // System Information
            E('div', { 'class': 'cbi-section' }, [
                E('h3', {}, _('System Information')),
                E('table', { 'class': 'table' }, [
                    E('tr', {}, [
                        E('td', { 'style': 'width: 30%; font-weight: bold' }, _('OpenWrt Version')),
                        E('td', {}, versions.openwrt || 'unknown')
                    ]),
                    E('tr', {}, [
                        E('td', { 'style': 'font-weight: bold' }, _('LuCI Version')),
                        E('td', {}, versions.luci || 'unknown')
                    ])
                ])
            ]),

            // Credits and Links
            E('div', { 'class': 'cbi-section' }, [
                E('h3', {}, _('Credits')),
                E('p', {}, _('This application is a web interface for lpac, the eSIM/eUICC profile management tool.')),
                E('p', {}, [
                    _('lpac project: '),
                    E('a', {
                        'href': 'https://github.com/estkme-group/lpac',
                        'target': '_blank'
                    }, 'https://github.com/estkme-group/lpac')
                ]),
                E('p', {}, [
                    _('Documentation: '),
                    E('a', {
                        'href': 'https://github.com/YOUR_USERNAME/luci-app-lpac/wiki',
                        'target': '_blank'
                    }, 'Wiki')
                ]),
                E('p', {}, [
                    _('Report Issues: '),
                    E('a', {
                        'href': 'https://github.com/YOUR_USERNAME/luci-app-lpac/issues',
                        'target': '_blank'
                    }, 'GitHub Issues')
                ])
            ]),

            // Acknowledgments
            E('div', { 'class': 'cbi-section' }, [
                E('h3', {}, _('Acknowledgments')),
                E('p', {}, _('Special thanks to:')),
                E('ul', {}, [
                    E('li', {}, _('lpac developers for the excellent eSIM management tool')),
                    E('li', {}, _('OpenWrt community for the robust platform')),
                    E('li', {}, _('LuCI developers for the web framework')),
                    E('li', {}, _('All contributors and testers'))
                ])
            ])
        ]);
    }
});
```

#### 5. UCI Configuration (`root/etc/config/lpac`)

**Purpose:** Store lpac settings in OpenWrt's UCI format

```
config lpac 'config'
    option apdu_driver 'pcsc'
    option http_driver 'curl'
    option custom_aid ''
    option es10x_mss '60'
    option debug_http '0'
    option debug_apdu '0'
    option auto_notification '1'
    option qmi_slot '1'
    option pcsc_reader ''

config lpac 'advanced'
    option log_level 'info'
    option timeout '120'
```

#### 5. RPC ACL (`root/usr/share/rpcd/acl.d/luci-app-lpac.json`)

**Purpose:** Define permissions for RPC calls

```json
{
    "luci-app-lpac": {
        "description": "Grant access to lpac functionality",
        "read": {
            "uci": [ "lpac" ],
            "file": {
                "/usr/bin/lpac": [ "exec" ]
            }
        },
        "write": {
            "uci": [ "lpac" ],
            "cgi-io": [ "upload" ]
        }
    }
}
```

## User Interface Design

### UI/UX Principles

1. **Simplicity First:** Clear, uncluttered interface
2. **Responsive Design:** Works on desktop and mobile
3. **Immediate Feedback:** Loading indicators, success/error messages
4. **Confirmation Dialogs:** For destructive actions (delete, factory reset)
5. **Help Text:** Tooltips and inline help for complex settings
6. **Error Handling:** Clear error messages with troubleshooting hints

### Color Scheme

- **Primary:** LuCI default blue (#0099cc)
- **Success:** Green (#28a745)
- **Warning:** Orange (#ffc107)
- **Danger:** Red (#dc3545)
- **Info:** Light blue (#17a2b8)

### Page Layouts

#### 1. Dashboard Layout

```
┌───────────────────────────────────────────────────────────────┐
│  eSIM Management - Dashboard                                  │
├───────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────┐  ┌──────────────────────────┐   │
│  │   eUICC Status          │  │   Quick Actions          │   │
│  ├─────────────────────────┤  ├──────────────────────────┤   │
│  │ Status:    ● Connected  │  │  [📥 Download Profile]   │   │
│  │ EID:       89049032...  │  │  [🔄 Refresh]            │   │
│  │ Firmware:  2.2.0        │  │  [⚙️  Settings]           │   │
│  │ Memory:    280KB free   │  │                          │   │
│  │ Profiles:  2/5 active   │  │                          │   │
│  └─────────────────────────┘  └──────────────────────────┘   │
│                                                                │
│  Active Profiles                                   [View All] │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ● Vodafone TR                                          │  │
│  │   ICCID: 8901***890 | Personal | Enabled              │  │
│  │   [Disable] [Details]                                  │  │
│  ├────────────────────────────────────────────────────────┤  │
│  │ ○ T-Mobile US                                          │  │
│  │   ICCID: 8901***891 | Work | Disabled                 │  │
│  │   [Enable] [Details]                                   │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  Recent Activity                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ • Profile "Vodafone TR" enabled              2h ago    │  │
│  │ • Profile "T-Mobile US" downloaded           1d ago    │  │
│  │ • Notification processed                     1d ago    │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

#### 2. Chip Information Layout

```
┌───────────────────────────────────────────────────────────────┐
│  Chip Information                          [🔄 Refresh]        │
├───────────────────────────────────────────────────────────────┤
│  eUICC Information                                             │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ EID:                 890493222002xxxxxxxxxxxxx [📋 Copy]│  │
│  │ Manufacturer:        Thales (Certificate Issuer: GSMA) │  │
│  │ Firmware Version:    2.2.0                             │  │
│  │ SGP.22 Version:      2.2.2                             │  │
│  │ Profile Version:     3.0.0                             │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  Memory Information                                            │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Free NV Memory:      280 KB                            │  │
│  │ Free Volatile:       64 KB                             │  │
│  │ Installed Apps:      2                                 │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  Server Configuration                                          │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Default SM-DP+:      prod.smdp.example.com             │  │
│  │                      [✏️  Edit] [❌ Clear]               │  │
│  │                                                         │  │
│  │ Root SM-DS:          smds.gsma.com                     │  │
│  │                      (Read-only)                        │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  Capabilities                                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ✓ Profile Download      ✓ Profile Management          │  │
│  │ ✓ Notification Support  ✓ Profile Policy Rules        │  │
│  │ ✓ Test Mode             ✓ Secure Channel               │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  Danger Zone                                                   │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ [⚠️  Factory Reset]                                     │  │
│  │ Warning: This will delete all profiles!                │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

#### 3. Profile List Layout

```
┌───────────────────────────────────────────────────────────────┐
│  Profiles                                        [🔄 Refresh]  │
├───────────────────────────────────────────────────────────────┤
│  [🔍 Search]  Filter: [All ▼] [Enabled] [Disabled]            │
│                                                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ICCID       │ Nickname  │ Provider    │ State  │ Actions││  │
│  ├────────────────────────────────────────────────────────┤  │
│  │ 8901***890  │ Personal  │ Vodafone TR │ ● ON   │ [≡]   ││  │
│  │                                                         │  │
│  ├────────────────────────────────────────────────────────┤  │
│  │ 8901***891  │ Work      │ T-Mobile US │ ○ OFF  │ [≡]   ││  │
│  │                                                         │  │
│  ├────────────────────────────────────────────────────────┤  │
│  │ 8901***892  │ Travel    │ Orange FR   │ ○ OFF  │ [≡]   ││  │
│  │                                                         │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  Showing 3 of 3 profiles (2/5 slots used)                     │
│                                                                │
│  [📥 Download New Profile]                                     │
│                                                                │
├───────────────────────────────────────────────────────────────┤
│  Profile Actions Menu (when [≡] clicked):                     │
│  ┌──────────────────────┐                                     │
│  │ ▶ Enable Profile     │                                     │
│  │ ⏸  Disable Profile    │                                     │
│  │ ✏️  Edit Nickname     │                                     │
│  │ ℹ️  View Details      │                                     │
│  │ 🗑️  Delete Profile    │                                     │
│  └──────────────────────┘                                     │
└───────────────────────────────────────────────────────────────┘

Profile Details Modal (when "View Details" clicked):
┌───────────────────────────────────────────────────────────────┐
│  Profile Details                                     [✖ Close] │
├───────────────────────────────────────────────────────────────┤
│  General Information                                           │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Full ICCID:          8901170000123456890              │  │
│  │ ISD-P AID:           A0000005591010FFFFFFFF890001...  │  │
│  │ Profile State:       Enabled                          │  │
│  │ Profile Class:       Operational                      │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  Operator Information                                          │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Provider Name:       Vodafone Turkey                  │  │
│  │ Profile Name:        Vodafone Postpaid                │  │
│  │ Nickname:            Personal                          │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  [Edit Nickname] [Enable/Disable] [Delete]                    │
└───────────────────────────────────────────────────────────────┘
```

#### 4. Download Profile Layout

```
┌───────────────────────────────────────────────────────────────┐
│  Download Profile                                              │
├───────────────────────────────────────────────────────────────┤
│  Input Method                                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ● Activation Code (QR Code or LPA: string)            │  │
│  │   ┌──────────────────────────────────────────────────┐ │  │
│  │   │ LPA:1$prod.smdp.example.com$MATCHING-ID          │ │  │
│  │   └──────────────────────────────────────────────────┘ │  │
│  │                                                         │  │
│  │   Or scan QR code:                                      │  │
│  │   [📷 Upload QR Code Image]                             │  │
│  │                                                         │  │
│  │ ○ Manual Entry                                         │  │
│  │   SM-DP+ Address: [_______________________________]    │  │
│  │   Matching ID:    [_______________________________]    │  │
│  │   Confirm Code:   [_______________] (optional)         │  │
│  │   Custom IMEI:    [_______________] (optional)         │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  Options                                                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ [✓] Auto-process notifications after download         │  │
│  │ [✓] Enable profile immediately after download         │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  [Cancel] [📥 Download Profile]                                │
└───────────────────────────────────────────────────────────────┘

Download Progress Modal (during download):
┌───────────────────────────────────────────────────────────────┐
│  Downloading Profile...                                        │
├───────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Progress:  ████████████████░░░░░░░░░░░  60%            │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  Status:                                                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ✓ Connecting to SM-DP+ server...                      │  │
│  │ ✓ Authenticating...                                    │  │
│  │ ✓ Retrieving profile metadata...                      │  │
│  │ ⏳ Downloading profile data... (60%)                   │  │
│  │   Installing to eUICC...                               │  │
│  │   Enabling profile...                                  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  Please do not close this window or disconnect the eUICC.     │
│                                                                │
│  [Cancel Download]                                             │
└───────────────────────────────────────────────────────────────┘

Download Success Modal:
┌───────────────────────────────────────────────────────────────┐
│  ✓ Profile Downloaded Successfully                             │
├───────────────────────────────────────────────────────────────┤
│  Profile Information:                                          │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Provider:   Vodafone Turkey                            │  │
│  │ Profile:    Vodafone Postpaid                          │  │
│  │ ICCID:      8901170000123456890                        │  │
│  │ State:      Enabled                                    │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  Next Steps:                                                   │
│  • Your device should now connect to the network               │
│  • You can manage this profile in the Profiles page            │
│                                                                │
│  [View Profiles] [Download Another]                            │
└───────────────────────────────────────────────────────────────┘
```

#### 5. Notifications Layout

```
┌───────────────────────────────────────────────────────────────┐
│  Notifications                              [🔄 Refresh]       │
├───────────────────────────────────────────────────────────────┤
│  Pending Notifications: 2                                      │
│                                                                │
│  [Process All] [Remove All]                                    │
│                                                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Seq │ Operation      │ SM-DP+ Address        │ ICCID  │ ││  │
│  ├────────────────────────────────────────────────────────┤  │
│  │ 1   │ Install        │ prod.smdp.example.com │ 89***90│ ││  │
│  │     │                │                       │ [≡]    │ ││  │
│  │                                                         │  │
│  ├────────────────────────────────────────────────────────┤  │
│  │ 2   │ Enable         │ prod.smdp.example.com │ 89***91│ ││  │
│  │     │                │                       │ [≡]    │ ││  │
│  │                                                         │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
├───────────────────────────────────────────────────────────────┤
│  Notification Actions Menu (when [≡] clicked):                │
│  ┌──────────────────────────┐                                 │
│  │ ✓ Process & Remove       │                                 │
│  │ ▶ Process Only           │                                 │
│  │ 🗑️  Remove                │                                 │
│  │ ℹ️  View Details          │                                 │
│  └──────────────────────────┘                                 │
└───────────────────────────────────────────────────────────────┘

Notification Details Modal:
┌───────────────────────────────────────────────────────────────┐
│  Notification Details                              [✖ Close]   │
├───────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Sequence Number:         1                             │  │
│  │ Operation:               install                       │  │
│  │ Notification Address:    prod.smdp.example.com        │  │
│  │ Related ICCID:           8901170000123456890          │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  What does this mean?                                          │
│  This notification indicates that a profile installation has   │
│  completed. Processing it will inform the SM-DP+ server that   │
│  the operation was successful.                                 │
│                                                                │
│  [Process & Remove] [Process Only] [Remove Only] [Cancel]     │
└───────────────────────────────────────────────────────────────┘

Info Box (when no notifications):
┌───────────────────────────────────────────────────────────────┐
│  Notifications                              [🔄 Refresh]       │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                                                         │  │
│  │                   ℹ️  No Notifications                   │  │
│  │                                                         │  │
│  │  There are no pending notifications at this time.      │  │
│  │                                                         │  │
│  │  Notifications are automatically created after profile │  │
│  │  operations and should be processed to inform the      │  │
│  │  network operator.                                      │  │
│  │                                                         │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

#### 6. Settings Layout

```
┌───────────────────────────────────────────────────────────────┐
│  Settings                                         [💾 Save]    │
├───────────────────────────────────────────────────────────────┤
│  APDU Driver Configuration                                     │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Driver Type:  ● auto  ○ pcsc  ○ qmi  ○ mbim  ○ at     │  │
│  │                                                         │  │
│  │ PC/SC Reader (when pcsc selected):                     │  │
│  │ Reader Name:  [Gemalto PC Twin Reader________] [Scan]  │  │
│  │                                                         │  │
│  │ QMI Configuration (when qmi selected):                 │  │
│  │ Slot Number:  ○ 1  ● 2                                 │  │
│  │                                                         │  │
│  │ AT Configuration (when at selected):                   │  │
│  │ Device Path:  [/dev/ttyUSB2________________]           │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  HTTP Driver Configuration                                     │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ HTTP Library: ● curl  ○ stdio (testing only)          │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  Advanced Settings                                             │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Custom ISD-R AID:                                       │  │
│  │   Preset: [Default ▼]                                   │  │
│  │            ├─ Default (A00000055910...)                │  │
│  │            ├─ 5ber                                      │  │
│  │            ├─ esim.me                                   │  │
│  │            └─ xesim                                     │  │
│  │   Custom:  [_______________________________]           │  │
│  │                                                         │  │
│  │ ES10x Max Segment Size:                                │  │
│  │   [60____] (6-255, default: 60)                        │  │
│  │                                                         │  │
│  │ Debug Options:                                          │  │
│  │   [✓] Enable HTTP debugging                            │  │
│  │   [✓] Enable APDU debugging                            │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  Notification Processing                                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ [✓] Auto-process notifications after downloads        │  │
│  │ [✓] Auto-remove processed notifications               │  │
│  │                                                         │  │
│  │ ⚠️  Note: Disabling automatic notification processing  │  │
│  │    may violate GSMA specifications.                    │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  [Restore Defaults] [Cancel] [💾 Save Changes]                 │
└───────────────────────────────────────────────────────────────┘
```

#### 7. About Page Layout

```
┌───────────────────────────────────────────────────────────────┐
│  About luci-app-lpac                                           │
├───────────────────────────────────────────────────────────────┤
│  Application Information                                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Application:    luci-app-lpac                          │  │
│  │ Version:        1.0.0                                  │  │
│  │ lpac Version:   2.3.0                                  │  │
│  │ License:        GPL-3.0                                │  │
│  │ Repository:     [🔗 GitHub]                             │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  System Information                                            │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ OpenWrt Version: 24.05.0                               │  │
│  │ LuCI Version:    24.05                                 │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  Credits                                                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ This application is a web interface for lpac, the      │  │
│  │ eSIM/eUICC profile management tool.                    │  │
│  │                                                         │  │
│  │ lpac project: [🔗 github.com/estkme-group/lpac]        │  │
│  │ Documentation: [🔗 Wiki]                                │  │
│  │ Report Issues: [🔗 GitHub Issues]                       │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                                │
│  Acknowledgments                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Special thanks to:                                      │  │
│  │ • lpac developers for the excellent eSIM tool          │  │
│  │ • OpenWrt community for the robust platform            │  │
│  │ • LuCI developers for the web framework                │  │
│  │ • All contributors and testers                          │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

## Security Considerations

### OpenWrt Security Context

OpenWrt routers typically operate in trusted local networks with single-user access. Security measures should be **pragmatic and appropriate** for this context, avoiding over-engineering while maintaining basic protections.

### Essential Security Measures

#### 1. Authentication and Authorization

- **LuCI Authentication:** Use built-in LuCI login system (already handles sessions)
- **RPC ACL:** Restrict lpac operations to admin users (standard OpenWrt practice)
- **Input Validation:** Sanitize user inputs to prevent command injection

#### 2. Command Injection Prevention

**Critical:** Prevent shell injection attacks

```lua
-- ❌ NEVER: Direct string concatenation
local cmd = "lpac profile enable " .. iccid
os.execute(cmd)  -- Vulnerable to injection!

-- ✅ ALWAYS: Use proper argument handling
local lpac = require "luci.model.lpac.lpac_interface"
local result = lpac.enable_profile(iccid)  -- Safe, uses luci.util.exec with args

-- Or with explicit escaping:
local util = require "luci.util"
local iccid_safe = util.shellquote(iccid)
```

#### 3. Sensitive Data Handling

- **ICCID Masking:** Mask ICCIDs by default (8901***890) for privacy
- **Confirmation Codes:** Don't log confirmation codes in system logs
- **Optional:** Hide EID in screenshots (user preference)

### Optional Security Features

These features are **optional** and can be implemented later or made configurable:

#### 1. CSRF Protection

**Status:** Already handled by LuCI framework

- LuCI automatically adds CSRF tokens to forms
- No additional implementation needed
- Just use LuCI's standard form/JSON handlers

**Recommendation:** Don't add extra CSRF logic, trust LuCI's built-in protection.

#### 2. Rate Limiting

**Context:** OpenWrt is typically single-user on local network

**Pragmatic Approach:**

```lua
-- Simple operation throttling (optional)
-- Only for expensive operations like download

local last_download = 0
local DOWNLOAD_COOLDOWN = 60  -- seconds

function can_download()
    local now = os.time()
    if now - last_download < DOWNLOAD_COOLDOWN then
        return false, "Please wait before downloading another profile"
    end
    last_download = now
    return true
end
```

**When to use:**

- ✅ Prevent accidental multiple downloads (user double-clicking)
- ✅ Avoid overwhelming SM-DP+ servers
- ❌ NOT for preventing "attacks" (local network is trusted)
- ❌ NOT for regular operations (enable/disable/list)

**Recommendation:** Implement simple cooldown only for download operations, make it configurable or disable by default.

#### 3. HTTPS/SSL

**Status:** LuCI supports HTTPS via uhttpd

- Not enforced by default in OpenWrt
- User can enable if needed
- Most home networks don't need SSL for local access

**Recommendation:** Document how to enable HTTPS, don't require it.

### What We Actually Need

**Priority 1 (Must Have):**

1. ✅ Input validation (prevent injection)
2. ✅ Use LuCI's built-in authentication
3. ✅ RPC ACL for admin-only access
4. ✅ Don't log sensitive data

**Priority 2 (Nice to Have):**

1. 🔶 Basic download cooldown (30-60 seconds)
2. 🔶 ICCID masking in UI

**Priority 3 (Optional/Future):**

1. ⭕ Configurable rate limiting
2. ⭕ HTTPS enforcement (user choice)
3. ⭕ Audit logging

### Security Best Practices for Development

```lua
-- ✅ Good: Always validate and sanitize inputs
function validate_iccid(iccid)
    -- ICCID should be 19-20 digits
    if not iccid or not iccid:match("^%d+$") or #iccid < 19 or #iccid > 20 then
        return false, "Invalid ICCID format"
    end
    return true
end

-- ✅ Good: Use luci.util.exec with argument array
local util = require "luci.util"
local result = util.exec("/usr/bin/lpac", {"profile", "enable", iccid})

-- ✅ Good: Limit input length
function sanitize_nickname(nickname)
    if #nickname > 64 then
        return nickname:sub(1, 64)  -- Truncate to 64 chars
    end
    return nickname
end
```

### Threat Model (Realistic for OpenWrt)

**Real Threats:**

1. 🔴 Command injection from malicious input → **Must prevent**
2. 🟡 Accidental multiple operations from UI bugs → **Should prevent**
3. 🟢 Local network eavesdropping → **Low risk (trusted network)**
4. 🟢 CSRF from external website → **Very low risk (LuCI handles it)**
5. 🟢 Brute force attacks → **Very low risk (local network, LuCI login)**

**Non-Threats (in typical OpenWrt context):**

- ❌ DDoS attacks (local network)
- ❌ Advanced persistent threats (home router)
- ❌ Multi-tenant security (single user)
- ❌ Compliance requirements (GDPR, PCI, etc.)

### Conclusion

For luci-app-lpac on OpenWrt:

- **Focus on:** Input validation, command injection prevention
- **Use built-in:** LuCI authentication, CSRF tokens (automatic)
- **Keep simple:** Basic cooldown for downloads (optional)
- **Don't over-engineer:** No complex rate limiting, no forced HTTPS

Remember: We're building a tool for **trusted users on local networks**, not a public-facing banking application. Security should be **appropriate, not paranoid**.

## Error Handling

### Error Types

1. **lpac Errors:**
   - Command execution failure
   - JSON parsing errors
   - lpac return code != 0

2. **Hardware Errors:**
   - eUICC not found
   - Card reader disconnected
   - Communication timeout

3. **Configuration Errors:**
   - Invalid UCI settings
   - Missing dependencies
   - Driver not available

### Error Display

```javascript
// User-friendly error messages
var errorMessages = {
    'SCardEstablishContext() failed: 8010001D':
        'PC/SC service not running. Please install and start pcscd.',
    'es10c_euicc_init error: -1':
        'Failed to initialize eUICC. Check ISD-R AID in settings.',
    'es9p_error: 8.1/3.8':
        'Matching ID not found on SM-DP+ server.',
    'es9p_error: 8.2/2.2':
        'Invalid confirmation code.'
};

function displayError(error) {
    var message = errorMessages[error] || error;
    ui.addNotification(null, E('p', message), 'error');
}
```

## Installation and Packaging

### OpenWrt Package Structure

```makefile
# Makefile
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-lpac
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=GPL-3.0
PKG_MAINTAINER:=Your Name <your.email@example.com>

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-lpac
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI support for lpac eSIM management
  DEPENDS:=+luci-base +lpac +luci-lib-jsonc
  PKGARCH:=all
endef

define Package/luci-app-lpac/description
  Web interface for managing eSIM profiles using lpac
endef

define Build/Compile
endef

define Package/luci-app-lpac/install
 $(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
 $(INSTALL_DATA) ./luasrc/controller/*.lua $(1)/usr/lib/lua/luci/controller/

 $(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/lpac
 $(INSTALL_DATA) ./luasrc/model/lpac/*.lua $(1)/usr/lib/lua/luci/model/lpac/

 $(INSTALL_DIR) $(1)/www/luci-static/resources/view/lpac
 $(INSTALL_DATA) ./htdocs/luci-static/resources/view/lpac/*.js \
  $(1)/www/luci-static/resources/view/lpac/

 $(INSTALL_DIR) $(1)/etc/config
 $(INSTALL_CONF) ./root/etc/config/lpac $(1)/etc/config/

 $(INSTALL_DIR) $(1)/etc/uci-defaults
 $(INSTALL_BIN) ./root/etc/uci-defaults/* $(1)/etc/uci-defaults/

 $(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
 $(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/*.json \
  $(1)/usr/share/rpcd/acl.d/
endef

$(eval $(call BuildPackage,luci-app-lpac))
```

### Post-Installation Script (`root/etc/uci-defaults/90-luci-lpac`)

```bash
#!/bin/sh

# Initialize UCI configuration if not exists
uci -q get lpac.config || {
    uci set lpac.config=lpac
    uci set lpac.config.apdu_driver='pcsc'
    uci set lpac.config.http_driver='curl'
    uci set lpac.config.custom_aid=''
    uci set lpac.config.es10x_mss='60'
    uci set lpac.config.auto_notification='1'
    uci commit lpac
}

# Restart rpcd to load new ACLs
/etc/init.d/rpcd restart

# Clear LuCI cache
rm -rf /tmp/luci-*

exit 0
```

### Build Instructions

```bash
# Clone OpenWrt buildroot
git clone https://git.openwrt.org/openwrt/openwrt.git
cd openwrt

# Update and install feeds
./scripts/feeds update -a
./scripts/feeds install -a

# Copy luci-app-lpac to feeds
cp -r /path/to/luci-app-lpac package/luci-app-lpac/

# Configure build
make menuconfig
# Navigate to: LuCI -> 3. Applications -> luci-app-lpac
# Select as <M> (module)

# Build package
make package/luci-app-lpac/compile V=s

# Package will be in: bin/packages/*/luci/luci-app-lpac_*.ipk
```

## Development Roadmap

### Milestone 1: MVP (Weeks 1-4)

**Week 1: Project Setup**

- [x] Create project structure
- [x] Set up development environment
- [x] Design UCI configuration schema
- [x] Write Makefile

**Week 2: Backend Development**

- [ ] Implement lpac_interface.lua
- [ ] Implement lpac_model.lua
- [ ] Create controller with API endpoints
- [ ] Write unit tests

**Week 3: Frontend Development**

- [ ] Implement dashboard.js
- [ ] Implement profiles.js
- [ ] Implement download.js
- [ ] Add CSS styling

**Week 4: Testing and Polish**

- [ ] Integration testing
- [ ] Bug fixes
- [ ] Documentation
- [ ] Package build

### Milestone 2: Enhanced Features (Weeks 5-6)

- [ ] Chip information page
- [ ] Notification management
- [ ] Settings page with driver configuration
- [ ] Profile details modal

### Milestone 3: Advanced Features (Weeks 7-8)

- [ ] Profile discovery (SM-DS)
- [ ] Multi-reader support
- [ ] Real-time progress updates (WebSocket)
- [ ] Error handling improvements

### Milestone 4: Release (Week 9)

- [ ] Final testing on multiple devices
- [ ] Documentation completion
- [ ] Submission to OpenWrt packages feed
- [ ] Community feedback integration

## Testing Strategy

### Unit Testing

**Framework:** busted (Lua testing framework)

**Test Coverage:**

- lpac_interface.lua: Command execution, JSON parsing
- lpac_model.lua: Business logic, error handling
- lpac_util.lua: Utility functions

**Example Test:**

```lua
describe("lpac_interface", function()
    local lpac = require "luci.model.lpac.lpac_interface"

    it("should parse chip info correctly", function()
        local result = lpac.get_chip_info()
        assert.is_not_nil(result)
        assert.equals("lpa", result.type)
        assert.equals(0, result.payload.code)
    end)

    it("should handle lpac errors gracefully", function()
        -- Mock lpac failure
        local result = lpac.enable_profile("invalid_iccid")
        assert.is_not_nil(result.payload)
        assert.is_not.equals(0, result.payload.code)
    end)
end)
```

### Integration Testing

**Test Scenarios:**

1. **Profile Download Flow:**
   - Enter activation code
   - Submit download form
   - Verify progress display
   - Check profile appears in list

2. **Profile Enable/Disable:**
   - Click enable button
   - Verify state change
   - Check modem connection

3. **Settings Update:**
   - Change APDU driver
   - Save settings
   - Verify UCI update
   - Test lpac with new driver

### Hardware Testing

**Test Devices:**

- GL.iNet routers (GL-X3000, GL-XE3000)
- Generic x86 router with USB card reader
- Raspberry Pi with USB card reader
- Router with built-in QMI modem

**Test Cases:**

- PC/SC reader detection
- QMI modem communication
- Multiple reader support
- USB hotplug handling

### User Acceptance Testing

**Test Users:**

- Technical users (router enthusiasts)
- Non-technical users (home users)

**Feedback Collection:**

- GitHub issues
- OpenWrt forum thread
- User survey

## Documentation

### User Documentation

1. **Quick Start Guide:**
   - Installation instructions
   - First-time setup
   - Download first profile

2. **User Manual:**
   - Feature overview
   - Step-by-step tutorials
   - Troubleshooting guide

3. **FAQ:**
   - Common errors and solutions
   - Hardware compatibility
   - Configuration tips

### Developer Documentation

1. **Architecture Overview:**
   - Component diagram
   - Data flow
   - Function reference

2. **Contributing Guide:**
   - Code style guidelines
   - Pull request process
   - Testing requirements

3. **Integration Guide:**
   - Using lpac CLI from scripts
   - LuCI RPC examples
   - UCI configuration reference

## Localization Plan (Phase 2)

### Translation Framework

Using LuCI's i18n system:

```lua
-- In Lua code
_("Profile Management")

-- In JavaScript
_('Download Profile')
```

### Supported Languages (Priority Order)

1. **English** (en) - Default
2. **Turkish** (tr) - Native user base
3. **Chinese** (zh-cn) - Large OpenWrt community
4. **German** (de) - European users
5. **Spanish** (es) - Latin America
6. **French** (fr) - French-speaking countries

### Translation Workflow

1. Extract strings: `./build/i18n-scan.pl`
2. Create .po files for each language
3. Translate via Weblate or POEditor
4. Compile .po to .mo files
5. Include in package

## Performance Optimization

### Backend Optimization

1. **Caching:**
   - Cache chip info (5 min TTL)
   - Cache profile list (1 min TTL)
   - Invalidate cache on operations

2. **Async Operations:**
   - Long operations (download) via background jobs
   - WebSocket for progress updates
   - Polling fallback for older browsers

3. **Resource Management:**
   - Limit concurrent lpac processes
   - Timeout handling (120s default)
   - Memory-efficient JSON parsing

### Frontend Optimization

1. **Lazy Loading:**
   - Load views on demand
   - Defer non-critical scripts

2. **Debouncing:**
   - Debounce search input (300ms)
   - Throttle refresh operations

3. **Caching:**
   - Cache static resources
   - Browser caching headers

## Maintenance and Support

### Version Compatibility

**OpenWrt Versions:**

- 23.05.x (LuCI 23.05)
- 24.05.x (LuCI 24.05)
- Snapshot (testing)

**lpac Versions:**

- 2.0.0+ (minimum)
- 2.3.0+ (recommended)

### Upgrade Path

**Version Migration:**

```bash
# Check existing version
opkg list-installed | grep luci-app-lpac

# Upgrade package
opkg update
opkg upgrade luci-app-lpac

# Migrate configuration if needed
# (handled by uci-defaults script)
```

### Bug Reporting

**Issue Template:**

```markdown
## Bug Report

**Environment:**
- OpenWrt version:
- lpac version:
- luci-app-lpac version:
- Hardware:

**Steps to Reproduce:**
1.
2.
3.

**Expected Behavior:**

**Actual Behavior:**

**Logs:**
```

### Support Channels

1. **GitHub Issues:** Bug reports, feature requests
2. **OpenWrt Forum:** General discussion, help
3. **Documentation Wiki:** Guides, tutorials

## Success Metrics

### Technical Metrics

- **Package size:** < 100KB
- **Memory footprint:** < 5MB
- **Load time:** < 2s on typical router
- **API response time:** < 500ms (except download)

### User Metrics

- **Installation success rate:** > 95%
- **First-time setup completion:** > 80%
- **User satisfaction:** > 4.0/5.0
- **Bug reports:** < 5 critical bugs in first month

### Adoption Metrics

- **Downloads:** Track via OpenWrt package stats
- **Active users:** Estimate from forum activity
- **Community contributions:** Pull requests, translations

## Risks and Mitigation

### Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| lpac API changes | High | Medium | Version pinning, compatibility layer |
| Hardware compatibility | Medium | High | Extensive testing, fallback options |
| LuCI breaking changes | High | Low | Follow LuCI versioning, timely updates |
| Security vulnerabilities | High | Medium | Regular audits, input validation |

### Resource Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Developer availability | High | Medium | Documentation, community involvement |
| Testing hardware shortage | Medium | Medium | Community testing program |
| Translation delays | Low | High | Start with English only |

### User Adoption Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Complex setup | Medium | High | Quick start guide, defaults |
| Limited hardware support | Medium | Medium | Clear compatibility documentation |
| Competition | Low | Low | Unique OpenWrt integration |

## Future Enhancements

### Short-term (3-6 months)

- QR code scanning via image upload
- Profile backup and restore
- Email notifications for events

### Medium-term (6-12 months)

- Multi-language support (5+ languages)
- Profile scheduling (time-based switching)
- Integration with mwan3 (load balancing)
- Mobile app companion

### Long-term (12+ months)

- Cloud sync for profiles across devices
- Analytics and reporting
- Enterprise features (fleet management)
- Marketplace for eSIM providers

## Conclusion

luci-app-lpac will bring professional eSIM management to OpenWrt routers, making it easy for users to manage eSIM profiles through a familiar web interface. By leveraging the robust lpac backend and LuCI's proven framework, we can deliver a reliable, secure, and user-friendly solution.

The project follows OpenWrt and LuCI best practices, ensuring seamless integration with the existing ecosystem. With careful planning, thorough testing, and community engagement, luci-app-lpac has the potential to become a valuable addition to the OpenWrt package repository.

**Next Steps:**

1. Validate plan with OpenWrt/LuCI community
2. Set up development environment
3. Begin MVP implementation
4. Iterate based on feedback

---

**Document Version:** 1.0
**Last Updated:** 2025-10-23
**Status:** Planning Phase
**Author:** Project Team
