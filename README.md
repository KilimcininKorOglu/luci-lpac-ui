# LuCI App LPAC

A LuCI web interface for managing eSIM profiles on OpenWrt routers with Quectel modems.

## Overview

LuCI App LPAC provides a user-friendly web interface for eSIM profile management through the LPAC (Local Profile Assistant Client) binary. It enables administrators to manage eSIM profiles directly from the OpenWrt router's web interface, supporting operations such as adding, deleting, enabling, and disabling profiles.

## Features

### Core Functionality

- List all eSIM profiles with detailed information (ICCID, state, nickname, provider)
- Enable and disable eSIM profiles
- Delete profiles from the eUICC
- Add new profiles via activation codes
- Set custom nicknames for profiles
- Real-time profile status monitoring
- Automatic GSMA notification processing

### Driver Support

- AT (Standard AT commands)
- AT_CSIM (AT+CSIM commands)
- MBIM (Mobile Broadband Interface Model)

### Architecture

- Classic LuCI template-based design
- Seamless integration with OpenWrt themes
- Standard fieldset structure following OpenWrt UI guidelines
- JSON-based communication with lpac binary
- UCI configuration system integration

## Requirements

### Runtime Dependencies

- OpenWrt 21.02 or later
- luci-base
- luci-compat
- lpac binary (eSIM profile management client)
- curl or wget (for HTTP communication)
- Quectel modem with eSIM support

### Build Dependencies

- bash
- tar
- gzip
- sed
- awk
- perl

## Installation

### From IPK Package

1. Download the latest IPK package from releases
2. Transfer to your router
3. Install using opkg:

```bash
opkg install luci-app-lpac_*.ipk
```

4. Clear LuCI cache (done automatically by postinst script):

```bash
rm -rf /tmp/luci-modulecache/* /tmp/luci-indexcache/*
```

5. Refresh your browser and navigate to: Network > LPAC eSIM

### From Source

1. Clone this repository
2. Run the build script:

```bash
./build.sh
```

3. Install the generated IPK package

## Configuration

The package uses UCI for configuration. Edit `/etc/config/lpac`:

```
config lpac 'config'
    option apdu_driver 'AT'
    option device '/dev/ttyUSB2'
    option timeout '30'
```

### Configuration Options

- **apdu_driver**: Communication driver (AT, AT_CSIM, or MBIM)
- **device**: Modem device path
- **timeout**: Command timeout in seconds

## Build System

### Automated Build Features

The build system includes comprehensive automation to ensure consistency and reduce manual maintenance:

#### 1. Version Management

- Auto-increments build number based on existing IPK files
- Updates PKG_RELEASE in Makefile
- Synchronizes version across all files before building

#### 2. Metadata Synchronization

- Extracts package information from Makefile (single source of truth)
- Automatically updates about.htm with:
  - Package name
  - Version number
  - License information
  - Developer name

#### 3. Changelog Generation

- Parses recent git commit messages
- Filters meaningful commits (excludes version bumps and chores)
- Extracts descriptions from conventional commit format
- Auto-generates "What's New" section in about.htm
- Displays up to 5 recent changes

### Build Process

Run the build script from the project directory:

```bash
./build.sh
```

The script performs the following steps:

1. Determines next build number by scanning existing IPK files
2. Updates Makefile with new PKG_RELEASE
3. Extracts metadata from Makefile
4. Generates changelog from git commits
5. Updates about.htm with version, metadata, and changelog
6. Creates directory structure
7. Copies LuCI files (controller, views, scripts)
8. Verifies file formats (Unix line endings)
9. Creates package metadata (control file, postinst, prerm scripts)
10. Builds IPK package with correct structure
11. Verifies IPK integrity

### Build Output

The build creates an IPK package in the project root:

```bash
luci-app-lpac_1.0.1-N_all.ipk
```

Where N is the auto-incremented build number.

## File Structure

```bash
luci-app-lpac/
├── build.sh                          # Automated build script
├── Makefile                          # OpenWrt package definition
├── luasrc/
│   ├── controller/
│   │   └── lpac.lua                  # LuCI controller
│   └── view/
│       └── lpac/
│           ├── profiles.htm          # Main profile management page
│           └── about.htm             # About page with version info
└── root/
    ├── usr/bin/
    │   └── lpac_json                 # Wrapper script for lpac binary
    └── etc/config/
        └── lpac                      # UCI configuration file
```

## Usage

1. Access the web interface at: `http://router-ip/cgi-bin/luci/admin/network/lpac`
2. Configure your modem settings in the About tab
3. Return to Profiles tab to view and manage eSIM profiles
4. Use action buttons to enable/disable/delete profiles
5. Enter activation code to add new profiles
6. Set custom nicknames for easier identification

## Development

### Commit Message Format

This project uses conventional commits for automated changelog generation:

```bash
emoji type(scope): description

Examples:
feat(ui): add profile nickname support
fix(driver): resolve MBIM communication timeout
docs(readme): update installation instructions
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes following the commit message format
4. Test the build process
5. Submit a pull request

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Maintainer

Kilimcinin Kör Oğlu

- Email: <k@keremgok.tr>
- GitHub: <https://github.com/KilimcininKorOglu/luci-lpac-ui>
- X (Twitter): @KorOglan

## Acknowledgments

- OpenWrt project for the robust embedded Linux platform
- LuCI team for the web interface framework
- LPAC project for the eSIM management client
- Quectel for modem hardware and documentation

## Support

For issues, questions, or contributions, please visit:
<https://github.com/KilimcininKorOglu/luci-lpac-ui/issues>

## Changelog

Recent changes are automatically generated from git commits and displayed in the About page of the web interface. For detailed history, see the git commit log.
