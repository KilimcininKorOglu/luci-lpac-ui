# AT Commands Comprehensive Guide for Cellular Modems and IoT Devices

## Table of Contents
1. [Overview](#overview)
2. [History and Background](#history-and-background)
3. [AT Command Syntax](#at-command-syntax)
4. [Command Types and Suffixes](#command-types-and-suffixes)
5. [Response Codes](#response-codes)
6. [Standard AT Commands](#standard-at-commands)
7. [Network Registration Commands](#network-registration-commands)
8. [Data Connection Setup](#data-connection-setup)
9. [PPP Connection Procedure](#ppp-connection-procedure)
10. [Modem Information Commands](#modem-information-commands)
11. [SMS Commands](#sms-commands)
12. [SIMCom Specific Commands](#simcom-specific-commands)
13. [Quectel Specific Commands](#quectel-specific-commands)
14. [Debugging and Diagnostics](#debugging-and-diagnostics)
15. [Best Practices](#best-practices)
16. [Common Use Cases](#common-use-cases)
17. [Troubleshooting](#troubleshooting)
18. [References](#references)

---

## Overview

AT commands (Attention commands) are text-based instructions used to control and configure cellular modems. They provide a standardized interface for modem communication, enabling tasks such as:

- Network registration and connection
- Data transmission (TCP/UDP)
- SMS sending and receiving
- Modem configuration
- Diagnostics and monitoring
- GPS/location services (on supported modems)

**Key Applications:**
- IoT device connectivity
- M2M (Machine-to-Machine) communication
- Remote monitoring systems
- Cellular router configuration
- Modem testing and diagnostics

**Compatibility:**
AT commands work across various cellular technologies:
- 2G (GSM/GPRS)
- 3G (UMTS/HSPA)
- 4G (LTE)
- 5G (NR)
- NB-IoT / LTE-M

---

## History and Background

### Origins

**Hayes Smartmodem (1981):**
- Dennis Hayes invented AT commands for dial-up modems
- "AT" = "Attention" (get modem's attention)
- Originally for telephone line modems
- Became industry standard

**Evolution:**
- 1990s: Adapted for cellular modems (GSM)
- 2000s: Extended for 3G/4G technologies
- 2010s: Refined for IoT applications (NB-IoT, LTE-M)
- Present: Standardized by ITU-T and 3GPP

### Standardization Bodies

**ITU-T V.250:**
- International Telecommunication Union standard
- Defines basic AT command set
- Last updated: 2003
- Stable, widely supported

**3GPP TS 27.007:**
- 3rd Generation Partnership Project
- Mobile Equipment (ME) control commands
- Regularly updated for new technologies

**3GPP TS 27.005:**
- SMS-specific AT commands
- Text and PDU modes

**Manufacturer Extensions:**
- Each modem manufacturer adds proprietary commands
- Examples: Quectel (AT+Q...), SIMCom (AT+C...), u-blox (AT+U...)

---

## AT Command Syntax

### Basic Structure

```
AT<COMMAND><SUFFIX><PARAMETERS>
```

**Components:**

1. **AT Prefix:**
   - Always starts with "AT" (case-insensitive)
   - "Attention" signal to modem

2. **Command:**
   - Basic commands: Single character (e.g., `D` for dial)
   - Extended commands: Start with `+` (e.g., `+CREG`)

3. **Suffix:**
   - Defines command operation type
   - See [Command Types](#command-types-and-suffixes)

4. **Parameters:**
   - Command-specific arguments
   - Separated by commas
   - Strings may need quotes

5. **Line Terminator:**
   - Carriage Return (CR, `\r`, `0x0D`)
   - Required to execute command

### Examples

**Basic command:**
```
AT<CR>
```
Test modem responsiveness.

**Extended command with parameters:**
```
AT+CGDCONT=1,"IP","internet"<CR>
```
Set PDP context #1 to IP type with APN "internet".

**Query command:**
```
AT+CREG?<CR>
```
Query network registration status.

**Test command:**
```
AT+CREG=?<CR>
```
Show supported parameters for CREG command.

### Command Chaining

Multiple commands can be sent on one line using semicolon (`;`):

```
AT+CREG?;+CGREG?<CR>
```

**Rules:**
- First command includes "AT" prefix
- Subsequent commands omit "AT" but keep `+`
- Separated by semicolons
- All execute in sequence

---

## Command Types and Suffixes

### Suffix Types

| Suffix | Type | Purpose | Example |
|--------|------|---------|---------|
| (none) | Execute | Perform action | `ATD*99#` (dial) |
| `=<value>` | Set | Set parameter value | `AT+CREG=1` |
| `?` | Read | Get current setting | `AT+CREG?` |
| `=?` | Test | Query supported values | `AT+CREG=?` |

### Detailed Examples

**1. Execute Command:**
```
ATD*99#
```
- No suffix
- Immediate action
- Establishes data call

**2. Set Command:**
```
AT+CREG=2
```
- Sets unsolicited result code mode to 2
- Changes modem behavior

**3. Read Command:**
```
AT+CREG?
```
- Queries current CREG setting
- Response: `+CREG: 2,5`

**4. Test Command:**
```
AT+CREG=?
```
- Shows supported values
- Response: `+CREG: (0-2)`

---

## Response Codes

### Success Responses

**OK:**
```
AT
OK
```
- Command executed successfully
- Standard success response

**CONNECT:**
```
ATD*99#
CONNECT
```
- Data connection established
- Modem enters data mode

### Error Responses

**ERROR:**
```
AT+INVALID
ERROR
```
- Generic error
- Command failed or invalid

**+CME ERROR:**
```
AT+CPIN?
+CME ERROR: 10
```
- Mobile Equipment error
- Numeric code indicates error type
- Enable verbose: `AT+CMEE=2`

**+CMS ERROR:**
```
AT+CMGS="1234"
+CMS ERROR: 500
```
- SMS-related error
- Numeric error code

**ABORTED:**
```
AT+COPS=?
ABORTED
```
- Command interrupted or timed out

### Error Code Tables

**Common CME Errors:**

| Code | Description |
|------|-------------|
| 0 | Phone failure |
| 3 | Operation not allowed |
| 4 | Operation not supported |
| 10 | SIM not inserted |
| 11 | SIM PIN required |
| 13 | SIM failure |
| 30 | No network service |
| 100 | Unknown error |

**Common CMS Errors:**

| Code | Description |
|------|-------------|
| 300 | ME failure |
| 500 | Unknown error |
| 513 | Invalid length |

### Verbose Error Mode

**Enable detailed error messages:**
```
AT+CMEE=2
```

**Modes:**
- `0` - Disable (numeric codes only)
- `1` - Enable numeric codes
- `2` - Enable verbose (text) descriptions

**Example:**
```
AT+CMEE=2
OK

AT+CPIN?
+CME ERROR: SIM not inserted
```

---

## Standard AT Commands

### Basic Commands

**AT - Test Command:**
```
AT
OK
```
- Verify modem responds
- Basic connectivity test

**ATZ - Reset:**
```
ATZ
OK
```
- Soft reset to user profile
- Does not factory reset

**AT&F - Factory Reset:**
```
AT&F
OK
```
- Reset to factory defaults
- Clears custom configuration

**AT&W - Save Configuration:**
```
AT&W
OK
```
- Save current settings to profile
- Persists across reboots

**ATE - Echo Mode:**
```
ATE0    # Disable echo
ATE1    # Enable echo
```
- Controls command echoing
- Useful for scripting (disable echo)

**AT+CFUN - Functionality Level:**
```
AT+CFUN=<fun>[,<rst>]
```

**Modes:**
- `0` - Minimum functionality (offline)
- `1` - Full functionality
- `4` - Airplane mode (disable RF)

**Example:**
```
AT+CFUN=1,1    # Full functionality with reset
```

---

## Network Registration Commands

### AT+COPS - Operator Selection

**Purpose:** Select and register on cellular network operator.

**Syntax:**
```
AT+COPS=[<mode>[,<format>[,<oper>[,<AcT>]]]]
```

**Parameters:**
- `<mode>`:
  - `0` - Automatic (default)
  - `1` - Manual
  - `2` - Deregister
  - `3` - Set format only
  - `4` - Manual/automatic
- `<format>`:
  - `0` - Long alphanumeric (e.g., "T-Mobile")
  - `1` - Short alphanumeric (e.g., "TMO")
  - `2` - Numeric (e.g., "310260")
- `<oper>`: Operator identifier
- `<AcT>`: Access technology
  - `0` - GSM
  - `2` - UTRAN
  - `7` - E-UTRAN (LTE)

**Examples:**

**Query current operator:**
```
AT+COPS?
+COPS: 0,0,"T-Mobile",7
OK
```

**Scan available operators:**
```
AT+COPS=?
+COPS: (2,"T-Mobile","TMO","310260",7),(1,"AT&T","ATT","310410",7)
OK
```

**Set automatic mode:**
```
AT+COPS=0
OK
```

**Manual selection:**
```
AT+COPS=1,2,"310260"
OK
```

### AT+CREG - Network Registration (2G/3G)

**Purpose:** Query and control network registration status.

**Syntax:**
```
AT+CREG=[<n>]
```

**Modes (`<n>`):**
- `0` - Disable unsolicited result codes (default)
- `1` - Enable network registration codes
- `2` - Enable network registration and location codes

**Query status:**
```
AT+CREG?
+CREG: 2,5,"1A2B","01234567",7
OK
```

**Response fields:**
- Field 1: Mode setting (0-2)
- Field 2: Registration status:
  - `0` - Not registered, not searching
  - `1` - Registered, home network
  - `2` - Not registered, searching
  - `3` - Registration denied
  - `4` - Unknown
  - `5` - Registered, roaming
- Field 3: Location Area Code (LAC) - hex
- Field 4: Cell ID - hex
- Field 5: Access Technology (0=GSM, 2=UTRAN, 7=LTE)

**Enable notifications:**
```
AT+CREG=2
OK

+CREG: 5,"1A2B","01234567",7    # Unsolicited notification when registered
```

### AT+CGREG - Packet Switched Registration

**Purpose:** GPRS/data network registration status (identical to CREG but for packet-switched).

**Syntax:**
```
AT+CGREG=[<n>]
```

**Same parameters as AT+CREG**

**Example:**
```
AT+CGREG?
+CGREG: 2,5,"1A2B","01234567",7
OK
```

### AT+CEREG - EPS Network Registration (LTE+)

**Purpose:** LTE/5G network registration status.

**Syntax:**
```
AT+CEREG=[<n>]
```

**Extended status values:**
- Same as CREG (0-5)
- Plus additional LTE-specific states

**Example:**
```
AT+CEREG?
+CEREG: 2,5,"1A2B","01234567",7,"1"
OK
```

**Best Practice:**
Enable all three for comprehensive status:
```
AT+CREG=2;+CGREG=2;+CEREG=2
```

---

## Data Connection Setup

### AT+CGDCONT - Define PDP Context

**Purpose:** Configure Packet Data Protocol context for data connections.

**Syntax:**
```
AT+CGDCONT=<cid>,<PDP_type>,<APN>[,<PDP_addr>[,<d_comp>[,<h_comp>]]]
```

**Parameters:**
- `<cid>`: Context Identifier (1-16, typically use 1)
- `<PDP_type>`:
  - `"IP"` - IPv4 (most common)
  - `"IPV6"` - IPv6
  - `"IPV4V6"` - Dual stack
  - `"PPP"` - Point-to-Point Protocol
  - `"Non-IP"` - NB-IoT non-IP
- `<APN>`: Access Point Name (carrier-specific)

**Examples:**

**Set APN for data:**
```
AT+CGDCONT=1,"IP","internet"
OK
```

**Multiple contexts:**
```
AT+CGDCONT=1,"IP","internet"
AT+CGDCONT=2,"IP","ims"
```

**Query current contexts:**
```
AT+CGDCONT?
+CGDCONT: 1,"IP","internet","0.0.0.0",0,0
+CGDCONT: 2,"IP","ims","0.0.0.0",0,0
OK
```

**Delete context:**
```
AT+CGDCONT=1
OK
```

### AT+CGACT - Activate/Deactivate PDP Context

**Purpose:** Activate or deactivate data connection.

**Syntax:**
```
AT+CGACT=<state>[,<cid>]
```

**Parameters:**
- `<state>`:
  - `0` - Deactivate
  - `1` - Activate
- `<cid>`: Context ID (optional, defaults to all)

**Examples:**

**Activate context 1:**
```
AT+CGACT=1,1
OK
```

**Deactivate context 1:**
```
AT+CGACT=0,1
OK
```

**Query activation status:**
```
AT+CGACT?
+CGACT: 1,1
+CGACT: 2,0
OK
```

### AT+CGATT - GPRS Attach/Detach

**Purpose:** Attach or detach from packet domain service.

**Syntax:**
```
AT+CGATT=<state>
```

**Parameters:**
- `<state>`:
  - `0` - Detach
  - `1` - Attach

**Example:**
```
AT+CGATT=1
OK
```

**Query status:**
```
AT+CGATT?
+CGATT: 1
OK
```

**Note:** Usually automatic when using `AT+CGACT=1`.

### Complete Data Connection Sequence

**Step-by-step procedure:**

```bash
# 1. Check modem responds
AT
OK

# 2. Set automatic operator selection
AT+COPS=0
OK

# 3. Wait for network registration
# Check until registered (status 1 or 5)
AT+CREG?
+CREG: 0,5    # 5 = registered, roaming
OK

# 4. Define PDP context with APN
AT+CGDCONT=1,"IP","your-apn-here"
OK

# 5. Activate PDP context
AT+CGACT=1,1
OK

# 6. Verify packet-switched registration
AT+CGREG?
+CGREG: 0,5
OK

# 7. Check IP address assigned (Quectel example)
AT+CGPADDR=1
+CGPADDR: 1,"10.123.45.67"
OK
```

---

## PPP Connection Procedure

**Point-to-Point Protocol for data connections:**

### Step-by-Step PPP Setup

```bash
# 1. Register on network
AT+COPS=0
OK

# 2. Wait for circuit-switched registration
AT+CREG?
+CREG: 0,5
OK

# 3. Wait for EPS registration (LTE)
AT+CEREG?
+CEREG: 0,5
OK

# 4. Define PDP context
AT+CGDCONT=1,"IP","internet"
OK

# 5. Activate PDP context
AT+CGACT=1,1
OK

# 6. Dial to establish PPP connection
ATD*99#
CONNECT

# 7. PPP negotiation starts
# Modem enters data mode
# Serial port now carries PPP frames
```

**After `CONNECT`:**
- Modem switches to data mode
- AT commands no longer work
- PPP daemon (pppd) handles protocol
- To exit: Send `+++` (escape sequence)

### PPP on Linux/OpenWRT

**Using pppd:**

```bash
# /etc/ppp/peers/mobile
/dev/ttyUSB3 115200
connect "/usr/sbin/chat -v -f /etc/ppp/chat/mobile"
noauth
defaultroute
usepeerdns
persist
```

**Chat script (`/etc/ppp/chat/mobile`):**

```
ABORT "NO CARRIER"
ABORT "ERROR"
"" AT
OK AT+CGDCONT=1,"IP","internet"
OK ATD*99#
CONNECT ""
```

**Start PPP:**
```bash
pppd call mobile
```

---

## Modem Information Commands

### Reset and Configuration

**ATZ - Soft Reset:**
```
ATZ
OK
```
Reset to saved user profile.

**AT&F - Factory Reset:**
```
AT&F
OK
```
Reset all settings to factory defaults.

**AT&W - Save Settings:**
```
AT&W
OK
```
Save current configuration.

### Modem Identification

**ATI - Modem Information:**
```
ATI
Quectel
EC25
Revision: EC25EFAR06A08M4G
OK
```

**AT+GMI - Manufacturer:**
```
AT+GMI
Quectel
OK
```

**AT+GMM - Model:**
```
AT+GMM
EC25
OK
```

**AT+GMR - Revision:**
```
AT+GMR
EC25EFAR06A08M4G
OK
```

**AT+CGMR - Firmware Version:**
```
AT+CGMR
EC25EFAR06A08M4G
OK
```

### SIM and Device Identifiers

**AT+CIMI - IMSI:**
```
AT+CIMI
310260123456789
OK
```
International Mobile Subscriber Identity (15 digits).

**AT+CGSN - IMEI:**
```
AT+CGSN
123456789012345
OK
```
International Mobile Equipment Identity (15 digits).

**AT+CCID - ICCID:**
```
AT+CCID
+CCID: 8901260123456789012
OK
```
Integrated Circuit Card ID (SIM card serial number, 19-20 digits).

**AT+CNUM - Phone Number:**
```
AT+CNUM
+CNUM: "","1234567890",129
OK
```
Subscriber number (may be empty if not programmed).

### Signal Quality

**AT+CSQ - Signal Quality:**
```
AT+CSQ
+CSQ: 25,99
OK
```

**Response fields:**
- Field 1: RSSI (Received Signal Strength Indication)
  - 0-31: Signal strength (-113 dBm to -51 dBm)
  - 99: Not known or not detectable
  - Formula: dBm = -113 + (RSSI × 2)
- Field 2: Bit Error Rate
  - 0-7: BER values
  - 99: Not known

**Example calculation:**
- RSSI = 25
- dBm = -113 + (25 × 2) = -63 dBm (good signal)

---

## SMS Commands

### SMS Mode Configuration

**AT+CMGF - Message Format:**
```
AT+CMGF=<mode>
```

**Modes:**
- `0` - PDU mode (binary format, supports all features)
- `1` - Text mode (easier for ASCII text)

**Set text mode:**
```
AT+CMGF=1
OK
```

### Send SMS (Text Mode)

**AT+CMGS - Send Message:**
```
AT+CMGS="<recipient_number>"
> <message_text><Ctrl+Z>
```

**Example:**
```
AT+CMGF=1
OK

AT+CMGS="1234567890"
> Hello from modem!
+CMGS: 12
OK
```

**Response:**
- `+CMGS: 12` - Message reference number
- `OK` - Successfully sent

**Cancel sending:**
- Send `ESC` (0x1B) instead of Ctrl+Z

### Read SMS

**AT+CMGL - List Messages:**
```
AT+CMGL="<status>"
```

**Status values:**
- `"REC UNREAD"` - Received unread
- `"REC READ"` - Received read
- `"STO UNSENT"` - Stored unsent
- `"STO SENT"` - Stored sent
- `"ALL"` - All messages

**Example:**
```
AT+CMGL="ALL"
+CMGL: 1,"REC READ","1234567890",,"23/10/15,14:30:00+00"
Hello world!
OK
```

**AT+CMGR - Read Message:**
```
AT+CMGR=<index>
```

**Example:**
```
AT+CMGR=1
+CMGR: "REC READ","1234567890",,"23/10/15,14:30:00+00"
Test message
OK
```

### Delete SMS

**AT+CMGD - Delete Message:**
```
AT+CMGD=<index>[,<delflag>]
```

**Delete flags:**
- `0` - Delete message at <index>
- `1` - Delete all read messages
- `2` - Delete all read and sent messages
- `3` - Delete all read, sent, and unsent messages
- `4` - Delete all messages

**Example:**
```
AT+CMGD=1
OK
```

### SMS Service Center

**AT+CSCA - Service Center Address:**
```
AT+CSCA="+1234567890"
OK
```

**Query current:**
```
AT+CSCA?
+CSCA: "+1234567890",145
OK
```

---

## SIMCom Specific Commands

### Data Connection (SIMCom)

**AT+CSTT - Start Task:**
```
AT+CSTT="<apn>"[,"<user>","<password>"]
```

**Example:**
```
AT+CSTT="internet"
OK
```

**AT+CIICR - Bring Up Connection:**
```
AT+CIICR
OK
```

**AT+CIFSR - Get IP Address:**
```
AT+CIFSR
10.123.45.67
```

**Complete sequence:**
```
AT+CSTT="internet"
OK
AT+CIICR
OK
AT+CIFSR
10.123.45.67
```

### Ping (SIMCom)

**AT+CIPPING - Ping Command:**
```
AT+CIPPING=<host>[,<retryNum>[,<dataLen>[,<timeout>[,<ttl>]]]]
```

**Parameters:**
- `<host>`: IP address (xxx.xxx.xxx.xxx) or domain name
- `<retryNum>`: 1-100 (default: 4)
- `<dataLen>`: 0-1024 bytes (default: 32)
- `<timeout>`: 1-600 units of 100ms (default: 100 = 10s)
- `<ttl>`: 1-255 (default: 64)

**Example:**
```
AT+CIPPING="8.8.8.8",4,32,100,64
+CIPPING: 1,8.8.8.8,32,100,255
+CIPPING: 2,8.8.8.8,32,95,255
+CIPPING: 3,8.8.8.8,32,98,255
+CIPPING: 4,8.8.8.8,32,102,255
OK
```

### TCP/UDP Communication (SIMCom)

**AT+CIPMODE - Transfer Mode:**
```
AT+CIPMODE=<mode>
```
- `0` - Non-transparent mode (command mode)
- `1` - Transparent mode (data mode)

**AT+CIPSTART - Start Connection:**
```
AT+CIPSTART=[<n>,]<mode>,<host>,<port>
```

**Parameters:**
- `<n>`: Connection number (0-5 for multi-connection)
- `<mode>`: "TCP" or "UDP"
- `<host>`: IP address or domain name
- `<port>`: Remote port (0-65535)

**Example - TCP connection:**
```
AT+CIPSTART="TCP","example.com",80
OK
CONNECT OK
```

**AT+CIPSEND - Send Data:**
```
AT+CIPSEND
> GET / HTTP/1.1
> Host: example.com
>
[Ctrl+Z]

SEND OK

HTTP/1.1 200 OK
...
```

**AT+CIPCLOSE - Close Connection:**
```
AT+CIPCLOSE
CLOSE OK
```

**AT+CIPSHUT - Deactivate Connection:**
```
AT+CIPSHUT
SHUT OK
```

### TCP Server (SIMCom)

**AT+CIPSERVER - Set TCP Server:**
```
AT+CIPSERVER=<mode>[,<port>]
```

**Parameters:**
- `<mode>`:
  - `0` - Close server
  - `1` - Open server
- `<port>`: Local port (default: 80)

**Example:**
```
AT+CIPSERVER=1,8080
OK
```

---

## Quectel Specific Commands

### Ping (Quectel)

**AT+QPING - Ping Command:**
```
AT+QPING=<contextID>,<host>[,<timeout>[,<pingnum>]]
```

**Parameters:**
- `<contextID>`: 1-16 (PDP context ID)
- `<host>`: Domain name or IP address
- `<timeout>`: 1-255 seconds (default: 4)
- `<pingnum>`: 1-10 pings (default: 4)

**Example:**
```
AT+QPING=1,"google.com",4,4
OK

+QPING: 0,"google.com",32,52,255
+QPING: 0,"google.com",32,48,255
+QPING: 0,"google.com",32,50,255
+QPING: 0,"google.com",32,51,255

+QPING: 0,4,4,0,50,48,52
```

**Response fields:**
- Result code (0=success)
- Host
- Bytes sent
- Reply time (ms)
- TTL

**Final statistics:**
- Result, sent, received, lost, min, avg, max

### Socket Service (Quectel)

**AT+QIOPEN - Open Socket:**
```
AT+QIOPEN=<contextID>,<connectID>,<service_type>,<IP_address>/<domain_name>,<remote_port>[,<local_port>[,<access_mode>]]
```

**Parameters:**
- `<contextID>`: 1-16
- `<connectID>`: 0-11 (socket index)
- `<service_type>`: "TCP", "UDP", "TCP LISTENER", "UDP SERVICE"
- `<IP_address>/<domain_name>`: Server address
- `<remote_port>`: 0-65535
- `<local_port>`: Local port (0=automatic)
- `<access_mode>`: 0=buffer, 1=direct push, 2=transparent

**Example - TCP client:**
```
AT+QIOPEN=1,0,"TCP","example.com",80,0,0
OK

+QIOPEN: 0,0
```

**AT+QISEND - Send Data:**
```
AT+QISEND=<connectID>[,<send_length>]
```

**Example:**
```
AT+QISEND=0
> GET / HTTP/1.1
> Host: example.com
>
[Ctrl+Z]

SEND OK
```

**AT+QIRD - Retrieve Data:**
```
AT+QIRD=<connectID>[,<read_length>]
```

**Parameters:**
- `<connectID>`: 0-11
- `<read_length>`: 0-1500 bytes (0=all available)

**Example:**
```
AT+QIRD=0,1500
+QIRD: 327
HTTP/1.1 200 OK
Content-Type: text/html
...

OK
```

**AT+QICLOSE - Close Socket:**
```
AT+QICLOSE=<connectID>[,<timeout>]
```

**Example:**
```
AT+QICLOSE=0
OK
```

### File System (Quectel)

**AT+QFLST - List Files:**
```
AT+QFLST="*"
+QFLST: "file1.txt",100
+QFLST: "file2.bin",2048
OK
```

**AT+QFUPL - Upload File:**
```
AT+QFUPL="filename.txt",<size>,<timeout>
CONNECT
<binary data>
OK
```

**AT+QFDWL - Download File:**
```
AT+QFDWL="filename.txt"
CONNECT
<binary data>
OK
```

**AT+QFDEL - Delete File:**
```
AT+QFDEL="filename.txt"
OK
```

---

## Debugging and Diagnostics

### Enable Verbose Errors

**AT+CMEE - Report Mobile Equipment Errors:**
```
AT+CMEE=<n>
```

**Modes:**
- `0` - Disable (default, shows "ERROR")
- `1` - Enable numeric codes (e.g., "+CME ERROR: 10")
- `2` - Enable verbose (e.g., "+CME ERROR: SIM not inserted")

**Example:**
```
AT+CMEE=2
OK

AT+CPIN?
+CME ERROR: SIM not inserted
```

### Signal Quality Monitoring

**AT+CSQ - Signal Strength:**
```
AT+CSQ
+CSQ: 25,99
OK
```

**Interpretation:**
- 0-9: Marginal
- 10-14: OK
- 15-19: Good
- 20-30: Excellent
- 31: Maximum
- 99: Unknown

### Network Information

**AT+COPS - Current Operator:**
```
AT+COPS?
+COPS: 0,0,"T-Mobile USA",7
OK
```

**AT+CPSI - System Information (Quectel):**
```
AT+CPSI?
+CPSI: LTE,Online,310-260,0x1A2B,12345678,100,EUTRAN-BAND12,5230,3,3,-105,-10,-72,12
OK
```

Provides detailed cell information.

### Connection Status

**Check registration status:**
```
AT+CREG?;+CGREG?;+CEREG?
+CREG: 2,5,"1A2B","01234567",7
+CGREG: 2,5,"1A2B","01234567",7
+CEREG: 2,5,"1A2B","01234567",7
OK
```

All showing `5` = registered, roaming.

### Data Connection Verification

**AT+CGACT - Check PDP activation:**
```
AT+CGACT?
+CGACT: 1,1
OK
```

**AT+CGPADDR - Get IP address:**
```
AT+CGPADDR=1
+CGPADDR: 1,"10.123.45.67"
OK
```

### Timing and Buffering

**Best practices (per u-blox recommendations):**
- Wait 20ms between commands
- Flush serial buffer before sending new command
- Wait for response before next command

**Example script:**
```bash
#!/bin/bash
send_at() {
    echo -e "$1\r" > /dev/ttyUSB2
    sleep 0.02  # 20ms delay
    timeout 5 cat /dev/ttyUSB2
}

send_at "AT"
send_at "AT+CREG?"
send_at "AT+CSQ"
```

---

## Best Practices

### 1. Always Check Registration

```bash
# Before attempting data connection
AT+CREG?
# Wait for response showing 1 or 5
```

### 2. Enable Error Reporting

```bash
# First command after modem init
AT+CMEE=2
```

### 3. Set Proper APN

```bash
# Use correct APN for your carrier
AT+CGDCONT=1,"IP","carrier-apn"
```

### 4. Handle Unsolicited Result Codes

```bash
# Enable registration notifications
AT+CREG=2
AT+CGREG=2
AT+CEREG=2

# Your application should handle:
# +CREG: 5
# +CGREG: 5
# etc.
```

### 5. Implement Retry Logic

```bash
#!/bin/bash
retry_count=0
max_retries=3

while [ $retry_count -lt $max_retries ]; do
    result=$(send_at "AT+CGACT=1,1")
    if echo "$result" | grep -q "OK"; then
        echo "Success"
        break
    fi
    retry_count=$((retry_count + 1))
    sleep 5
done
```

### 6. Graceful Shutdown

```bash
# Before powering off modem
AT+CGACT=0,1  # Deactivate PDP
AT+CFUN=0     # Minimum functionality
# Wait 1-2 seconds
# Then cut power
```

### 7. Timeout Handling

- Always set timeouts for AT commands
- Typical timeout: 5-30 seconds
- `AT+COPS=?` may take 60+ seconds

### 8. Buffer Management

- Flush input buffer before sending command
- Read all output including unsolicited codes
- Use line-oriented reading

---

## Common Use Cases

### Use Case 1: Basic Internet Connection

```bash
# Complete sequence
AT                          # Test
AT+CFUN=1                  # Full functionality
AT+COPS=0                  # Automatic operator
# Wait for registration
AT+CREG?                   # Check registration
AT+CGDCONT=1,"IP","internet"  # Set APN
AT+CGACT=1,1              # Activate
ATD*99#                    # Start PPP
# PPP daemon takes over
```

### Use Case 2: Send SMS Alert

```bash
AT+CMGF=1                  # Text mode
AT+CMGS="1234567890"       # Send to number
> Alert: Temperature exceeded threshold!
<Ctrl+Z>
# Wait for +CMGS response
```

### Use Case 3: HTTP Request (Quectel)

```bash
AT+QHTTPCFG="contextid",1
AT+QHTTPCFG="requestheader",1
AT+QHTTPURL=23,30          # URL length, timeout
> http://example.com/api
AT+QHTTPGET=30            # GET with 30s timeout
# Wait for +QHTTPGET response
AT+QHTTPREAD=30           # Read response
```

### Use Case 4: GPS Location (if supported)

```bash
AT+QGPS=1                 # Start GPS
# Wait for fix
AT+QGPSLOC=2              # Get location
+QGPSLOC: 123456.000,37.7749,-122.4194,1.2,62.5,3,0.0,0.0,0.0,150323,08
```

### Use Case 5: Firmware Update Check

```bash
AT+CGMR                   # Current firmware
AT+QFOTADL="http://example.com/firmware.bin"  # Download (Quectel)
# Modem downloads and updates
```

---

## Troubleshooting

### Problem: No Response to AT Commands

**Symptoms:**
- Commands return nothing
- Modem appears dead

**Solutions:**

1. **Check serial connection:**
   ```bash
   ls -l /dev/ttyUSB*
   # Verify device exists
   ```

2. **Check baud rate:**
   ```bash
   # Common rates: 9600, 19200, 38400, 115200
   # Try auto-detection or set manually
   ```

3. **Enable echo (if disabled):**
   ```
   ATE1
   ```

4. **Hardware reset:**
   - Power cycle modem
   - Check power supply (sufficient current)

### Problem: Registration Fails

**Symptoms:**
- `AT+CREG?` shows 0,0 or 0,2
- Cannot connect to network

**Solutions:**

1. **Check SIM card:**
   ```bash
   AT+CPIN?
   +CPIN: READY  # Should be READY
   ```

2. **Check signal:**
   ```bash
   AT+CSQ
   +CSQ: 99,99  # 99 = no signal
   ```
   - Move to location with better coverage
   - Check antenna connection

3. **Manual operator selection:**
   ```bash
   AT+COPS=?  # Scan operators
   AT+COPS=1,2,"310260"  # Select manually
   ```

4. **Check SIM status:**
   ```bash
   AT+CCID  # Should return ICCID
   AT+CIMI  # Should return IMSI
   ```

### Problem: Data Connection Fails

**Symptoms:**
- `AT+CGACT=1,1` returns ERROR
- Cannot get IP address

**Solutions:**

1. **Verify registration:**
   ```bash
   AT+CGREG?
   # Must show 1 or 5
   ```

2. **Check APN:**
   ```bash
   AT+CGDCONT?
   # Verify APN is correct for carrier
   ```

3. **Check PDP activation:**
   ```bash
   AT+CGACT?
   +CGACT: 1,0  # 0 = not activated
   ```

4. **Re-configure:**
   ```bash
   AT+CGACT=0,1        # Deactivate
   AT+CGDCONT=1,"IP","correct-apn"
   AT+CGACT=1,1        # Re-activate
   ```

### Problem: Frequent Disconnections

**Symptoms:**
- Connection drops randomly
- Unsolicited `NO CARRIER` messages

**Solutions:**

1. **Check signal stability:**
   ```bash
   # Monitor signal over time
   while true; do
     AT+CSQ
     sleep 5
   done
   ```

2. **Increase minimum signal threshold:**
   - Move to better location
   - Use external antenna

3. **Check for network issues:**
   - Carrier network congestion
   - Tower maintenance

### Problem: SMS Not Sending

**Symptoms:**
- `AT+CMGS` returns +CMS ERROR

**Solutions:**

1. **Set SMS center:**
   ```bash
   AT+CSCA="+1234567890"  # Carrier's SMSC number
   ```

2. **Check text mode:**
   ```bash
   AT+CMGF=1  # Ensure text mode
   ```

3. **Verify network registration:**
   ```bash
   AT+CREG?  # Must be registered
   ```

4. **Check SIM SMS capability:**
   ```bash
   AT+CPMS?  # Check SMS storage
   ```

---

## References

### Standards and Specifications

**ITU-T V.250:**
- AT command set for DCE control
- URL: https://www.itu.int/rec/T-REC-V.250/

**3GPP TS 27.007:**
- Mobile equipment AT command set
- URL: https://www.3gpp.org/DynaReport/27007.htm

**3GPP TS 27.005:**
- AT command set for SMS
- URL: https://www.3gpp.org/DynaReport/27005.htm

### Manufacturer Documentation

**Quectel:**
- AT Commands Manual: Available from Quectel support
- Product page: https://www.quectel.com/

**SIMCom:**
- AT Command Manual: Available from SIMCom
- Product page: https://www.simcom.com/

**u-blox:**
- AT Commands Manual: Available from u-blox
- Product page: https://www.u-blox.com/

### Community Resources

**Original Article:**
- Onomondo AT Commands Guide: https://onomondo.com/blog/at-commands-guide-for-iot-devices/

**Forums:**
- OpenWRT Forum: https://forum.openwrt.org/
- Quectel Forums: https://forums.quectel.com/

---

## Summary

AT commands provide a standardized interface for controlling cellular modems:

**Essential Commands:**
- `AT` - Test communication
- `AT+COPS=0` - Register on network
- `AT+CREG?` - Check registration
- `AT+CGDCONT=1,"IP","apn"` - Set APN
- `AT+CGACT=1,1` - Activate data
- `AT+CMGS` - Send SMS
- `AT+CSQ` - Check signal

**Best Practices:**
- Enable error reporting (`AT+CMEE=2`)
- Check registration before data connection
- Use correct APN for carrier
- Implement retry logic
- Handle unsolicited result codes
- Wait between commands (20ms recommended)

**Common Sequence for Data:**
```
AT → AT+COPS=0 → Wait for CREG → AT+CGDCONT → AT+CGACT → ATD*99#
```

AT commands remain the fundamental interface for cellular modem control across 2G/3G/4G/5G technologies, providing consistent, text-based control for IoT and M2M applications.

---

*This guide is based on industry standards (ITU-T V.250, 3GPP TS 27.007/27.005) and manufacturer-specific documentation from Quectel, SIMCom, and u-blox.*
