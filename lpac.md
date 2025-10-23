# lpac - Technical Documentation

## Overview

**lpac** is a cross-platform Local Profile Assistant (LPA) implementation written in C, fully compatible with **SGP.22 version 2.2.2** specification. It serves as the foundational library that powers all eSIM management applications in the ecosystem.

**Repository:** https://github.com/estkme-group/lpac
**Version:** 2.3.0
**License:** GPL-3.0-or-later (core), MIT (some components)
**Copyright:** © 2023-2025 ESTKME TECHNOLOGY LIMITED, Hong Kong

## Project Significance

lpac is the **heart of the entire eSIM management ecosystem**. All other applications are built on top of lpac:

- **EasyLPAC**: Uses lpac as subprocess (Windows, Linux, macOS)
- **OpenEUICC/EasyEUICC**: Integrates lpac via JNI (Android)
- **lpa-gtk (eSIM Manager)**: Uses lpac as subprocess (Linux Mobile)
- **rlpa-server**: Server-side lpac integration

**Without lpac, none of these applications would function.**

## Key Features

### Profile Management
- Download profiles with activation code and confirmation code
- Enable/disable profiles with refresh control
- Delete profiles
- Set profile nicknames
- List all profiles with detailed information

### SM-DS Discovery
- Automatic profile discovery through SM-DS servers
- Support for event-driven profile detection

### Chip Management
- Query eUICC information (EID, firmware, memory)
- View/modify default SM-DP+ server
- Access extended eUICC Info2 (SGP.22 v2.1+)
- Factory reset (purge) functionality

### Notification Management
- List pending notifications
- Process and send notifications to SM-DP+ server
- Delete notifications

### Custom Options
- Custom IMEI sent to server
- Custom ISD-R AID support
- Configurable ES10x maximum segment size (MSS)

## Architecture

### Component Structure

```
lpac/
├── euicc/              # libeuicc - Core eUICC library
│   ├── es10a.c         # ES10a: Profile discovery
│   ├── es10b.c         # ES10b: Profile package operations
│   ├── es10c.c         # ES10c: Profile management
│   ├── es10c_ex.c      # ES10c extensions (EuiccInfo2)
│   ├── es8p.c          # ES8+: SM-DS communication
│   ├── es9p.c          # ES9+: SM-DP+ communication
│   ├── euicc.c         # Core context management
│   ├── interface.c     # APDU/HTTP interface abstraction
│   └── derutil.c       # DER/ASN.1 encoding/decoding
├── driver/             # Backend driver system
│   ├── apdu/           # APDU interface drivers
│   │   ├── pcsc.c      # PC/SC (smart card)
│   │   ├── qmi.c       # Qualcomm QMI
│   │   ├── qmi_qrtr.c  # QMI over QRTR
│   │   ├── mbim.c      # MBIM (Mobile Broadband)
│   │   ├── at_*.c      # AT command-based
│   │   ├── gbinder_hidl.c # Android HAL binder
│   │   └── stdio.c     # Standard I/O (testing)
│   ├── http/           # HTTP interface drivers
│   │   ├── curl.c      # cURL library
│   │   ├── winhttp.c   # Windows WinHTTP
│   │   └── stdio.c     # Standard I/O (testing)
│   └── euicc-driver-loader.c # Dynamic driver loading
├── src/                # CLI application
│   ├── main.c          # Entry point, context setup
│   ├── applet/         # Command implementations
│   │   ├── chip/       # Chip-related commands
│   │   ├── profile/    # Profile management commands
│   │   └── notification/ # Notification commands
│   └── jprint.c        # JSON output formatter
├── utils/              # Utility libraries
│   ├── base64.c        # Base64 encoding/decoding
│   ├── hexutil.c       # Hex string utilities
│   ├── sha256.c        # SHA-256 hashing
│   └── derutil.c       # DER utilities
└── cjson-ext/          # cJSON extensions
```

### Core Library: libeuicc

The `libeuicc` library implements the SGP.22 specification:

