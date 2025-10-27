# eSIM Features Implementation Plan

## EP06-E AT Commands Integration into quectel_lpad

**Created:** 2025-10-26
**Author:** Kerem Gök
**Goal:** Add all missing EP06-E eSIM AT command features to quectel_lpad application

---

## Current Status

### ✅ Already Implemented (2 features)

1. Profile Download (OTA) - `AT+QESIM="ota"` equivalent
   - Flag: `-A <activation_code>`
   - Flag: `-C <confirmation_code>` (optional)
2. Profile Delete - `AT+QESIM="delete"` equivalent
   - Flag: `-R <profile_id>`

### ❌ Missing Features (19 features)

- 3 Setup/Configuration commands
- 2 Profile query commands
- 8 Profile management commands
- 5 Network status commands
- 1 Debug command

---

## Implementation Strategy

We will implement features in **6 phases**, each phase building on the previous one.
Each step will have its own commit.

---

## PHASE 1: Infrastructure & Core QMI Support (Steps 1-4)

### Step 1: Add QMI Message Definitions for New Operations

**File:** `qmi_manager/qmi_manager.h`

**Tasks:**

- Add QMI_UIM_GET_EID_REQ_V01 (0x004E) message ID
- Add QMI_UIM_GET_SLOTS_STATUS_REQ_V01 (0x0047) message ID
- Add QMI_UIM_GET_PROFILE_INFO_REQ_V01 (0x006B) message ID
- Add QMI_UIM_UPDATE_PROFILE_NICKNAME_REQ_V01 (0x006A) message ID
- Add QMI_UIM_EUICC_MEMORY_RESET_REQ_V01 (0x006C) message ID
- Add QMI_UIM_SET_SIM_PROFILE_REQ_V01 (0x0069) message ID

**Commit Message:**

```
feat: Add QMI message IDs for eSIM operations

- Add QMI_UIM_GET_EID_REQ_V01 (0x004E)
- Add QMI_UIM_GET_SLOTS_STATUS_REQ_V01 (0x0047)
- Add QMI_UIM_GET_PROFILE_INFO_REQ_V01 (0x006B)
- Add QMI_UIM_UPDATE_PROFILE_NICKNAME_REQ_V01 (0x006A)
- Add QMI_UIM_EUICC_MEMORY_RESET_REQ_V01 (0x006C)
- Add QMI_UIM_SET_SIM_PROFILE_REQ_V01 (0x0069)

These message IDs enable EID query, profile listing, nickname update,
enable/disable operations.
```

---

### Step 2: Define QMI Request/Response Structures

**File:** `qmi_manager/qmi_manager.c`

**Tasks:**

- Define `uim_get_eid_req_msg_v01` structure
- Define `uim_get_eid_resp_msg_v01` structure
- Define `uim_get_profile_info_req_msg_v01` structure
- Define `uim_get_profile_info_resp_msg_v01` structure
- Define `uim_update_profile_nickname_req_msg_v01` structure
- Define `uim_set_sim_profile_req_msg_v01` structure (enable/disable)

**Commit Message:**

```
feat: Define QMI structures for eSIM query operations

- Add uim_get_eid_req/resp structures
- Add uim_get_profile_info_req/resp structures
- Add uim_update_profile_nickname_req/resp structures
- Add uim_set_sim_profile_req/resp structures

These structures support EID query, profile listing, nickname management,
and profile enable/disable operations via QMI.
```

---

### Step 3: Add Profile Information Storage Structure

**File:** `common/common_def.h`

**Tasks:**

- Define `esim_profile_info_t` structure:

  ```c
  typedef struct {
      char iccid[21];           // 19-20 digits + null
      char nickname[65];        // max 64 chars + null
      char provider_name[65];
      uint8_t state;            // 0=disabled, 1=enabled
      uint8_t profile_class;    // operational, provisioning, testing
      uint8_t slot_id;
  } esim_profile_info_t;
  ```

- Define `esim_profile_list_t` structure for storing multiple profiles
- Define max profile count: `ESIM_MAX_PROFILES` (8)

**Commit Message:**

```
feat: Add eSIM profile information structures

- Define esim_profile_info_t for storing profile details
- Define esim_profile_list_t for multi-profile storage
- Add ESIM_MAX_PROFILES constant (8 profiles max)

These structures enable profile listing and management operations.
```

---

### Step 4: Implement EID Storage and Helper Functions

**File:** `common/common_def.h` and new file `common/esim_utils.c`

**Tasks:**

