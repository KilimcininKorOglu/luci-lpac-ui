# lpa-gtk (eSIM Manager) - Technical Documentation

## Overview

**eSIM Manager** (lpa-gtk) is a GTK4 + Libadwaita-based graphical user interface for managing eSIM profiles on Linux devices, particularly targeting Linux phones using Phosh/GNOME Mobile. It uses [lpac](https://github.com/estkme-group/lpac) as its backend to interact with eUICC (embedded Universal Integrated Circuit Card) hardware.

**Repository:** <https://codeberg.org/lucaweiss/lpa-gtk>
**License:** GPL-3.0-only
**Version:** 0.3

## Project Purpose

lpa-gtk provides a mobile-friendly GTK4 application for:

- Managing eSIM profiles on Linux phones and computers
- Downloading and activating eSIM profiles
- Managing both built-in and removable eUICC cards
- Supporting dual-SIM devices (multiple slots)
- Handling automatic notification processing in the background

## Architecture

### Technology Stack

- **Language:** Python 3
- **GUI Framework:** GTK4 + Libadwaita 1.7+
- **UI Definition:** Blueprint Compiler
- **Build System:** Meson
- **Backend:** lpac (external command-line tool)
- **Modem Communication:** QMI over QRTR (Qualcomm modems)

### System Requirements

#### Runtime Dependencies

- GTK4
- Libadwaita (≥ 1.7)
- Python 3
- PyGObject (Python GObject Introspection bindings)
- lpac

#### Build-Time Dependencies

- Meson
- Blueprint Compiler

### Supported Hardware

- **Primary Target:** Qualcomm-based phones using QMI + QRTR
  - Must use QMI + QRTR to communicate with modem
  - Recent phones (not 10+ year old devices)
- **Potential Support:** Other platforms with lpac backend (requires minor changes)

## How lpac is Used

### Integration Method

lpa-gtk integrates with lpac through:

1. **Binary Discovery:** Uses `shutil.which("lpac")` to locate lpac executable
2. **Process Execution:** Spawns lpac as subprocess via `subprocess.Popen()` or `subprocess.check_output()`
3. **Environment Configuration:** Sets required environment variables
4. **JSON Parsing:** Parses line-delimited JSON output from lpac
5. **Stream Processing:** Supports streaming progress updates during operations

### Backend Architecture

lpa-gtk implements a modular backend system with two implementations:

#### 1. LpacBackend (Production)

Real lpac integration for actual hardware interaction.

#### 2. DummyBackend (Development/Testing)

Mock backend for development without hardware, enabled via `LPA_GTK_BACKEND=dummy`.

### lpac Execution Pattern

```python
# From esim.py:266
class LpacBackend(ESimBackend):
    def __init__(self, slot: int, backend_type: LpacBackend.Type):
        self.slot = slot
        self.backend_type = backend_type
        self.lpac_exe = shutil.which("lpac")  # Find lpac binary
```

#### Environment Variables Setup

```python
# From esim.py:270
def __get_lpac_env(self) -> dict[str, str]:
    env = os.environ.copy()

    if self.backend_type == ESimBackend.Type.QMI_QRTR:
        env["LPAC_APDU"] = "qmi_qrtr"
        env["LPAC_APDU_QMI_UIM_SLOT"] = str(self.slot)
        env["UIM_SLOT"] = str(self.slot)  # deprecated

    return env
```

| Variable | Purpose | Value |
|----------|---------|-------|
| `LPAC_APDU` | APDU driver interface | `qmi_qrtr` |
| `LPAC_APDU_QMI_UIM_SLOT` | Modem SIM slot number | `1` or `2` |
| `UIM_SLOT` | Legacy slot specification | `1` or `2` (deprecated) |

#### Execution Methods

**1. Simple Command Execution (`__run_lpac`)**

```python
# From esim.py:308
def __run_lpac(self, lpac_args) -> dict:
    output = subprocess.check_output(
        [self.lpac_exe] + lpac_args,
        env=self.__get_lpac_env()
    )
    res = self.__parse_output(json.loads(output))
    return res.data
```

**2. Streaming Execution (`__run_lpac_stream`)**

```python
# From esim.py:318
def __run_lpac_stream(self, lpac_args) -> Iterator[LpacProgressTypes]:
    with subprocess.Popen(
        [self.lpac_exe] + lpac_args,
        env=self.__get_lpac_env(),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT
    ) as process:
        for line_obj in process.stdout:
            line = line_obj.decode('utf8')
            try:
                obj = json.loads(line)
                yield self.__parse_output(obj)
            except json.decoder.JSONDecodeError:
                # Pass through non-JSON output (e.g., curl errors)
                yield LpacBackend.LpacMisc(line.strip())
```

### lpac Response Types

lpa-gtk handles three types of responses:

#### 1. LpacData

```python
@dataclass
class LpacData:
    message: str           # Function name or status
    data: str | dict | None  # Response data
```

#### 2. LpacProgress

```python
@dataclass
class LpacProgress:
    message: str           # Progress step name
    data: str | dict | None  # Progress data
```

#### 3. LpacMisc

```python
@dataclass
class LpacMisc:
    value: str  # Non-JSON output (errors, debug info)
```

### JSON Output Parsing

```python
# From esim.py:291
def __parse_output(self, output: dict) -> LpacProgressTypes:
    data_type = output["type"]
    payload = output["payload"]

    if data_type == "lpa":
        code = payload["code"]
        if code != 0:
            raise ESimError(f"Error from lpac: {code}")
        return LpacBackend.LpacData(
            message=payload["message"],
            data=payload["data"]
        )

    if data_type == "progress":
        code = payload["code"]
        if code != 0:
            raise ESimError(f"Error from lpac: {code}")
        return LpacBackend.LpacProgress(
            message=payload["message"],
            data=payload["data"]
        )
```

## lpac Command Reference

### 1. Profile Management

#### List Profiles

**Command:**

```bash
lpac profile list
```

**Implementation:**

```python
# From esim.py:336
def get_profiles(self) -> list[ESimProfile]:
    profiles = []
    for profile_data in self.__run_lpac(["profile", "list"]):
        profile = ESimProfile.from_dict(self, profile_data)
        profiles.append(profile)
    return profiles
```

#### Download Profile (with SM-DP+ server and matching ID)

**Command:**

```bash
lpac profile download -s <smdp_server> -m <matching_id>
```

**Implementation:**

```python
# From esim.py:344
def download_profile(self, smdp_server: str, matching_id: str) -> Iterator[LpacProgressTypes]:
    res = self.__run_lpac_stream([
        "profile", "download",
        "-s", smdp_server,
        "-m", matching_id
    ])
    return res
```

#### Download Profile (with activation code)

**Command:**

```bash
lpac profile download -a <activation_code>
```

**Implementation:**

```python
# From esim.py:348
def download_profile_code(self, activation_code: str) -> Iterator[LpacProgressTypes]:
    res = self.__run_lpac_stream([
        "profile", "download",
        "-a", activation_code
    ])
    return res
```

**Progress Steps During Download:**

1. `es10b_get_euicc_challenge_and_info`
2. `es9p_initiate_authentication`
3. `es10b_authenticate_server`
4. `es9p_authenticate_client`
5. `es10b_prepare_download`
6. `es9p_get_bound_profile_package`
7. `es10b_load_bound_profile_package`
8. Success message

#### Enable Profile

**Command:**

```bash
lpac profile enable <iccid>
```

**Implementation:**

```python
# From esim.py:352
def enable_profile(self, iccid: str) -> None:
    self.__run_lpac(["profile", "enable", iccid])
```

#### Disable Profile

**Command:**

```bash
lpac profile disable <iccid>
```

**Implementation:**

```python
# From esim.py:355
def disable_profile(self, iccid: str) -> None:
    self.__run_lpac(["profile", "disable", iccid])
```

#### Delete Profile

**Command:**

```bash
lpac profile delete <iccid>
```

**Implementation:**

```python
# From esim.py:358
def delete_profile(self, iccid: str) -> None:
    self.__run_lpac(["profile", "delete", iccid])
```

#### Set Profile Nickname

**Command:**

```bash
lpac profile nickname <iccid> <nickname>
```

**Implementation:**

```python
# From esim.py:361
def set_profile_nickname(self, iccid: str, nickname: str) -> None:
    self.__run_lpac(["profile", "nickname", iccid, nickname])
```

---

### 2. Chip Information

**Command:**

```bash
lpac chip info
```

**Implementation:**

```python
# From esim.py:364
def get_chip_info(self) -> dict:
    return self.__run_lpac(["chip", "info"])
```

---

### 3. Notification Management

#### List Notifications

**Command:**

```bash
lpac notification list
```

**Implementation:**

```python
# From esim.py:367
def get_notifications(self) -> list[ESimNotification]:
    notifications = []
    for notification_data in self.__run_lpac(["notification", "list"]):
        notification = ESimNotification.from_dict(self, notification_data)
        notifications.append(notification)
    return notifications
```

#### Process All Notifications

**Command:**

```bash
lpac notification process -a [-r]
```

**Implementation:**

```python
# From esim.py:375
def process_notifications(self, remove: bool) -> Iterator[LpacProgressTypes]:
    command = ["notification", "process", "-a"]
    if remove:
        command.append("-r")
    res = self.__run_lpac_stream(command)
    return res
```

**Parameters:**

- `-a`: Process all notifications
- `-r`: Remove notification after processing

#### Process Specific Notification(s)

**Command:**

```bash
lpac notification process [-r] <seq_number> [<seq_number2> ...]
```

**Implementation:**

```python
# From esim.py:382
def process_notification(self, seq_numbers: list[int], remove: bool) -> Iterator[LpacProgressTypes]:
    command = ["notification", "process"]
    if remove:
        command.append("-r")
    for seq_number in seq_numbers:
        command.append(str(seq_number))
    res = self.__run_lpac_stream(command)
    return res
```

#### Remove Notification

**Command:**

```bash
lpac notification remove <seq_number>
```

**Implementation:**

```python
# From esim.py:391
def remove_notification(self, seq_number: int) -> Iterator[LpacProgressTypes]:
    res = self.__run_lpac_stream([
        "notification", "remove",
        str(seq_number)
    ])
    return res
```

## Data Structures

### ESimProfile

```python
@dataclass
class ESimProfile:
    _backend: ESimBackend

    iccid: str                        # ICCID of Profile
    isdp_aid: str                     # AID of Profile
    state: ESimProfileState           # "enabled" or "disabled"
    nickname: str | None              # User-defined nickname
    service_provider_name: str        # Telecom operator name
    name: str                         # Profile name
    icon_type: str | None             # "none", "png", "jpg"
    icon: bytes | None                # Profile icon data
    profile_class: ESimProfileClass   # "test", "provisioning", "operational"

    # Methods
    def enable(self) -> None
    def disable(self) -> None
    def delete(self) -> None
    def set_nickname(self, nickname: str) -> None
```

### ESimNotification

```python
@dataclass
class ESimNotification:
    _backend: ESimBackend

    seq_number: int                      # Sequence number
    profile_management_operation: str    # Operation type (e.g., "install")
    notification_address: str            # Server address
    iccid: str                           # Related profile ICCID

    # Methods
    def process(self, remove: bool) -> Iterator[LpacProgressTypes]
    def remove(self) -> Iterator[LpacProgressTypes]
```

### ESimManager

```python
class ESimManager:
    """Main interface for eSIM operations"""

    def __init__(self, backends: list[ESimBackend])
    def get_chip_info(self, slot: int) -> dict
    def get_profiles(self, slot: int) -> list[ESimProfile]
    def download_profile(self, slot: int, smdp_server: str, matching_id: str) -> Iterator
    def download_profile_code(self, slot: int, activation_code: str) -> Iterator
    def get_notifications(self, slot: int) -> list[ESimNotification]
```

## Project Structure

### Core Source Files

| File | Purpose |
|------|---------|
| `src/main.py` | Application entry point, GTK/Adwaita initialization |
| `src/mainwindow.py` | Main window controller, navigation management |
| `src/esim.py` | Core eSIM management logic, lpac backend integration |
| `src/notificationtask.py` | Background notification processing thread |
| `src/helpers.py` | UI helper functions (toasts, dialogs) |

### UI Pages

| File | Purpose |
|------|---------|
| `src/pages/esimlist.py` | Profile list page |
| `src/pages/esimdetail.py` | Profile detail/management page |
| `src/pages/esimdownload.py` | Profile download page |
| `src/pages/chipinfo.py` | eUICC chip information page |

### UI Components

| File | Purpose |
|------|---------|
| `src/widgets/esimprofile.py` | Profile list item widget |
| `*.blp` files | Blueprint UI definitions (compiled to GTK XML) |

### Build System

| File | Purpose |
|------|---------|
| `meson.build` | Main Meson build configuration |
| `src/meson.build` | Source installation rules |
| `data/meson.build` | Resource installation rules |

### Application Data

| File | Purpose |
|------|---------|
| `data/eu.lucaweiss.lpa_gtk.desktop` | Desktop entry file |
| `data/eu.lucaweiss.lpa_gtk.metainfo.xml` | AppStream metadata |
| `data/*.svg` | Application icons |

## Key Features

### 1. Multi-Slot Support

lpa-gtk supports dual-SIM devices with independent eUICC in each slot:

```python
# From mainwindow.py:32
backends = esim.ESimBackend.get_operational_backends()

# Backends can return [slot1], [slot2], or [slot1, slot2]
# UI adapts automatically:
# - Single slot: Hide slot selector
# - Dual slot: Show slot toggle buttons
```

### 2. Automatic Notification Processing

Background thread automatically processes eSIM notifications after operations:

```python
# From notificationtask.py:35
def notification_thread(self, success_cb, error_cb) -> None:
    for slot in self.available_slots:
        notifications = self.esim_manager.get_notifications(slot)
        for notification in notifications:
            for val in notification.process(remove=True):
                # Process progress updates
                logs.append(progress_message)
```

**Notification Processing Steps:**

1. `es10b_retrieve_notifications_list` - Retrieve notification
2. `es9p_handle_notification` - Send to server
3. Optional: Remove notification from eUICC

### 3. Profile Filtering

UI filters profiles to show only operational profiles by default:

```python
# From esimlist.py:73
all_profiles = self._manager.get_profiles(self.active_slot)
profiles = list(filter(
    lambda p: p.profile_class == esim.ESimProfileClass.OPERATIONAL,
    all_profiles
))
```

Profile classes:

- **operational**: Regular user profiles (shown)
- **provisioning**: Temporary provisioning profiles (hidden)
- **test**: Test profiles (hidden)

### 4. Development Mode

Dummy backend for development without hardware:

```bash
LPA_GTK_BACKEND=dummy lpa-gtk
```

Features:

- Generates random dummy profiles
- Simulates download progress with delays
- Mock notification processing
- No real hardware required

## Installation

### Building from Source

```bash
# Install dependencies (example for Debian/Ubuntu)
sudo apt install meson blueprint-compiler \
    libgtk-4-dev libadwaita-1-dev \
    python3-gi lpac

# Build
meson setup builddir -Dprefix=/usr
meson compile -C builddir
meson install -C builddir
```

### Running

```bash
# Normal mode
lpa-gtk

# Development mode (dummy backend)
LPA_GTK_BACKEND=dummy lpa-gtk
```

## Workflow Examples

### Example 1: Download Profile with Activation Code

1. **User:** Enters activation code (e.g., `LPA:1$...`)
2. **Application:**

   ```python
   manager.download_profile_code(slot, activation_code)
   ```

3. **lpac execution:**

   ```bash
   LPAC_APDU=qmi_qrtr LPAC_APDU_QMI_UIM_SLOT=1 \
   lpac profile download -a "LPA:1$..."
   ```

4. **Progress updates:** UI shows each step
5. **Post-download:** Automatic notification processing
6. **Result:** Profile appears in list

### Example 2: Enable Profile

1. **User:** Selects disabled profile, clicks "Enable"
2. **Application:**

   ```python
   profile.enable()  # Calls backend.enable_profile(iccid)
   ```

3. **lpac execution:**

   ```bash
   lpac profile enable 89001012345678901234
   ```

4. **UI update:** Profile list refreshes, profile shows as enabled

### Example 3: Automatic Notification Processing

1. **Application startup:** Notification task initialized
2. **After download/enable:** Task starts in background thread
3. **Process:**
   - Retrieve pending notifications
   - Send each to server
   - Remove after successful processing
   - Log all steps
4. **UI feedback:**
   - Success: Toast notification
   - Error: Toast with detailed error dialog

## Known Limitations

### 1. Platform Support

- **Qualcomm only:** Currently supports QMI + QRTR interface
- **Modern devices:** Requires recent Qualcomm modems
- **Other platforms:** Requires backend implementation (interface is ready)

### 2. QR Code Scanning

- **Not implemented:** Cannot scan QR codes from camera
- **Workaround:** Manually enter activation code starting with `LPA:1$`
- **Tracking:** <https://codeberg.org/lucaweiss/lpa-gtk/issues/14>

### 3. Profile Filtering

- **Hidden profiles:** Test and provisioning profiles hidden by default
- **No toggle:** Cannot view hidden profiles in UI (planned feature)

## Error Handling

### Exception Hierarchy

```python
class ESimError(Exception):
    """Base exception for eSIM operations"""
```

### Error Sources

1. **lpac errors:** Non-zero code in JSON response
2. **Process errors:** lpac execution failure
3. **Parse errors:** Invalid JSON output
4. **Hardware errors:** Modem communication issues

### Error Display

```python
# From helpers.py:14
def show_toast_info(overlay, parent, title: str, info: str, markup: bool):
    # Shows toast with "Details" button
    # Details button opens dialog with full error and logs
```

## Development Notes

### Testing Without Hardware

Use dummy backend:

```bash
LPA_GTK_BACKEND=dummy lpa-gtk
```

Dummy backend provides:

- Instant feedback without delays
- Random profile generation
- Simulated progress updates
- Safe testing environment

### Adding New Backend Support

Implement `ESimBackend` interface:

```python
class NewBackend(ESimBackend):
    def get_profiles(self) -> list[ESimProfile]: ...
    def enable_profile(self, iccid: str) -> None: ...
    def disable_profile(self, iccid: str) -> None: ...
    # ... implement all abstract methods
```

Register in `get_operational_backends()`:

```python
@staticmethod
def get_operational_backends() -> list[ESimBackend]:
    backends = []
    # Try new backend
    new_backend = NewBackend(slot)
    if new_backend.is_operational():
        backends.append(new_backend)
    return backends
```

### Thread Safety

- **Notification processing:** Runs in daemon thread
- **UI updates:** Must use GLib idle callbacks
- **lpac execution:** Blocking in background thread, safe

## Additional Resources

- **lpac Documentation:** <https://github.com/estkme-group/lpac>
- **GTK4 Documentation:** <https://docs.gtk.org/gtk4/>
- **Libadwaita Documentation:** <https://gnome.pages.gitlab.gnome.org/libadwaita/>
- **Blueprint Compiler:** <https://jwestman.pages.gitlab.gnome.org/blueprint-compiler/>
- **LPA Overview:** <https://euicc-manual.osmocom.org/docs/lpa/known-solution/>
- **Issue Tracker:** <https://codeberg.org/lucaweiss/lpa-gtk/issues>

## Version Information

- **lpa-gtk Version:** 0.3
- **Compatible lpac:** Any version with JSON output interface
- **Target Platform:** Linux phones (Phosh/GNOME Mobile)

---

**Last Updated:** 2025-10-23