**ES10 Functions (eUICC-side):**
- **ES10a**: Profile metadata retrieval and discovery
- **ES10b**: Profile package download and installation
- **ES10c**: Profile lifecycle management (enable/disable/delete)
- **ES10c_ex**: Extended information queries

**ES9+ Functions (SM-DP+ server-side):**
- Initiate authentication
- Authenticate client
- Get bound profile package
- Handle notifications
- Cancel sessions

**ES8+ Functions (SM-DS server-side):**
- Discover events
- Retrieve event records

### Driver System

lpac uses a **pluggable driver architecture** with dynamic loading:

#### APDU Interface Drivers

APDU (Application Protocol Data Unit) drivers provide communication with eUICC hardware:

| Driver | Platform | Description |
|--------|----------|-------------|
| **pcsc** | All | PC/SC smart card (default) |
| **qmi** | Linux | Qualcomm QMI protocol |
| **qmi_qrtr** | Linux | QMI over QRTR transport |
| **mbim** | Linux/Windows | Mobile Broadband Interface Model |
| **at** | All | AT commands (ETSI, CSIM variants) |
| **gbinder** | Android | Android HAL via binder IPC |
| **stdio** | All | Standard I/O (testing only) |

#### HTTP Interface Drivers

HTTP drivers handle SM-DP+ and SM-DS server communication:

| Driver | Platform | Description |
|--------|----------|-------------|
| **curl** | All | libcurl library (default) |
| **winhttp** | Windows | Native WinHTTP API |
| **stdio** | All | Standard I/O (testing only) |

#### Driver Selection

Drivers are selected via environment variables:

```bash
export LPAC_APDU=pcsc          # APDU driver
export LPAC_HTTP=curl          # HTTP driver
```

If not specified, defaults to `pcsc` and `curl`.

#### Dynamic Loading

Drivers are compiled as shared libraries (`.so`, `.dll`, `.dylib`) and loaded at runtime:

```
Linux:   /usr/lib/lpac/driver/apdu/libapdu_pcsc.so
Windows: executables/driver/apdu/apdu_pcsc.dll
macOS:   /usr/local/lib/lpac/driver/apdu/libapdu_pcsc.dylib
```

## Core Concepts

### eUICC Context

All lpac operations revolve around the `euicc_ctx` structure:

```c
struct euicc_ctx {
    const uint8_t *aid;        // ISD-R Application Identifier
    uint8_t aid_len;
    uint8_t es10x_mss;         // Maximum Segment Size

    struct {
        const struct euicc_apdu_interface *interface;
        struct {
            int logic_channel;
            // Request buffer
        } _internal;
        FILE *log_fp;          // Debug logging
    } apdu;

    struct {
        const struct euicc_http_interface *interface;
        const char *server_address;
        struct {
            // Transaction state
        } _internal;
        FILE *log_fp;          // Debug logging
    } http;

    void *userdata;            // Application-specific data
};
```

**Lifecycle:**
1. Initialize context with `euicc_init()`
2. Perform operations (download, enable, etc.)
3. Clean up with `euicc_fini()`

### Interface Abstraction

lpac uses function pointer interfaces for hardware abstraction:

#### APDU Interface

```c
struct euicc_apdu_interface {
    int (*connect)(struct euicc_ctx *ctx);
    void (*disconnect)(struct euicc_ctx *ctx);
    int (*logic_channel_open)(struct euicc_ctx *ctx, const uint8_t *aid, uint8_t aid_len);
    void (*logic_channel_close)(struct euicc_ctx *ctx, uint8_t channel);
    int (*transmit)(struct euicc_ctx *ctx, uint8_t **rx, uint32_t *rx_len,
                    const uint8_t *tx, uint32_t tx_len);
    void *userdata;
};
```

**Operations:**
- `connect()`: Establish connection to eUICC
- `disconnect()`: Close connection
- `logic_channel_open()`: Open logical channel with AID
- `logic_channel_close()`: Close logical channel
- `transmit()`: Send/receive APDU commands