- Add global variable for EID storage: `char g_eid[33]`
- Create `common/esim_utils.c` with helper functions:
  - `esim_utils_format_eid()` - Format EID for display
  - `esim_utils_validate_iccid()` - Validate ICCID format
  - `esim_utils_profile_state_to_string()` - Convert state to string
  - `esim_utils_format_profile_info()` - Format profile for display

**Commit Message:**

```
feat: Add eSIM utility functions and EID storage

- Add global EID storage (g_eid[33])
- Create common/esim_utils.c with helper functions
- Add EID formatting function
- Add ICCID validation function
- Add profile state to string converter
- Add profile info formatter for display

These utilities support eSIM query and display operations.
```

---

## PHASE 2: Profile Query Features (Steps 5-6)

### Step 5: Implement EID Query Feature (-E flag)

**Files:** `app/main.c`, `qmi_manager/qmi_manager.c`

**Tasks:**

- Add `-E` flag to args_parse() for EID query
- Add `query_eid` boolean to `use_args_t` structure
- Implement QMI request function: `qm_get_eid()`
- Add EID response handler
- Update usage() help text
- Add JSON support for EID output

**Example Usage:**

```bash
./quectel_lpad -E
# Output: EID: 89049032003451234567890123456789

./quectel_lpad -E -J
# JSON Output: {"operation":"query_eid","eid":"89049...","status":"success"}
```

**Commit Message:**

```
feat: Add EID query feature (-E flag)

- Add -E flag for querying eUICC ID
- Implement qm_get_eid() QMI function
- Add EID response handler
- Support JSON output for EID query
- Update usage() help text

Usage: quectel_lpad -E
Output: EID: 89049032003451234567890123456789
```

---

### Step 6: Implement Profile List Feature (-L flag)

**Files:** `app/main.c`, `qmi_manager/qmi_manager.c`

**Tasks:**

- Add `-L` flag to args_parse() for profile listing
- Add `list_profiles` boolean to `use_args_t` structure
- Implement QMI request function: `qm_get_profile_list()`
- Add profile list response handler
- Format output in tabular format (normal mode)
- Add JSON array support for profile list
- Display: Index, ICCID, State, Nickname, Provider

**Example Usage:**

```bash
./quectel_lpad -L
# Output:
# Profiles (2 total):
# [0] ICCID: 8901234567890123456  State: Enabled   Nickname: My Profile      Provider: Operator A
# [1] ICCID: 8909876543210987654  State: Disabled  Nickname: Test Profile    Provider: Operator B

./quectel_lpad -L -J
# JSON Output: {"operation":"list_profiles","count":2,"profiles":[...]}
```

**Commit Message:**

```
feat: Add profile listing feature (-L flag)

- Add -L flag for listing all eSIM profiles
- Implement qm_get_profile_list() QMI function
- Add profile list response handler
- Display profiles in tabular format (normal mode)
- Support JSON array output for profile list
- Show: Index, ICCID, State, Nickname, Provider
- Update usage() help text

Usage: quectel_lpad -L
```

---

## PHASE 3: Profile Management Features (Steps 7-9)

### Step 7: Implement Profile Enable Feature (-N flag)

**Files:** `app/main.c`, `qmi_manager/qmi_manager.c`

**Tasks:**

- Add `-N <iccid>` flag for enabling profile by ICCID
- Add `enable_profile_iccid` char array to `use_args_t`
- Implement QMI request function: `qm_enable_profile()`
- Add enable response handler
- Note: Only one profile can be enabled at a time (auto-disables others)
- Add JSON support

**Example Usage:**

```bash
./quectel_lpad -N 8901234567890123456
# Output: Profile 8901234567890123456 enabled successfully
```

**Commit Message:**

```
feat: Add profile enable feature (-N flag)

- Add -N <iccid> flag for enabling profile
- Implement qm_enable_profile() QMI function
- Auto-disable other profiles when enabling
- Add enable response handler
- Support JSON output
- Update usage() help text

Usage: quectel_lpad -N <iccid>
Note: Only one profile can be active at a time
```

---

### Step 8: Implement Profile Disable Feature (-X flag)

**Files:** `app/main.c`, `qmi_manager/qmi_manager.c`

**Tasks:**

- Add `-X <iccid>` flag for disabling profile by ICCID
- Add `disable_profile_iccid` char array to `use_args_t`
- Implement QMI request function: `qm_disable_profile()`
- Add disable response handler
- Add JSON support

**Example Usage:**

