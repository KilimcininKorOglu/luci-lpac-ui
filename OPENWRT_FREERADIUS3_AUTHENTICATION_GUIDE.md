# OpenWRT FreeRADIUS3 Authentication Guide

## Table of Contents
1. [Overview](#overview)
2. [RADIUS Authentication Concepts](#radius-authentication-concepts)
3. [System Requirements](#system-requirements)
4. [Installation](#installation)
5. [Basic Configuration](#basic-configuration)
6. [Certificate Management](#certificate-management)
7. [User Management](#user-management)
8. [WiFi Access Point Configuration](#wifi-access-point-configuration)
9. [Client Device Setup](#client-device-setup)
10. [Testing and Debugging](#testing-and-debugging)
11. [Advanced Configuration](#advanced-configuration)
12. [Security Hardening](#security-hardening)
13. [Troubleshooting](#troubleshooting)
14. [Performance and Scaling](#performance-and-scaling)

---

## Overview

FreeRADIUS is an open-source RADIUS (Remote Authentication Dial-In User Service) server that provides centralized authentication, authorization, and accounting (AAA) for network access.

### What is RADIUS?

RADIUS is a networking protocol that provides:
- **Authentication**: Verify user credentials
- **Authorization**: Grant or deny network access
- **Accounting**: Track usage and session data

### Why Use FreeRADIUS on OpenWRT?

**Benefits:**
- ✅ **WPA2/WPA3 Enterprise**: Secure WiFi with per-user credentials
- ✅ **Centralized Authentication**: Single user database for all access points
- ✅ **Better Security**: Individual passwords instead of shared PSK
- ✅ **User Accountability**: Track which user accessed when
- ✅ **Easy User Management**: Add/remove users without changing WiFi password
- ✅ **VPN Integration**: Authenticate VPN connections
- ✅ **802.1X Support**: Wired network authentication

**Use Cases:**
- Small office/enterprise WiFi
- Guest network with individual credentials
- Multi-AP deployments with centralized auth
- VPN authentication backend
- Hotspot with user tracking

### WPA2 Personal vs WPA2 Enterprise

| Feature | WPA2 Personal (PSK) | WPA2 Enterprise (RADIUS) |
|---------|-------------------|------------------------|
| Authentication | Shared password | Individual username/password |
| User Management | Change WiFi password | Add/remove users in RADIUS |
| Security | All users share same key | Each user has unique credentials |
| Accountability | No user tracking | Full user session logging |
| Complexity | Simple | Moderate to complex |
| Best For | Home networks | Business/organizations |

---

## RADIUS Authentication Concepts

### RADIUS Protocol

**Communication Flow:**
```
[Client Device] → [Access Point] → [RADIUS Server] → [User Database]
                       ↓
                 [Grant/Deny Access]
```

**Components:**
1. **RADIUS Client**: Access point or NAS (Network Access Server)
2. **RADIUS Server**: FreeRADIUS on OpenWRT
3. **User Database**: Files, LDAP, SQL, etc.

### EAP Methods

**EAP (Extensible Authentication Protocol)** provides framework for authentication.

**Common EAP Methods:**

| EAP Method | Security | Certificate Required | Use Case |
|------------|----------|---------------------|----------|
| **EAP-TLS** | Highest | Server + Client | Maximum security |
| **EAP-TTLS** | High | Server only | Good balance |
| **PEAP** | High | Server only | Most common |
| **EAP-MD5** | Low | None | Not recommended |

**PEAP (Protected EAP):**
- Most widely supported
- Requires server certificate
- Client uses username/password
- Creates encrypted tunnel for auth
- **Recommended for most deployments**

**EAP-TTLS:**
- Similar to PEAP
- More flexible
- Supports various inner auth methods
- Good alternative to PEAP

**EAP-TLS:**
- Strongest security
- Requires client certificates
- More complex deployment
- Best for high-security environments

### RADIUS Ports

- **Port 1812**: Authentication (UDP)
- **Port 1813**: Accounting (UDP)
- **Legacy Port 1645**: Old authentication port
- **Legacy Port 1646**: Old accounting port

---

## System Requirements

### Hardware Requirements

**Minimum:**
- 64MB RAM (128MB recommended)
- 16MB Flash + external storage
- 400MHz CPU

**Recommended:**
- 128MB+ RAM
- 32MB Flash or external storage
- 600MHz+ CPU

### Storage Requirements

- FreeRADIUS3 core: ~500KB
- FreeRADIUS3 modules: ~2-5MB
- Certificates: ~10KB
- Logs: 1-10MB+ (depending on usage)

**Total:** 5-10MB for complete installation

### OpenWRT Version

- OpenWRT 19.07+ (Chaos Calmer)
- OpenWRT 21.02+ recommended
- OpenWRT 22.03 or 23.05 (latest)

---

## Installation

### Step 1: Update Package List

```bash
opkg update
```

### Step 2: Install FreeRADIUS3

**Basic installation:**

```bash
# Install FreeRADIUS3 core
opkg install freeradius3

# Install demo certificates (for testing)
opkg install freeradius3-democerts

# Install common modules
opkg install freeradius3-mod-always
opkg install freeradius3-mod-attr-filter
opkg install freeradius3-mod-chap
opkg install freeradius3-mod-detail
opkg install freeradius3-mod-eap
opkg install freeradius3-mod-eap-gtc
opkg install freeradius3-mod-eap-md5
opkg install freeradius3-mod-eap-mschapv2
opkg install freeradius3-mod-eap-peap
opkg install freeradius3-mod-eap-tls
opkg install freeradius3-mod-eap-ttls
opkg install freeradius3-mod-exec
opkg install freeradius3-mod-expiration
opkg install freeradius3-mod-expr
opkg install freeradius3-mod-files
opkg install freeradius3-mod-logintime
opkg install freeradius3-mod-mschap
opkg install freeradius3-mod-pap
opkg install freeradius3-mod-preprocess
opkg install freeradius3-mod-radutmp
opkg install freeradius3-mod-realm
opkg install freeradius3-mod-unix

# Install utilities for testing
opkg install freeradius3-utils
```

**Quick install (all common modules):**

```bash
opkg install freeradius3 freeradius3-democerts freeradius3-common freeradius3-utils
```

### Step 3: Verify Installation

```bash
# Check installed packages
opkg list-installed | grep freeradius

# Check FreeRADIUS version
radiusd -v

# Output example:
# radiusd: FreeRADIUS Version 3.0.25
```

### Step 4: Check Configuration Directory

```bash
ls -la /etc/freeradius3/
# Should contain:
# - radiusd.conf (main config)
# - clients.conf (RADIUS clients)
# - users (user database)
# - mods-enabled/ (enabled modules)
# - sites-enabled/ (enabled sites)
# - certs/ (certificates)
```

---

## Basic Configuration

### Configure RADIUS Clients

**RADIUS clients** are access points or devices that connect to FreeRADIUS.

Edit `/etc/freeradius3/clients.conf`:

```conf
# Client definition for localhost (testing)
client localhost {
    ipaddr = 127.0.0.1
    secret = testing123
    require_message_authenticator = no
    nas_type = other
}

# Client definition for your access point
client openwrt-ap {
    # IP address of your access point
    ipaddr = 192.168.1.1

    # Shared secret (change this!)
    secret = SuperSecretKey123!

    # Require message authenticator for security
    require_message_authenticator = yes

    # NAS type
    nas_type = other

    # Optional: Friendly name
    shortname = main-ap
}

# Client definition for network range (multiple APs)
client lan-network {
    # Allow entire subnet
    ipaddr = 192.168.1.0/24

    # Shared secret (same for all APs in range)
    secret = AnotherSecretKey456!

    require_message_authenticator = yes
}
```

**Important settings:**
- **ipaddr**: IP address of access point or client
- **secret**: Shared secret key (must match on AP)
- **require_message_authenticator**: Set to `yes` for security

**⚠️ Change default secret!** Never use `testing123` in production.

### Configure Listening Interfaces

Edit `/etc/freeradius3/radiusd.conf`:

Find the `listen` section and configure:

```conf
# Listen on all interfaces
listen {
    type = auth
    ipaddr = *
    port = 1812
}

# Accounting
listen {
    type = acct
    ipaddr = *
    port = 1813
}

# Or listen only on LAN interface
listen {
    type = auth
    ipaddr = 192.168.1.1
    port = 1812
}
```

### Enable Required Modules

Check `/etc/freeradius3/mods-enabled/`:

```bash
ls -la /etc/freeradius3/mods-enabled/

# Required modules (should be symlinks):
# - eap
# - files
# - mschap
# - pap
# - preprocess
```

If missing, create symlinks:

```bash
cd /etc/freeradius3/mods-enabled/
ln -s ../mods-available/eap eap
ln -s ../mods-available/files files
ln -s ../mods-available/mschap mschap
ln -s ../mods-available/pap pap
```

### Configure EAP Module

Edit `/etc/freeradius3/mods-available/eap`:

```conf
eap {
    # Default EAP type
    default_eap_type = peap

    # Timer settings
    timer_expire = 60
    ignore_unknown_eap_types = no
    cisco_accounting_username_bug = no
    max_sessions = 4096

    # TLS configuration
    tls-config tls-common {
        private_key_password = whatever
        private_key_file = ${certdir}/server.key
        certificate_file = ${certdir}/server.pem
        ca_file = ${cadir}/ca.pem
        dh_file = ${certdir}/dh
        ca_path = ${cadir}
        cipher_list = "HIGH"
        cipher_server_preference = no
        tls_min_version = "1.2"
        tls_max_version = "1.3"
    }

    # PEAP configuration (most common)
    peap {
        tls = tls-common
        default_eap_type = mschapv2
        copy_request_to_tunnel = no
        use_tunneled_reply = no
    }

    # TTLS configuration
    ttls {
        tls = tls-common
        default_eap_type = mschapv2
        copy_request_to_tunnel = no
        use_tunneled_reply = no
    }

    # TLS configuration (requires client certificates)
    tls {
        tls = tls-common
    }

    # MD5 (not recommended - insecure)
    md5 {
    }

    # MSCHAPv2 (used inside PEAP/TTLS)
    mschapv2 {
    }
}
```

---

## Certificate Management

### Using Demo Certificates (Testing Only)

Demo certificates are installed with `freeradius3-democerts`:

```bash
ls -la /etc/freeradius3/certs/

# Demo certificates:
# - ca.pem (CA certificate)
# - server.pem (server certificate)
# - server.key (server private key)
```

**⚠️ WARNING**: Demo certificates are **insecure** and should only be used for testing!

### Generate Production Certificates

**Method 1: Using FreeRADIUS cert generation script**

```bash
cd /etc/freeradius3/certs

# Edit certificate parameters
vi ca.cnf
# Change: countryName, stateOrProvinceName, localityName, organizationName

vi server.cnf
# Change: countryName, stateOrProvinceName, localityName, organizationName
# Change: commonName to your server hostname

# Generate CA certificate
make ca.pem

# Generate server certificate
make server.pem

# Generate DH parameters (takes time!)
make dh
```

**Method 2: Using OpenSSL directly**

```bash
cd /etc/freeradius3/certs

# Generate CA private key
openssl genrsa -out ca.key 4096

# Generate CA certificate
openssl req -new -x509 -days 3650 -key ca.key -out ca.pem \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=RADIUS-CA"

# Generate server private key
openssl genrsa -out server.key 4096

# Generate server CSR
openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=radius.example.com"

# Sign server certificate with CA
openssl x509 -req -days 365 -in server.csr -CA ca.pem -CAkey ca.key \
  -CAcreateserial -out server.pem

# Generate DH parameters
openssl dhparam -out dh 2048

# Set permissions
chmod 640 *.key *.pem
chown root:radiusd *.key *.pem
```

### Install Certificates

```bash
# Verify certificates
openssl x509 -in /etc/freeradius3/certs/server.pem -text -noout

# Check server certificate
openssl verify -CAfile /etc/freeradius3/certs/ca.pem \
  /etc/freeradius3/certs/server.pem

# Should output: server.pem: OK
```

### Distribute CA Certificate to Clients

Clients need the CA certificate to trust your RADIUS server:

```bash
# Copy CA certificate for distribution
cp /etc/freeradius3/certs/ca.pem /www/ca.crt

# Make accessible via web
# Download from: http://192.168.1.1/ca.crt
```

---

## User Management

### File-Based Users

Edit `/etc/freeradius3/mods-config/files/authorize`:

```conf
# User format:
# username Cleartext-Password := "password"

# Example users
john Cleartext-Password := "SecurePass123!"
jane Cleartext-Password := "AnotherPass456!"
guest Cleartext-Password := "GuestPassword789!"

# User with VLAN assignment
alice Cleartext-Password := "AlicePass!"
      Tunnel-Type = VLAN,
      Tunnel-Medium-Type = IEEE-802,
      Tunnel-Private-Group-Id = 100

# User with bandwidth limit
bob Cleartext-Password := "BobPass!"
    WISPr-Bandwidth-Max-Down = 10000000,
    WISPr-Bandwidth-Max-Up = 5000000

# User with session timeout (1 hour = 3600 seconds)
charlie Cleartext-Password := "CharliePass!"
        Session-Timeout = 3600

# User with expiration date
dave Cleartext-Password := "DavePass!"
     Expiration := "Dec 31 2024"

# Disabled user (prefix with #)
# olduser Cleartext-Password := "OldPass!"
```

**Password encryption options:**

```conf
# Cleartext (readable, works with all EAP methods)
user1 Cleartext-Password := "password1"

# MD5 hash (more secure storage)
user2 MD5-Password := "5f4dcc3b5aa765d61d8327deb882cf99"

# SHA1 hash
user3 SHA1-Password := "5baa61e4c9b93f3f0682250b6cf8331b7ee68fd8"

# Crypt (Unix password hash)
user4 Crypt-Password := "$1$XXXXXX$YYYYYYYYYYYYYYYYYYYY"

# NT-Password (for MS-CHAP)
user5 NT-Password := "8846F7EAEE8FB117AD06BDD830B7586C"
```

**Generate password hashes:**

```bash
# MD5
echo -n "password" | md5sum

# SHA1
echo -n "password" | sha1sum

# Crypt
echo "password" | mkpasswd -m sha-512

# NT-Password (for Windows clients)
echo -n "password" | iconv -t utf16le | openssl md4
```

### Check User File Syntax

```bash
# Test user file for errors
radiusd -C

# Should output: Configuration appears to be OK
```

---

## WiFi Access Point Configuration

### Step 1: Install Full wpad

**WPA2 Enterprise requires full wpad, not wpad-mini:**

```bash
# Remove wpad-mini
opkg remove wpad-mini

# Install full wpad
opkg install wpad

# Or install wpad-openssl (includes OpenSSL support)
opkg install wpad-openssl

# Reboot recommended
reboot
```

### Step 2: Configure WiFi for WPA2 Enterprise

Edit `/etc/config/wireless`:

```bash
# Edit wireless configuration
uci set wireless.@wifi-iface[0].encryption='wpa2'
uci set wireless.@wifi-iface[0].server='127.0.0.1'  # RADIUS server IP
uci set wireless.@wifi-iface[0].port='1812'
uci set wireless.@wifi-iface[0].key='SuperSecretKey123!'  # Shared secret

# Alternative manual edit:
vi /etc/config/wireless
```

**Configuration example:**

```conf
config wifi-iface
    option device 'radio0'
    option network 'lan'
    option mode 'ap'
    option ssid 'Enterprise-WiFi'

    # WPA2 Enterprise settings
    option encryption 'wpa2'

    # RADIUS server settings
    option server '127.0.0.1'     # IP of RADIUS server (localhost if on same device)
    option port '1812'             # RADIUS authentication port
    option key 'SuperSecretKey123!'  # Shared secret (must match clients.conf)

    # Optional: Accounting
    option acct_server '127.0.0.1'
    option acct_port '1813'
    option acct_secret 'SuperSecretKey123!'

    # Optional: Dynamic VLAN assignment
    option dynamic_vlan '1'
```

**WPA2+WPA3 Enterprise (modern):**

```conf
config wifi-iface
    option device 'radio0'
    option network 'lan'
    option mode 'ap'
    option ssid 'Enterprise-WiFi'

    # WPA2+WPA3 Enterprise
    option encryption 'wpa2+wpa3'
    option ieee80211w '1'  # Management frame protection (required for WPA3)

    option server '127.0.0.1'
    option port '1812'
    option key 'SuperSecretKey123!'
```

### Step 3: Restart WiFi

```bash
# Commit changes
uci commit wireless

# Restart WiFi
wifi reload

# Or restart network
/etc/init.d/network restart
```

### Separate RADIUS Server Configuration

If RADIUS server is on different device:

```conf
config wifi-iface
    option device 'radio0'
    option network 'lan'
    option mode 'ap'
    option ssid 'Enterprise-WiFi'
    option encryption 'wpa2'

    # Remote RADIUS server
    option server '192.168.1.10'  # IP of RADIUS server
    option port '1812'
    option key 'SuperSecretKey123!'
```

**Firewall rules (if needed):**

```bash
# Allow RADIUS traffic from AP to RADIUS server
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-RADIUS-Auth'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest_ip='192.168.1.10'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='1812 1813'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart
```

---

## Client Device Setup

### Windows 10/11

1. **Connect to WiFi network**
2. **Enter credentials when prompted:**
   - Select network: `Enterprise-WiFi`
   - Click "Connect"

3. **Security settings:**
   - Click "Connect using a security key instead" (if shown)
   - Choose "Use my user account"

4. **Enter credentials:**
   - Username: `john`
   - Password: `SecurePass123!`

5. **Certificate warning:**
   - Click "Connect" (if certificate not trusted)
   - Or import CA certificate first (better security)

**Import CA certificate (recommended):**

1. Download `ca.crt` from router
2. Double-click certificate file
3. Click "Install Certificate"
4. Store Location: "Current User"
5. Certificate Store: "Trusted Root Certification Authorities"
6. Click "Finish"

### macOS

1. **Connect to network:**
   - Select WiFi: `Enterprise-WiFi`

2. **Authentication:**
   - Mode: Automatic
   - Username: `john`
   - Password: `SecurePass123!`

3. **Certificate:**
   - Click "Continue" (if warned about certificate)
   - Or add CA certificate to Keychain first

**Import CA certificate:**

1. Download `ca.crt`
2. Open Keychain Access
3. File → Import Items → Select `ca.crt`
4. Certificate → Trust → "Always Trust"

### Linux (NetworkManager)

**GUI Method:**

1. Right-click WiFi icon → Edit Connections
2. Add → Wi-Fi
3. **General:**
   - SSID: `Enterprise-WiFi`
4. **Wi-Fi Security:**
   - Security: WPA & WPA2 Enterprise
   - Authentication: Protected EAP (PEAP)
   - Anonymous identity: (leave empty)
   - CA certificate: `/path/to/ca.pem`
   - PEAP version: Automatic
   - Inner authentication: MSCHAPv2
   - Username: `john`
   - Password: `SecurePass123!`
5. Save

**Command-line method:**

```bash
# Create connection
nmcli connection add \
  type wifi \
  ifname wlan0 \
  con-name Enterprise-WiFi \
  ssid Enterprise-WiFi

# Configure security
nmcli connection modify Enterprise-WiFi \
  wifi-sec.key-mgmt wpa-eap \
  802-1x.eap peap \
  802-1x.phase2-auth mschapv2 \
  802-1x.identity john \
  802-1x.password SecurePass123! \
  802-1x.ca-cert /path/to/ca.pem

# Connect
nmcli connection up Enterprise-WiFi
```

### Android

1. **Settings → Wi-Fi**
2. **Select network:** `Enterprise-WiFi`
3. **Configure:**
   - EAP method: PEAP
   - Phase 2 authentication: MSCHAPV2
   - CA certificate: (Install ca.crt first, or select "Don't validate")
   - Identity: `john`
   - Anonymous identity: (leave empty)
   - Password: `SecurePass123!`
4. **Connect**

### iOS/iPadOS

1. **Settings → Wi-Fi**
2. **Select network:** `Enterprise-WiFi`
3. **Enter credentials:**
   - Username: `john`
   - Password: `SecurePass123!`
4. **Trust certificate:**
   - Tap "Trust" when prompted

---

## Testing and Debugging

### Start FreeRADIUS in Debug Mode

```bash
# Stop service
/etc/init.d/radiusd stop

# Start in debug mode
radiusd -XXX

# Output should show:
# Ready to process requests
```

**Debug output shows:**
- Configuration loading
- Module initialization
- Client requests
- Authentication attempts
- Accept/Reject decisions

### Test Authentication with radtest

```bash
# Test local authentication
radtest john SecurePass123! localhost 0 testing123

# Output on success:
# Sent Access-Request Id 123 from 0.0.0.0:xxxxx to 127.0.0.1:1812
# Received Access-Accept Id 123 from 127.0.0.1:1812

# Test from remote host
radtest john SecurePass123! 192.168.1.1 0 SuperSecretKey123!
```

**Interpretation:**
- **Access-Accept**: Authentication successful
- **Access-Reject**: Authentication failed (wrong password/user)
- **No response**: Network issue, firewall, or wrong shared secret

### Test EAP Authentication

```bash
# Test PEAP authentication
eapol_test -c peap.conf -s SuperSecretKey123!
```

**Create test config** `peap.conf`:

```conf
network={
    ssid="Enterprise-WiFi"
    key_mgmt=WPA-EAP
    eap=PEAP
    identity="john"
    password="SecurePass123!"
    phase2="auth=MSCHAPV2"

    # Certificate validation
    ca_cert="/etc/freeradius3/certs/ca.pem"
}
```

### Check Logs

```bash
# View authentication log
tail -f /var/log/radius/radius.log

# View detailed log
cat /var/log/freeradius/radiusd.log

# System log
logread | grep radius
```

### Common Debug Commands

```bash
# Check if FreeRADIUS is running
ps | grep radiusd

# Check listening ports
netstat -anup | grep radius

# Test configuration syntax
radiusd -C

# Show loaded modules
radiusd -XXX 2>&1 | grep "Loading module"

# Test specific user
echo "User-Name=john,User-Password=SecurePass123!" | radclient localhost auth testing123
```

---

## Advanced Configuration

### LDAP Backend Integration

```bash
# Install LDAP module
opkg install freeradius3-mod-ldap

# Enable LDAP module
cd /etc/freeradius3/mods-enabled
ln -s ../mods-available/ldap ldap
```

**Configure LDAP** - Edit `/etc/freeradius3/mods-available/ldap`:

```conf
ldap {
    server = 'ldap://192.168.1.100'
    port = 389
    identity = 'cn=admin,dc=example,dc=com'
    password = admin_password
    base_dn = 'ou=users,dc=example,dc=com'

    filter = "(uid=%{%{Stripped-User-Name}:-%{User-Name}})"

    update {
        control:Password-With-Header += 'userPassword'
    }
}
```

### SQL Backend (MySQL/PostgreSQL)

```bash
# Install SQL module
opkg install freeradius3-mod-sql
opkg install freeradius3-mod-sql-mysql  # For MySQL
# or
opkg install freeradius3-mod-sql-postgresql  # For PostgreSQL
```

**Configure SQL** - Edit `/etc/freeradius3/mods-available/sql`:

```conf
sql {
    driver = "rlm_sql_mysql"

    server = "localhost"
    port = 3306
    login = "radius"
    password = "radpass"
    radius_db = "radius"

    read_clients = yes

    client_table = "nas"
}
```

### Dynamic VLANassignment

**In user file:**

```conf
alice Cleartext-Password := "AlicePass!"
      Tunnel-Type = VLAN,
      Tunnel-Medium-Type = IEEE-802,
      Tunnel-Private-Group-Id = 100  # VLAN ID
```

**On AP, enable dynamic VLAN:**

```bash
uci set wireless.@wifi-iface[0].dynamic_vlan='1'
uci commit wireless
wifi reload
```

### Rate Limiting

**Limit authentication attempts:**

Edit `/etc/freeradius3/sites-available/default`:

```conf
authorize {
    # Limit failed attempts
    if (Login-LAT-Port) {
        update control {
            Max-Daily-Session := 3600
        }
    }
}
```

### MAC Address Filtering

**Allow specific MAC addresses:**

Edit `/etc/freeradius3/mods-config/files/authorize`:

```conf
# MAC-based authentication
aa:bb:cc:dd:ee:ff Cleartext-Password := "aa:bb:cc:dd:ee:ff"
```

---

## Security Hardening

### Change Default Secrets

```bash
# Change shared secret in clients.conf
# Never use "testing123" in production!

# Generate strong secret
openssl rand -base64 32

# Update clients.conf with new secret
```

### Restrict Listening Interfaces

```conf
# In radiusd.conf
listen {
    type = auth
    ipaddr = 192.168.1.1  # Only LAN, not 0.0.0.0
    port = 1812
}
```

### Use Strong Certificates

```bash
# Use 4096-bit keys
openssl genrsa -out server.key 4096

# Use SHA256 or higher
openssl req -new -sha256 ...
```

### Disable Weak EAP Methods

**Disable EAP-MD5:**

Comment out in `/etc/freeradius3/mods-available/eap`:

```conf
# md5 {
# }
```

### Enable TLS 1.2+ Only

```conf
# In EAP TLS config
tls-config tls-common {
    tls_min_version = "1.2"
    tls_max_version = "1.3"
    cipher_list = "HIGH:!aNULL:!MD5:!RC4"
}
```

### Log Security Events

```conf
# In radiusd.conf
log {
    destination = files

    file = ${logdir}/radius.log

    # Log authentication attempts
    auth = yes
    auth_badpass = yes
    auth_goodpass = no  # Don't log passwords!
}
```

### Firewall Rules

```bash
# Allow only from known sources
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-RADIUS-LAN'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='1812 1813'
uci set firewall.@rule[-1].target='ACCEPT'

# Block from WAN
uci add firewall rule
uci set firewall.@rule[-1].name='Block-RADIUS-WAN'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='1812 1813'
uci set firewall.@rule[-1].target='REJECT'

uci commit firewall
/etc/init.d/firewall restart
```

---

## Troubleshooting

### FreeRADIUS Won't Start

**Check configuration:**
```bash
radiusd -C
# Shows configuration errors
```

**Check logs:**
```bash
logread | grep radius
```

**Common issues:**
- Certificate files missing or wrong permissions
- Port already in use
- Configuration syntax errors
- Missing modules

### Authentication Always Fails

**Check shared secret:**
- Must match on AP and in `clients.conf`
- Case-sensitive

**Check user credentials:**
```bash
# Test with radtest
radtest username password localhost 0 testing123
```

**Check logs in debug mode:**
```bash
radiusd -XXX
# Look for "Access-Reject" messages
```

**Common issues:**
- Wrong username/password
- User not in authorize file
- EAP method mismatch
- Certificate validation failure

### Certificate Warnings on Clients

**Issue:** Clients show certificate warnings

**Solutions:**
1. **Import CA certificate on clients**
2. **Use proper hostname in certificate CN**
3. **Ensure certificate not expired:**
   ```bash
   openssl x509 -in server.pem -noout -dates
   ```

### Clients Can't Connect

**Check WiFi configuration:**
```bash
cat /etc/config/wireless
# Verify encryption='wpa2'
# Verify server IP and secret
```

**Check RADIUS is listening:**
```bash
netstat -anup | grep 1812
```

**Check firewall:**
```bash
# Temporarily disable for testing
/etc/init.d/firewall stop
# Test connection
/etc/init.d/firewall start
```

### Slow Authentication

**Optimize certificate validation:**
```conf
# In EAP config
check_cert_cn = no  # If not needed
```

**Reduce logging:**
```conf
# In radiusd.conf
log {
    auth = no
    auth_badpass = yes  # Only log failures
}
```

### High CPU Usage

**Check for authentication loops:**
```bash
top
# Monitor CPU usage

# Check logs for repeated attempts
tail -f /var/log/radius/radius.log
```

**Solutions:**
- Implement rate limiting
- Check for misconfigured clients
- Optimize database queries (if using SQL)

---

## Performance and Scaling

### Resource Usage

**Typical FreeRADIUS usage:**
- CPU: 1-5% (idle), 10-20% (active auth)
- RAM: 10-20MB
- Disk I/O: Low (unless heavy logging)

### Capacity Planning

**Single OpenWRT router can handle:**
- ~10-50 concurrent users (depending on hardware)
- ~100-500 authentications/minute
- Suitable for small office/home (< 50 users)

**For larger deployments:**
- Use dedicated RADIUS server (not on router)
- Multiple RADIUS servers with load balancing
- Database backend for user management

### Optimization Tips

1. **Disable unnecessary logging:**
```conf
log {
    auth = no
    auth_goodpass = no
}
```

2. **Cache authentication results:**
```conf
cache {
    enable = yes
    ttl = 3600
}
```

3. **Use simpler EAP methods when possible**
   - PEAP is lighter than EAP-TLS

4. **Store logs on external storage**
   - Reduces flash wear
   - Faster I/O with USB 3.0 drive

---

## Conclusion

FreeRADIUS on OpenWRT provides enterprise-grade WiFi authentication for small to medium deployments.

### Summary

✅ **Installation:**
- Install FreeRADIUS3 and required modules
- Replace wpad-mini with full wpad
- Generate or install certificates

✅ **Configuration:**
- Configure RADIUS clients (clients.conf)
- Add users (authorize file)
- Configure EAP methods
- Set up WiFi for WPA2 Enterprise

✅ **Security:**
- Change default secrets
- Use proper certificates
- Enable TLS 1.2+
- Restrict interfaces
- Implement logging

✅ **Testing:**
- Use radiusd -XXX for debugging
- Test with radtest
- Check logs for issues

### Best Practices

1. **Use WPA2/WPA3 Enterprise** instead of PSK
2. **PEAP-MSCHAPv2** for most deployments
3. **Proper certificates** (not demo certs)
4. **Strong shared secrets** (32+ characters)
5. **Regular user audits** (remove old accounts)
6. **Monitor logs** for security events

### When to Use FreeRADIUS on OpenWRT

**Good fit:**
- Small office (<50 users)
- Home lab/testing
- Single or few access points
- File-based user database

**Not recommended:**
- Large enterprise (>100 users)
- High-performance requirements
- Complex user management needs
- Critical security applications

**Alternative:** Dedicated RADIUS server with OpenWRT APs as clients

---

*Document Version: 1.0*
*Last Updated: 2025*
*Based on: https://eko.one.pl/?p=openwrt-freeradius3*
*Compatible with: OpenWRT 19.07+*