#### HTTP Interface

```c
struct euicc_http_interface {
    int (*transmit)(struct euicc_ctx *ctx, const char *url, uint32_t *rcode,
                    uint8_t **rx, uint32_t *rx_len, const uint8_t *tx,
                    uint32_t tx_len, const char **headers);
    void *userdata;
};
```

**Operations:**
- `transmit()`: Send HTTP POST request to SM-DP+/SM-DS

### ISD-R AID (Application Identifier)

The ISD-R (Issuer Security Domain Root) AID identifies the eUICC management applet:

**Default AID:** `A0000005591010FFFFFFFF8900000100`

**Custom AIDs for specific vendors:**
- **5ber:** `A0000005591010FFFFFFFF8900050500`
- **esim.me:** `A0000005591010000000008900000300`
- **xesim:** `A0000005591010FFFFFFFF8900000177`

Configure via environment variable:
```bash
export LPAC_CUSTOM_ISD_R_AID=A0000005591010FFFFFFFF8900050500
```

### ES10x Maximum Segment Size (MSS)

Controls APDU command fragmentation for compatibility with slower hardware:

**Default:** 60 bytes (set by libeuicc)
**Range:** 6-255 bytes

Configure via environment variable:
```bash
export LPAC_ES10X_MSS=30  # Use smaller segments
```

## CLI Usage

### Command Format

```bash
lpac <command> [subcommand] [parameters]
```

**Main Commands:**
- `chip`: View and manage eUICC chip information
- `profile`: Manage eSIM profiles
- `notification`: Manage notifications
- `driver`: View driver information
- `version`: Show lpac version

### JSON Output Format

All lpac commands return JSON in a standard format:

```json
{
  "type": "lpa",
  "payload": {
    "code": 0,
    "message": "success",
    "data": { /* command-specific data */ }
  }
}
```

**Fields:**
- `type`: Always `"lpa"`
- `code`: `0` for success, non-zero for errors
- `message`: Success message or error description
- `data`: Command result (empty object on error)

**Progress Updates:**

During long operations (e.g., download), lpac outputs progress:

```json
{
  "type": "progress",
  "payload": {
    "code": 0,
    "message": "es10b_get_euicc_challenge_and_info",
    "data": null
  }
}
```

### Chip Commands

#### Get Chip Info

```bash
lpac chip info
```

**Returns:**
- EID (eUICC Identifier)
- Default SM-DP+ address
- Root SM-DS address
- EUICCInfo2 (firmware version, memory, capabilities)

<details>
<summary>Example Output</summary>

```json
{
  "type": "lpa",
  "payload": {
    "code": 0,
    "message": "success",
    "data": {
      "eidValue": "89049032004008882600013212345678",
      "EuiccConfiguredAddresses": {
        "defaultDpAddress": null,
        "rootDsAddress": "testrootsmds.gsma.com"
      },
      "EUICCInfo2": {
        "profileVersion": "2.1.0",
        "svn": "2.2.0",
        "euiccFirmwareVer": "4.6.0",
        "extCardResource": {
          "installedApplication": 0,
          "freeNonVolatileMemory": 291666,
          "freeVolatileMemory": 5970
        },
        "uiccCapability": ["usimSupport", "isimSupport", ...],
        "globalplatformVersion": "2.3.0",
        "rspCapability": ["additionalProfile", "testProfileSupport"]
      }
    }
  }
}
```
</details>

---

#### Set Default SM-DP+

```bash
lpac chip defaultsmdp <smdp-address>
```

**Example:**
```bash
lpac chip defaultsmdp smdp.example.com
```

---

#### Purge eUICC (Factory Reset)

```bash
lpac chip purge
```

**Warning:** Deletes all profiles permanently!

---

### Profile Commands

#### List Profiles

```bash
lpac profile list
```

**Returns:** Array of profile objects

<details>
<summary>Example Output</summary>

