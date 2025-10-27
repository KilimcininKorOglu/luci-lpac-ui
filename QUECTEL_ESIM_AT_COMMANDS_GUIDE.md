# Quectel eSIM AT Commands - Comprehensive Guide

**Document Version:** 1.0
**Last Updated:** October 2025
**Target Modules:** EC25 Series, EG21-G, EM160R, EC200U, EG915U, BG95, and compatible Quectel LTE modules with eSIM support

---

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [AT+QESIM Command Overview](#atqesim-command-overview)
4. [Profile Management Commands](#profile-management-commands)
5. [Profile Download Commands](#profile-download-commands)
6. [Profile Information Commands](#profile-information-commands)
7. [Advanced Operations](#advanced-operations)
8. [Error Codes and Troubleshooting](#error-codes-and-troubleshooting)
9. [Practical Examples](#practical-examples)
10. [Integration with quectel_lpad](#integration-with-quectel_lpad)
11. [Best Practices](#best-practices)

---

## Introduction

### What is eSIM?

eSIM (embedded SIM) is a programmable SIM card that is permanently embedded in a device. Unlike traditional physical SIM cards, eSIM profiles can be downloaded, activated, and managed remotely without physical card swapping.

### AT+QESIM Command Set

The **AT+QESIM** command set is Quectel's proprietary AT command interface for managing eSIM profiles on supported LTE modules. This command set implements the GSMA RSP (Remote SIM Provisioning) specification for local profile management.

### Key Capabilities

- Download eSIM profiles from SM-DP+ servers
- List installed profiles on eUICC
- Enable/disable profiles
- Delete profiles
- Manage profile nicknames
- Retrieve eUICC Identifier (EID)
- Handle OTA (Over-The-Air) profile provisioning

---

## Prerequisites

### Hardware Requirements

**Supported Modules:**
- EC25 Series (EC25-E, EC25-A, EC25-AU, EC25-J, EC25-V, EC25-EC)
- EG21-G
- EM160R (with eSIM-enabled firmware)
- EC200AAU, EC200AEU
- BG95M1, BG95M3, BG95M8
- EC600U Series (with eSIM support)

**Physical Requirements:**
- Module with embedded eUICC chip
- Active antenna connection for cellular signal
- Stable power supply (3.3V-4.2V depending on module)

### Software Requirements

**Firmware:**
- eSIM-enabled firmware version
- Verify support: `AT+QESIM=?`
- If command returns `ERROR`, eSIM is not supported on current firmware

**Network Requirements:**
- Active internet connection (for profile download)
- Access to SM-DP+ server (operator's provisioning server)
- DNS resolution capability
- Open ports for HTTPS (443)

### Initial Setup

Before using AT+QESIM commands, ensure basic modem configuration:

```bash
# Check module information
AT+CGMI          # Manufacturer
AT+CGMM          # Model
AT+CGMR          # Firmware version

# Configure APN (if using external network for download)
AT+CGDCONT=1,"IP","your.apn.here"

# Enable Bearer Independent Protocol (required for eSIM)
AT+QCFG="bip/auth",1

# Activate PDP context
AT+CGACT=1,1

# Verify network registration
AT+CREG?         # GSM registration
AT+CGREG?        # GPRS registration
```

---

## AT+QESIM Command Overview

### Command Query

To view all available AT+QESIM operations:

```bash
AT+QESIM=?
```

**Expected Response:**
```
+QESIM: "list"
+QESIM: "enable"
+QESIM: "disable"
+QESIM: "delete"
+QESIM: "download"
+QESIM: "nickname"
+QESIM: "eid"
+QESIM: "trans"
+QESIM: "ota"

OK
```

### General Syntax

```
AT+QESIM="<operation>"[,<param1>[,<param2>[,...]]]
```

**Response Format:**
```
+QESIM: "<operation>",<result>[,<additional_data>]

OK
```

**Error Response:**
```
+QESIM: "<operation>",<error_code>

ERROR
```

---

## Profile Management Commands

### List Installed Profiles

Retrieve all profiles currently installed on the eUICC.

**Command:**
```
AT+QESIM="list"
```

**Response:**
```
+QESIM: "list",<result>
+QESIM: <index>,<iccid>,<profileState>,<profileNickname>,<serviceProviderName>,<profileName>,<profileClass>

OK
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `result` | Integer | 0 = Success, 1-3 = Error codes |
| `index` | Integer | Profile index number (1-based) |
| `iccid` | String | Integrated Circuit Card Identifier (19-20 digits) |
| `profileState` | Integer | 0 = Disabled, 1 = Enabled |
| `profileNickname` | String | User-defined profile name (if set) |
| `serviceProviderName` | String | Operator name from profile |
| `profileName` | String | Profile name from profile metadata |
| `profileClass` | Integer | 0 = Test, 1 = Provisioning, 2 = Operational |

**Example:**
```
AT+QESIM="list"

+QESIM: "list",0
+QESIM: 1,89882280666047154321,1,"My Primary SIM","Operator A","LTE Profile","2"
+QESIM: 2,89882281777158265432,0,"Backup SIM","Operator B","Data Only","2"

OK
```

**Interpretation:**
- Profile 1: Enabled operational profile for "Operator A"
- Profile 2: Disabled operational profile for "Operator B"

---

### Enable Profile

Activate a specific eSIM profile by ICCID.

**Command:**
```
AT+QESIM="enable","<iccid>"
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `iccid` | String | 19-20 digit ICCID of target profile |

**Response:**
```
+QESIM: "enable",<result>

OK
```

**Result Codes:**

| Code | Meaning |
|------|---------|
| 0 | Profile enabled successfully |
| 1 | Profile not found |
| 2 | Profile already enabled |
| 3 | eUICC error |

**Example:**
```
AT+QESIM="enable","89882280666047154321"

+QESIM: "enable",0

OK
```

**Post-Enable Actions:**

After enabling a profile, the module typically requires a reset to register with the network:

```bash
# Option 1: CFUN reset (soft reset)
AT+CFUN=0
# Wait 2-3 seconds
AT+CFUN=1

# Option 2: Full module reset
AT+CFUN=1,1
```

**Verify activation:**
```bash
AT+CIMI          # Get IMSI (should reflect new profile)
AT+ICCID         # Get ICCID (should match enabled profile)
AT+CREG?         # Check network registration
```

---

### Disable Profile

Deactivate a currently enabled profile.

**Command:**
```
AT+QESIM="disable","<iccid>"
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `iccid` | String | 19-20 digit ICCID of target profile |

**Response:**
```
+QESIM: "disable",<result>

OK
```

**Result Codes:**

| Code | Meaning |
|------|---------|
| 0 | Profile disabled successfully |
| 1 | Profile not found |
| 2 | Profile already disabled |
| 3 | eUICC error |

**Example:**
```
AT+QESIM="disable","89882280666047154321"

+QESIM: "disable",0

OK
```

**Important Notes:**

- **Cannot disable the only enabled profile**: Most eUICC implementations require at least one active profile
- **Network disconnection**: Disabling the active profile will cause network deregistration
- **No automatic fallback**: Module will not automatically enable another profile

**Use Case - Profile Switching:**
```bash
# Step 1: Disable current profile
AT+QESIM="disable","89882280666047154321"
# Wait for response

# Step 2: Enable target profile
AT+QESIM="enable","89882281777158265432"
# Wait for response

# Step 3: Reset module
AT+CFUN=1,1
```

---

### Delete Profile

Permanently remove a profile from eUICC.

**Command:**
```
AT+QESIM="delete","<iccid>"
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `iccid` | String | 19-20 digit ICCID of profile to delete |

**Response:**
```
+QESIM: "delete",<result>

OK
```

**Result Codes:**

| Code | Meaning |
|------|---------|
| 0 | Profile deleted successfully |
| 1 | Profile not found |
| 2 | Cannot delete enabled profile |
| 3 | eUICC error |

**Example:**
```
AT+QESIM="delete","89882281777158265432"

+QESIM: "delete",0

OK
```

**Critical Warnings:**

⚠️ **Cannot delete enabled profile**: Must disable before deleting
⚠️ **Permanent operation**: Deleted profiles cannot be recovered from eUICC
⚠️ **Operator notification**: SM-DP+ server should be notified (see reportProfileDelNotification)
⚠️ **Profile reuse**: Some profiles can be re-downloaded, others are single-use only

**Safe Deletion Procedure:**

```bash
# Step 1: List profiles to confirm target
AT+QESIM="list"

# Step 2: Verify profile is disabled (profileState=0)
# If enabled, disable it first:
AT+QESIM="disable","89882281777158265432"

# Step 3: Delete the profile
AT+QESIM="delete","89882281777158265432"

# Step 4: Verify deletion
AT+QESIM="list"
# Profile should no longer appear
```

**Notification to SM-DP+ (if required):**

Some operators require notification when a profile is deleted. This is typically handled automatically by the modem's LPA, but can be triggered manually if needed. The `quectel_lpad` application handles this via QMI messages.

---

### Set Profile Nickname

Assign a user-friendly name to a profile for easier identification.

**Command:**
```
AT+QESIM="nickname","<iccid>","<new_nickname>"
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `iccid` | String | 19-20 digit ICCID of target profile |
| `new_nickname` | String | New nickname (max length varies by module, typically 64 chars) |

**Response:**
```
+QESIM: "nickname",<result>

OK
```

**Result Codes:**

| Code | Meaning |
|------|---------|
| 0 | Nickname updated successfully |
| 1 | Profile not found |
| 2 | Invalid nickname (too long, invalid characters) |
| 3 | eUICC error |

**Example:**
```
AT+QESIM="nickname","89882280666047154321","My Work SIM"

+QESIM: "nickname",0

OK
```

**Verify nickname:**
```
AT+QESIM="list"

+QESIM: "list",0
+QESIM: 1,89882280666047154321,1,"My Work SIM","Operator A","LTE Profile","2"

OK
```

**Nickname Guidelines:**

- **Allowed characters**: Alphanumeric, spaces, common punctuation
- **Max length**: Typically 64 characters (module-dependent)
- **Persistence**: Stored in eUICC, survives module reset
- **Locale**: Usually supports ASCII only, some modules support UTF-8

---

## Profile Download Commands

### Download Profile (Basic)

Download and install an eSIM profile using an activation code.

**Command:**
```
AT+QESIM="download","<activation_code>"[,"<confirmation_code>"]
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `activation_code` | String | Yes | LPA:1$SM-DP+ address$MatchingID format |
| `confirmation_code` | String | Conditional | Required if profile needs confirmation |

**Activation Code Format:**

Standard GSMA format:
```
LPA:1$<SM-DP+ Address>$<MatchingID>[$<OID>]
```

**Example activation codes:**
```
LPA:1$smdp.example.com$ABC123DEF456
LPA:1$prod.smdp.rsp.goog$MATCHING-ID-12345
LPA:1$lpa.ds.gsma.com$T4G6A9H1K3$1.3.6.1.4.1.31746
```

**Response:**
```
+QESIM: "download",<result>

OK
```

**Asynchronous Notification:**

During profile download, the module sends unsolicited result codes (URC) to indicate progress:

```
+QESIM: "download",0         # Download initiated successfully
+QESIM: "download",254,50    # Download in progress (50% complete)
+QESIM: "download",254,100   # Download complete, installing profile
+QESIM: "download",0         # Installation successful
```

**Result Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success (download initiated or completed) |
| 1 | Invalid activation code format |
| 2 | Network error (cannot reach SM-DP+) |
| 3 | SM-DP+ rejected request (invalid MatchingID) |
| 4 | Confirmation code required |
| 5 | Invalid confirmation code |
| 6 | eUICC storage full |
| 7 | Profile already installed |
| 254 | Download in progress (includes percentage) |
| 255 | Unknown error |

**Example - Simple Download:**
```
AT+QESIM="download","LPA:1$smdp.operator.com$ABC123"

+QESIM: "download",0
# Wait for async notifications...
+QESIM: "download",254,25
+QESIM: "download",254,50
+QESIM: "download",254,75
+QESIM: "download",254,100
+QESIM: "download",0

OK
```

**Example - Download with Confirmation Code:**
```
AT+QESIM="download","LPA:1$smdp.operator.com$XYZ789","1234"

+QESIM: "download",0
# Download proceeds as above...

OK
```

**Timeout Considerations:**

Profile downloads can take 30 seconds to 5 minutes depending on:
- Network speed and signal quality
- Profile size (typically 2-20 KB)
- SM-DP+ server response time
- Cryptographic operations during profile installation

**Best practices:**
- Set AT command timeout to at least 180 seconds (3 minutes)
- Monitor signal strength before initiating download (`AT+CSQ`)
- Ensure stable power supply during download
- Do not reset module during download process

---

### Download Profile (OTA)

Alternative method for profile download using OTA provisioning.

**Command:**
```
AT+QESIM="ota","<activation_code>"[,"<confirmation_code>"]
```

**Differences from "download":**

| Feature | "download" | "ota" |
|---------|-----------|-------|
| Network mode | Uses module's internet connection | Uses BIP (Bearer Independent Protocol) |
| Profile activation | Manual (requires enable command) | Automatic after installation |
| Progress reporting | Detailed percentage updates | Basic status only |
| Module compatibility | All eSIM-capable modules | Requires BIP support |

**Prerequisites for OTA:**
```bash
# Enable BIP
AT+QCFG="bip/auth",1

# Configure APN for BIP channel
AT+CGDCONT=1,"IP","your.apn"

# Activate PDP context
AT+CGACT=1,1
```

**Example:**
```
AT+QESIM="ota","LPA:1$smdp.operator.com$OTA456"

+QESIM: "ota",0
# Profile downloads and automatically activates

OK
```

**When to use OTA vs Download:**

**Use "download":**
- Need precise progress monitoring
- Want manual control over profile activation
- Debugging profile installation issues

**Use "ota":**
- Simplified deployment (fewer steps)
- Automatic activation desired
- Module supports BIP properly

---

### Activation Code Validation

Before initiating download, validate activation code format:

**Manual validation:**
```bash
# Activation code must start with LPA:1$
# Format: LPA:1$<SM-DP+>$<MatchingID>[$<OID>]

# Example valid codes:
LPA:1$smdp.example.com$ABC123                    ✓
LPA:1$prod.smdp.rsp.goog$MATCH123$1.3.6.1.4      ✓

# Example invalid codes:
LPA:smdp.example.com$ABC123                      ✗ (missing version)
LPA:1$ABC123                                      ✗ (missing SM-DP+)
smdp.example.com$ABC123                           ✗ (missing LPA: prefix)
```

**Programmatic validation (quectel_lpad approach):**

From `quectel_lpad` source code:
```c
#define ACTIVATION_CODE_MINLEN (10)

// Validate activation code length
if (strlen(activation_code) < ACTIVATION_CODE_MINLEN) {
    fprintf(stderr, "Activation code too short\n");
    return -1;
}

// Special case: default SM-DP+
if (strcmp(activation_code, "UseSMDP") == 0) {
    // Use modem's default SM-DP+ address
    use_default_smdp = true;
}
```

---

## Profile Information Commands

### Get eUICC ID (EID)

Retrieve the unique identifier of the embedded UICC chip.

**Command:**
```
AT+QESIM="eid"
```

**Response:**
```
+QESIM: "eid",<result>,"<eid>"

OK
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `result` | Integer | 0 = Success, 1-3 = Error |
| `eid` | String | 32-digit hexadecimal EID |

**Example:**
```
AT+QESIM="eid"

+QESIM: "eid",0,"89049032123451234512345678901224"

OK
```

**EID Format:**

The EID is a 32-digit hexadecimal number structured as follows:

```
89 04 9032 123451234512345678901224
│  │  │    └─ Individual Identification Number (25 digits)
│  │  └─ EUM Identification Number (4 digits)
│  └─ Country Code (2 digits)
└─ Industry Identifier (2 digits, 89 = Telecom)
```

**Use Cases for EID:**

1. **Profile provisioning**: Required by operators for profile assignment
2. **Device registration**: Unique device identifier for eSIM services
3. **Troubleshooting**: Identify specific eUICC for support tickets
4. **Inventory management**: Track eSIM-enabled devices

**EID Persistence:**

- **Permanent**: EID is burned into eUICC during manufacturing
- **Read-only**: Cannot be changed or modified
- **Survives**: Firmware updates, factory resets, profile deletions

---

### Query Profile Deletion Notifications

Check for profiles that were deleted locally but not yet confirmed by SM-DP+ server.

**Command:**
```
AT+QESIM="getProfileDelNotification"
```

**Response:**
```
+QESIM: "getProfileDelNotification",<result>
+QESIM: <index>,<iccid>

OK
```

**Example:**
```
AT+QESIM="getProfileDelNotification"

+QESIM: "getProfileDelNotification",0
+QESIM: 1,"89882281777158265432"

OK
```

**Interpretation:**

Profile with ICCID `89882281777158265432` was deleted from the eUICC but the SM-DP+ server has not been notified yet. This profile is pending deletion notification.

---

### Report Profile Deletion to SM-DP+

Notify the SM-DP+ server that a profile has been deleted.

**Command:**
```
AT+QESIM="reportProfileDelNotification","<iccid>"
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `iccid` | String | ICCID of deleted profile |

**Response:**
```
+QESIM: "reportProfileDelNotification",<result>

OK
```

**Result Codes:**

| Code | Meaning |
|------|---------|
| 0 | Notification sent successfully |
| 1 | Profile not in deletion queue |
| 2 | Network error (cannot reach SM-DP+) |
| 3 | SM-DP+ rejected notification |

**Example:**
```
AT+QESIM="reportProfileDelNotification","89882281777158265432"

+QESIM: "reportProfileDelNotification",0

OK
```

**Complete Deletion Workflow:**

```bash
# Step 1: Disable profile (if enabled)
AT+QESIM="disable","89882281777158265432"
# Response: +QESIM: "disable",0

# Step 2: Delete profile from eUICC
AT+QESIM="delete","89882281777158265432"
# Response: +QESIM: "delete",0

# Step 3: Check pending deletion notifications
AT+QESIM="getProfileDelNotification"
# Response: +QESIM: 1,"89882281777158265432"

# Step 4: Notify SM-DP+ server
AT+QESIM="reportProfileDelNotification","89882281777158265432"
# Response: +QESIM: "reportProfileDelNotification",0

# Step 5: Verify notification queue is clear
AT+QESIM="getProfileDelNotification"
# Response: +QESIM: "getProfileDelNotification",0
# (No profiles listed = all notifications sent)
```

**Why Notification Matters:**

- **Operator billing**: Prevents continued billing for deleted profiles
- **Profile reuse**: Allows re-downloading single-use profiles in some cases
- **Compliance**: Required by GSMA RSP specification
- **Audit trail**: Maintains accurate provisioning records

---

## Advanced Operations

### Transparent DP+ Message Forwarding

Forward custom messages to SM-DP+ server for advanced provisioning scenarios.

**Command:**
```
AT+QESIM="trans","<sm_dp_plus_address>","<message>"
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sm_dp_plus_address` | String | SM-DP+ server FQDN or IP |
| `message` | String | Base64-encoded message payload |

**Response:**
```
+QESIM: "trans",<result>,"<response>"

OK
```

**Use Cases:**

- Custom provisioning workflows
- Proprietary operator commands
- Testing SM-DP+ server implementations
- Advanced profile management operations

**Example:**
```
AT+QESIM="trans","smdp.operator.com","SGVsbG8gU00tRFArIQ=="

+QESIM: "trans",0,"UmVzcG9uc2UgZnJvbSBTTS1EUCs="

OK
```

**Important Notes:**

⚠️ **Advanced feature**: Requires deep understanding of GSMA RSP protocol
⚠️ **Operator-specific**: Message format depends on SM-DP+ implementation
⚠️ **Limited documentation**: Not commonly used in standard deployments

---

### Module-Specific Configuration

Some modules require additional configuration for eSIM functionality:

#### EC25 Series

```bash
# Enable eSIM functionality
AT+QCFG="esim/enable",1

# Select eSIM as primary SIM
AT+QCFG="uim/select",1

# Configure eUICC slot
AT+QUIMSLOT=1
```

#### EM160R

```bash
# Check eSIM capability
AT+QESIM=?

# If no response, upgrade to eSIM-capable firmware
# Contact Quectel support for firmware download
```

#### BG95 Series

```bash
# Enable LPA functionality
AT+QCFG="lpa/enable",1

# Configure profile download mode
AT+QCFG="lpa/mode",0    # 0=Internal, 1=External
```

---

## Error Codes and Troubleshooting

### Common Error Codes

| Error Code | Operation | Cause | Solution |
|------------|-----------|-------|----------|
| 1 | All | Profile not found | Verify ICCID with `AT+QESIM="list"` |
| 2 | enable/disable | Already in target state | Check current state before operation |
| 2 | delete | Cannot delete enabled profile | Disable first with `AT+QESIM="disable"` |
| 2 | download | Network error | Check signal (`AT+CSQ`), APN, PDP context |
| 3 | All | eUICC error | Reset module with `AT+CFUN=1,1` |
| 4 | download | Confirmation code required | Provide confirmation code parameter |
| 5 | download | Invalid confirmation code | Verify code with operator |
| 6 | download | eUICC storage full | Delete unused profiles |
| 7 | download | Profile already installed | Check with `AT+QESIM="list"` |

### Troubleshooting Workflows

#### Profile Download Fails

**Symptom:** `AT+QESIM="download"` returns error code 2 or 255

**Diagnostic steps:**

```bash
# Step 1: Check signal quality
AT+CSQ
# Response: +CSQ: 20,99
# Signal should be > 10 for reliable download

# Step 2: Verify network registration
AT+CREG?
# Response: +CREG: 0,1  (0=disabled reporting, 1=registered home network)
# Should be 1 or 5

# Step 3: Check PDP context
AT+CGACT?
# Response: +CGACT: 1,1  (context 1 is active)

# Step 4: Verify internet connectivity
AT+QPING=1,"8.8.8.8"
# Should receive ping responses

# Step 5: Check DNS resolution
AT+QIDNSGIP=1,"smdp.operator.com"
# Should resolve to IP address

# Step 6: Verify activation code format
# Manual inspection: must start with LPA:1$

# Step 7: Check eUICC storage
AT+QESIM="list"
# Count installed profiles, max is typically 5-8
```

**Common fixes:**

- **Weak signal**: Move device to location with better coverage
- **Wrong APN**: Configure correct APN with `AT+CGDCONT`
- **PDP context inactive**: Activate with `AT+CGACT=1,1`
- **Firewall blocking HTTPS**: Check network allows outbound port 443
- **Invalid activation code**: Request new code from operator

---

#### Profile Won't Enable

**Symptom:** `AT+QESIM="enable"` returns error or profile remains disabled

**Diagnostic steps:**

```bash
# Step 1: Verify profile exists
AT+QESIM="list"
# Check if ICCID is listed

# Step 2: Check current state
# If profileState=1, already enabled

# Step 3: Try disabling other profiles first
AT+QESIM="disable","<other_iccid>"

# Step 4: Reset module
AT+CFUN=1,1

# Step 5: Re-enable target profile
AT+QESIM="enable","<target_iccid>"

# Step 6: Verify with ICCID query
AT+ICCID
# Should match target ICCID
```

---

#### Network Won't Register After Profile Enable

**Symptom:** Profile enabled successfully but `AT+CREG?` shows not registered

**Diagnostic steps:**

```bash
# Step 1: Verify profile is enabled
AT+QESIM="list"
# Check profileState=1

# Step 2: Check ICCID matches
AT+ICCID
# Should match enabled profile ICCID

# Step 3: Check IMSI
AT+CIMI
# Should match operator's IMSI range

# Step 4: Check network operator
AT+COPS?
# May show searching or no operator

# Step 5: Force network search
AT+COPS=0
# Wait 30-60 seconds for registration

# Step 6: Check available networks
AT+COPS=?
# List of visible operators

# Step 7: Manually select operator (if needed)
AT+COPS=1,2,"<mcc><mnc>"
# Example: AT+COPS=1,2,"310260" for T-Mobile USA
```

**Common causes:**

- **Profile not activated by operator**: Contact operator to activate
- **Invalid IMSI**: Profile may be test profile, not operational
- **Network incompatibility**: Profile may be for different region
- **SIM lock**: Module may be locked to specific operator
- **Insufficient CFUN reset**: Try full power cycle

---

#### eUICC Storage Full

**Symptom:** Cannot download new profile, error code 6

**Solution:**

```bash
# Step 1: List all profiles
AT+QESIM="list"

# Step 2: Identify unused profiles
# Look for profiles with profileState=0 (disabled)

# Step 3: Disable if needed
AT+QESIM="disable","<unused_iccid>"

# Step 4: Delete unused profile
AT+QESIM="delete","<unused_iccid>"

# Step 5: Verify space available
AT+QESIM="list"
# Fewer profiles listed

# Step 6: Retry download
AT+QESIM="download","<activation_code>"
```

**eUICC capacity:**
- Most modules support 5-8 profiles simultaneously
- Check module datasheet for exact capacity
- Keep 1-2 slots free for temporary profiles

---

### Debug Logging

Enable verbose logging for troubleshooting:

```bash
# Enable URC (unsolicited result code) output
AT+QURCCFG="urcport","usbat"

# Enable debug logging (module-specific)
AT+QCFG="dbglog",1

# Check logs via
# /dev/ttyUSBx (depending on module configuration)
```

---

## Practical Examples

### Example 1: First-Time eSIM Setup

**Scenario:** New module, no profiles installed, want to download and activate first profile.

```bash
# Step 1: Verify eSIM support
AT+QESIM=?
# Response should list available operations

# Step 2: Get EID (for operator registration)
AT+QESIM="eid"
# Response: +QESIM: "eid",0,"89049032123451234512345678901224"
# Provide EID to operator

# Step 3: Configure network (if needed for download)
AT+CGDCONT=1,"IP","internet"
AT+CGACT=1,1

# Step 4: Download profile using activation code from operator
AT+QESIM="download","LPA:1$smdp.operator.com$ABC123XYZ"
# Wait for download to complete (may take 1-3 minutes)
# Response: +QESIM: "download",254,25
#           +QESIM: "download",254,50
#           +QESIM: "download",254,100
#           +QESIM: "download",0

# Step 5: Verify profile installed
AT+QESIM="list"
# Response: +QESIM: 1,89882280666047154321,0,"","Operator A","LTE","2"

# Step 6: Enable the profile
AT+QESIM="enable","89882280666047154321"
# Response: +QESIM: "enable",0

# Step 7: Reset module to activate
AT+CFUN=1,1

# Step 8: Wait for module to restart (10-20 seconds)
# Send AT commands until response received
AT
# Response: OK (module ready)

# Step 9: Verify network registration
AT+CREG?
# Response: +CREG: 0,1 (registered on home network)

# Step 10: Verify ICCID
AT+ICCID
# Response: +ICCID: 89882280666047154321

# Step 11: Test data connection
AT+QPING=1,"8.8.8.8"
# Response: successful pings
```

---

### Example 2: Switch Between Two Profiles

**Scenario:** Two profiles installed, want to switch from Profile A to Profile B.

```bash
# Step 1: List current profiles
AT+QESIM="list"
# Response:
# +QESIM: 1,89882280666047154321,1,"Work SIM","Operator A","LTE","2"
# +QESIM: 2,89882281777158265432,0,"Personal SIM","Operator B","Data","2"
# Profile 1 is currently enabled

# Step 2: Disable current profile
AT+QESIM="disable","89882280666047154321"
# Response: +QESIM: "disable",0

# Step 3: Enable target profile
AT+QESIM="enable","89882281777158265432"
# Response: +QESIM: "enable",0

# Step 4: Reset module
AT+CFUN=0
# Wait 2 seconds
AT+CFUN=1

# Step 5: Verify switch
AT+ICCID
# Response: +ICCID: 89882281777158265432 (Profile B active)

# Step 6: Check network registration
AT+COPS?
# Response: +COPS: 0,0,"Operator B",7 (registered on Operator B)
```

**Timing:**
- Total switch time: ~15-30 seconds
- No SIM card physical access required
- Can be automated with scripts

---

### Example 3: Delete Unused Profile

**Scenario:** Profile no longer needed, want to free up storage space.

```bash
# Step 1: List profiles
AT+QESIM="list"
# Response:
# +QESIM: 1,89882280666047154321,1,"Work SIM","Operator A","LTE","2"
# +QESIM: 2,89882281777158265432,0,"Old Test","Test Operator","Test","0"
# Want to delete profile 2 (test profile)

# Step 2: Ensure profile is disabled
AT+QESIM="disable","89882281777158265432"
# Response: +QESIM: "disable",0 (or error 2 if already disabled)

# Step 3: Delete the profile
AT+QESIM="delete","89882281777158265432"
# Response: +QESIM: "delete",0

# Step 4: Verify deletion
AT+QESIM="list"
# Response: +QESIM: 1,89882280666047154321,1,"Work SIM","Operator A","LTE","2"
# Profile 2 no longer listed

# Step 5: Check pending deletion notifications
AT+QESIM="getProfileDelNotification"
# Response: +QESIM: 1,"89882281777158265432"
# Profile pending notification to SM-DP+

# Step 6: Notify SM-DP+ server (if internet available)
AT+QESIM="reportProfileDelNotification","89882281777158265432"
# Response: +QESIM: "reportProfileDelNotification",0

# Step 7: Verify notification sent
AT+QESIM="getProfileDelNotification"
# Response: +QESIM: "getProfileDelNotification",0
# No profiles pending (notification successful)
```

---

### Example 4: Download Profile with Confirmation Code

**Scenario:** Operator requires confirmation code for security.

```bash
# Step 1: Attempt download without confirmation code
AT+QESIM="download","LPA:1$smdp.operator.com$SECURE789"
# Response: +QESIM: "download",4
# Error 4: Confirmation code required

# Step 2: Obtain confirmation code from operator
# (Usually sent via SMS, email, or operator portal)
# Example: 1234

# Step 3: Download with confirmation code
AT+QESIM="download","LPA:1$smdp.operator.com$SECURE789","1234"
# Response: +QESIM: "download",0
#           +QESIM: "download",254,50
#           +QESIM: "download",254,100
#           +QESIM: "download",0

# Step 4: Enable downloaded profile
AT+QESIM="list"
# Find new profile ICCID
AT+QESIM="enable","<new_iccid>"
AT+CFUN=1,1
```

---

### Example 5: Multi-Profile Management for IoT Gateway

**Scenario:** IoT gateway with failover between 3 operators.

```bash
# Initial setup: Download 3 profiles

# Profile 1: Primary operator
AT+QESIM="download","LPA:1$primary.smdp.com$PRIMARY123"
# Wait for completion
AT+QESIM="nickname","<iccid_1>","Primary"

# Profile 2: Secondary operator
AT+QESIM="download","LPA:1$secondary.smdp.com$BACKUP456"
# Wait for completion
AT+QESIM="nickname","<iccid_2>","Secondary"

# Profile 3: Tertiary operator
AT+QESIM="download","LPA:1$tertiary.smdp.com$FAILOVER789"
# Wait for completion
AT+QESIM="nickname","<iccid_3>","Tertiary"

# Enable primary profile
AT+QESIM="enable","<iccid_1>"
AT+CFUN=1,1

# Automated failover script (pseudocode):
# while true:
#   if network_fails(primary):
#     switch_to(secondary)
#   if network_fails(secondary):
#     switch_to(tertiary)
#   if network_fails(tertiary):
#     switch_to(primary)
#   sleep(60)
```

**OpenWrt integration with mwan3:**
- Use `quectel_lpad` for profile downloads
- Use `AT+QESIM="enable"` in hotplug scripts for failover
- Monitor connection with `simplefailover` or `mwan3` packages

---

## Integration with quectel_lpad

### Relationship Between AT Commands and QMI

The `quectel_lpad` application uses **QMI (Qualcomm MSM Interface)** for eSIM management instead of AT commands. However, the operations are equivalent:

| AT Command | quectel_lpad Operation | QMI Message |
|------------|------------------------|-------------|
| `AT+QESIM="download"` | `./quectel_lpad -A <code>` | `QMI_UIM_ADD_PROFILE_REQ_V01` |
| `AT+QESIM="delete"` | `./quectel_lpad -R <id>` | `QMI_UIM_DELETE_PROFILE_REQ_V01` |
| `AT+QESIM="list"` | *(Not implemented)* | `QMI_UIM_GET_PROFILES_REQ_V01` |
| `AT+QESIM="eid"` | *(Not implemented)* | `QMI_UIM_GET_EID_REQ_V01` |

### Why QMI Instead of AT Commands?

**Advantages of QMI:**
- **Binary protocol**: More efficient than text-based AT commands
- **Asynchronous**: Better handling of long operations (profile download)
- **Direct modem access**: No AT parser overhead
- **Standardized**: Same interface across Qualcomm-based modems
- **Rich data structures**: Complex parameters easier to handle

**When to use AT commands:**
- **Quick testing**: Easier to type manually in terminal
- **Legacy systems**: Existing AT command infrastructure
- **Simple operations**: Single-operation tasks
- **Cross-platform**: Works with any serial terminal

**When to use quectel_lpad (QMI):**
- **OpenWrt integration**: Automated profile management
- **Production deployments**: Reliable, event-driven architecture
- **HTTP proxy mode**: Modem offloads HTTP to application
- **Progress monitoring**: Real-time download percentage
- **LuCI integration**: Web UI for profile management (luci-app-lpac)

### Using AT Commands with quectel_lpad Environment

You can use AT commands for operations not implemented in quectel_lpad:

**List profiles (AT command):**
```bash
# Access AT command interface
echo -e "AT+QESIM=\"list\"\r" > /dev/ttyUSB2
cat /dev/ttyUSB2
```

**Enable profile (AT command) after quectel_lpad download:**
```bash
# Download via quectel_lpad
./quectel_lpad -A "LPA:1$smdp.operator.com$ABC123"

# Enable via AT command
echo -e "AT+QESIM=\"enable\",\"89882280666047154321\"\r" > /dev/ttyUSB2
```

**OpenWrt AT command helper:**
```bash
#!/bin/sh
# /usr/bin/qesim-at

DEVICE="/dev/ttyUSB2"
CMD="$1"

echo -e "AT+QESIM=\"$CMD\"\r" > $DEVICE
timeout 5 cat $DEVICE
```

**Usage:**
```bash
qesim-at "list"
qesim-at "eid"
qesim-at "enable,89882280666047154321"
```

---

## Best Practices

### Security

**Protect Activation Codes:**
- Never log activation codes in plain text
- Single-use codes cannot be reused
- Treat confirmation codes like passwords

**Secure Communication:**
- Profile downloads use TLS (HTTPS)
- SM-DP+ authenticates eUICC via cryptographic challenge
- LPA validates server certificates

**Access Control:**
```bash
# Restrict AT command interface access
chmod 600 /dev/ttyUSB2
chown root:root /dev/ttyUSB2

# Use udev rules for permissions
# /etc/udev/rules.d/99-qmi.rules
KERNEL=="ttyUSB2", MODE="0600", OWNER="root"
```

---

### Performance

**Signal Quality:**
- Minimum CSQ: 10 for reliable download
- Optimal CSQ: 15-31
- Check before download: `AT+CSQ`

**Timeout Settings:**
```bash
# AT command timeout
# Short operations (list, enable): 10 seconds
# Download operations: 180 seconds (3 minutes)
# Network registration: 60 seconds
```

**Power Management:**
- Keep power stable during download
- Avoid `AT+CFUN` during download
- Use UPS for critical deployments

---

### Automation

**Profile Download Script:**
```bash
#!/bin/sh
# download_profile.sh

DEVICE="/dev/ttyUSB2"
ACTIVATION_CODE="$1"
CONFIRMATION_CODE="$2"

send_at() {
    echo -e "$1\r" > $DEVICE
    sleep 1
    timeout 5 cat $DEVICE
}

# Check signal
CSQ=$(send_at "AT+CSQ" | grep "+CSQ:" | cut -d' ' -f2 | cut -d',' -f1)
if [ "$CSQ" -lt 10 ]; then
    echo "Signal too weak: $CSQ"
    exit 1
fi

# Download profile
if [ -z "$CONFIRMATION_CODE" ]; then
    send_at "AT+QESIM=\"download\",\"$ACTIVATION_CODE\""
else
    send_at "AT+QESIM=\"download\",\"$ACTIVATION_CODE\",\"$CONFIRMATION_CODE\""
fi

# Wait for download (check every 10 seconds for 3 minutes)
for i in $(seq 1 18); do
    sleep 10
    RESULT=$(send_at "AT+QESIM=\"list\"" | grep "$ACTIVATION_CODE")
    if [ -n "$RESULT" ]; then
        echo "Download complete"
        exit 0
    fi
done

echo "Download timeout"
exit 1
```

**Usage:**
```bash
./download_profile.sh "LPA:1$smdp.operator.com$ABC123"
./download_profile.sh "LPA:1$smdp.operator.com$ABC123" "1234"
```

---

**Profile Switching Script:**
```bash
#!/bin/sh
# switch_profile.sh

DEVICE="/dev/ttyUSB2"
TARGET_ICCID="$1"

send_at() {
    echo -e "$1\r" > $DEVICE
    timeout 5 cat $DEVICE
}

# Get current enabled profile
CURRENT=$(send_at "AT+ICCID" | grep "+ICCID:" | cut -d' ' -f2)

if [ "$CURRENT" = "$TARGET_ICCID" ]; then
    echo "Already using target profile"
    exit 0
fi

# Disable current
send_at "AT+QESIM=\"disable\",\"$CURRENT\""

# Enable target
send_at "AT+QESIM=\"enable\",\"$TARGET_ICCID\""

# Reset
send_at "AT+CFUN=0"
sleep 2
send_at "AT+CFUN=1"

# Wait for registration
for i in $(seq 1 30); do
    sleep 2
    REG=$(send_at "AT+CREG?" | grep "+CREG: 0,1")
    if [ -n "$REG" ]; then
        echo "Switched to $TARGET_ICCID"
        exit 0
    fi
done

echo "Switch timeout"
exit 1
```

---

### Monitoring

**Health Check Script:**
```bash
#!/bin/sh
# esim_health.sh

DEVICE="/dev/ttyUSB2"

send_at() {
    echo -e "$1\r" > $DEVICE
    timeout 5 cat $DEVICE
}

echo "=== eSIM Health Check ==="

# Signal quality
CSQ=$(send_at "AT+CSQ")
echo "Signal: $CSQ"

# Network registration
CREG=$(send_at "AT+CREG?")
echo "Registration: $CREG"

# Current ICCID
ICCID=$(send_at "AT+ICCID")
echo "Active ICCID: $ICCID"

# Installed profiles
echo "Installed profiles:"
send_at "AT+QESIM=\"list\""

# Pending deletions
echo "Pending deletions:"
send_at "AT+QESIM=\"getProfileDelNotification\""

# EID
EID=$(send_at "AT+QESIM=\"eid\"")
echo "EID: $EID"
```

**Run periodically:**
```bash
# Add to crontab
*/15 * * * * /usr/bin/esim_health.sh >> /var/log/esim_health.log
```

---

### Error Recovery

**Automatic recovery script:**
```bash
#!/bin/sh
# esim_recover.sh

DEVICE="/dev/ttyUSB2"

send_at() {
    echo -e "$1\r" > $DEVICE
    timeout 5 cat $DEVICE
}

# Check if registered
REG=$(send_at "AT+CREG?" | grep "+CREG: 0,[15]")

if [ -z "$REG" ]; then
    echo "Not registered, attempting recovery..."

    # Try network search
    send_at "AT+COPS=0"
    sleep 30

    REG=$(send_at "AT+CREG?" | grep "+CREG: 0,[15]")
    if [ -n "$REG" ]; then
        echo "Recovered via network search"
        exit 0
    fi

    # Try module reset
    send_at "AT+CFUN=1,1"
    sleep 20

    REG=$(send_at "AT+CREG?" | grep "+CREG: 0,[15]")
    if [ -n "$REG" ]; then
        echo "Recovered via module reset"
        exit 0
    fi

    echo "Recovery failed"
    exit 1
fi

echo "Already registered"
exit 0
```

---

## Appendix

### Supported Modules Reference

| Module | eSIM Support | Firmware Version | Notes |
|--------|--------------|------------------|-------|
| EC25-E | Yes | ≥ EC25EFAR05A04M4G | Standard LTE |
| EC25-A | Yes | ≥ EC25AFAR05A05M4G | Americas |
| EC25-AU | Yes | ≥ EC25AUGAR08A03M4G | Australia |
| EG21-G | Yes | ≥ EG21GGBR07A08M2G | Global |
| EM160R | Yes | ≥ EM160RGLAUR01A05M4G | Router-optimized |
| EC200A-EU | Yes | ≥ EC200AEUABR03A01M08 | Europe |
| BG95M3 | Yes | ≥ BG95M3LAR02A03 | NB-IoT/LTE-M |
| EC600U-CN | Yes | ≥ EC600UCNAAR01A01M08 | China |

**Firmware update for eSIM:**

If module doesn't respond to `AT+QESIM=?`, firmware upgrade may be needed:

```bash
# Check current firmware
AT+CGMR
# Response: EC25EFAR05A03M4G (example)

# Download eSIM-enabled firmware from Quectel
# Use QFlash tool (Windows) or qfirehose (Linux)
# Contact Quectel technical support for firmware files
```

---

### GSMA RSP Specification Reference

**Official documents:**
- GSMA SGP.21: Remote Provisioning Architecture
- GSMA SGP.22: RSP Technical Specification
- GSMA SGP.23: RSP eUICC Test Plan

**Key concepts:**

**SM-DP+ (Subscription Manager Data Preparation Plus):**
- Operator's profile provisioning server
- Generates encrypted profile packages
- Handles profile download requests

**LPA (Local Profile Assistant):**
- On-device component for profile management
- Handles user interface (in smartphones)
- Offloads HTTP in modems (quectel_lpad approach)

**eUICC (embedded Universal Integrated Circuit Card):**
- Physical eSIM chip in the module
- Stores up to 5-8 profiles simultaneously
- Tamper-resistant secure element

**EID (eUICC Identifier):**
- 32-digit unique identifier
- Burned into eUICC during manufacturing
- Used for profile assignment and device tracking

---

### Additional Resources

**Quectel Documentation:**
- [Quectel Forums](https://forums.quectel.com/)
- [Quectel Download Center](https://www.quectel.com/download/)
- EC25 Series AT Commands Manual
- EC25 & EG21-G eSIM AT Commands Manual

**GSMA Specifications:**
- [GSMA RSP Specifications](https://www.gsma.com/esim/resources/)
- SGP.22 v2.2.2 or later

**OpenWrt Integration:**
- `quectel_lpad` application (this project)
- `luci-app-lpac` LuCI interface
- ModemManager with eSIM support (≥ v1.18)

**Third-Party Tools:**
- lpac: Open-source LPA implementation
- eUICC-manual: Manual eSIM management tools
- QMI CLI tools: qmicli, uqmi

---

## Glossary

| Term | Definition |
|------|------------|
| **eSIM** | Embedded SIM, programmable SIM card built into device |
| **eUICC** | Embedded Universal Integrated Circuit Card, the physical eSIM chip |
| **EID** | eUICC Identifier, 32-digit unique ID of eSIM chip |
| **ICCID** | Integrated Circuit Card Identifier, 19-20 digit profile identifier |
| **IMSI** | International Mobile Subscriber Identity, subscriber identifier |
| **LPA** | Local Profile Assistant, software for managing eSIM profiles |
| **SM-DP+** | Subscription Manager Data Preparation Plus, profile provisioning server |
| **RSP** | Remote SIM Provisioning, GSMA standard for eSIM management |
| **Activation Code** | QR code or string used to download eSIM profile |
| **Confirmation Code** | Additional security code for profile download |
| **Profile** | Complete SIM configuration (IMSI, keys, operator data) |
| **QMI** | Qualcomm MSM Interface, binary protocol for modem control |
| **AT Commands** | Hayes command set for modem control via text |
| **BIP** | Bearer Independent Protocol, allows SIM to access internet |
| **OTA** | Over-The-Air, remote profile provisioning |

---

## Conclusion

The AT+QESIM command set provides comprehensive eSIM management capabilities for Quectel modems. Key takeaways:

**Essential operations:**
- `AT+QESIM="list"` - View installed profiles
- `AT+QESIM="download"` - Download new profiles
- `AT+QESIM="enable"` - Activate a profile
- `AT+QESIM="disable"` - Deactivate a profile
- `AT+QESIM="delete"` - Remove a profile
- `AT+QESIM="eid"` - Get eUICC identifier

**Best practices:**
- Verify signal strength before downloads
- Always reset module after enabling/disabling profiles
- Notify SM-DP+ server when deleting profiles
- Set appropriate AT command timeouts
- Monitor profile state with regular health checks

**Integration options:**
- **AT commands**: Quick testing, manual operations
- **quectel_lpad (QMI)**: Production deployments, OpenWrt integration
- **Hybrid approach**: Use both for complete functionality

**Next steps:**
- Test basic operations with your module
- Implement automation scripts for your use case
- Integrate with OpenWrt using `luci-app-lpac`
- Set up monitoring and failover strategies

For further assistance, consult Quectel technical support or the community forums.

---

**Document History:**

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | October 2025 | Initial comprehensive guide |

**Contributors:**
- Based on Quectel official documentation
- GSMA RSP specifications
- quectel_lpad project integration
- Community forum contributions

**License:** This documentation is provided for educational and integration purposes. AT+QESIM commands are proprietary to Quectel. GSMA RSP specifications are subject to GSMA licensing.
