# AT Commands - KORE Wireless SuperSIM Guide

## Table of Contents
1. [Overview](#overview)
2. [AT Commands History](#at-commands-history)
3. [Command Syntax and Structure](#command-syntax-and-structure)
4. [Command Types](#command-types)
5. [Essential AT Commands](#essential-at-commands)
6. [KORE SuperSIM Configuration](#kore-supersim-configuration)
7. [Network Management](#network-management)
8. [SIM Card Operations](#sim-card-operations)
9. [Signal Quality and Diagnostics](#signal-quality-and-diagnostics)
10. [Response Formats](#response-formats)
11. [Interactive Modem Operations](#interactive-modem-operations)
12. [Terminal Access Methods](#terminal-access-methods)
13. [Practical Examples](#practical-examples)
14. [Troubleshooting](#troubleshooting)
15. [Best Practices](#best-practices)
16. [References](#references)

---

## Overview

**AT Commands** are text-based instructions used to control and configure cellular modems. They provide a standardized interface for:

- Modem configuration and settings
- Network connection establishment
- SIM card interaction (including KORE SuperSIM)
- Connection status monitoring
- Diagnostics and debugging
- SMS operations
- Data session management

**Key Features:**
- Universal compatibility across cellular modules
- Human-readable text format
- Scriptable and automatable
- Real-time configuration and status retrieval
- Standardized by ITU-T and 3GPP

**Use Cases:**
- IoT device provisioning
- Network diagnostics
- SIM card management
- Automated modem configuration
- Development and testing
- Remote device management

---

## AT Commands History

### Origin: Hayes Command Set

**AT Commands** were developed by **Dennis Hayes** in the early 1980s for dial-up modems.

**Etymology:**
- **AT** = "Attention"
- Commands literally mean "come to ATtention"
- Tells modem to listen for instructions

### Evolution Timeline

**1981** - Hayes introduces Smartmodem with AT command set
**1985** - Hayes command set becomes de facto standard
**1990s** - Extended to cellular modems (GSM/CDMA)
**2000s** - 3GPP standardization (TS 27.007, TS 27.005)
**2010s** - IoT and M2M adaptations
**Present** - Universal standard for cellular modules

### Modern Standards

**Standardized by:**
- **ITU-T V.250** - Serial asynchronous automatic dialing and control
- **3GPP TS 27.007** - AT command set for User Equipment (UE)
- **3GPP TS 27.005** - SMS commands
- **Manufacturer extensions** - Vendor-specific commands (Quectel, u-blox, Sierra, etc.)

---

## Command Syntax and Structure

### Basic Structure

**All AT commands follow this format:**

```
AT<COMMAND><SUFFIX><DATA><CR>
```

**Components:**

| Component | Description | Example |
|-----------|-------------|---------|
| `AT` | Attention prefix (mandatory) | `AT` |
| `<COMMAND>` | Command identifier | `+CGMI` |
| `<SUFFIX>` | Operation type | `?` or `=` |
| `<DATA>` | Parameters (optional) | `1,"IP","super"` |
| `<CR>` | Carriage return (0x0D) | `\r` |

### Complete Examples

```bash
# Read command (no parameters)
AT+CGMI<CR>

# Query command
AT+CPIN?<CR>

# Set command with parameters
AT+CGDCONT=1,"IP","super"<CR>

# Test command
AT+COPS=?<CR>
```

### Command Chaining

**Multiple commands can be executed in sequence:**

```bash
# Chain with semicolons
AT<CMD1>;<CMD2>;<CMD3><CR>

# Example - Get manufacturer, model, and serial
AT+CGMI;+CGMM;+CGSN<CR>
```

**Important rules:**
- Only ONE `AT` prefix per line
- Semicolons separate commands
- Commands processed sequentially
- Failure in one command stops chain

### Syntax Requirements

**Case sensitivity:**
```bash
AT+CGMI    # Correct (uppercase)
at+cgmi    # May work (some modems case-insensitive)
AT+cgmi    # Mixed case (not recommended)
```

**Line length:**
- Maximum: Typically **80 characters**
- Varies by modem manufacturer
- Long commands may need splitting

**Termination:**
```bash
# Required terminators
<CR>       # Carriage Return (0x0D) - mandatory
<LF>       # Line Feed (0x0A) - optional

# Common representations
\r         # Programming languages
\n         # Sometimes accepted
<Enter>    # Terminal applications
```

---

## Command Types

### 1. Read Commands

**Syntax:** `AT<COMMAND>?`

**Purpose:** Retrieve current configuration or status

**Examples:**

```bash
# Check SIM readiness
AT+CPIN?
Response: +CPIN: READY

# Check network registration
AT+CREG?
Response: +CREG: 0,1

# Check APN configuration
AT+CGDCONT?
Response: +CGDCONT: 1,"IP","super","0.0.0.0",0,0
```

**When to use:**
- Query current settings
- Check status
- Verify configuration
- Diagnostic purposes

### 2. Set Commands

**Syntax:** `AT<COMMAND>=<PARAMETERS>`

**Purpose:** Configure modem settings

**Examples:**

```bash
# Set APN
AT+CGDCONT=1,"IP","super"

# Enable extended error reporting
AT+CMEE=2

# Set network selection mode
AT+COPS=1,2,"310410"
```

**Parameter types:**
- **Integers**: `1`, `2`, `0`
- **Strings**: `"super"`, `"IP"`
- **Comma-separated**: `1,"IP","super"`

### 3. Execute Commands

**Syntax:** `AT<COMMAND>`

**Purpose:** Trigger an action without parameters

**Examples:**

```bash
# Get manufacturer
AT+CGMI

# Get signal quality
AT+CSQ

# Get IMSI
AT+CIMI

# Dial data connection
ATD*99#
```

**Characteristics:**
- No parameters
- Immediate action
- Returns result

### 4. Test Commands

**Syntax:** `AT<COMMAND>=?`

**Purpose:** Check command support and valid parameters

**Examples:**

```bash
# Test COPS command support
AT+COPS=?
Response: +COPS: (1,"Carrier1","Carrier1","310410",7),...

# Test CGDCONT parameters
AT+CGDCONT=?
Response: +CGDCONT: (1-16),"IP",,,(0,1),(0,1)
```

**Use cases:**
- Verify command availability
- Discover valid parameters
- Check modem capabilities
- Development and testing

---

## Essential AT Commands

### Modem Information Commands

**Get manufacturer:**
```bash
AT+CGMI
Response: Quectel
```

**Get model number:**
```bash
AT+CGMM
Response: EC25
```

**Get serial number (IMEI):**
```bash
AT+CGSN
Response: 866425030123456
```

**Get firmware version:**
```bash
ATI
Response:
Quectel
EC25
Revision: EC25EFAR06A02M4G
```

**Complete modem info:**
```bash
# Chain commands for full info
AT+CGMI;+CGMM;+CGSN;I

# Or query individually
echo -e "AT+CGMI\r" > /dev/ttyUSB2
echo -e "AT+CGMM\r" > /dev/ttyUSB2
echo -e "AT+CGSN\r" > /dev/ttyUSB2
```

### SIM Card Commands

**Check SIM status:**
```bash
AT+CPIN?

Responses:
+CPIN: READY              # SIM ready
+CPIN: SIM PIN            # PIN required
+CPIN: SIM PUK            # PUK required
+CPIN: SIM PIN2           # PIN2 required
```

**Get IMSI (International Mobile Subscriber Identity):**
```bash
AT+CIMI
Response: 310410123456789
```

**Get ICCID (SIM card number):**
```bash
AT+CCID
Response: +CCID: 89014103271234567890
```

**Unlock SIM with PIN:**
```bash
# Enter PIN
AT+CPIN="1234"

# Verify
AT+CPIN?
Response: +CPIN: READY
```

### Network Commands

**Check network registration:**
```bash
AT+CREG?

Responses:
+CREG: 0,1    # Registered, home network
+CREG: 0,5    # Registered, roaming
+CREG: 0,0    # Not registered, not searching
+CREG: 0,2    # Searching for network
```

**Get current network operator:**
```bash
AT+COPS?
Response: +COPS: 0,0,"AT&T",7
```

**Scan available networks:**
```bash
AT+COPS=?
Response:
+COPS: (1,"AT&T","AT&T","310410",7),
       (1,"T-Mobile","T-Mobile","310260",7),
       (1,"Verizon","Verizon","311480",7)

# Format: (status,"long name","short name","numeric ID",access tech)
# Status: 1=available, 2=current, 3=forbidden
```

**Manual network selection:**
```bash
# Select network by numeric ID
AT+COPS=1,2,"310410"

# Automatic selection
AT+COPS=0
```

### Signal Quality Commands

**Get signal strength:**
```bash
AT+CSQ
Response: +CSQ: 23,99

# Format: +CSQ: <rssi>,<ber>
# rssi: 0-31 (signal strength), 99=unknown
# ber: 0-7 (bit error rate), 99=unknown
```

**Signal strength conversion:**
```
RSSI Value → dBm
0 → -113 dBm or less
1 → -111 dBm
2-30 → -109 to -53 dBm (2 dBm steps)
31 → -51 dBm or greater
99 → Unknown
```

**Calculate signal quality:**
```bash
# Example: +CSQ: 23,99
# RSSI = 23
# dBm = -113 + (23 × 2) = -67 dBm
# Quality: Good signal
```

### APN Configuration Commands

**Read current APN:**
```bash
AT+CGDCONT?
Response: +CGDCONT: 1,"IP","super","0.0.0.0",0,0
```

**Set APN:**
```bash
# Basic syntax
AT+CGDCONT=<cid>,"<PDP_type>","<APN>"

# Example for KORE SuperSIM
AT+CGDCONT=1,"IP","super"

# With authentication
AT+CGDCONT=1,"IP","super.apn"
```

**Multiple PDP contexts:**
```bash
# Context 1
AT+CGDCONT=1,"IP","super"

# Context 2
AT+CGDCONT=2,"IP","iot.apn"

# Context 3
AT+CGDCONT=3,"IPV4V6","dual.apn"
```

---

## KORE SuperSIM Configuration

### About KORE SuperSIM

**KORE SuperSIM** is a multi-network SIM card that automatically selects the best available cellular network across multiple carriers worldwide.

**Key features:**
- Multi-carrier support
- Automatic network switching
- Global coverage
- Single APN: `super`
- Roaming enabled by default

### Basic SuperSIM Setup

**1. Confirm SIM readiness:**
```bash
AT+CPIN?
Response: +CPIN: READY
```

**2. Set APN to "super":**
```bash
AT+CGDCONT=1,"IP","super"
```

**3. Verify APN configuration:**
```bash
AT+CGDCONT?
Response: +CGDCONT: 1,"IP","super","0.0.0.0",0,0
```

**4. Enable roaming (if needed):**
```bash
# Quectel modems
AT+QCFG="roamservice",2

# u-blox modems
AT+UDCONF=20,1

# Generic (if supported)
AT+CROAMING=1
```

**5. Register to network:**
```bash
# Check registration
AT+CREG?

# If not registered, enable auto-registration
AT+COPS=0
```

### Quectel Modem Specific Configuration

**Enable roaming service:**
```bash
# Set roaming mode
AT+QCFG="roamservice",2

# Verify
AT+QCFG="roamservice"
Response: +QCFG: "roamservice",2

# Values:
# 0 = Roaming disabled
# 1 = Roaming enabled (roaming carrier only)
# 2 = Roaming enabled (all carriers)
```

**Configure network search mode:**
```bash
# Set to automatic (LTE/3G/2G)
AT+QCFG="nwscanmode",0

# LTE only
AT+QCFG="nwscanmode",3

# 3G only
AT+QCFG="nwscanmode",2
```

**Configure network selection priority:**
```bash
# Set priority: LTE > 3G > 2G
AT+QCFG="nwscanseq",020103

# Verify
AT+QCFG="nwscanseq"
```

### u-blox Modem Specific Configuration

**Enable roaming:**
```bash
# Set roaming configuration
AT+UDCONF=20,1

# Verify
AT+UDCONF=20
Response: +UDCONF: 20,1

# Values:
# 0 = Roaming disabled
# 1 = Roaming enabled
```

**Configure RAT (Radio Access Technology) priority:**
```bash
# Set to automatic
AT+URAT=9

# LTE only
AT+URAT=7

# 3G only
AT+URAT=2
```

### Complete SuperSIM Setup Script

**For Quectel modems:**
```bash
#!/bin/bash
# supersim-setup-quectel.sh

DEVICE="/dev/ttyUSB2"

echo "Configuring KORE SuperSIM on Quectel modem..."

# Function to send AT command
send_at() {
    echo -e "$1\r" > "$DEVICE"
    sleep 1
    cat "$DEVICE" &
    sleep 1
    killall cat 2>/dev/null
}

# Check SIM
echo "1. Checking SIM status..."
send_at "AT+CPIN?"

# Set APN
echo "2. Setting APN to 'super'..."
send_at 'AT+CGDCONT=1,"IP","super"'

# Enable roaming
echo "3. Enabling roaming..."
send_at 'AT+QCFG="roamservice",2'

# Set network mode
echo "4. Setting network mode to auto..."
send_at 'AT+QCFG="nwscanmode",0'

# Enable auto network selection
echo "5. Enabling automatic network selection..."
send_at "AT+COPS=0"

# Verify configuration
echo "6. Verifying configuration..."
send_at "AT+CGDCONT?"
send_at 'AT+QCFG="roamservice"'
send_at "AT+CREG?"

echo "SuperSIM configuration complete!"
```

**For u-blox modems:**
```bash
#!/bin/bash
# supersim-setup-ublox.sh

DEVICE="/dev/ttyUSB0"

echo "Configuring KORE SuperSIM on u-blox modem..."

# Function to send AT command
send_at() {
    echo -e "$1\r" > "$DEVICE"
    sleep 1
}

# Check SIM
echo "1. Checking SIM status..."
send_at "AT+CPIN?"

# Set APN
echo "2. Setting APN to 'super'..."
send_at 'AT+CGDCONT=1,"IP","super"'

# Enable roaming
echo "3. Enabling roaming..."
send_at "AT+UDCONF=20,1"

# Set network mode
echo "4. Setting RAT to auto..."
send_at "AT+URAT=9"

# Enable auto network selection
echo "5. Enabling automatic network selection..."
send_at "AT+COPS=0"

# Verify configuration
echo "6. Verifying configuration..."
send_at "AT+CGDCONT?"
send_at "AT+UDCONF=20"
send_at "AT+CREG?"

echo "SuperSIM configuration complete!"
```

---

## Network Management

### Registration Status

**Check registration status:**
```bash
AT+CREG?

# Response format: +CREG: <n>,<stat>[,<lac>,<ci>]
```

**Status codes:**
```
0 = Not registered, not searching
1 = Registered, home network
2 = Not registered, searching
3 = Registration denied
4 = Unknown
5 = Registered, roaming
```

**Enable unsolicited registration updates:**
```bash
# Enable with location info
AT+CREG=2

# Now modem sends updates automatically:
# +CREG: 5,"1A2B","01234567",7
```

### Network Selection

**Automatic selection (recommended):**
```bash
AT+COPS=0
```

**Manual selection:**
```bash
# By numeric ID
AT+COPS=1,2,"310410"

# By short name
AT+COPS=1,1,"ATT"

# By long name
AT+COPS=1,0,"AT&T"
```

**Deregister from network:**
```bash
AT+COPS=2
```

### Network Scanning

**Scan available networks:**
```bash
AT+COPS=?

# Example response:
+COPS: (1,"AT&T","ATT","310410",7),
       (1,"T-Mobile","TMO","310260",7),
       (3,"Verizon","VZW","311480",7)

# Format: (status,"long","short","numeric",tech)
```

**Access technology codes:**
```
0 = GSM
2 = UTRAN (3G)
3 = GSM with EDGE
4 = UTRAN with HSDPA
5 = UTRAN with HSUPA
6 = UTRAN with HSDPA and HSUPA
7 = E-UTRAN (LTE)
```

### Roaming Configuration

**Check roaming status:**
```bash
AT+CREG?
# Response: +CREG: 0,5  (5 = roaming)
```

**Enable/disable roaming:**
```bash
# Quectel
AT+QCFG="roamservice",2    # Enable
AT+QCFG="roamservice",0    # Disable

# u-blox
AT+UDCONF=20,1             # Enable
AT+UDCONF=20,0             # Disable
```

---

## SIM Card Operations

### PIN Management

**Check PIN status:**
```bash
AT+CPIN?

Responses:
READY              # No PIN required or already entered
SIM PIN            # PIN required
SIM PUK            # PUK required
SIM PIN2           # PIN2 required
```

**Enter PIN:**
```bash
AT+CPIN="1234"
Response: OK
```

**Change PIN:**
```bash
# Enable PIN lock first (if disabled)
AT+CLCK="SC",1,"1234"

# Change PIN
AT+CPWD="SC","1234","5678"

# Verify
AT+CPIN?
```

**Disable PIN requirement:**
```bash
AT+CLCK="SC",0,"1234"
```

**Enable PIN requirement:**
```bash
AT+CLCK="SC",1,"1234"
```

### SIM Information

**Get IMSI:**
```bash
AT+CIMI
Response: 310410123456789

# IMSI structure:
# 310-410-123456789
# MCC-MNC-MSIN
```

**Get ICCID:**
```bash
AT+CCID
Response: +CCID: 89014103271234567890

# Or
AT+QCCID  # Quectel
AT+CRSM=176,12258,0,0,10  # Low-level read
```

**Get SIM card manufacturer:**
```bash
AT+CGMI
```

### Advanced SIM Commands

**Read SIM file:**
```bash
# Generic command
AT+CRSM=<command>,<fileid>[,<P1>,<P2>,<P3>[,<data>]]

# Example: Read ICCID
AT+CRSM=176,12258,0,0,10
```

**Check SIM card capabilities:**
```bash
# Check if SIM supports LTE
AT+CRSM=176,28486,0,0,0
```

---

## Signal Quality and Diagnostics

### Signal Strength Measurement

**Basic signal quality:**
```bash
AT+CSQ
Response: +CSQ: 23,99
```

**Extended signal quality (if supported):**
```bash
AT+CESQ
Response: +CESQ: 99,99,255,255,20,50

# Format: <rxlev>,<ber>,<rscp>,<ecno>,<rsrq>,<rsrp>
```

**LTE signal quality (Quectel):**
```bash
AT+QENG="servingcell"
Response:
+QENG: "servingcell","NOCONN","LTE","FDD",310,410,1A2B,123,100,5,5,-67,-8,-45,15

# Includes: RSRP, RSRQ, SINR values
```

### Connection Diagnostics

**Check connection status:**
```bash
# PDP context status
AT+CGACT?
Response: +CGACT: 1,1

# IP address
AT+CGPADDR=1
Response: +CGPADDR: 1,"10.1.2.3"
```

**Get detailed network information:**
```bash
# Serving cell info
AT+QENG="servingcell"   # Quectel
AT+UCELLINFO=0         # u-blox

# Neighbor cells
AT+QENG="neighbourcell"  # Quectel
```

### Error Reporting

**Enable extended error codes:**
```bash
# Enable verbose errors
AT+CMEE=2

# Now errors show descriptive text:
+CME ERROR: SIM not inserted

# Instead of just:
ERROR
```

**Error levels:**
```bash
AT+CMEE=0    # Disable (only ERROR shown)
AT+CMEE=1    # Enable numeric codes (+CME ERROR: 10)
AT+CMEE=2    # Enable verbose text (+CME ERROR: SIM not inserted)
```

**Common error codes:**
```
0   = Phone failure
1   = No connection to phone
2   = Phone adapter link reserved
3   = Operation not allowed
4   = Operation not supported
10  = SIM not inserted
11  = SIM PIN required
12  = SIM PUK required
13  = SIM failure
14  = SIM busy
16  = Incorrect password
17  = SIM PIN2 required
18  = SIM PUK2 required
30  = No network service
31  = Network timeout
32  = Network not allowed
```

---

## Response Formats

### Success Responses

**OK response:**
```bash
AT+CGMI
Quectel
OK
```

**Response with data:**
```bash
AT+CSQ
+CSQ: 23,99

OK
```

**Multiple responses (chained commands):**
```bash
AT+CGMI;+CGMM;+CGSN

Quectel
OK

EC25
OK

866425030123456
OK
```

### Error Responses

**Basic error:**
```bash
AT+INVALID

ERROR
```

**Extended error (numeric):**
```bash
AT+CMEE=1
AT+CPIN?

+CME ERROR: 10
```

**Extended error (verbose):**
```bash
AT+CMEE=2
AT+CPIN?

+CME ERROR: SIM not inserted
```

### Unsolicited Result Codes

**Registration updates:**
```bash
# After AT+CREG=1
+CREG: 5    # Registered, roaming

# After AT+CREG=2
+CREG: 5,"1A2B","01234567",7
```

**Signal quality changes:**
```bash
+CSQ: 18,99
```

**Incoming call/SMS:**
```bash
RING

+CMTI: "SM",5    # New SMS at index 5
```

---

## Interactive Modem Operations

### Modem Data Prompts

When modems request data, they respond with `>` prompt.

**How to respond:**

1. **Send data** - Type/send the data
2. **Terminate with:**
   - `Ctrl-Z` (0x1A) - Send and execute
   - `ESC` (0x1B) - Cancel operation

### SMS Sending Example

**Send SMS workflow:**

```bash
# 1. Set SMS format to text mode
AT+CMGF=1
Response: OK

# 2. Initiate SMS send
AT+CMGS="1234567890"
Response: >

# 3. Type message
This is a test message

# 4. Send with Ctrl-Z (0x1A)
<Ctrl-Z>

# 5. Modem response
+CMGS: 123
OK
```

**In script form:**

```bash
#!/bin/bash
# send-sms.sh

DEVICE="/dev/ttyUSB2"
PHONE="1234567890"
MESSAGE="This is a test message"

# Set text mode
echo -e "AT+CMGF=1\r" > "$DEVICE"
sleep 1

# Initiate send
echo -e "AT+CMGS=\"$PHONE\"\r" > "$DEVICE"
sleep 1

# Send message with Ctrl-Z
echo -e "$MESSAGE\x1A" > "$DEVICE"
sleep 2

# Check response
cat "$DEVICE"
```

### Cancel Operation

**Cancel data entry:**

```bash
AT+CMGS="1234567890"
>
Test message
<ESC>    # Press Escape key (0x1B)

ERROR    # Operation cancelled
```

---

## Terminal Access Methods

### Linux - Using Minicom

**Install Minicom:**
```bash
sudo apt update
sudo apt install minicom
```

**Configure Minicom:**
```bash
# Run setup
sudo minicom -s

# Configure:
# - Serial Device: /dev/ttyUSB2
# - Baud Rate: 115200 (or modem default)
# - Hardware Flow Control: No
# - Software Flow Control: No
```

**Connect to modem:**
```bash
# Direct connection
sudo minicom -D /dev/ttyUSB2 -b 115200

# Or use configured profile
sudo minicom
```

**Minicom usage:**
```
Ctrl-A Z    # Help menu
Ctrl-A Q    # Quit
Ctrl-A E    # Enable local echo (see what you type)
Ctrl-A W    # Line wrap on/off
```

**Test commands:**
```bash
AT              # Should respond: OK
ATI             # Modem info
AT+CGMI         # Manufacturer
AT+CPIN?        # SIM status
```

### Linux - Using screen

**Connect with screen:**
```bash
# Install if needed
sudo apt install screen

# Connect
screen /dev/ttyUSB2 115200

# Enable echo for typing visibility
AT E1

# Exit screen
Ctrl-A K (then confirm with Y)
```

### Linux - Using cu

**Connect with cu:**
```bash
# Install if needed
sudo apt install cu

# Connect
sudo cu -l /dev/ttyUSB2 -s 115200

# Exit
~.
```

### Linux - Direct echo method

**Simple command sending:**
```bash
# Send single command
echo -e "AT+CGMI\r" > /dev/ttyUSB2

# Read response
cat /dev/ttyUSB2 &
sleep 1
killall cat

# Or combined
(echo -e "AT+CGMI\r" && sleep 1) | tee /dev/ttyUSB2 | cat /dev/ttyUSB2
```

### macOS - Using Minicom

**Install Minicom via Homebrew:**
```bash
# Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Minicom
brew install minicom
```

**Find device:**
```bash
# List USB devices
ls /dev/cu.*

# Common modem devices:
# /dev/cu.usbserial-*
# /dev/cu.SLAB_USBtoUART
```

**Connect:**
```bash
minicom -D /dev/cu.usbserial-XXXX -b 115200
```

### macOS - Using screen

```bash
# Find device
ls /dev/cu.*

# Connect
screen /dev/cu.usbserial-XXXX 115200

# Exit
Ctrl-A K (then Y)
```

### Windows - Using PuTTY

**Download PuTTY:**
- https://www.putty.org/

**Find COM port:**
```
1. Open Device Manager (devmgmt.msc)
2. Expand "Ports (COM & LPT)"
3. Find modem port (e.g., "Quectel USB AT Port (COM3)")
4. Note COM port number
```

**Configure PuTTY:**
```
1. Connection Type: Serial
2. Serial line: COM3 (your port)
3. Speed: 115200 (or modem default)
4. Open
```

**Settings:**
```
Connection → Serial:
- Speed: 115200
- Data bits: 8
- Stop bits: 1
- Parity: None
- Flow control: None
```

**Enable local echo:**
```
Terminal → Line discipline options:
- Force on: Local echo
- Force on: Local line editing
```

### Windows - Using TeraTerm

**Download TeraTerm:**
- https://ttssh2.osdn.jp/

**Connect:**
```
1. File → New Connection
2. Serial
3. Port: COM3
4. Baud rate: 115200
5. OK
```

**Configure:**
```
Setup → Terminal:
- Local echo: ON

Setup → Serial Port:
- Baud rate: 115200
- Data: 8 bit
- Parity: none
- Stop: 1 bit
- Flow control: none
```

---

## Practical Examples

### Complete Modem Information Gathering

**Script to collect all modem info:**

```bash
#!/bin/bash
# modem-info.sh - Collect comprehensive modem information

DEVICE="/dev/ttyUSB2"
OUTPUT="modem-info.txt"

echo "=== Modem Information Report ===" > "$OUTPUT"
echo "Generated: $(date)" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Function to send AT command and capture response
query_at() {
    local cmd="$1"
    local desc="$2"

    echo "[$desc]" >> "$OUTPUT"
    echo "Command: $cmd" >> "$OUTPUT"

    # Send command
    echo -e "$cmd\r" > "$DEVICE"
    sleep 1

    # Capture response
    timeout 2 cat "$DEVICE" >> "$OUTPUT" 2>/dev/null
    echo "" >> "$OUTPUT"
}

# Hardware info
query_at "AT+CGMI" "Manufacturer"
query_at "AT+CGMM" "Model"
query_at "AT+CGSN" "Serial Number (IMEI)"
query_at "ATI" "Firmware Version"

# SIM info
query_at "AT+CPIN?" "SIM Status"
query_at "AT+CIMI" "IMSI"
query_at "AT+CCID" "ICCID"

# Network info
query_at "AT+CREG?" "Network Registration"
query_at "AT+COPS?" "Current Operator"
query_at "AT+CSQ" "Signal Quality"

# Configuration
query_at "AT+CGDCONT?" "APN Configuration"

echo "Report saved to: $OUTPUT"
cat "$OUTPUT"
```

### Network Connection Establishment

**Complete connection script:**

```bash
#!/bin/bash
# connect-network.sh - Establish data connection

DEVICE="/dev/ttyUSB2"
APN="super"

echo "=== Establishing Network Connection ==="

# Function to send AT command
send_at() {
    echo -e "$1\r" > "$DEVICE"
    sleep 1
    cat "$DEVICE" &
    sleep 1
    killall cat 2>/dev/null
}

# 1. Check SIM
echo "1. Checking SIM status..."
send_at "AT+CPIN?"

# 2. Set APN
echo "2. Configuring APN: $APN"
send_at "AT+CGDCONT=1,\"IP\",\"$APN\""

# 3. Enable auto network selection
echo "3. Enabling automatic network selection..."
send_at "AT+COPS=0"

# 4. Wait for registration
echo "4. Waiting for network registration..."
for i in {1..30}; do
    reg=$(echo -e "AT+CREG?\r" | timeout 2 cat "$DEVICE" 2>/dev/null | grep "+CREG:")
    if echo "$reg" | grep -q "+CREG: 0,[15]"; then
        echo "   Registered to network!"
        break
    fi
    echo "   Attempt $i/30: Not registered yet..."
    sleep 2
done

# 5. Check signal
echo "5. Checking signal quality..."
send_at "AT+CSQ"

# 6. Activate PDP context
echo "6. Activating data connection..."
send_at "AT+CGACT=1,1"

# 7. Get IP address
echo "7. Getting IP address..."
send_at "AT+CGPADDR=1"

# 8. Verify connection
echo "8. Verifying connection..."
send_at "AT+CGACT?"

echo "=== Connection Established ==="
```

### Signal Monitoring Script

**Continuous signal monitoring:**

```bash
#!/bin/bash
# signal-monitor.sh - Monitor signal strength continuously

DEVICE="/dev/ttyUSB2"
INTERVAL=5  # seconds

echo "=== Signal Strength Monitor ==="
echo "Press Ctrl-C to stop"
echo ""

while true; do
    # Get signal quality
    csq=$(echo -e "AT+CSQ\r" > "$DEVICE" && sleep 1 && timeout 1 cat "$DEVICE" 2>/dev/null | grep "+CSQ:")

    if [ -n "$csq" ]; then
        # Extract RSSI value
        rssi=$(echo "$csq" | sed 's/+CSQ: \([0-9]*\),.*/\1/')

        # Convert to dBm
        if [ "$rssi" -eq 99 ]; then
            dbm="Unknown"
            quality="No signal"
        else
            dbm=$((rssi * 2 - 113))

            # Determine quality
            if [ $dbm -ge -70 ]; then
                quality="Excellent"
            elif [ $dbm -ge -85 ]; then
                quality="Good"
            elif [ $dbm -ge -100 ]; then
                quality="Fair"
            else
                quality="Poor"
            fi
        fi

        # Display
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] RSSI: $rssi | Signal: $dbm dBm | Quality: $quality"
    else
        echo "[$timestamp] Error reading signal"
    fi

    sleep $INTERVAL
done
```

### Profile Switching Script

**Switch between network profiles:**

```bash
#!/bin/bash
# profile-switch.sh - Switch between APN profiles

DEVICE="/dev/ttyUSB2"

# Define profiles
declare -A PROFILES
PROFILES=(
    ["supersim"]="super"
    ["carrier1"]="internet"
    ["carrier2"]="broadband"
    ["iot"]="iot.apn"
)

# Function to send AT command
send_at() {
    echo -e "$1\r" > "$DEVICE"
    sleep 1
}

# Function to list profiles
list_profiles() {
    echo "Available profiles:"
    for profile in "${!PROFILES[@]}"; do
        echo "  - $profile (APN: ${PROFILES[$profile]})"
    done
}

# Function to switch profile
switch_profile() {
    local profile_name="$1"
    local apn="${PROFILES[$profile_name]}"

    if [ -z "$apn" ]; then
        echo "Error: Profile '$profile_name' not found"
        list_profiles
        exit 1
    fi

    echo "Switching to profile: $profile_name"
    echo "APN: $apn"

    # Deactivate current connection
    echo "1. Deactivating current connection..."
    send_at "AT+CGACT=0,1"

    # Set new APN
    echo "2. Setting APN to: $apn"
    send_at "AT+CGDCONT=1,\"IP\",\"$apn\""

    # Reactivate connection
    echo "3. Activating connection..."
    send_at "AT+CGACT=1,1"

    # Verify
    echo "4. Verifying configuration..."
    send_at "AT+CGDCONT?"
    cat "$DEVICE" &
    sleep 2
    killall cat 2>/dev/null

    echo "Profile switched successfully!"
}

# Main
case "$1" in
    list)
        list_profiles
        ;;
    switch)
        if [ -z "$2" ]; then
            echo "Usage: $0 switch <profile_name>"
            list_profiles
            exit 1
        fi
        switch_profile "$2"
        ;;
    *)
        echo "Usage: $0 {list|switch <profile_name>}"
        exit 1
        ;;
esac
```

**Usage:**
```bash
chmod +x profile-switch.sh

# List available profiles
./profile-switch.sh list

# Switch to SuperSIM profile
./profile-switch.sh switch supersim
```

---

## Troubleshooting

### No Response from Modem

**Symptom:** AT commands don't produce any output

**Solutions:**

1. **Check device path:**
   ```bash
   # Linux - list USB devices
   ls -l /dev/ttyUSB*
   dmesg | grep tty

   # Correct device usually:
   # /dev/ttyUSB2 or /dev/ttyUSB3 (AT command port)
   ```

2. **Check baud rate:**
   ```bash
   # Common baud rates: 115200, 9600, 57600
   stty -F /dev/ttyUSB2 115200
   ```

3. **Check permissions:**
   ```bash
   # Add user to dialout group
   sudo usermod -aG dialout $USER
   # Log out and back in
   ```

4. **Stop ModemManager:**
   ```bash
   sudo systemctl stop ModemManager
   ```

### ERROR Response

**Symptom:** Commands return ERROR

**Solutions:**

1. **Enable verbose errors:**
   ```bash
   AT+CMEE=2
   # Now try command again for descriptive error
   ```

2. **Check command syntax:**
   ```bash
   # Test command support
   AT+COMMAND=?
   ```

3. **Verify modem state:**
   ```bash
   # Check if modem initialized
   AT
   ATI
   ```

### SIM Not Ready

**Symptom:** `+CME ERROR: SIM not inserted` or `+CPIN: SIM PIN`

**Solutions:**

1. **Check physical SIM:**
   - Reseat SIM card
   - Verify SIM orientation
   - Check for damage

2. **Enter PIN if required:**
   ```bash
   AT+CPIN?
   # If response: +CPIN: SIM PIN
   AT+CPIN="1234"
   ```

3. **Wait for initialization:**
   ```bash
   # SIM may need time after insertion
   for i in {1..10}; do
       echo -e "AT+CPIN?\r" > /dev/ttyUSB2
       sleep 2
   done
   ```

### Network Registration Failed

**Symptom:** `+CREG: 0,0` or `+CREG: 0,2` (not registered)

**Solutions:**

1. **Check signal:**
   ```bash
   AT+CSQ
   # RSSI should be > 10 for stable connection
   ```

2. **Check SIM activation:**
   - Verify SIM is activated with carrier
   - Check account status

3. **Enable roaming (for SuperSIM):**
   ```bash
   # Quectel
   AT+QCFG="roamservice",2

   # u-blox
   AT+UDCONF=20,1
   ```

4. **Manual network selection:**
   ```bash
   # Scan networks
   AT+COPS=?

   # Select manually
   AT+COPS=1,2,"310410"
   ```

### Connection Establishment Failed

**Symptom:** Cannot activate PDP context

**Solutions:**

1. **Verify APN:**
   ```bash
   AT+CGDCONT?
   # Check if APN is correct
   ```

2. **Reset modem:**
   ```bash
   AT+CFUN=1,1
   # Wait 30 seconds for reboot
   ```

3. **Check carrier compatibility:**
   - Verify SIM supports carrier
   - Check frequency bands

4. **Deactivate and reactivate:**
   ```bash
   AT+CGACT=0,1
   sleep 2
   AT+CGACT=1,1
   ```

### Weak Signal Issues

**Symptom:** Connection drops frequently, slow data

**Solutions:**

1. **Check signal strength:**
   ```bash
   AT+CSQ
   # RSSI < 10 is too weak
   ```

2. **Improve antenna:**
   - Use external antenna
   - Reposition modem/router
   - Move to window area

3. **Lock to better band:**
   ```bash
   # Quectel - lock to LTE band 4
   AT+QCFG="band",0,4,0
   ```

---

## Best Practices

### Script Development

**Always include:**

1. **Error handling:**
   ```bash
   send_at() {
       echo -e "$1\r" > "$DEVICE" || {
           echo "Error sending command"
           exit 1
       }
   }
   ```

2. **Timeouts:**
   ```bash
   response=$(timeout 5 cat "$DEVICE" 2>/dev/null)
   ```

3. **Verification:**
   ```bash
   # Verify each step
   if ! echo "$response" | grep -q "OK"; then
       echo "Command failed"
       exit 1
   fi
   ```

### Production Use

**Security:**
- Never hardcode PINs in scripts
- Use environment variables or secure storage
- Implement proper access controls

**Logging:**
```bash
# Log all commands and responses
AT_LOG="/var/log/at-commands.log"

send_at() {
    echo "[$(date)] CMD: $1" >> "$AT_LOG"
    echo -e "$1\r" > "$DEVICE"
    sleep 1
    response=$(cat "$DEVICE")
    echo "[$(date)] RSP: $response" >> "$AT_LOG"
}
```

**Monitoring:**
- Monitor registration status
- Log signal strength periodically
- Alert on connection failures

### Performance

**Optimization:**
- Use command chaining where possible
- Cache modem information
- Minimize AT command frequency
- Use unsolicited result codes instead of polling

**Example - efficient vs inefficient:**

```bash
# Inefficient - 3 separate commands
AT+CGMI
AT+CGMM
AT+CGSN

# Efficient - single chained command
AT+CGMI;+CGMM;+CGSN
```

---

## References

### Standards Documents

**ITU-T:**
- V.250 - Serial asynchronous automatic dialing and control

**3GPP:**
- TS 27.007 - AT command set for User Equipment (UE)
- TS 27.005 - Use of Data Terminal Equipment - Data Circuit terminating Equipment (DTE-DCE) interface for Short Message Service (SMS)
- TS 27.010 - Terminal Equipment to Terminal Adapter (TE-TA) multiplexer protocol

### Manufacturer Documentation

**Quectel:**
- AT Commands Manual: Available from Quectel support
- Product documentation: https://www.quectel.com/

**u-blox:**
- AT Commands Manual: Available from u-blox
- Product documentation: https://www.u-blox.com/

**Sierra Wireless:**
- AT Command Reference: Available from Sierra Wireless
- Product documentation: https://www.sierrawireless.com/

### KORE Wireless Resources

**Official Documentation:**
- KORE SuperSIM: https://docs.korewireless.com/
- Support Portal: https://support.korewireless.com/

**Related Guides:**
- SuperSIM Getting Started
- Network Configuration
- Troubleshooting Guide

### Tools and Utilities

**Terminal Programs:**
- Minicom: https://salsa.debian.org/minicom-team/minicom
- PuTTY: https://www.putty.org/
- TeraTerm: https://ttssh2.osdn.jp/

**Testing Tools:**
- AT Command Tester: Various open-source projects on GitHub
- ModemManager: https://www.freedesktop.org/wiki/Software/ModemManager/

---

## Summary

AT Commands provide a powerful, standardized interface for cellular modem control and configuration.

**Key Concepts:**
- ✅ Commands follow `AT<COMMAND><SUFFIX><DATA><CR>` format
- ✅ Four types: Read (?), Set (=), Execute (none), Test (=?)
- ✅ Responses: OK, ERROR, +CME ERROR
- ✅ Enable verbose errors with `AT+CMEE=2`

**KORE SuperSIM Setup:**
```bash
AT+CGDCONT=1,"IP","super"         # Set APN
AT+QCFG="roamservice",2           # Enable roaming (Quectel)
AT+COPS=0                          # Auto network selection
```

**Essential Commands:**
```bash
AT+CPIN?           # Check SIM status
AT+CREG?           # Check registration
AT+CSQ             # Check signal
AT+COPS?           # Check operator
AT+CGDCONT?        # Check APN
```

**Troubleshooting:**
- Enable `AT+CMEE=2` for detailed errors
- Check permissions: Add user to `dialout` group
- Stop ModemManager if conflicts occur
- Use correct device path (/dev/ttyUSB2 for AT commands)

**Best Practices:**
- Always verify command success
- Implement error handling in scripts
- Use command chaining for efficiency
- Log commands for debugging
- Secure sensitive data (PINs, activation codes)

AT Commands enable complete control of cellular connectivity for IoT devices, development, and production deployments.

---

*This guide is based on KORE Wireless documentation and industry-standard AT command specifications.*