```json
{
  "type": "lpa",
  "payload": {
    "code": 0,
    "message": "success",
    "data": [
      {
        "iccid": "89012345678901234567",
        "isdpAid": "a0000005591010ffffffff8900000100",
        "profileState": "enabled",
        "profileNickname": "My Profile",
        "serviceProviderName": "Example Carrier",
        "profileName": "Personal Plan",
        "iconType": "jpg",
        "icon": "/9j/4AAQSkZJRgABAQAAAQABAAD...",
        "profileClass": "operational"
      }
    ]
  }
}
```
</details>

**Profile States:**
- `enabled`: Active profile
- `disabled`: Inactive profile

**Profile Classes:**
- `operational`: Regular user profile
- `provisioning`: Temporary provisioning profile
- `test`: Test profile

---

#### Enable Profile

```bash
lpac profile enable <iccid> [refresh]
```

**Parameters:**
- `iccid`: Profile ICCID or ISD-P AID
- `refresh`: `1` (default) or `0` to control modem refresh

**Example:**
```bash
lpac profile enable 89012345678901234567
lpac profile enable 89012345678901234567 0  # No refresh
```

---

#### Disable Profile

```bash
lpac profile disable <iccid> [refresh]
```

**Parameters:**
- `iccid`: Profile ICCID or ISD-P AID
- `refresh`: `1` (default) or `0` to control modem refresh

**Example:**
```bash
lpac profile disable 89012345678901234567
```

---

#### Delete Profile

```bash
lpac profile delete <iccid>
```

**Example:**
```bash
lpac profile delete 89012345678901234567
```

---

#### Set Nickname

```bash
lpac profile nickname <iccid> <nickname>
```

**Example:**
```bash
lpac profile nickname 89012345678901234567 "Work SIM"
```

---

#### Download Profile

```bash
lpac profile download [options]
```

**Options:**
- `-a <activation-code>`: Full activation code (LPA:1$...)
- `-s <smdp-address>`: SM-DP+ server address
- `-m <matching-id>`: Matching ID
- `-c <confirmation-code>`: Confirmation code
- `-i <imei>`: Custom IMEI

**Examples:**

Download with activation code:
```bash
lpac profile download -a "LPA:1$smdp.example.com$MATCHING-ID-12345"
```

Download with confirmation code:
```bash
lpac profile download -a "LPA:1$smdp.example.com$MATCHING-ID-12345" -c "1234"
```

Download with custom IMEI:
```bash
lpac profile download -s smdp.example.com -m MATCHING-ID -i 123456789012345
```

**Download Progress:**

lpac outputs progress updates during download:

```json
{"type":"progress","payload":{"code":0,"message":"es10b_get_euicc_challenge_and_info","data":null}}
{"type":"progress","payload":{"code":0,"message":"es9p_initiate_authentication","data":null}}
{"type":"progress","payload":{"code":0,"message":"es10b_authenticate_server","data":null}}
{"type":"progress","payload":{"code":0,"message":"es9p_authenticate_client","data":null}}
{"type":"progress","payload":{"code":0,"message":"es10b_prepare_download","data":null}}
{"type":"progress","payload":{"code":0,"message":"es9p_get_bound_profile_package","data":null}}
{"type":"progress","payload":{"code":0,"message":"es10b_load_bound_profile_package","data":null}}
{"type":"lpa","payload":{"code":0,"message":"success","data":null}}
```

---

#### Profile Discovery (SM-DS)

```bash
lpac profile discovery [options]
```

**Options:**
- `-s <smds-address>`: SM-DS server address (optional)

**Example:**
```bash
lpac profile discovery
lpac profile discovery -s smds.example.com
```

**Returns:** List of available profiles registered on SM-DS

---

### Notification Commands

#### List Notifications

```bash
lpac notification list
```

**Returns:** Array of notification objects

<details>
<summary>Example Output</summary>

