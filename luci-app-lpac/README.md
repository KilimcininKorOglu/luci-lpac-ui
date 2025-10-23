# luci-app-lpac

**Modern LuCI web interface for managing eSIM profiles on OpenWrt routers using lpac**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-23.05%2B-blue)](https://openwrt.org/)
[![LuCI](https://img.shields.io/badge/LuCI-Modern%20(ng)-green)](https://github.com/openwrt/luci)

## Overview

luci-app-lpac provides a comprehensive web interface for managing eSIM (eUICC) profiles on OpenWrt routers. Built on top of the powerful [lpac](https://github.com/estkme-group/lpac) command-line tool, it brings professional eSIM management capabilities to your router's web interface.

**Perfect for:**

- LTE/5G routers with built-in eUICC support
- Travel routers with eSIM capabilities
- Multi-SIM failover setups
- IoT devices with eSIM connectivity

## Features

### Core Functionality

- **📊 Dashboard**: Real-time overview of eUICC status, profiles, and notifications
- **💳 Profile Management**: Full CRUD operations
  - List, enable, disable, delete profiles
  - Rename profiles with custom nicknames
  - View detailed profile information
- **📥 Profile Download**: Flexible installation methods
  - Activation code (QR code) support
  - Manual entry with SM-DP+ address
  - Optional confirmation codes and IMEI
- **🔔 Notification Management**: Handle eUICC notifications
  - Process/remove individual or all notifications
  - Support for install, enable, disable, delete operations
- **⚙️ Settings**: Advanced configuration
  - APDU driver selection (PC/SC, QMI, MBIM, AT)
  - Profile discovery from SM-DS
  - Factory reset with safety confirmation
- **ℹ️ Chip Information**: Comprehensive eUICC details
  - EID, firmware, memory status
  - Platform and capability information

### User Experience

- Modern LuCI interface (LuCI ng for OpenWrt 23.05+)
- Responsive design (desktop, tablet, mobile)
- Real-time feedback and notifications
- Confirmation dialogs for destructive operations
- Color-coded status indicators

## Requirements

### System Requirements

- **OpenWrt**: 23.05 or later (for Modern LuCI support)
- **lpac**: Version 2.0.0+ (2.3.0+ recommended)
- **Dependencies**:
  - `luci-base` (>= 23.05)
  - `luci-lib-jsonc`
  - `libuci-lua`

### Hardware Requirements

Compatible eUICC hardware (one of):

- **PC/SC**: USB card reader with eUICC card
- **QMI**: Qualcomm modem with eUICC support
- **MBIM**: MBIM-compatible modem with eUICC
- **AT**: AT command-based modem with eUICC

### Optional Packages

- `pcscd` - PC/SC daemon (for USB card readers)
- `kmod-usb-serial` - USB serial support
- `qmi-utils` - QMI modem utilities
- `libmbim` - MBIM modem support

## Installation

### From Package Repository

Once published to OpenWrt packages feed:

```bash
opkg update
opkg install luci-app-lpac
```

### Manual Installation

1. Install lpac first:

```bash
opkg update
opkg install lpac
```

2. Build and install luci-app-lpac:

```bash
# Clone repository
git clone https://github.com/KilimcininKorOglu/luci-lpac-ui.git
cd luci-lpac-ui/luci-app-lpac

# Copy to OpenWrt buildroot
cp -r ../luci-app-lpac /path/to/openwrt/package/

# Build
cd /path/to/openwrt
make package/luci-app-lpac/compile V=s

# Install
opkg install bin/packages/*/luci/luci-app-lpac_*.ipk
```

3. Clear LuCI cache:

```bash
rm -rf /tmp/luci-*
```

## Usage

1. Access LuCI web interface
2. Navigate to **Network > eSIM Management**
3. Configure your eUICC interface in Settings
4. Start managing your eSIM profiles

## Hardware Support

### Supported Interfaces

- **PC/SC**: USB card readers
- **QMI**: Qualcomm modems
- **MBIM**: MBIM-compatible modems
- **AT Commands**: AT command-based modems

### Tested Devices

- GL.iNet routers with built-in LTE modems
- x86 devices with USB card readers
- Various OpenWrt-supported routers with USB ports

## Configuration

Configuration is stored in `/etc/config/luci-lpac`:

```
config luci_lpac 'config'
    option apdu_driver 'pcsc'
    option http_driver 'curl'
    option auto_notification '1'
    # ... more options
```

## Troubleshooting

### PC/SC Service Not Running

```bash
# Start pcscd service
/etc/init.d/pcscd start
/etc/init.d/pcscd enable
```

### Card Reader Not Detected

```bash
# List available readers
lpac driver apdu list
```

### Custom ISD-R AID Required

Some eSIM providers (like 5ber, esim.me) require custom ISD-R AIDs. Configure them in Settings.

## Development

### Building from Source

```bash
# Clone OpenWrt buildroot
git clone https://git.openwrt.org/openwrt/openwrt.git
cd openwrt

# Add luci-app-lpac
cp -r /path/to/luci-app-lpac package/luci-app-lpac/

# Configure and build
make menuconfig  # Select luci-app-lpac
make package/luci-app-lpac/compile V=s
```

### Project Structure

```
luci-app-lpac/
├── Makefile                 # OpenWrt package definition
├── luasrc/                  # Lua backend
│   ├── controller/          # LuCI controllers (HTTP API)
│   └── model/lpac/          # lpac interface layer
├── htdocs/                  # JavaScript frontend
│   └── luci-static/resources/view/lpac/
└── root/                    # Configuration files
    ├── etc/config/luci-lpac # UCI configuration
    └── etc/uci-defaults/    # Post-install setup
```

## License

GPL-3.0 - See LICENSE file for details

## Credits

- [lpac](https://github.com/estkme-group/lpac) - Local Profile Agent (command-line)
- [OpenWrt](https://openwrt.org/) - Linux distribution for embedded devices
- [LuCI](https://github.com/openwrt/luci) - OpenWrt web interface

## Support

- GitHub Issues: <https://github.com/YOUR_USERNAME/luci-app-lpac/issues>
- OpenWrt Forum: <https://forum.openwrt.org/>

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Changelog

### v1.0.0 (Initial Release)

- eUICC chip information display
- Profile management (list, enable, disable, delete)
- Profile download via activation code
- Notification management
- Settings configuration
- Multi-interface support (PC/SC, QMI, MBIM, AT)
