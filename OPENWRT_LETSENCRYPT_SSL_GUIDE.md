# OpenWRT Let's Encrypt SSL Certificate Guide

## Table of Contents
1. [Overview](#overview)
2. [Let's Encrypt Concepts](#lets-encrypt-concepts)
3. [Requirements](#requirements)
4. [Installation](#installation)
5. [Certificate Issuance Methods](#certificate-issuance-methods)
6. [HTTP-01 Challenge Setup](#http-01-challenge-setup)
7. [DNS-01 Challenge Setup](#dns-01-challenge-setup)
8. [Web Server Configuration](#web-server-configuration)
9. [Automatic Renewal](#automatic-renewal)
10. [Wildcard Certificates](#wildcard-certificates)
11. [Troubleshooting](#troubleshooting)
12. [Advanced Configuration](#advanced-configuration)
13. [Security Best Practices](#security-best-practices)

---

## Overview

Let's Encrypt provides free SSL/TLS certificates that enable HTTPS encryption for websites and services. This guide covers implementing Let's Encrypt certificates on OpenWRT routers using acme.sh.

### What is Let's Encrypt?

**Let's Encrypt** is a free, automated, and open Certificate Authority (CA) that provides SSL/TLS certificates.

**Benefits:**
- ✅ **Free certificates** - No cost for SSL
- ✅ **Automated renewal** - Scripts handle renewals
- ✅ **Trusted by browsers** - Recognized by all major browsers
- ✅ **Modern encryption** - TLS 1.2/1.3 support
- ✅ **Domain validation** - Simple verification process

### Use Cases on OpenWRT

- **Web Interface (LuCI)**: Secure admin access via HTTPS
- **VPN Server**: OpenVPN/WireGuard with valid certificates
- **Web Server**: Host websites with SSL
- **API Endpoints**: Secure REST APIs
- **Home Automation**: HTTPS for IoT dashboards
- **Network Services**: Any service requiring SSL/TLS

### How It Works

```
[OpenWRT Router] → [Request Certificate] → [Let's Encrypt CA]
                         ↓
                  [Domain Validation]
                         ↓
                  [Challenge Verification]
                         ↓
                  [Certificate Issued]
                         ↓
              [Install on Web Server]
```

**Certificate Lifecycle:**
1. Request certificate for domain
2. Let's Encrypt validates domain ownership
3. Certificate issued (valid 90 days)
4. Automatic renewal every 60 days
5. Web server reloads with new certificate

---

## Let's Encrypt Concepts

### ACME Protocol

**ACME (Automatic Certificate Management Environment)** is the protocol used by Let's Encrypt.

**acme.sh** is a pure shell script ACME client that:
- Implements ACME protocol
- Supports multiple challenge types
- Handles automatic renewal
- Works on embedded systems (perfect for OpenWRT)

### Domain Validation Methods

**HTTP-01 Challenge:**
- Validates domain via HTTP
- Requires port 80 accessible from internet
- Let's Encrypt checks `http://domain/.well-known/acme-challenge/`
- **Cannot issue wildcard certificates**

**DNS-01 Challenge:**
- Validates domain via DNS TXT record
- Requires DNS API access
- Can issue wildcard certificates (*.example.com)
- Works without open ports

**TLS-ALPN-01 Challenge:**
- Validates via TLS handshake on port 443
- Less common, not covered in this guide

### Certificate Types

**Single Domain:**
```
example.com
```

**Multiple Domains (SAN):**
```
example.com
www.example.com
subdomain.example.com
```

**Wildcard:**
```
*.example.com (covers all subdomains)
```

### Certificate Validity

- **Validity Period**: 90 days
- **Renewal Window**: 30 days before expiration
- **Automatic Renewal**: Via cron job (daily check)

---

## Requirements

### Network Requirements

**Essential:**
- Public IP address (static or dynamic)
- Domain name pointing to your OpenWRT router
- Internet connectivity

**For HTTP-01 Challenge:**
- Port 80 accessible from internet (forwarded to OpenWRT)
- Port 443 for HTTPS (optional but recommended)

**For DNS-01 Challenge:**
- DNS provider with API support
- API credentials

### Domain Setup

**Option 1: Registered Domain**
- Purchase domain (e.g., from Namecheap, GoDaddy)
- Point A record to your public IP
- Example: `router.example.com → 203.0.113.10`

**Option 2: Dynamic DNS (DDNS)**
- Use DDNS service (DuckDNS, No-IP, Dynu)
- Configure OpenWRT DDNS client
- Example: `myrouter.duckdns.org`

**Configure DDNS on OpenWRT:**

```bash
# Install DDNS client
opkg update
opkg install luci-app-ddns ddns-scripts

# Configure via LuCI: Services → Dynamic DNS
# Or via command line:
uci set ddns.myddns=service
uci set ddns.myddns.service_name='duckdns.org'
uci set ddns.myddns.domain='myrouter'
uci set ddns.myddns.username='your-duckdns-token'
uci set ddns.myddns.enabled='1'
uci commit ddns
/etc/init.d/ddns start
```

### Storage Requirements

- acme.sh: ~500KB
- Certificates: ~10KB per domain
- Logs: ~1-5MB (over time)

**Total:** 5-10MB recommended

### OpenWRT Version

- OpenWRT 19.07+
- OpenWRT 21.02+ recommended
- OpenWRT 22.03 or 23.05 (latest)

---

## Installation

### Step 1: Install Prerequisites

```bash
# Update package list
opkg update

# Install required packages
opkg install ca-certificates
opkg install wget
opkg install socat
opkg install openssl-util

# For IPv6 support (recommended)
opkg install ip6tables
opkg install kmod-ip6tables
```

### Step 2: Install ACME Package

```bash
# Install acme package
opkg install acme

# Install acme-acmesh (includes acme.sh script)
opkg install acme-acmesh

# Install LuCI app (optional, for web interface)
opkg install luci-app-acme

# Verify installation
which acme.sh
# Output: /usr/lib/acme/acme.sh
```

### Step 3: Install Web Server (if not already installed)

**For uhttpd (default OpenWRT web server):**

```bash
# Install uhttpd with SSL support
opkg install uhttpd
opkg install libustream-openssl

# Verify uhttpd is running
/etc/init.d/uhttpd status
```

**For lighttpd:**

```bash
opkg install lighttpd
opkg install lighttpd-mod-openssl
```

**For nginx:**

```bash
opkg install nginx
opkg install nginx-ssl
```

### Step 4: Configure Firewall

**Open port 80 (required for HTTP-01 challenge):**

```bash
# Allow HTTP traffic from WAN
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-HTTP'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='80'
uci set firewall.@rule[-1].target='ACCEPT'

# Allow HTTPS traffic
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-HTTPS'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='443'
uci set firewall.@rule[-1].target='ACCEPT'

uci commit firewall
/etc/init.d/firewall restart
```

**Verify ports are open:**

```bash
# Check from external network
nmap -p 80,443 YOUR_PUBLIC_IP

# Or use online port checker
# https://www.yougetsignal.com/tools/open-ports/
```

---

## Certificate Issuance Methods

### HTTP-01 Challenge (Standalone Mode)

**Best for:**
- Single domain certificates
- Simple setup
- Public IP with port 80 access

**Advantages:**
- Easy to configure
- No DNS API needed
- Quick validation

**Disadvantages:**
- Requires port 80 open
- Cannot issue wildcard certificates
- Service interruption during issuance

### DNS-01 Challenge

**Best for:**
- Wildcard certificates
- Private/internal servers
- No port 80 access

**Advantages:**
- No open ports needed
- Supports wildcard certificates
- Works behind firewall/NAT

**Disadvantages:**
- Requires DNS API access
- More complex setup
- Slower validation

---

## HTTP-01 Challenge Setup

### Configure ACME

Edit `/etc/config/acme`:

```conf
config acme
    option state_dir '/etc/acme'
    option account_email 'your-email@example.com'
    option debug '0'

config cert 'router'
    option enabled '1'
    option use_staging '0'
    option keylength '2048'
    list domains 'router.example.com'
    list domains 'www.router.example.com'  # Optional: additional domains
    option validation_method 'standalone'
    option standalone_listen_port '80'
    option webroot '/www'
    option update_uhttpd '1'
```

**Configuration options:**

- **account_email**: Your email (for renewal notices)
- **use_staging**: Set to '1' for testing (staging certificates)
- **keylength**: Key size (2048 or 4096)
- **domains**: List of domains for certificate
- **validation_method**: 'standalone' for HTTP-01
- **update_uhttpd**: Auto-update uhttpd config with new cert
- **webroot**: Web root directory for challenge files

### Issue Certificate

```bash
# Run ACME client
/etc/init.d/acme start

# Or manually trigger
/usr/lib/acme/run.sh

# Check logs
logread | grep acme

# Monitor process
tail -f /var/log/acme.log
```

### Certificate Location

Certificates are stored in `/etc/acme/`:

```bash
ls -la /etc/acme/router.example.com/

# Files:
# fullchain.cer - Full certificate chain
# router.example.com.cer - Domain certificate
# router.example.com.key - Private key
# ca.cer - CA certificate
```

### Manual Certificate Issuance

```bash
# Issue certificate manually (standalone mode)
/usr/lib/acme/acme.sh --issue \
  -d router.example.com \
  -d www.router.example.com \
  --standalone \
  --httpport 80 \
  --server letsencrypt

# Force renewal
/usr/lib/acme/acme.sh --renew \
  -d router.example.com \
  --force

# Check certificate expiry
/usr/lib/acme/acme.sh --list

# Show certificate info
openssl x509 -in /etc/acme/router.example.com/fullchain.cer -text -noout
```

---

## DNS-01 Challenge Setup

### Supported DNS Providers

acme.sh supports 100+ DNS providers:
- Cloudflare
- AWS Route53
- Google Cloud DNS
- Digital Ocean
- DuckDNS
- Namecheap
- GoDaddy
- And many more...

Full list: https://github.com/acmesh-official/acme.sh/wiki/dnsapi

### Configure DNS API (Example: Cloudflare)

**Get Cloudflare API token:**
1. Login to Cloudflare
2. My Profile → API Tokens
3. Create Token → Edit zone DNS
4. Copy token

**Configure in OpenWRT:**

```bash
# Set environment variables
export CF_Token="your-cloudflare-api-token"
export CF_Account_ID="your-account-id"  # Optional

# Or create config file
cat > /root/.acme.sh/account.conf << 'EOF'
CF_Token='your-cloudflare-api-token'
CF_Account_ID='your-account-id'
EOF

chmod 600 /root/.acme.sh/account.conf
```

### Issue Certificate with DNS-01

```bash
# Issue certificate using Cloudflare DNS
/usr/lib/acme/acme.sh --issue \
  -d router.example.com \
  -d www.router.example.com \
  --dns dns_cf \
  --server letsencrypt

# For wildcard certificate
/usr/lib/acme/acme.sh --issue \
  -d example.com \
  -d '*.example.com' \
  --dns dns_cf \
  --server letsencrypt
```

### Configure ACME for DNS-01

Edit `/etc/config/acme`:

```conf
config cert 'router_dns'
    option enabled '1'
    option use_staging '0'
    option keylength '2048'
    list domains 'router.example.com'
    option validation_method 'dns'
    option dns 'dns_cf'
    option credentials '/root/.acme.sh/account.conf'
    option update_uhttpd '1'
```

---

## Web Server Configuration

### uhttpd (Default OpenWRT)

**Automatic configuration (recommended):**

When `update_uhttpd '1'` is set in `/etc/config/acme`, uhttpd config is automatically updated.

**Manual configuration:**

Edit `/etc/config/uhttpd`:

```conf
config uhttpd 'main'
    list listen_http '0.0.0.0:80'
    list listen_http '[::]:80'
    list listen_https '0.0.0.0:443'
    list listen_https '[::]:443'
    option home '/www'
    option rfc1918_filter '1'
    option max_requests '3'
    option max_connections '100'
    option cert '/etc/acme/router.example.com/fullchain.cer'
    option key '/etc/acme/router.example.com/router.example.com.key'
    option cgi_prefix '/cgi-bin'
    option script_timeout '60'
    option network_timeout '30'
    option http_keepalive '20'
    option tcp_keepalive '1'
```

**Restart uhttpd:**

```bash
/etc/init.d/uhttpd restart

# Verify HTTPS
netstat -antp | grep 443
```

### lighttpd

**Configuration:**

Edit `/etc/lighttpd/lighttpd.conf`:

```conf
# SSL engine
ssl.engine = "enable"

# Certificate files
ssl.pemfile = "/etc/acme/router.example.com/fullchain.cer"
ssl.privkey = "/etc/acme/router.example.com/router.example.com.key"

# SSL protocols
ssl.use-sslv2 = "disable"
ssl.use-sslv3 = "disable"

# SSL ciphers (strong only)
ssl.cipher-list = "HIGH:!aNULL:!MD5:!RC4"

# Listen on HTTPS port
server.port = 443
```

**Install certificate:**

```bash
# Create combined PEM file (if needed)
cat /etc/acme/router.example.com/fullchain.cer \
    /etc/acme/router.example.com/router.example.com.key \
    > /etc/lighttpd/server.pem

chmod 600 /etc/lighttpd/server.pem

# Update config to use combined file
# ssl.pemfile = "/etc/lighttpd/server.pem"

# Restart lighttpd
/etc/init.d/lighttpd restart
```

### nginx

**Configuration:**

Edit `/etc/nginx/nginx.conf`:

```nginx
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name router.example.com;

    # SSL certificates
    ssl_certificate /etc/acme/router.example.com/fullchain.cer;
    ssl_certificate_key /etc/acme/router.example.com/router.example.com.key;

    # SSL protocols
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # SSL session cache
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS (optional)
    add_header Strict-Transport-Security "max-age=31536000" always;

    root /www;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name router.example.com;
    return 301 https://$server_name$request_uri;
}
```

**Restart nginx:**

```bash
# Test configuration
nginx -t

# Restart nginx
/etc/init.d/nginx restart
```

---

## Automatic Renewal

### How Automatic Renewal Works

- Cron job runs daily
- Checks certificate expiry
- Renews if less than 30 days remaining
- Reloads web server automatically

### Cron Job Configuration

ACME package installs cron job automatically:

```bash
# View cron jobs
crontab -l

# Should contain:
# 0 0 * * * /etc/init.d/acme start
```

**If missing, add manually:**

```bash
# Add to root crontab
echo "0 0 * * * /etc/init.d/acme start" >> /etc/crontabs/root

# Restart cron
/etc/init.d/cron restart
```

### Manual Renewal Testing

```bash
# Check certificate status
/usr/lib/acme/acme.sh --list

# Force renewal (testing)
/usr/lib/acme/acme.sh --renew \
  -d router.example.com \
  --force

# Dry run (no actual renewal)
/usr/lib/acme/acme.sh --renew \
  -d router.example.com \
  --force \
  --debug
```

### Post-Renewal Hooks

**Reload web server after renewal:**

Edit `/etc/config/acme`:

```conf
config cert 'router'
    option enabled '1'
    list domains 'router.example.com'
    option validation_method 'standalone'
    option update_uhttpd '1'

    # Custom post-renewal script
    option run_post_hook '1'
    option post_hook '/root/scripts/post-renewal.sh'
```

**Create post-renewal script** `/root/scripts/post-renewal.sh`:

```bash
#!/bin/sh

# Reload uhttpd
/etc/init.d/uhttpd reload

# Reload nginx (if using nginx)
# /etc/init.d/nginx reload

# Send notification
logger -t acme "Certificate renewed for router.example.com"

# Optional: Email notification
# echo "Certificate renewed" | mail -s "Cert Renewal" admin@example.com
```

Make executable:
```bash
chmod +x /root/scripts/post-renewal.sh
```

---

## Wildcard Certificates

### Requirements

- DNS-01 challenge method
- DNS API access
- Root domain and wildcard in certificate

### Issue Wildcard Certificate

```bash
# Using Cloudflare DNS
export CF_Token="your-token"

# Issue wildcard certificate
/usr/lib/acme/acme.sh --issue \
  -d example.com \
  -d '*.example.com' \
  --dns dns_cf \
  --server letsencrypt

# Certificate covers:
# - example.com
# - *.example.com (all subdomains)
```

### Configure ACME for Wildcard

Edit `/etc/config/acme`:

```conf
config cert 'wildcard'
    option enabled '1'
    option use_staging '0'
    option keylength '2048'
    list domains 'example.com'
    list domains '*.example.com'
    option validation_method 'dns'
    option dns 'dns_cf'
    option credentials '/root/.acme.sh/account.conf'
    option update_uhttpd '1'
```

### Use Wildcard for Multiple Services

```bash
# Install same wildcard cert on multiple servers
# Copy certificate files to each server

# For uhttpd on router
scp /etc/acme/example.com/* root@router:/etc/acme/example.com/

# For nginx on server
scp /etc/acme/example.com/* root@server:/etc/nginx/ssl/

# Update each server's config to use wildcard cert
```

---

## Troubleshooting

### Certificate Issuance Fails

**Check domain DNS:**
```bash
# Verify DNS resolves to correct IP
nslookup router.example.com

# Should return your public IP
dig router.example.com +short
```

**Check port 80 accessible:**
```bash
# Test from external network
curl -I http://router.example.com

# Or use online checker
# https://www.canyouseeme.org/
```

**Check firewall:**
```bash
# Verify ports open
iptables -L INPUT -n | grep -E "80|443"

# Temporarily disable for testing
/etc/init.d/firewall stop
# Test certificate issuance
# Re-enable firewall
/etc/init.d/firewall start
```

**View detailed logs:**
```bash
# Enable debug mode
/usr/lib/acme/acme.sh --issue \
  -d router.example.com \
  --standalone \
  --debug 2

# Check system log
logread | grep acme
```

### Rate Limit Errors

**Let's Encrypt rate limits:**
- 50 certificates per registered domain per week
- 5 failed validation attempts per hour

**Solution:**
```bash
# Use staging server for testing
/usr/lib/acme/acme.sh --issue \
  -d router.example.com \
  --standalone \
  --staging

# Once working, issue production cert
/usr/lib/acme/acme.sh --issue \
  -d router.example.com \
  --standalone \
  --server letsencrypt
```

### Renewal Fails

**Check cron job running:**
```bash
# View cron logs
logread | grep cron

# Manually trigger renewal
/etc/init.d/acme start
```

**Force renewal:**
```bash
/usr/lib/acme/acme.sh --renew \
  -d router.example.com \
  --force

# Check expiry date
/usr/lib/acme/acme.sh --list
```

### Certificate Not Trusted

**Check certificate chain:**
```bash
# Verify chain complete
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt \
  /etc/acme/router.example.com/fullchain.cer

# Should output: OK
```

**Update CA certificates:**
```bash
opkg update
opkg install ca-certificates
opkg upgrade ca-certificates
```

### Web Server Not Using New Certificate

**Reload web server:**
```bash
# For uhttpd
/etc/init.d/uhttpd reload

# For lighttpd
/etc/init.d/lighttpd reload

# For nginx
/etc/init.d/nginx reload
```

**Check file permissions:**
```bash
ls -la /etc/acme/router.example.com/

# Should be readable by web server user
chmod 644 /etc/acme/router.example.com/*.cer
chmod 600 /etc/acme/router.example.com/*.key
```

---

## Advanced Configuration

### Multiple Domains

**Single certificate for multiple domains (SAN):**

```bash
/usr/lib/acme/acme.sh --issue \
  -d router.example.com \
  -d www.router.example.com \
  -d vpn.router.example.com \
  -d dashboard.router.example.com \
  --standalone
```

**Separate certificates for different domains:**

Edit `/etc/config/acme`:

```conf
config cert 'main'
    option enabled '1'
    list domains 'router.example.com'
    option validation_method 'standalone'
    option update_uhttpd '1'

config cert 'vpn'
    option enabled '1'
    list domains 'vpn.example.com'
    option validation_method 'dns'
    option dns 'dns_cf'
```

### OCSP Stapling

**Improve SSL handshake performance:**

**For nginx:**

```nginx
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/acme/router.example.com/fullchain.cer;
```

**For lighttpd:**

```conf
ssl.stapling-file = "/etc/lighttpd/ocsp-response.der"
```

### Certificate for OpenVPN

```bash
# Issue certificate
/usr/lib/acme/acme.sh --issue \
  -d vpn.example.com \
  --standalone

# Copy to OpenVPN directory
cp /etc/acme/vpn.example.com/fullchain.cer /etc/openvpn/server.crt
cp /etc/acme/vpn.example.com/vpn.example.com.key /etc/openvpn/server.key

# Update OpenVPN config
# cert server.crt
# key server.key

# Restart OpenVPN
/etc/init.d/openvpn restart
```

### Monitoring Certificate Expiry

**Create monitoring script:**

```bash
cat > /root/check-cert-expiry.sh << 'EOF'
#!/bin/sh

CERT="/etc/acme/router.example.com/fullchain.cer"
DAYS_WARNING=14

EXPIRY=$(openssl x509 -enddate -noout -in $CERT | cut -d= -f2)
EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
NOW_EPOCH=$(date +%s)
DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

echo "Certificate expires in $DAYS_LEFT days"

if [ $DAYS_LEFT -lt $DAYS_WARNING ]; then
    echo "WARNING: Certificate expiring soon!"
    logger -t cert-monitor "SSL certificate expires in $DAYS_LEFT days"
    # Send notification (email, webhook, etc.)
fi
EOF

chmod +x /root/check-cert-expiry.sh

# Add to cron (check daily)
echo "0 6 * * * /root/check-cert-expiry.sh" >> /etc/crontabs/root
```

---

## Security Best Practices

### 1. Use Strong Key Sizes

```conf
# In /etc/config/acme
option keylength '4096'  # Use 4096-bit keys for better security
```

### 2. Enable HSTS

**HTTP Strict Transport Security forces HTTPS:**

**For uhttpd:**
Add to response headers (requires custom configuration)

**For nginx:**
```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
```

**For lighttpd:**
```conf
setenv.add-response-header = (
    "Strict-Transport-Security" => "max-age=31536000; includeSubDomains"
)
```

### 3. Disable Weak Protocols

**Disable TLS 1.0 and 1.1:**

**For uhttpd:**
Limited configuration options (uses system defaults)

**For nginx:**
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```

**For lighttpd:**
```conf
ssl.use-sslv2 = "disable"
ssl.use-sslv3 = "disable"
# TLS 1.2+ only
ssl.openssl.ssl-conf-cmd = ("MinProtocol" => "TLSv1.2")
```

### 4. Use Strong Ciphers

```nginx
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
ssl_prefer_server_ciphers on;
```

### 5. Protect Private Keys

```bash
# Restrict permissions
chmod 600 /etc/acme/*/\.key
chown root:root /etc/acme/*/*.key

# Backup securely (encrypted)
tar czf - /etc/acme | gpg --encrypt --recipient admin@example.com > acme-backup.tar.gz.gpg
```

### 6. Monitor Renewal Logs

```bash
# Check renewal logs weekly
grep -i error /var/log/acme.log

# Set up alerting for failed renewals
```

### 7. Test SSL Configuration

**Use SSL testing tools:**
- https://www.ssllabs.com/ssltest/
- https://www.immuniweb.com/ssl/

**Check for vulnerabilities:**
```bash
# Install testssl.sh
wget https://github.com/drwetter/testssl.sh/archive/3.0.tar.gz
tar xzf 3.0.tar.gz
cd testssl.sh-3.0

# Test your SSL configuration
./testssl.sh https://router.example.com
```

---

## Conclusion

Let's Encrypt provides free, trusted SSL certificates for OpenWRT routers, enabling secure HTTPS access.

### Summary

✅ **Installation:**
- Install acme, ca-certificates, socat
- Install web server (uhttpd/nginx/lighttpd)
- Configure firewall (ports 80, 443)

✅ **Certificate Issuance:**
- HTTP-01: Standalone mode (simple, port 80 required)
- DNS-01: DNS API (wildcard support, no open ports)
- Configure domain and email

✅ **Web Server:**
- Auto-configure uhttpd (recommended)
- Manual config for nginx/lighttpd
- Reload after certificate issuance

✅ **Automatic Renewal:**
- Cron job runs daily
- Renews 30 days before expiry
- Auto-reload web server

✅ **Security:**
- Use 4096-bit keys
- Enable TLS 1.2/1.3 only
- Strong ciphers
- HSTS headers
- Monitor expiry

### Best Practices

1. **Test with staging** - Use Let's Encrypt staging server first
2. **Monitor logs** - Check renewal success
3. **Backup certificates** - Encrypted backup of /etc/acme
4. **Use DNS-01 for wildcard** - Single cert for all subdomains
5. **Secure private keys** - Proper permissions (600)
6. **Auto-reload services** - Post-renewal hooks
7. **Test SSL config** - Use SSL Labs or testssl.sh

### Common Issues

**Certificate not trusted:**
- Check certificate chain (use fullchain.cer)
- Update ca-certificates package

**Renewal fails:**
- Check cron job running
- Verify domain DNS still correct
- Check port 80 still accessible (HTTP-01)

**Web server not using new cert:**
- Reload web server after renewal
- Check file paths in config
- Verify file permissions

### Resources

- Let's Encrypt: https://letsencrypt.org/
- acme.sh Documentation: https://github.com/acmesh-official/acme.sh
- OpenWRT acme package: https://openwrt.org/docs/guide-user/services/tls/acme
- SSL Labs Test: https://www.ssllabs.com/ssltest/

---

*Document Version: 1.0*
*Last Updated: 2025*
*Based on: https://eko.one.pl/?p=openwrt-letsencrypt*
*Compatible with: OpenWRT 19.07+*

**Note:** Let's Encrypt certificates are domain validation only (DV). For organization validation (OV) or extended validation (EV), use commercial certificate authorities.