```bash
./quectel_lpad -X 8901234567890123456
# Output: Profile 8901234567890123456 disabled successfully
```

**Commit Message:**

```
feat: Add profile disable feature (-X flag)

- Add -X <iccid> flag for disabling profile
- Implement qm_disable_profile() QMI function
- Add disable response handler
- Support JSON output
- Update usage() help text

Usage: quectel_lpad -X <iccid>
```

---

### Step 9: Implement Profile Nickname Update Feature (-K flag)

**Files:** `app/main.c`, `qmi_manager/qmi_manager.c`

**Tasks:**

- Add `-K <iccid>:<nickname>` flag for updating nickname
- Parse ICCID and nickname from single argument (split by ':')
- Add `nickname_iccid` and `nickname_value` to `use_args_t`
- Implement QMI request function: `qm_update_nickname()`
- Add nickname update response handler
- Validate nickname length (max 64 chars)
- Add JSON support

**Example Usage:**

```bash
./quectel_lpad -K 8901234567890123456:"My Work SIM"
# Output: Nickname updated successfully for profile 8901234567890123456
```

**Commit Message:**

```
feat: Add profile nickname update feature (-K flag)

- Add -K <iccid>:<nickname> flag for nickname update
- Parse ICCID:nickname format (split by ':')
- Implement qm_update_nickname() QMI function
- Validate nickname length (max 64 characters)
- Add nickname update response handler
- Support JSON output
- Update usage() help text

Usage: quectel_lpad -K <iccid>:<nickname>
Example: quectel_lpad -K 8901234567890123456:"My Work SIM"
```

---

## PHASE 4: Network Status Query Features (Steps 10-14)

### Step 10: Add Network Query Infrastructure

**Files:** `qmi_manager/qmi_manager.h`, `qmi_manager/qmi_manager.c`

**Tasks:**

- Add QMI_NAS client type support (Network Access Service)
- Define QMI_NAS_GET_SIGNAL_STRENGTH_REQ_V01 (0x0020)
- Define QMI_NAS_GET_SYS_INFO_REQ_V01 (0x004D)
- Define QMI_NAS_GET_SERVING_SYSTEM_REQ_V01 (0x0024)
- Add NAS message structures
- Initialize QMI_NAS client in qm_client_init()

**Commit Message:**

```
feat: Add QMI NAS client support for network queries

- Add QMI_NAS client type to qm_client_init()
- Define QMI_NAS_GET_SIGNAL_STRENGTH_REQ_V01 (0x0020)
- Define QMI_NAS_GET_SYS_INFO_REQ_V01 (0x004D)
- Define QMI_NAS_GET_SERVING_SYSTEM_REQ_V01 (0x0024)
- Add NAS request/response structures

QMI NAS client enables signal strength, network registration,
and serving system queries.
```

---

### Step 11: Implement Signal Quality Query (-Q flag)

**Files:** `app/main.c`, `qmi_manager/qmi_manager.c`

**Tasks:**

- Add `-Q` flag for signal quality query
- Implement `qm_get_signal_strength()` using QMI NAS
- Parse RSSI (0-31, 99=unknown) and BER (0-7, 99=unknown)
- Calculate dBm: `dBm = -113 + (2 * rssi)`
- Display signal quality with interpretation (Weak/Fair/Good/Excellent)
- Add JSON support

**Example Usage:**

```bash
./quectel_lpad -Q
# Output:
# Signal Quality:
#   RSSI: 23 (-67 dBm) - Good
#   BER: 0

./quectel_lpad -Q -J
# JSON: {"operation":"signal_quality","rssi":23,"dbm":-67,"ber":0,"quality":"good"}
```

**Commit Message:**

```
feat: Add signal quality query feature (-Q flag)

- Add -Q flag for querying signal strength
- Implement qm_get_signal_strength() via QMI NAS
- Parse RSSI (0-31) and BER (0-7)
- Calculate dBm from RSSI: dBm = -113 + (2 * rssi)
- Display signal quality interpretation
- Support JSON output
- Update usage() help text

Usage: quectel_lpad -Q
Equivalent to: AT+CSQ
```

---

### Step 12: Implement Network Registration Status Query (-G flag)

**Files:** `app/main.c`, `qmi_manager/qmi_manager.c`

**Tasks:**

- Add `-G` flag for network registration status
- Implement `qm_get_serving_system()` using QMI NAS
- Display registration state (Not registered/Home/Roaming/Denied/Unknown)
- Display LAC (Location Area Code) and Cell ID if available
- Display access technology (GSM/UTRAN/LTE/5G)
- Add JSON support