```json
{
  "type": "lpa",
  "payload": {
    "code": 0,
    "message": "success",
    "data": [
      {
        "seqNumber": 1,
        "profileManagementOperation": "install",
        "notificationAddress": "smdp.example.com",
        "iccid": "89012345678901234567"
      }
    ]
  }
}
```
</details>

---

#### Process Notification

```bash
lpac notification process <seq-number> [-r]
```

**Options:**
- `seq-number`: Notification sequence number
- `-r`: Remove notification after processing

**Example:**
```bash
lpac notification process 1 -r
```

---

#### Process All Notifications

```bash
lpac notification process -a [-r]
```

**Options:**
- `-a`: Process all notifications
- `-r`: Remove notifications after processing

**Example:**
```bash
lpac notification process -a -r
```

---

#### Remove Notification

```bash
lpac notification remove <seq-number>
```

**Example:**
```bash
lpac notification remove 1
```

---

### Driver Commands

#### List APDU Drivers

```bash
lpac driver apdu list
```

**Returns:** List of available APDU interfaces (e.g., card readers)

---

#### List HTTP Drivers

```bash
lpac driver http list
```

**Returns:** Information about loaded HTTP driver

---

### Version Command

```bash
lpac version
```

**Returns:** lpac version information

---

## Environment Variables

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `LPAC_APDU` | `pcsc` | APDU interface driver |
| `LPAC_HTTP` | `curl` | HTTP interface driver |
| `LPAC_CUSTOM_ISD_R_AID` | `A000...0100` | Custom ISD-R AID |
| `LPAC_ES10X_MSS` | `60` | Maximum segment size (6-255) |

### Driver-Specific Configuration

| Variable | Description |
|----------|-------------|
| `LPAC_APDU_QMI_UIM_SLOT` | QMI UIM slot number (1 or 2) |
| `UIM_SLOT` | Legacy QMI slot (deprecated) |
| `DRIVER_IFID` | PC/SC reader name |

### Debugging

| Variable | Description |
|----------|-------------|
| `LIBEUICC_DEBUG_HTTP` | Enable HTTP debugging (`1`) |
| `LIBEUICC_DEBUG_APDU` | Enable APDU debugging (`1`) |
| `LPAC_APDU_DEBUG` | APDU driver debug logging |
| `LPAC_HTTP_DEBUG` | HTTP driver debug logging |

**Example:**
```bash
export LIBEUICC_DEBUG_HTTP=1
export LIBEUICC_DEBUG_APDU=1
lpac chip info  # Outputs debug info
```

## Building lpac

### Prerequisites

**Required:**
- CMake 3.23+
- C99-compatible compiler (GCC, Clang, MSVC)
- cJSON library (auto-downloaded if needed)

**Optional (drivers):**
- libpcsclite (PC/SC)
- libcurl (HTTP)
- libqmi (Qualcomm QMI)
- libmbim (MBIM)
- Windows SDK (WinHTTP)

### Build Commands

#### Linux/macOS

```bash
cmake -B build
cmake --build build
cmake --install build
```

#### Windows (MSVC)

```bash
cmake -B build -G "Visual Studio 17 2022"
cmake --build build --config Release
cmake --install build
```

#### Cross-Compilation

```bash
cmake -B build -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake
cmake --build build
```

### Build Options

| Option | Default | Description |
|--------|---------|-------------|
| `USE_SYSTEM_DEPS` | `OFF` | Use system-installed dependencies |
| `STANDALONE_MODE` | `OFF` | Relocatable directory structure |
| `LPAC_DYNAMIC_LIBEUICC` | `ON` | Build libeuicc as shared library |

**Example:**
```bash
cmake -B build -DUSE_SYSTEM_DEPS=ON -DSTANDALONE_MODE=ON
```

### Output Structure

**Linux Standard:**
```
/usr/bin/lpac
/usr/lib/libeuicc.so
/usr/lib/lpac/driver/apdu/*.so
/usr/lib/lpac/driver/http/*.so
```

