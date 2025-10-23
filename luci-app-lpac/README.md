# luci-app-lpac

LuCI web interface for managing eSIM profiles on OpenWrt using lpac.

## Description

luci-app-lpac provides a user-friendly web interface for managing eSIM (eUICC) profiles on OpenWrt routers. It leverages the powerful [lpac](https://github.com/estkme-group/lpac) command-line tool to provide full eSIM profile management capabilities through the LuCI web interface.

## Features

- **eUICC Information**: View chip details, EID, firmware version, and available memory
- **Profile Management**: List, enable, disable, and delete eSIM profiles
- **Profile Download**: Download new profiles via activation codes or manual entry
- **Notification Management**: View and process profile notifications
- **Settings**: Configure APDU/HTTP drivers, custom ISD-R AID, and other advanced options
- **Multi-Interface Support**: PC/SC, QMI, MBIM, and AT command interfaces

## Requirements

- OpenWrt 23.05 or later
- lpac package installed
- Compatible eUICC hardware (card reader or built-in modem)

## Installation

### From Package Repository

```bash
opkg update
opkg install luci-app-lpac
```

### Manual Installation

1. Build the package:
```bash
make package/luci-app-lpac/compile V=s
```

2. Install the built package:
```bash
opkg install luci-app-lpac_*.ipk
```

## Usage

1. Access LuCI web interface
2. Navigate to **Services > eSIM Management**
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

Configuration is stored in `/etc/config/lpac`:

```
config lpac 'config'
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
│   ├── controller/          # LuCI controllers
│   └── model/lpac/          # lpac interface layer
├── htdocs/                  # JavaScript frontend
│   └── luci-static/resources/view/lpac/
└── root/                    # Configuration files
    ├── etc/config/lpac      # UCI configuration
    └── usr/share/rpcd/acl.d/  # RPC ACL
```

## License

GPL-3.0 - See LICENSE file for details

## Credits

- [lpac](https://github.com/estkme-group/lpac) - Local Profile Agent (command-line)
- [OpenWrt](https://openwrt.org/) - Linux distribution for embedded devices
- [LuCI](https://github.com/openwrt/luci) - OpenWrt web interface

## Support

- GitHub Issues: https://github.com/YOUR_USERNAME/luci-app-lpac/issues
- OpenWrt Forum: https://forum.openwrt.org/

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