**Example Usage:**

```bash
./quectel_lpad -G
# Output:
# Network Registration:
#   Status: Registered (Home network)
#   LAC: 0x1A2B
#   Cell ID: 0x01C3D4E5
#   Technology: LTE (E-UTRAN)

./quectel_lpad -G -J
# JSON: {"operation":"network_reg","status":"home","lac":"0x1A2B","cid":"0x01C3D4E5","tech":"lte"}
```

**Commit Message:**

```
feat: Add network registration query feature (-G flag)

- Add -G flag for network registration status
- Implement qm_get_serving_system() via QMI NAS
- Display registration state (home/roaming/denied/unknown)
- Show LAC and Cell ID in hex format
- Show access technology (GSM/UTRAN/LTE/5G)
- Support JSON output
- Update usage() help text

Usage: quectel_lpad -G
Equivalent to: AT+CGREG?
```

---

### Step 13: Implement IP Address Query (-I flag enhancement)

**Files:** `app/main.c`, `qmi_manager/qmi_manager.c`

**Tasks:**

- Note: `-I` flag already exists but for different purpose
- Change to `-T` flag for IP address query (T = aTtached IP)
- Add QMI_WDS client support (Wireless Data Service)
- Define QMI_WDS_GET_RUNTIME_SETTINGS_REQ_V01 (0x002D)
- Implement `qm_get_ip_address()` using QMI WDS
- Display IPv4 and IPv6 addresses if available
- Add JSON support

**Example Usage:**

```bash
./quectel_lpad -T
# Output:
# IP Addresses:
#   IPv4: 10.123.45.67
#   IPv6: 2001:db8::1

./quectel_lpad -T -J
# JSON: {"operation":"ip_address","ipv4":"10.123.45.67","ipv6":"2001:db8::1"}
```

**Commit Message:**

```
feat: Add IP address query feature (-T flag)

- Add -T flag for querying assigned IP addresses
- Add QMI_WDS client support
- Define QMI_WDS_GET_RUNTIME_SETTINGS_REQ_V01
- Implement qm_get_ip_address() via QMI WDS
- Display both IPv4 and IPv6 addresses
- Support JSON output
- Update usage() help text

Usage: quectel_lpad -T
Equivalent to: AT+CGPADDR
```

---

### Step 14: Implement Operator Selection Query (-O flag)

**Files:** `app/main.c`, `qmi_manager/qmi_manager.c`

**Tasks:**

- Add `-O` flag for operator information query
- Use existing QMI NAS serving system info
- Display operator name (if available from NAS)
- Display operator code (MCC+MNC)
- Display selection mode (automatic/manual)
- Add JSON support

**Example Usage:**

```bash
./quectel_lpad -O
# Output:
# Operator Information:
#   Name: T-Mobile DE
#   Code: 26201 (MCC: 262, MNC: 01)
#   Mode: Automatic

./quectel_lpad -O -J
# JSON: {"operation":"operator","name":"T-Mobile DE","code":"26201","mcc":"262","mnc":"01","mode":"auto"}
```

**Commit Message:**

```
feat: Add operator selection query feature (-O flag)

- Add -O flag for operator information query
- Display operator name and code (MCC+MNC)
- Show selection mode (automatic/manual)
- Use QMI NAS serving system info
- Support JSON output
- Update usage() help text

Usage: quectel_lpad -O
Equivalent to: AT+COPS?
```

---

## PHASE 5: Advanced Configuration Features (Steps 15-17)

### Step 15: Implement Manual APN Configuration (-B flag)

**Files:** `app/main.c`, `qmi_manager/qmi_manager.c`

**Tasks:**

- Add `-B <apn_name>` flag for APN configuration
- Add QMI_WDS_MODIFY_PROFILE_SETTINGS_REQ_V01
- Implement `qm_set_apn()` function
- Store APN in QMI WDS profile
- Support PDP type selection (IP/IPV6/IPV4V6)
- Add `-W <pdp_type>` flag for PDP type (default: IP)
- Add JSON support

**Example Usage:**

```bash
./quectel_lpad -B internet.apn
# Output: APN configured: internet.apn (PDP Type: IP)

./quectel_lpad -B internet.apn -W IPV4V6
# Output: APN configured: internet.apn (PDP Type: IPV4V6)
```

**Commit Message:**