**Standalone Mode:**
```
executables/lpac
executables/lib/libeuicc.so
executables/driver/apdu/*.so
executables/driver/http/*.so
```

## Integration Guide

### Subprocess Integration (EasyLPAC, lpa-gtk)

Execute lpac as external process and parse JSON output:

```python
import subprocess
import json

def lpac_chip_info():
    result = subprocess.run(
        ['lpac', 'chip', 'info'],
        capture_output=True,
        text=True,
        env={'LPAC_APDU': 'pcsc', 'LPAC_HTTP': 'curl'}
    )

    response = json.loads(result.stdout)
    if response['payload']['code'] == 0:
        return response['payload']['data']
    else:
        raise Exception(response['payload']['message'])
```

### JNI Integration (OpenEUICC)

Link against libeuicc and call functions directly:

```c
// JNI wrapper
JNIEXPORT jlong JNICALL
Java_LpacJni_createContext(JNIEnv *env, jclass cls, jbyteArray aid,
                           jobject apdu_iface, jobject http_iface) {
    struct euicc_ctx *ctx = malloc(sizeof(struct euicc_ctx));

    // Initialize APDU interface
    ctx->apdu.interface = &apdu_interface_impl;

    // Initialize HTTP interface
    ctx->http.interface = &http_interface_impl;

    // Initialize context
    if (euicc_init(ctx) < 0) {
        free(ctx);
        return 0;
    }

    return (jlong)ctx;
}
```

### Direct Library Integration

Link against libeuicc in C/C++ applications:

```c
#include <euicc/euicc.h>
#include <euicc/es10c.h>

struct euicc_ctx ctx = {0};
ctx.apdu.interface = &my_apdu_interface;
ctx.http.interface = &my_http_interface;

if (euicc_init(&ctx) < 0) {
    fprintf(stderr, "Failed to initialize\n");
    return -1;
}

// List profiles
struct es10c_profile_info *profiles = NULL;
if (es10c_get_profiles_info(&ctx, &profiles) == 0) {
    for (struct es10c_profile_info *p = profiles; p; p = p->next) {
        printf("ICCID: %s\n", p->iccid);
        printf("State: %s\n", p->profileState);
    }
    es10c_profile_info_free_all(profiles);
}

euicc_fini(&ctx);
```

## Error Handling

### Error Codes

lpac uses negative return codes for errors:

| Code | Description |
|------|-------------|
| `0` | Success |
| `-1` | Generic error |
| `-2` | Memory allocation failure |
| `-3` | APDU transmission error |
| `-4` | HTTP transmission error |
| `-5` | Invalid response from server |
| `-6` | Profile not found |
| `-7` | Operation not allowed |

### ES9+ Error Codes

Server-side errors from SM-DP+:

| Subject Code | Reason Code | Description |
|-------------|-------------|-------------|
| `8.1` | `3.1` | Unable to process the request |
| `8.1` | `3.8` | Matching ID not found |
| `8.1` | `3.9` | Incompatible profile |
| `8.2` | `2.2` | Invalid confirmation code |
| `8.8` | - | Undefined error |

**Example Error:**
```json
{
  "type": "lpa",
  "payload": {
    "code": -1,
    "message": "es9p_error",
    "data": "{\"subjectCode\":\"8.1\",\"reasonCode\":\"3.8\",\"message\":\"Matching ID not found\"}"
  }
}
```

## Ecosystem Software

Applications built on lpac:

