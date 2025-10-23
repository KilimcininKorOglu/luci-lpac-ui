# EasyLPAC - Technical Documentation

## Overview

EasyLPAC is a cross-platform GUI frontend for [lpac](https://github.com/estkme-group/lpac), written in Go using the Fyne toolkit. It provides a user-friendly interface for managing eSIM profiles through the lpac command-line tool.

**Repository:** <https://github.com/creamlike1024/EasyLPAC>

## Project Purpose

EasyLPAC serves as a graphical wrapper around the lpac CLI tool, making eSIM profile management accessible to users who prefer a GUI over command-line interactions. It handles:

- eUICC chip information retrieval
- eSIM profile management (download, enable, disable, delete)
- Profile notifications processing
- Card reader detection and management

## Architecture

### Technology Stack

- **Language:** Go 1.24
- **GUI Framework:** Fyne v2.6.0
- **Backend:** lpac (command-line tool)
- **Communication:** Executes lpac as external process, parses JSON output

### System Requirements

- **Windows:** Windows 10+ (Windows 7 supported up to v0.7.7.2)
- **macOS:** Latest macOS
- **Linux:** `pcscd`, `pcsclite`, `libcurl`, `gtk3dialog`
- **Card Reader:** PC/SC compatible card reader

### Supported Interfaces

- **APDU Interface:** PC/SC (PCSC)
- **HTTP Interface:** cURL

## How lpac is Used

### Integration Method

EasyLPAC integrates with lpac by:

1. Locating the lpac binary (same directory or `/usr/bin/lpac` on Linux)
2. Executing lpac commands via `os/exec.Command()`
3. Setting required environment variables
4. Parsing JSON-formatted stdout responses
5. Handling errors from stderr

### lpac Execution Flow

```go
// From cmd.go:19
func runLpac(args ...string) (json.RawMessage, error) {
    // 1. Build command path
    lpacPath := filepath.Join(ConfigInstance.LpacDir, ConfigInstance.EXEName)

    // 2. Create command with arguments
    cmd := exec.Command(lpacPath, args...)

    // 3. Set environment variables
    cmd.Env = []string{
        "LPAC_APDU=pcsc",
        "LPAC_HTTP=curl",
        fmt.Sprintf("DRIVER_IFID=%s", ConfigInstance.DriverIFID),
        fmt.Sprintf("LPAC_CUSTOM_ISD_R_AID=%s", ConfigInstance.LpacAID),
    }

    // 4. Execute and parse JSON response
    // 5. Return parsed data
}
```

### Environment Variables

| Variable | Purpose | Value |
|----------|---------|-------|
| `LPAC_APDU` | APDU driver interface | `pcsc` |
| `LPAC_HTTP` | HTTP library interface | `curl` |
| `DRIVER_IFID` | PC/SC card reader identifier | Set from card reader selection |
| `LPAC_CUSTOM_ISD_R_AID` | Custom ISD-R Application Identifier | Configurable (default, 5ber, esim.me, xesim) |
| `LIBEUICC_DEBUG_HTTP` | Enable HTTP debugging | `1` (optional) |
| `LIBEUICC_DEBUG_APDU` | Enable APDU debugging | `1` (optional) |

### Predefined AIDs

```go
// From config.go:11-14
const AID_DEFAULT = "A0000005591010FFFFFFFF8900000100"
const AID_5BER = "A0000005591010FFFFFFFF8900050500"
const AID_ESIMME = "A0000005591010000000008900000300"
const AID_XESIM = "A0000005591010FFFFFFFF8900000177"
```

## lpac Command Reference

### 1. Chip Information

**Command:**

```bash
lpac chip info
```

**Function in EasyLPAC:**

```go
func LpacChipInfo() (*EuiccInfo, error)
```

**Returns:**

- EID (eUICC Identifier)
- Default SM-DP+ address
- Root SM-DS address
- EUICCInfo2 (firmware version, capabilities, free memory, etc.)

---

### 2. Profile Management

#### List Profiles

**Command:**

```bash
lpac profile list
```

**Function:**

```go
func LpacProfileList() ([]*Profile, error)
```

**Returns:** Array of profiles with:

- ICCID
- Profile state (enabled/disabled)
- Service provider name
- Profile nickname
- Profile class

#### Enable Profile

**Command:**

```bash
lpac profile enable <iccid>
```

**Function:**

```go
func LpacProfileEnable(iccid string) error
```

#### Disable Profile

**Command:**

```bash
lpac profile disable <iccid>
```

**Function:**

```go
func LpacProfileDisable(iccid string) error
```

#### Delete Profile

**Command:**

```bash
lpac profile delete <iccid>
```

**Function:**

```go
func LpacProfileDelete(iccid string) error
```

#### Download Profile

**Command:**

```bash
lpac profile download -s <smdp> -m <matchid> -c <confirmcode> -i <imei>
```

**Function:**

```go
func LpacProfileDownload(info PullInfo)
```

**Parameters:**

- `-s`: SM-DP+ address
- `-m`: Matching ID
- `-c`: Confirmation code
- `-i`: IMEI (optional)

#### Set Profile Nickname

**Command:**

```bash
lpac profile nickname <iccid> <nickname>
```

**Function:**

```go
func LpacProfileNickname(iccid, nickname string) error
```

---

### 3. Notification Management

#### List Notifications

**Command:**

```bash
lpac notification list
```

**Function:**

```go
func LpacNotificationList() ([]*Notification, error)
```

#### Process Notification

**Command:**

```bash
lpac notification process [-r] <seqnumber>
```

**Function:**

```go
func LpacNotificationProcess(seq int, remove bool) error
```

**Parameters:**

- `-r`: Remove notification after processing

#### Remove Notification

**Command:**

```bash
lpac notification remove <seqnumber>
```

**Function:**

```go
func LpacNotificationRemove(seq int) error
```

---

### 4. Driver Management

#### List APDU Drivers

**Command:**

```bash
lpac driver apdu list
```

**Function:**

```go
func LpacDriverApduList() ([]*ApduDriver, error)
```

**Returns:** List of available PC/SC card readers

---

### 5. Chip Configuration

#### Set Default SM-DP+

**Command:**

```bash
lpac chip defaultsmdp <smdp>
```

**Function:**

```go
func LpacChipDefaultSmdp(smdp string) error
```

---

### 6. Version Information

**Command:**

```bash
lpac version
```

**Function:**

```go
func LpacVersion() (string, error)
```

## Data Structures

### Profile

```go
type Profile struct {
    Iccid               string
    IsdpAid             string
    ProfileState        string
    ProfileNickname     *string
    ServiceProviderName string
    ProfileName         string
    IconType            string
    Icon                []byte
    ProfileClass        string
}
```

### Notification

```go
type Notification struct {
    SeqNumber                  int
    ProfileManagementOperation string
    NotificationAddress        string
    Iccid                      string
}
```

### EuiccInfo

```go
type EuiccInfo struct {
    EidValue                 string
    EuiccConfiguredAddresses struct {
        DefaultDpAddress any
        RootDsAddress    string
    }
    EUICCInfo2 struct {
        ProfileVersion   string
        Svn              string
        EuiccFirmwareVer string
        ExtCardResource  struct {
            InstalledApplication  int
            FreeNonVolatileMemory int
            FreeVolatileMemory    int
        }
        // ... more fields
    }
}
```

### lpac Response Format

```go
type LpacReturnValue struct {
    Type    string // Always "lpa"
    Payload struct {
        Code    int             // 0 = success, non-zero = error
        Message string          // Error message or function name
        Data    json.RawMessage // Actual response data
    }
}
```

## Key Source Files

### Core Files

| File | Purpose |
|------|---------|
| `main.go` | Application entry point, initialization |
| `cmd.go` | lpac command execution and wrapper functions |
| `struct.go` | Data structure definitions |
| `control.go` | Application control logic, refresh operations |
| `window.go` | Main window UI layout |
| `widgets.go` | UI widget definitions and event handlers |
| `config.go` | Configuration management, lpac binary location |

### Supporting Files

| File | Purpose |
|------|---------|
| `i18n.go` | Internationalization support |
| `theme.go` | Custom Fyne theme |
| `font.go` | Font embedding |
| `utils.go` | Utility functions |
| `ci-registry.go` | Certificate Issuer registry |
| `eum-registry.go` | eUICC Manufacturer registry |
| `proc_windows.go` | Windows-specific process handling |
| `proc_other.go` | Unix-like OS process handling |

## Configuration

### lpac Binary Search Order (Linux)

1. Same directory as EasyLPAC executable
2. `/usr/bin/lpac`

### Log Files

- **Windows:** `<exe_dir>/log/lpac-YYYYMMDD-HHMMSS.txt`
- **Linux/macOS:** `/tmp/EasyLPAC-log/lpac-YYYYMMDD-HHMMSS.txt`

### Auto-Process Notification

By default, EasyLPAC automatically processes and removes notifications after successful operations. This can be disabled in Settings.

**Note:** Manual notification manipulation does not comply with GSMA specifications.

## Common Issues and Troubleshooting

### lpac Error: `euicc_init` (5ber users)

**Solution:** Go to Settings → lpac ISD-R AID → Select "5ber" to set custom AID

### macOS: `SCardTransmit() failed: 80100016`

**Cause:** Bug in Apple's USB CCID Card Reader Driver on macOS Sonoma

**Solution:** Install card reader manufacturer's driver

### `SCardEstablishContext() failed: 8010001D`

**Cause:** PCSC service not running

**Solution (Linux):**

```bash
sudo systemctl start pcscd
```

### `SCardListReaders() failed: 8010002E`

**Cause:** Card reader not connected

**Solution:** Connect card reader before running EasyLPAC

## Workflow Examples

### Example 1: Download Profile

1. **User Action:** Enter activation code in UI
2. **EasyLPAC:** Parses QR code or manual input
3. **Execution:**

   ```bash
   lpac profile download -s <smdp> -m <matchid> -c <confirmcode>
   ```

4. **Post-Download:**
   - Refresh notification list
   - Find new notification
   - If auto-mode: Process and remove notification
   - If manual-mode: Prompt user to process notification

### Example 2: Enable Profile

1. **User Action:** Select profile, click "Enable"
2. **Execution:**

   ```bash
   lpac profile enable <iccid>
   ```

3. **Post-Enable:** Refresh profile list to update UI

### Example 3: Get Chip Info

1. **User Action:** Click "Refresh" button
2. **Execution:**

   ```bash
   lpac chip info
   ```

3. **Display:**
   - EID
   - Default SM-DP+ address
   - Free memory
   - Manufacturer info (from EUM registry)

## Development Notes

### Concurrency Model

- **Status Updates:** Channel-based (`StatusChan`)
- **Button Locking:** Channel-based (`LockButtonChan`)
- **Long Operations:** Run in goroutines with UI blocking

### Error Handling

- lpac errors parsed from JSON response codes
- PC/SC errors detected from stderr
- Error dialogs shown to user via Fyne dialog

### Testing

Unit tests in `utils_test.go` for utility functions.

## Build and Deployment

### Dependencies

Install via `go get`:

```bash
go mod download
```

### Building

```bash
# Native build
go build

# Cross-platform with Fyne
fyne package
```

### Release Platforms

- Windows (x86_64)
- macOS (Universal)
- Linux (x86_64, with/without lpac binary)

## Additional Resources

- **lpac Documentation:** <https://github.com/estkme-group/lpac>
- **Fyne Documentation:** <https://docs.fyne.io/>
- **PCSC-Lite Error Codes:** <https://pcsclite.apdu.fr/api/group__ErrorCodes.html>
- **GSMA SGP.22 Specification:** Remote SIM Provisioning standard

## Version Information

- **EasyLPAC Version:** Defined in `main.go:13` as `Version` constant
- **Compatible lpac Interface:** JSON-based command-line interface

---

**Last Updated:** 2025-10-23