```
feat: Add manual APN configuration feature (-B flag)

- Add -B <apn> flag for APN configuration
- Add -W <pdp_type> flag for PDP type selection
- Implement qm_set_apn() via QMI WDS
- Support IP/IPV6/IPV4V6 PDP types
- Store APN in QMI WDS profile
- Support JSON output
- Update usage() help text

Usage: quectel_lpad -B <apn> [-W <pdp_type>]
Equivalent to: AT+CGDCONT
```

---

### Step 16: Implement BIP Configuration (-V flag)

**Files:** `app/main.c`, `qmi_manager/qmi_manager.c`

**Tasks:**

- Add `-V <0|1>` flag for BIP (Bearer Independent Protocol) control
- Use QMI_UIM_SET_CONFIGURATION_REQ_V01 (0x003B)
- Implement `qm_set_bip_config()` function
- 0 = disable BIP, 1 = enable BIP
- Note: BIP is required for eSIM profile downloads
- Add JSON support

**Example Usage:**

```bash
./quectel_lpad -V 1
# Output: BIP (Bearer Independent Protocol) enabled

./quectel_lpad -V 0
# Output: BIP (Bearer Independent Protocol) disabled
```

**Commit Message:**

```
feat: Add BIP configuration feature (-V flag)

- Add -V <0|1> flag for BIP enable/disable
- Implement qm_set_bip_config() via QMI UIM
- Use QMI_UIM_SET_CONFIGURATION_REQ_V01
- Display BIP status after configuration
- Support JSON output
- Update usage() help text

Usage: quectel_lpad -V <0|1>
Equivalent to: AT+QCFG="bip/auth",<mode>
Note: BIP is required for eSIM profile downloads
```

---

### Step 17: Implement Data Connection Control (-S flag)

**Files:** `app/main.c`, `qmi_manager/qmi_manager.c`

**Tasks:**

- Add `-S <0|1>` flag for data connection (GPRS attach/detach)
- Use QMI_NAS_SET_SYSTEM_SELECTION_PREFERENCE_REQ_V01
- Implement `qm_set_data_connection()` function
- 0 = detach from network, 1 = attach to network
- Display connection status
- Add JSON support

**Example Usage:**

```bash
./quectel_lpad -S 1
# Output: Data connection activated (GPRS attached)

./quectel_lpad -S 0
# Output: Data connection deactivated (GPRS detached)
```

**Commit Message:**

```
feat: Add data connection control feature (-S flag)

- Add -S <0|1> flag for GPRS attach/detach
- Implement qm_set_data_connection() via QMI NAS
- Use QMI_NAS_SET_SYSTEM_SELECTION_PREFERENCE
- Display connection status after operation
- Support JSON output
- Update usage() help text

Usage: quectel_lpad -S <0|1>
Equivalent to: AT+CGACT=<state>
```

---

## PHASE 6: Documentation & Testing (Steps 18-20)

### Step 18: Update All Documentation

**Files:** `CLAUDE.md`, `README.md` (if exists), update usage()

**Tasks:**

- Update CLAUDE.md with all new features
- Document all new command-line flags
- Add examples for each operation
- Update architecture section
- Document new QMI message types
- Update JSON output format documentation
- Create examples directory with sample scripts

**Commit Message:**

```
docs: Update documentation for all new eSIM features

- Update CLAUDE.md with complete feature list
- Document all 17 new command-line flags
- Add usage examples for each operation
- Update architecture documentation
- Document new QMI message types
- Add JSON output format examples
- Create examples/ directory with sample scripts

Documentation now covers all EP06-E AT command equivalents.
```

---

### Step 19: Create Comprehensive Test Script

**File:** `tests/test_all_features.sh`

**Tasks:**

- Create test script that exercises all features
- Test each flag individually
- Test flag combinations
- Test JSON output for all operations
- Test error conditions (invalid ICCID, etc.)
- Add verbose output mode
- Create expected output samples

**Commit Message:**

```
test: Add comprehensive feature test script

- Create tests/test_all_features.sh
- Test all 19 implemented features
- Test individual flags and combinations
- Verify JSON output format
- Test error handling (invalid inputs)
- Add verbose mode for debugging
- Include expected output samples

Usage: ./tests/test_all_features.sh [-v]
```

---

### Step 20: Create Updated Help System and Man Page

**Files:** `app/main.c` (update usage()), create `docs/quectel_lpad.1` (man page)

**Tasks:**

- Reorganize usage() output by category:
  - Profile Management Operations
  - Profile Query Operations
  - Network Status Queries
  - Configuration Operations
  - General Options
