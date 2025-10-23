# OpenEUICC - Technical Documentation

## Overview

**OpenEUICC** is a fully free and open-source Local Profile Assistant (LPA) implementation for Android devices. It provides complete eSIM management capabilities using the [lpac](https://github.com/estkme-group/lpac) library integrated through JNI (Java Native Interface).

**Repository:** https://gitea.angry.im/PeterCxy/OpenEUICC
**License:** GPL-3.0 (without "or later" clause)

## Project Variants

OpenEUICC has two variants serving different use cases:

| Feature | OpenEUICC | EasyEUICC |
|---------|-----------|-----------|
| **Privileged** | Must be system app | No |
| **Internal eSIM** | Supported | Unsupported |
| **External eSIM** [^1] | Supported | Supported |
| **USB Readers** | Supported | Supported |
| **Requires allowlisting** | No | Yes (except USB) |
| **System Integration** | Partial [^2] | No |
| **Minimum Android** | Android 11+ (API 30) | Android 9+ (API 28) |

[^1]: Also known as "Removable eSIM"
[^2]: Carrier Partner API unimplemented

### OpenEUICC (Privileged)
- Must be installed as system app
- Full access to device's internal eUICC
- Supports any SGP.22-compliant eUICC chip
- No allowlisting required

### EasyEUICC (Unprivileged)
- Regular user app installation
- Requires eUICC to proactively grant access via ARA-M field
- ARA-M hash for official builds: `2A2FA878BC7C3354C2CF82935A5945A3EDAE4AFA`
- Works with removable eSIM and USB readers

## Architecture

### Technology Stack

- **Language:** Kotlin
- **Platform:** Android (native)
- **Build System:** Gradle (Kotlin DSL)
- **Backend:** lpac (via JNI)
- **Minimum SDK:** 30 (OpenEUICC), 28 (EasyEUICC)
- **Target SDK:** 35

### Integration Method

OpenEUICC integrates lpac through **lpac-jni**, a custom JNI wrapper that provides native binding between Kotlin/Java and the C-based lpac library.

```
┌──────────────────────────────────────┐
│   Android App (Kotlin)               │
│   ┌──────────────────────────────┐   │
│   │  EuiccChannel                │   │
│   │  EuiccChannelManager         │   │
│   └──────────┬───────────────────┘   │
└──────────────┼───────────────────────┘
               │
┌──────────────▼───────────────────────┐
│   lpac-jni Library                   │
│   ┌──────────────────────────────┐   │
│   │  LocalProfileAssistant       │   │
│   │  (Kotlin Interface)          │   │
│   └──────────┬───────────────────┘   │
│              │ JNI calls             │
│   ┌──────────▼───────────────────┐   │
│   │  Native Code (C)             │   │
│   │  - lpac-jni.c                │   │
│   │  - interface-wrapper.c       │   │
│   └──────────┬───────────────────┘   │
└──────────────┼───────────────────────┘
               │
┌──────────────▼───────────────────────┐
│   lpac Library (C)                   │
│   - libeuicc (ES10x, ES9+)          │
│   - APDU handling                    │
│   - HTTP communication               │
└──────────────────────────────────────┘
```

## How lpac is Used

### 1. JNI Integration Layer

OpenEUICC uses a custom JNI library (`lpac-jni`) to interface with lpac's C code. This library is compiled as a native Android library (`.so` file).

#### Native Library Loading

```kotlin
// From LpacJni.kt:4
internal object LpacJni {
    init {
        System.loadLibrary("lpac-jni")  // Loads liblpac-jni.so
    }

    // JNI method declarations
    external fun createContext(
        isdrAid: ByteArray,
        apduInterface: ApduInterface,
        httpInterface: HttpInterface
    ): Long
    external fun euiccInit(handle: Long): Int
    // ... more JNI methods
}
```

### 2. Context Management

lpac operates with a context handle that maintains state throughout operations:

```kotlin
// From LocalProfileAssistantImpl.kt:87
private var contextHandle: Long = LpacJni.createContext(
    isdrAid,           // ISD-R Application Identifier
    apduInterface,     // APDU communication interface
    httpInterface      // HTTP communication interface
)

init {
    if (LpacJni.euiccInit(contextHandle) < 0) {
        throw IllegalArgumentException("Failed to initialize LPA")
    }
}
```

**Context Lifecycle:**
1. `createContext()` - Initialize lpac context
2. `euiccInit()` - Initialize eUICC connection
3. Perform operations (download, enable, delete, etc.)
4. `euiccFini()` - Finalize eUICC connection
5. `destroyContext()` - Clean up lpac context

### 3. Interface Abstraction

OpenEUICC provides two key interfaces that lpac uses:

#### ApduInterface
```kotlin
// From ApduInterface.kt:6
interface ApduInterface {
    fun connect()
    fun disconnect()
    fun logicalChannelOpen(aid: ByteArray): Int
    fun logicalChannelClose(handle: Int)
    fun transmit(handle: Int, tx: ByteArray): ByteArray
    val valid: Boolean
}
```

**Implementations:**
- **TelephonyManagerApduInterface**: Uses Android's TelephonyManager (privileged access)
- **OmapiApduInterface**: Uses OMAPI (Open Mobile API) for unprivileged access
- **UsbApduInterface**: Direct USB CCID communication

#### HttpInterface
```kotlin
// From HttpInterface.kt:8
interface HttpInterface {
    data class HttpResponse(val rcode: Int, val data: ByteArray)

    fun transmit(url: String, tx: ByteArray, headers: Array<String>): HttpResponse
    fun usePublicKeyIds(pkids: Array<String>)
}
```

**Implementation:**
- **HttpInterfaceImpl**: Standard HTTP client with certificate pinning support

### 4. Thread Safety

All lpac operations are protected by a reentrant lock since lpac is explicitly NOT thread-safe:

```kotlin
// From LocalProfileAssistantImpl.kt:81
private val lock = ReentrantLock()

override fun enableProfile(iccid: String, refresh: Boolean): Boolean = lock.withLock {
    LpacJni.es10cEnableProfile(contextHandle, iccid, refresh) == 0
}
```

## lpac Functions Reference

### Profile Management

#### Get Profile List
**JNI Method:**
```kotlin
external fun es10cGetProfilesInfo(handle: Long): Long
```

**Implementation:**
```kotlin
// From LocalProfileAssistantImpl.kt:113
override val profiles: List<LocalProfileInfo>
    get() = lock.withLock {
        val head = LpacJni.es10cGetProfilesInfo(contextHandle)
        var curr = head
        val ret = mutableListOf<LocalProfileInfo>()

        while (curr != 0L) {
            ret.add(LocalProfileInfo(
                LpacJni.profileGetIccid(curr),
                LocalProfileInfo.State.fromString(LpacJni.profileGetStateString(curr)),
                LpacJni.profileGetName(curr),
                LpacJni.profileGetNickname(curr),
                LpacJni.profileGetServiceProvider(curr),
                LpacJni.profileGetIsdpAid(curr),
                LocalProfileInfo.Clazz.fromString(LpacJni.profileGetClassString(curr))
            ))
            curr = LpacJni.profilesNext(curr)
        }

        LpacJni.profilesFree(head)
        return ret
    }
```

**Returns:** Linked list of profiles traversed through JNI

---

#### Enable Profile
**JNI Method:**
```kotlin
external fun es10cEnableProfile(handle: Long, iccid: String, refresh: Boolean): Int
```

**Usage:**
```kotlin
// Returns 0 on success
override fun enableProfile(iccid: String, refresh: Boolean): Boolean = lock.withLock {
    LpacJni.es10cEnableProfile(contextHandle, iccid, refresh) == 0
}
```

**Parameters:**
- `iccid`: Profile ICCID
- `refresh`: Whether to refresh the modem after enabling

---

#### Disable Profile
**JNI Method:**
```kotlin
external fun es10cDisableProfile(handle: Long, iccid: String, refresh: Boolean): Int
```

**Usage:**
```kotlin
override fun disableProfile(iccid: String, refresh: Boolean): Boolean = lock.withLock {
    LpacJni.es10cDisableProfile(contextHandle, iccid, refresh) == 0
}
```

---

#### Delete Profile
**JNI Method:**
```kotlin
external fun es10cDeleteProfile(handle: Long, iccid: String): Int
```

**Usage:**
```kotlin
override fun deleteProfile(iccid: String): Boolean = lock.withLock {
    LpacJni.es10cDeleteProfile(contextHandle, iccid) == 0
}
```

---

#### Download Profile
**JNI Method:**
```kotlin
external fun downloadProfile(
    handle: Long,
    smdp: String,
    matchingId: String?,
    imei: String?,
    confirmationCode: String?,
    callback: ProfileDownloadCallback
): Int
```

**Usage:**
```kotlin
// From LocalProfileAssistantImpl.kt:217
override fun downloadProfile(
    smdp: String,
    matchingId: String?,
    imei: String?,
    confirmationCode: String?,
    callback: ProfileDownloadCallback
) = lock.withLock {
    val res = LpacJni.downloadProfile(
        contextHandle,
        smdp,
        matchingId,
        imei,
        confirmationCode,
        callback
    )

    if (res != 0) {
        throw LocalProfileAssistant.ProfileDownloadException(
            lpaErrorReason = LpacJni.downloadErrCodeToString(-res),
            httpInterface.lastHttpResponse,
            httpInterface.lastHttpException,
            apduInterface.lastApduResponse,
            apduInterface.lastApduException,
        )
    }
}
```

**Callback Interface:**
```kotlin
interface ProfileDownloadCallback {
    fun onStateUpdate(state: String)
    fun onProgress(progress: Long, total: Long)
}
```

**Download Flow:**
1. ES10b: Get eUICC challenge and info
2. ES9+: Initiate authentication with SM-DP+
3. ES10b: Authenticate server
4. ES9+: Authenticate client
5. ES10b: Prepare download
6. ES9+: Get bound profile package
7. ES10b: Load bound profile package

---

#### Set Nickname
**JNI Method:**
```kotlin
external fun es10cSetNickname(handle: Long, iccid: String, nickNullTerminated: ByteArray): Int
```

**Usage:**
```kotlin
// From LocalProfileAssistantImpl.kt:257
override fun setNickname(iccid: String, nickname: String) = lock.withLock {
    val encoded = Charsets.UTF_8.encode(nickname).array()

    if (encoded.size >= 64) {
        throw LocalProfileAssistant.ProfileNameTooLongException()
    }

    val encodedNullTerminated = encoded + byteArrayOf(0)

    if (LpacJni.es10cSetNickname(contextHandle, iccid, encodedNullTerminated) != 0) {
        throw LocalProfileAssistant.ProfileRenameException()
    }
}
```

**Constraints:**
- Must be valid UTF-8
- Maximum 63 bytes (64 including null terminator)

---

### Chip Information

#### Get EID
**JNI Method:**
```kotlin
external fun es10cGetEid(handle: Long): String?
```

**Usage:**
```kotlin
override val eID: String
    get() = lock.withLock { LpacJni.es10cGetEid(contextHandle)!! }
```

---

#### Get Extended eUICC Info (EuiccInfo2)
**JNI Method:**
```kotlin
external fun es10cexGetEuiccInfo2(handle: Long): Long
```

**Usage:**
```kotlin
// From LocalProfileAssistantImpl.kt:170
override val euiccInfo2: EuiccInfo2?
    get() = lock.withLock {
        val cInfo = LpacJni.es10cexGetEuiccInfo2(contextHandle)
        if (cInfo == 0L) return null

        try {
            return EuiccInfo2(
                Version(LpacJni.euiccInfo2GetSGP22Version(cInfo)),
                Version(LpacJni.euiccInfo2GetProfileVersion(cInfo)),
                Version(LpacJni.euiccInfo2GetEuiccFirmwareVersion(cInfo)),
                Version(LpacJni.euiccInfo2GetGlobalPlatformVersion(cInfo)),
                LpacJni.euiccInfo2GetSasAcreditationNumber(cInfo),
                Version(LpacJni.euiccInfo2GetPpVersion(cInfo)),
                LpacJni.euiccInfo2GetFreeNonVolatileMemory(cInfo).toInt(),
                LpacJni.euiccInfo2GetFreeVolatileMemory(cInfo).toInt(),
                // ... certificate PKIDs
            )
        } finally {
            LpacJni.euiccInfo2Free(cInfo)
        }
    }
```

**EuiccInfo2 Fields:**
- SGP.22 version
- Profile version
- Firmware version
- GlobalPlatform version
- SAS accreditation number
- Protection Profile version
- Free memory (volatile and non-volatile)
- Certificate PKIDs (signing and verification)

---

### Notification Management

#### List Notifications
**JNI Method:**
```kotlin
external fun es10bListNotification(handle: Long): Long
```

**Usage:**
```kotlin
// From LocalProfileAssistantImpl.kt:139
override val notifications: List<LocalProfileNotification>
    get() = lock.withLock {
        val head = LpacJni.es10bListNotification(contextHandle)
        var curr = head

        try {
            val ret = mutableListOf<LocalProfileNotification>()
            while (curr != 0L) {
                ret.add(LocalProfileNotification(
                    LpacJni.notificationGetSeq(curr),
                    LocalProfileNotification.Operation.fromString(
                        LpacJni.notificationGetOperationString(curr)
                    ),
                    LpacJni.notificationGetAddress(curr),
                    LpacJni.notificationGetIccid(curr),
                ))
                curr = LpacJni.notificationsNext(curr)
            }
            return ret.sortedBy { it.seqNumber }.reversed()
        } finally {
            LpacJni.notificationsFree(head)
        }
    }
```

---

#### Handle Notification
**JNI Method:**
```kotlin
external fun handleNotification(handle: Long, seqNumber: Long): Int
```

**Usage:**
```kotlin
// Send notification to SM-DP+ server
override fun handleNotification(seqNumber: Long): Boolean = lock.withLock {
    LpacJni.handleNotification(contextHandle, seqNumber) == 0
}
```

---

#### Delete Notification
**JNI Method:**
```kotlin
external fun es10bDeleteNotification(handle: Long, seqNumber: Long): Int
```

**Usage:**
```kotlin
override fun deleteNotification(seqNumber: Long): Boolean = lock.withLock {
    LpacJni.es10bDeleteNotification(contextHandle, seqNumber) == 0
}
```

---

### Advanced Operations

#### Memory Reset
**JNI Method:**
```kotlin
external fun es10cEuiccMemoryReset(handle: Long): Int
```

**Usage:**
```kotlin
override fun euiccMemoryReset() {
    lock.withLock {
        LpacJni.es10cEuiccMemoryReset(contextHandle)
    }
}
```

**Warning:** Erases all profiles on the eUICC!

---

#### Set Maximum Segment Size
**JNI Method:**
```kotlin
external fun euiccSetMss(handle: Long, mss: Byte)
```

**Usage:**
```kotlin
override fun setEs10xMss(mss: Byte) {
    LpacJni.euiccSetMss(contextHandle, mss)
}
```

**Purpose:** Helps with removable eUICCs that may run at baud rates too fast for the modem. Default: 60 (set by libeuicc).

---

#### Cancel Sessions
**JNI Method:**
```kotlin
external fun cancelSessions(handle: Long)
```

**Usage:**
```kotlin
// Cancel any ongoing ES9+ and/or ES10b sessions
LpacJni.cancelSessions(contextHandle)
```

## Data Structures

### LocalProfileInfo
```kotlin
data class LocalProfileInfo(
    val iccid: String,
    val state: State,              // Enabled, Disabled
    val name: String,
    val nickName: String,
    val providerName: String,
    val isdpAID: String,
    val profileClass: Clazz        // Testing, Provisioning, Operational
)
```

### LocalProfileNotification
```kotlin
data class LocalProfileNotification(
    val seqNumber: Long,
    val operation: Operation,      // Install, Enable, Disable, Delete
    val address: String,           // SM-DP+ address
    val iccid: String
)
```

### EuiccInfo2
```kotlin
data class EuiccInfo2(
    val sgp22Version: Version,
    val profileVersion: Version,
    val euiccFirmwareVersion: Version,
    val globalPlatformVersion: Version,
    val sasAcreditationNumber: String,
    val ppVersion: Version,
    val freeNonVolatileMemory: Int,
    val freeVolatileMemory: Int,
    val euiccCiPKIdListForSigning: Set<String>,
    val euiccCiPKIdListForVerification: Set<String>
)
```

## Project Structure

### Module Organization

```
openeuicc/
├── app/                      # OpenEUICC (privileged variant)
│   └── src/main/java/im/angry/openeuicc/
│       ├── core/            # Privileged eUICC channel implementations
│       ├── di/              # Dependency injection
│       ├── service/         # System services
│       └── ui/              # User interface
├── app-unpriv/              # EasyEUICC (unprivileged variant)
│   └── src/main/java/im/angry/easyeuicc/
│       ├── core/            # Unprivileged channel implementations
│       └── ui/              # User interface
├── app-common/              # Shared code between variants
│   └── src/main/java/im/angry/openeuicc/
│       ├── core/            # Common channel abstractions
│       └── util/            # Utility classes
├── libs/
│   ├── lpac-jni/           # JNI wrapper for lpac
│   │   ├── src/main/java/  # Kotlin interfaces
│   │   └── src/main/jni/   # Native C code
│   ├── hidden-apis-stub/   # Android hidden API stubs
│   └── hidden-apis-shim/   # Android hidden API shims
└── app-deps/               # Dependency configurations
```

### Key Files

#### lpac-jni Module

| File | Purpose |
|------|---------|
| `LpacJni.kt` | JNI method declarations |
| `LocalProfileAssistant.kt` | Main interface for LPA operations |
| `LocalProfileAssistantImpl.kt` | Implementation of LPA interface |
| `ApduInterface.kt` | APDU communication interface |
| `HttpInterface.kt` | HTTP communication interface |
| `LocalProfileInfo.kt` | Profile data structure |
| `LocalProfileNotification.kt` | Notification data structure |
| `EuiccInfo2.kt` | Extended eUICC information |

#### Native Code (JNI)

| File | Purpose |
|------|---------|
| `lpac-jni.c` | Main JNI bindings |
| `lpac-download.c` | Profile download operations |
| `lpac-notifications.c` | Notification handling |
| `interface-wrapper.c` | APDU/HTTP interface wrappers |

#### App Common

| File | Purpose |
|------|---------|
| `EuiccChannel.kt` | Channel abstraction interface |
| `EuiccChannelImpl.kt` | Channel implementation |
| `EuiccChannelManager.kt` | Multi-channel management |
| `OmapiApduInterface.kt` | OMAPI APDU implementation |

#### OpenEUICC (Privileged)

| File | Purpose |
|------|---------|
| `TelephonyManagerApduInterface.kt` | System-level APDU access |
| `PrivilegedEuiccChannelManager.kt` | Privileged channel management |
| `OpenEuiccService.kt` | System service |

## Building

### Prerequisites

1. Android SDK (API 28-35)
2. Kotlin 1.9.20+
3. Gradle 8.1+
4. NDK (for native code compilation)
5. Git with submodules

### Clone Repository

```bash
git clone https://gitea.angry.im/PeterCxy/OpenEUICC.git
cd OpenEUICC
git submodule update --init
```

### Configure Signing

Create `keystore.properties` in root directory:

```ini
storePassword=my-store-password
keyPassword=my-password
keyAlias=my-key
unprivKeyPassword=my-unpriv-password
unprivKeyAlias=my-unpriv-key
storeFile=/path/to/android/keystore
```

### Build OpenEUICC (Privileged)

```bash
./gradlew :app:assembleRelease
```

**Output:** `app/build/outputs/apk/release/OpenEUICC-*.apk`

### Build EasyEUICC (Unprivileged)

```bash
./gradlew :app-unpriv:assembleRelease
```

**Output:** `app-unpriv/build/outputs/apk/release/EasyEUICC-*.apk`

### Build for AOSP

#### Method 1: Include in AOSP Tree

1. Add to `manifest.xml` with `sync-s="true"` for submodules
2. Include module: `PRODUCT_PACKAGES += OpenEUICC`
3. Build: `mm` in OpenEUICC directory

#### Method 2: Prebuilt APK

1. Build with Gradle
2. Import as prebuilt in AOSP
3. Include `privapp_whitelist_im.angry.openeuicc.xml`

## Installation

### OpenEUICC (System App)

**Requirements:**
- Root access or AOSP build integration
- System partition write access

**Methods:**
1. **Magisk Module:** Flash from CI artifacts
2. **Manual:** Copy to `/system/priv-app/OpenEUICC/`
3. **AOSP Build:** Include in system image

### EasyEUICC (User App)

**Requirements:**
- Android 9+ device
- Removable eSIM with correct ARA-M or USB reader

**Installation:**
1. Download APK from [releases](https://gitea.angry.im/PeterCxy/OpenEUICC/releases)
2. Install normally via APK installer
3. Grant USB permissions (if using USB reader)

## Usage Examples

### Example 1: Download Profile (Kotlin)

```kotlin
val lpa: LocalProfileAssistant = // ... obtained from EuiccChannel

// Download with activation code
lpa.downloadProfile(
    smdp = "smdp.example.com",
    matchingId = "MATCHING-ID-12345",
    imei = null,  // Optional
    confirmationCode = "1234",  // Optional
    callback = object : ProfileDownloadCallback {
        override fun onStateUpdate(state: String) {
            println("State: $state")
        }

        override fun onProgress(progress: Long, total: Long) {
            println("Progress: $progress/$total")
        }
    }
)
```

### Example 2: Enable Profile

```kotlin
val iccid = "89012345678901234567"
val success = lpa.enableProfile(iccid, refresh = true)

if (success) {
    println("Profile enabled successfully")
} else {
    println("Failed to enable profile")
}
```

### Example 3: List Profiles

```kotlin
val profiles: List<LocalProfileInfo> = lpa.profiles

for (profile in profiles) {
    println("ICCID: ${profile.iccid}")
    println("Name: ${profile.name}")
    println("Nickname: ${profile.nickName}")
    println("Provider: ${profile.providerName}")
    println("State: ${profile.state}")
    println("Class: ${profile.profileClass}")
    println("---")
}
```

### Example 4: Get eUICC Info

```kotlin
val eid = lpa.eID
println("EID: $eid")

val info = lpa.euiccInfo2
if (info != null) {
    println("SGP.22 Version: ${info.sgp22Version}")
    println("Firmware: ${info.euiccFirmwareVersion}")
    println("Free Memory: ${info.freeNonVolatileMemory} bytes")
}
```

## Key Features

### 1. Multi-Channel Support

OpenEUICC supports multiple eUICC channels simultaneously:
- Internal phone eSIM slots (1-2 slots)
- Removable eSIM cards
- USB CCID readers

### 2. Flexible APDU Access

**Privileged (OpenEUICC):**
- Direct TelephonyManager access
- Full control over internal eUICC

**Unprivileged (EasyEUICC):**
- OMAPI (Open Mobile API)
- Requires ARA-M allowlisting

**Universal:**
- USB CCID readers (no allowlisting needed)

### 3. Thread-Safe Operations

All lpac operations are synchronized using ReentrantLock to ensure thread safety since lpac's C code is not thread-safe.

### 4. Error Diagnostics

Comprehensive error capture:
- Last HTTP response/exception
- Last APDU response/exception
- LPA error codes with descriptions

### 5. Certificate Pinning

HTTP interface supports:
- Public key ID-based certificate validation
- Custom trust managers
- TLS certificate verification

## Known Limitations

### 1. Removable eSIM Support

- Not officially supported unless compatible with EasyEUICC
- Must follow SGP.22 standard (not guaranteed)
- DO NOT submit bug reports for non-functioning removable eSIMs

### 2. USB Reader Requirements

- Only `T=0` protocol readers supported
- Must use standard USB CCID protocol
- `T=1` and other protocols unsupported

### 3. System Integration

- Carrier Partner API not implemented
- Limited OS integration compared to native solutions

### 4. Platform Restrictions

- OpenEUICC: Android 11+ only (uses hidden APIs)
- EasyEUICC: Requires ARA-M allowlisting (except USB)

## Development Notes

### ARA-M Hash for EasyEUICC

For removable eSIM vendors to support EasyEUICC official builds:

**ARA-M Hash:** `2A2FA878BC7C3354C2CF82935A5945A3EDAE4AFA`

### Memory Management

Always ensure proper cleanup:

```kotlin
val lpa = LocalProfileAssistantImpl(...)
try {
    // Perform operations
} finally {
    lpa.close()  // Calls euiccFini() and destroyContext()
}
```

### JNI Linked List Traversal

lpac returns linked lists from C. Traverse carefully:

```kotlin
val head = LpacJni.someListFunction(handle)
var curr = head
try {
    while (curr != 0L) {
        // Process current node
        curr = LpacJni.someListNext(curr)
    }
} finally {
    LpacJni.someListFree(head)  // Always free!
}
```

### Interface Wrappers

Use wrapper pattern for diagnostics:

```kotlin
class ApduInterfaceWrapper(val apduInterface: ApduInterface) : ApduInterface by apduInterface {
    var lastApduResponse: ByteArray? = null
    var lastApduException: Exception? = null

    override fun transmit(handle: Int, tx: ByteArray): ByteArray =
        try {
            apduInterface.transmit(handle, tx).also {
                lastApduException = null
                lastApduResponse = it
            }
        } catch (e: Exception) {
            lastApduResponse = null
            lastApduException = e
            throw e
        }
}
```

## FAQs

**Q: Can I use OpenEUICC without root?**
A: No, OpenEUICC (privileged) requires system app installation. Use EasyEUICC instead.

**Q: Can EasyEUICC manage my phone's internal eSIM?**
A: No, EasyEUICC only works with allowlisted external eSIMs or USB readers.

**Q: Where can I get prebuilt APKs?**
A:
- OpenEUICC: Debug APKs and Magisk modules from [CI Actions](https://gitea.angry.im/PeterCxy/OpenEUICC/actions)
- EasyEUICC: Release APKs from [Releases](https://gitea.angry.im/PeterCxy/OpenEUICC/releases)

**Q: Are removable eSIMs a joke?**
A: No! Benefits include:
- Transfer profiles without carrier approval
- Use eSIM on unsupported devices (Wi-Fi hotspots, routers)
- Physical portability between devices

## Additional Resources

- **lpac Library:** https://github.com/estkme-group/lpac
- **SGP.22 Specification:** https://www.gsma.com/solutions-and-impact/technologies/esim/
- **USB CCID Protocol:** https://en.wikipedia.org/wiki/CCID_%28protocol%29
- **Android OMAPI:** https://source.android.com/devices/tech/config/omapi
- **Issue Tracker:** https://gitea.angry.im/PeterCxy/OpenEUICC/issues

## License

**OpenEUICC:** GPL-3.0 only (without "or later")
**lpac-jni:** LGPL-2.1

Any modification or derivative work MUST be released under the same license with source code available upon request.

---

**Last Updated:** 2025-10-23