1. **[EasyLPAC](https://github.com/creamlike1024/EasyLPAC)**
   - Platform: Windows, Linux, macOS
   - GUI: Fyne (Go)
   - Integration: Subprocess

2. **[OpenEUICC/EasyEUICC](https://gitea.angry.im/PeterCxy/OpenEUICC)**
   - Platform: Android
   - GUI: Native Android
   - Integration: JNI

3. **[lpa-gtk (eSIM Manager)](https://codeberg.org/lucaweiss/lpa-gtk)**
   - Platform: Linux Mobile (Phosh/GNOME)
   - GUI: GTK4 + Libadwaita
   - Integration: Subprocess

4. **[rlpa-server](https://github.com/estkme-group/rlpa-server)**
   - Platform: Server-side
   - Purpose: eSTK.me Cloud Enhance
   - Integration: Direct library

## Advanced Topics

### Custom Driver Development

Create a new APDU driver:

```c
// my_apdu_driver.c
#include "driver.h"

static int apdu_connect(struct euicc_ctx *ctx) {
    // Implement connection logic
    return 0;
}

static void apdu_disconnect(struct euicc_ctx *ctx) {
    // Implement disconnection logic
}

static int apdu_transmit(struct euicc_ctx *ctx, uint8_t **rx,
                        uint32_t *rx_len, const uint8_t *tx, uint32_t tx_len) {
    // Implement APDU transmission
    return 0;
}

const struct euicc_driver driver_apdu_my_driver = {
    .type = DRIVER_APDU,
    .name = "my_driver",
    .apdu = {
        .connect = apdu_connect,
        .disconnect = apdu_disconnect,
        .transmit = apdu_transmit,
    },
};
```

**Compile as shared library:**
```bash
gcc -shared -fPIC -o libapdu_my_driver.so my_apdu_driver.c
```

### Performance Tuning

**Reduce APDU overhead:**
```bash
export LPAC_ES10X_MSS=255  # Maximum segment size
```

**Enable connection pooling (cURL):**
```bash
export CURL_VERBOSE=0
```

**Optimize for slow card readers:**
```bash
export LPAC_ES10X_MSS=30  # Smaller segments
```

## Troubleshooting

### Common Issues

**1. "lpac: command not found"**
- Install lpac or add to PATH

**2. "SCardEstablishContext() failed: 8010001D"**
- PC/SC daemon not running
- Start: `sudo systemctl start pcscd`

**3. "es10c_euicc_init error: -1"**
- Wrong ISD-R AID
- Try: `export LPAC_CUSTOM_ISD_R_AID=<correct-aid>`

**4. "curl: (60) SSL certificate problem"**
- Certificate validation issue
- Debug: `export LIBEUICC_DEBUG_HTTP=1`

**5. Download fails at "es9p_authenticate_client"**
- Confirmation code required
- Add: `-c <confirmation-code>`

### Debug Logging

Enable comprehensive debugging:

```bash
export LIBEUICC_DEBUG_HTTP=1
export LIBEUICC_DEBUG_APDU=1
lpac profile download -a "LPA:1$..." 2>&1 | tee lpac.log
```

Output includes:
- HTTP requests/responses
- APDU commands/responses
- Internal state transitions

## References

### Specifications

- **SGP.22 v2.2.2**: RSP Technical Specification
- **SGP.21**: RSP Architecture
- **GlobalPlatform**: Card Specification v2.3
- **ETSI TS 102 221**: Smart Card Platform

### Related Projects

- **libeuicc**: Core library (part of lpac)
- **lpac-jni**: JNI wrapper for Android
- **qmi_uim**: Qualcomm QMI UIM library
- **pcscd**: PC/SC daemon

### Documentation

- [Usage Guide](https://github.com/estkme-group/lpac/blob/master/docs/USAGE.md)
- [Developer Guide](https://github.com/estkme-group/lpac/blob/master/docs/DEVELOPERS.md)
- [Environment Variables](https://github.com/estkme-group/lpac/blob/master/docs/ENVVARS.md)
- [FAQ](https://github.com/estkme-group/lpac/blob/master/docs/FAQ.md)

## License

lpac is free and open-source software:

- **Core (libeuicc)**: GPL-3.0-or-later
- **Utilities**: MIT and other permissive licenses
- **Drivers**: Various (see individual files)

See [REUSE.toml](https://github.com/estkme-group/lpac/blob/master/REUSE.toml) for complete licensing information.

---

**Last Updated:** 2025-10-23
**Project Maintainer:** ESTKME TECHNOLOGY LIMITED