- Add detailed examples for common use cases
- Create man page (groff format)
- Update version number to v2.0.0

**Commit Message:**

```
docs: Reorganize help system and add man page

- Reorganize usage() output by operation category
- Add detailed examples for common use cases
- Create man page (docs/quectel_lpad.1)
- Update version to v2.0.0 (major feature release)
- Add EXAMPLES section with real-world scenarios

New help categories:
- Profile Management Operations
- Profile Query Operations
- Network Status Queries
- Configuration Operations
- General Options
```

---

## Summary of New Flags

| Flag | Feature | AT Command Equivalent |
|------|---------|----------------------|
| `-E` | Query EID | `AT+QESIM="eid"` |
| `-L` | List profiles | `AT+QESIM="list"` |
| `-N <iccid>` | Enable profile | `AT+QESIM="enable",<iccid>` |
| `-X <iccid>` | Disable profile | `AT+QESIM="disable",<iccid>` |
| `-K <iccid>:<nickname>` | Update nickname | `AT+QESIM="nickname",<iccid>,<name>` |
| `-Q` | Signal quality | `AT+CSQ` |
| `-G` | Network registration | `AT+CGREG?` |
| `-T` | IP address | `AT+CGPADDR` |
| `-O` | Operator info | `AT+COPS?` |
| `-B <apn>` | Set APN | `AT+CGDCONT=1,"IP",<apn>` |
| `-W <type>` | PDP type | `AT+CGDCONT=1,<type>,<apn>` |
| `-V <0\|1>` | BIP config | `AT+QCFG="bip/auth",<mode>` |
| `-S <0\|1>` | Data connection | `AT+CGACT=<state>` |

**Existing flags preserved:**

- `-A <code>` - Add profile (activation code)
- `-C <code>` - Confirmation code
- `-R <id>` - Remove profile
- `-D <level>` - Debug level
- `-P <proxy>` - Proxy selection
- `-J` / `--json` - JSON output

---

## Implementation Notes

### QMI Client Types Required

1. `QMI_UIM` - Already implemented
2. `QMI_UIM_HTTP` - Already implemented
3. `QMI_NAS` - NEW (Network Access Service)
4. `QMI_WDS` - NEW (Wireless Data Service)

### JSON Output Format Extensions

Each new operation will extend the JSON output with operation-specific fields:

```json
{
  "version": "2.0.0",
  "timestamp": "2025-10-26T12:34:56Z",
  "operation": "list_profiles",
  "status": "success",
  "message": "Profiles retrieved successfully",
  "data": {
    "count": 2,
    "profiles": [
      {
        "index": 0,
        "iccid": "8901234567890123456",
        "state": "enabled",
        "nickname": "My Profile",
        "provider": "Operator A"
      }
    ]
  },
  "performance": {
    "duration_ms": 234
  }
}
```

### Backward Compatibility

- All existing flags (`-A`, `-R`, `-C`, `-D`, `-P`, `-J`) will work exactly as before
- New flags are optional and don't interfere with existing workflows
- Version bump to v2.0.0 signals major feature addition

---

## Testing Strategy

### For Each Step

1. Compile successfully
2. Test basic operation (without `-J`)
3. Test JSON output (with `-J`)
4. Test error conditions
5. Verify no regression in existing features
6. Commit with detailed message

### Integration Testing

After all steps complete, test combinations:

- Query EID, then list profiles, then enable a profile
- Configure APN, check IP address, query signal quality
- List profiles in JSON, parse with jq, enable specific profile

---

## Estimated Timeline

- **Phase 1** (Steps 1-4): Infrastructure - 1-2 hours
- **Phase 2** (Steps 5-6): Query features - 1 hour
- **Phase 3** (Steps 7-9): Profile management - 1.5 hours
- **Phase 4** (Steps 10-14): Network queries - 2 hours
- **Phase 5** (Steps 15-17): Configuration - 1.5 hours
- **Phase 6** (Steps 18-20): Documentation - 1 hour

**Total: ~8-9 hours of focused development**

---

## Success Criteria

✅ All 19 missing features implemented
✅ All features work in both normal and JSON modes
✅ No regression in existing `-A` and `-R` operations
✅ Comprehensive documentation updated
✅ Test script validates all features
✅ Man page created
✅ Version bumped to v2.0.0
✅ All commits follow conventional commit format

---

**Ready to start implementation!** 🚀

Would you like to proceed with Step 1?
