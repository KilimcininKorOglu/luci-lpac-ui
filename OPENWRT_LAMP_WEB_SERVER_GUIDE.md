# OpenWRT LAMP/LEMP Web Server Guide

## Table of Contents
1. [Overview](#overview)
2. [System Requirements](#system-requirements)
3. [Storage Preparation](#storage-preparation)
4. [Web Server Installation](#web-server-installation)
5. [PHP Installation and Configuration](#php-installation-and-configuration)
6. [Database Installation and Configuration](#database-installation-and-configuration)
7. [Testing the Stack](#testing-the-stack)
8. [phpMyAdmin Setup](#phpmyadmin-setup)
9. [Security Hardening](#security-hardening)
10. [Performance Optimization](#performance-optimization)
11. [Troubleshooting](#troubleshooting)
12. [Use Cases](#use-cases)

---

## Overview

This guide covers setting up a complete web server stack on OpenWRT routers. While traditional LAMP (Linux, Apache, MySQL, PHP) is possible, we recommend LEMP (Linux, nginx/lighttpd, MariaDB, PHP) for better performance on embedded systems.

### What is LAMP/LEMP?

**LAMP Stack:**
- **L**inux - Operating system (OpenWRT)
- **A**pache - Web server (not recommended for OpenWRT)
- **M**ySQL - Database (MariaDB on OpenWRT)
- **P**HP - Programming language

**LEMP Stack (Recommended):**
- **L**inux - Operating system (OpenWRT)
- **E**nginx/Lighttpd - Web server (efficient alternatives)
- **M**ariaDB - Database
- **P**HP - Programming language

### Use Cases

- **Home Automation**: Web interfaces for IoT devices
- **Personal Blog**: Low-traffic websites
- **Network Monitoring**: Status dashboards
- **File Sharing**: Web-based file managers
- **Development**: Test environment for PHP applications
- **Small Business**: Simple internal applications

### Important Limitations

⚠️ **OpenWRT routers are NOT suitable for:**
- High-traffic websites
- Production e-commerce sites
- Database-intensive applications
- Multiple concurrent users (>5-10)
- Large file uploads
- Complex web applications

**Why?**
- Limited RAM (32-512MB typical)
- Slow CPU (400-800MHz typical)
- Limited storage
- No hardware acceleration
- Power constraints

---

## System Requirements

### Hardware Requirements

**Minimum:**
- 64MB RAM (128MB recommended)
- 32MB Flash storage + USB drive
- 400MHz CPU
- USB port for external storage

**Recommended:**
- 256MB+ RAM
- 8GB+ USB drive
- 600MHz+ CPU
- Gigabit Ethernet

### Storage Requirements

**Base installation:**
- Lighttpd: ~200KB
- PHP7: ~5MB (with modules)
- MariaDB: ~10MB
- Database files: 50MB-2GB+ (external storage required)

**Total:** 15MB+ for software, 100MB+ for operation

### OpenWRT Version

- OpenWRT 19.07+ recommended
- OpenWRT 21.02 or newer preferred
- LEDE 17.01+ compatible

---

## Storage Preparation

### Why External Storage?

OpenWRT flash storage is too small for databases. External storage is **mandatory** for:
- Database files (can grow to GB sizes)
- Web application files
- Log files
- Temporary files

### Option 1: Extroot (Recommended)

**Extroot extends entire root filesystem to USB drive.**

```bash
# Install required packages
opkg update
opkg install block-mount kmod-fs-ext4 kmod-usb-storage

# Plug in USB drive and identify it
block info
# Note the device (e.g., /dev/sda1)

# Format USB drive as ext4
mkfs.ext4 /dev/sda1

# Configure extroot
mkdir -p /mnt/sda1
mount /dev/sda1 /mnt/sda1

# Copy root filesystem
tar -C /overlay -cvf - . | tar -C /mnt/sda1 -xf -

# Configure fstab for extroot
block detect > /etc/config/fstab
uci set fstab.@mount[0].enabled='1'
uci set fstab.@mount[0].target='/overlay'
uci commit fstab

# Reboot to activate extroot
reboot

# Verify extroot is active
df -h | grep overlay
# Should show USB drive size
```

### Option 2: Separate Mount Point

**Mount USB drive to specific directory (simpler but less flexible).**

```bash
# Install USB support
opkg update
opkg install kmod-usb-storage kmod-fs-ext4 block-mount

# Format USB drive
mkfs.ext4 /dev/sda1

# Create mount point
mkdir -p /mnt/usb

# Configure fstab
block detect > /etc/config/fstab
uci set fstab.@mount[0].enabled='1'
uci set fstab.@mount[0].target='/mnt/usb'
uci commit fstab

# Restart block-mount
/etc/init.d/fstab restart

# Verify mount
df -h | grep usb
```

### Create Directory Structure

```bash
# Create web and database directories
mkdir -p /www1
mkdir -p /mnt/usb/mysql

# Set permissions
chmod 755 /www1
chmod 750 /mnt/usb/mysql
```

---

## Web Server Installation

### Option 1: Lighttpd (Recommended)

**Why Lighttpd?**
- Lightweight (~200KB)
- Low memory usage (~2-5MB RAM)
- Fast for embedded systems
- Stable on OpenWRT
- Good PHP support

**Installation:**

```bash
# Install lighttpd
opkg update
opkg install lighttpd

# Install CGI module for PHP
opkg install lighttpd-mod-cgi

# Enable CGI module
lighttpd-enable-mod cgi

# Install additional modules (optional)
opkg install lighttpd-mod-access
opkg install lighttpd-mod-accesslog
```

**Configuration:**

Edit `/etc/lighttpd/lighttpd.conf`:

```conf
# Server settings
server.document-root = "/www1"
server.upload-dirs = ( "/tmp" )
server.errorlog = "/var/log/lighttpd/error.log"
server.pid-file = "/var/run/lighttpd.pid"
server.username = "http"
server.groupname = "www-data"
server.port = 80

# Performance tuning for embedded systems
server.max-connections = 20
server.max-worker = 2
server.max-fds = 128
server.max-request-size = 2048

# MIME types
mimetype.assign = (
  ".html" => "text/html",
  ".htm" => "text/html",
  ".txt" => "text/plain",
  ".jpg" => "image/jpeg",
  ".jpeg" => "image/jpeg",
  ".png" => "image/png",
  ".gif" => "image/gif",
  ".css" => "text/css",
  ".js" => "application/javascript",
  ".php" => "application/x-httpd-php"
)

# Index files
index-file.names = ( "index.php", "index.html", "index.htm" )

# CGI configuration for PHP
cgi.assign = ( ".php" => "/usr/bin/php-cgi" )

# Static file caching
static-file.etags = "enable"

# Directory listing
dir-listing.activate = "disable"

# Include modules
include "conf.d/*.conf"
```

**Start Lighttpd:**

```bash
# Enable service
/etc/init.d/lighttpd enable

# Start service
/etc/init.d/lighttpd start

# Check status
/etc/init.d/lighttpd status

# Verify listening on port 80
netstat -antp | grep 80
```

### Option 2: nginx (Alternative)

**Installation:**

```bash
# Install nginx
opkg install nginx

# Install additional modules
opkg install nginx-mod-luci
opkg install nginx-util
```

**Basic Configuration:**

Edit `/etc/nginx/nginx.conf`:

```nginx
user root;
worker_processes 1;

events {
    worker_connections 128;
}

http {
    include mime.types;
    default_type application/octet-stream;

    sendfile on;
    keepalive_timeout 65;

    server {
        listen 80;
        server_name localhost;
        root /www1;
        index index.php index.html;

        location / {
            try_files $uri $uri/ =404;
        }

        location ~ \.php$ {
            fastcgi_pass unix:/var/run/php7-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }
    }
}
```

**Start nginx:**

```bash
/etc/init.d/nginx enable
/etc/init.d/nginx start
```

### Option 3: Apache (Not Recommended)

**⚠️ WARNING**: Apache has stability issues on OpenWRT LEDE 17.01+. Use only for legacy compatibility.

**Installation:**

```bash
# Install Apache
opkg install apache

# Install PHP module (if available)
opkg install apache-mod-php7
```

**Note:** Due to stability issues, this guide focuses on Lighttpd and nginx.

### Disable LuCI (Required for Port 80)

**LuCI web interface uses port 80 by default. You must change it or disable it.**

**Option A: Change LuCI port to 8080:**

```bash
# Edit uHTTPd configuration
uci set uhttpd.main.listen_http='0.0.0.0:8080'
uci set uhttpd.main.listen_https='0.0.0.0:8443'
uci commit uhttpd
/etc/init.d/uhttpd restart

# Access LuCI at: http://192.168.1.1:8080
```

**Option B: Disable uHTTPd:**

```bash
/etc/init.d/uhttpd stop
/etc/init.d/uhttpd disable
```

---

## PHP Installation and Configuration

### Install PHP7

```bash
# Install PHP7 CGI
opkg install php7-cgi

# Install essential modules
opkg install php7-mod-mysqli    # MySQL/MariaDB support
opkg install php7-mod-pdo-mysql # PDO MySQL support
opkg install php7-mod-openssl   # OpenSSL support
opkg install php7-mod-xml       # XML support
opkg install php7-mod-curl      # cURL support
opkg install php7-mod-gd        # Image manipulation
opkg install php7-mod-json      # JSON support
opkg install php7-mod-session   # Session support

# Optional modules
opkg install php7-mod-zip       # ZIP support
opkg install php7-mod-mbstring  # Multibyte string support
opkg install php7-mod-hash      # Hash functions
opkg install php7-mod-filter    # Data filtering
```

### Configure PHP

Edit `/etc/php.ini`:

```ini
[PHP]
; Basic settings
engine = On
short_open_tag = Off
precision = 14
output_buffering = 4096
zlib.output_compression = Off

; Resource limits (adjusted for OpenWRT)
max_execution_time = 30
max_input_time = 60
memory_limit = 32M
post_max_size = 8M
upload_max_filesize = 8M

; Error handling
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = Off
display_startup_errors = Off
log_errors = On
error_log = /var/log/php_errors.log

; File uploads
file_uploads = On
upload_tmp_dir = /tmp

; Document root
doc_root = "/www1"

; Timezone
date.timezone = "Europe/Warsaw"  # Adjust to your timezone

; MySQL
mysqli.default_socket = /var/run/mysqld.sock

; Session
session.save_handler = files
session.save_path = "/tmp"
session.use_cookies = 1
session.cookie_httponly = 1
```

### Test PHP Installation

```bash
# Create test file
cat > /www1/info.php << 'EOF'
<?php
phpinfo();
?>
EOF

# Set permissions
chmod 644 /www1/info.php

# Access in browser: http://192.168.1.1/info.php
# Should display PHP configuration page
```

---

## Database Installation and Configuration

### Install MariaDB

**MariaDB is a drop-in replacement for MySQL, better suited for embedded systems.**

```bash
# Install MariaDB server
opkg install mariadb-server mariadb-client

# Install client libraries
opkg install mariadb-client-extra

# Install additional tools (optional)
opkg install mariadb-server-extra
```

### Configure MariaDB

**Create configuration file:**

Edit `/etc/mysql/my.cnf`:

```ini
[mysqld]
# Basic settings
user = root
port = 3306
socket = /var/run/mysqld.sock
pid-file = /var/run/mysqld.pid

# Data directory (on USB storage)
datadir = /mnt/usb/mysql

# Character set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

# Performance tuning for embedded systems
# Reduce memory usage significantly

# InnoDB settings
innodb_buffer_pool_size = 16M  # Default 128M, reduced for OpenWRT
innodb_log_file_size = 8M
innodb_log_buffer_size = 2M
innodb_flush_method = O_DIRECT

# Query cache (optional, uses RAM)
query_cache_size = 2M
query_cache_limit = 512K

# Table cache
table_open_cache = 64
table_definition_cache = 128

# Thread settings
thread_cache_size = 4
max_connections = 10  # Limit concurrent connections

# Buffer sizes
key_buffer_size = 4M
read_buffer_size = 128K
read_rnd_buffer_size = 256K
sort_buffer_size = 256K
join_buffer_size = 256K

# Temporary tables
tmp_table_size = 4M
max_heap_table_size = 4M

# Logging
log_error = /var/log/mysql/error.log
slow_query_log = 0

# Network
bind-address = 127.0.0.1  # Only local connections
skip-name-resolve = 1

[client]
port = 3306
socket = /var/run/mysqld.sock

[mysqldump]
quick
max_allowed_packet = 16M
```

### Initialize Database

```bash
# Create data directory
mkdir -p /mnt/usb/mysql
mkdir -p /var/log/mysql

# Set permissions
chown -R mariadb:mariadb /mnt/usb/mysql
chown -R mariadb:mariadb /var/log/mysql
chmod 750 /mnt/usb/mysql

# Initialize database
mysql_install_db --force --basedir=/usr --datadir=/mnt/usb/mysql

# Start MariaDB
/etc/init.d/mysqld enable
/etc/init.d/mysqld start

# Check status
/etc/init.d/mysqld status

# Verify MySQL is running
ps | grep mysql
netstat -antp | grep 3306
```

### Secure MariaDB Installation

```bash
# Run security script
mysql_secure_installation

# Answer prompts:
# Set root password? Y (choose strong password)
# Remove anonymous users? Y
# Disallow root login remotely? Y
# Remove test database? Y
# Reload privilege tables? Y
```

### Create Database and User

```bash
# Login to MySQL
mysql -u root -p

# Create database
CREATE DATABASE myapp;

# Create user and grant privileges
CREATE USER 'webuser'@'localhost' IDENTIFIED BY 'strong_password_here';
GRANT ALL PRIVILEGES ON myapp.* TO 'webuser'@'localhost';
FLUSH PRIVILEGES;

# Verify
SHOW DATABASES;
SELECT User, Host FROM mysql.user;

# Exit
EXIT;
```

---

## Testing the Stack

### Test 1: Web Server (Static Content)

```bash
# Create test HTML file
cat > /www1/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>OpenWRT Web Server Test</title>
</head>
<body>
    <h1>Welcome to OpenWRT Web Server!</h1>
    <p>If you see this page, the web server is working correctly.</p>
    <p><a href="test.php">Test PHP</a></p>
</body>
</html>
EOF

chmod 644 /www1/index.html
```

**Access:** `http://192.168.1.1/`

### Test 2: PHP Processing

```bash
# Create PHP test file
cat > /www1/test.php << 'EOF'
<?php
echo "<h1>PHP Test</h1>";
echo "<p>PHP version: " . phpversion() . "</p>";
echo "<p>Server time: " . date('Y-m-d H:i:s') . "</p>";

// Test loaded modules
echo "<h2>Loaded PHP Modules:</h2>";
echo "<ul>";
foreach (get_loaded_extensions() as $ext) {
    echo "<li>$ext</li>";
}
echo "</ul>";
?>
EOF

chmod 644 /www1/test.php
```

**Access:** `http://192.168.1.1/test.php`

### Test 3: Database Connection

```bash
# Create database test file
cat > /www1/dbtest.php << 'EOF'
<?php
$servername = "localhost";
$username = "webuser";
$password = "strong_password_here";
$dbname = "myapp";

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

echo "<h1>Database Connection Test</h1>";
echo "<p style='color: green;'>Connected successfully to database: $dbname</p>";

// Create test table
$sql = "CREATE TABLE IF NOT EXISTS test_table (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)";

if ($conn->query($sql) === TRUE) {
    echo "<p>Test table created successfully</p>";
} else {
    echo "<p style='color: red;'>Error creating table: " . $conn->error . "</p>";
}

// Insert test data
$sql = "INSERT INTO test_table (name) VALUES ('Test Entry')";
if ($conn->query($sql) === TRUE) {
    echo "<p>Test data inserted successfully</p>";
} else {
    echo "<p style='color: red;'>Error inserting data: " . $conn->error . "</p>";
}

// Query test data
$sql = "SELECT * FROM test_table";
$result = $conn->query($sql);

if ($result->num_rows > 0) {
    echo "<h2>Data from database:</h2>";
    echo "<table border='1'><tr><th>ID</th><th>Name</th><th>Created At</th></tr>";
    while($row = $result->fetch_assoc()) {
        echo "<tr><td>" . $row["id"] . "</td><td>" . $row["name"] . "</td><td>" . $row["created_at"] . "</td></tr>";
    }
    echo "</table>";
}

$conn->close();
?>
EOF

chmod 644 /www1/dbtest.php
```

**Access:** `http://192.168.1.1/dbtest.php`

---

## phpMyAdmin Setup

### Installation

```bash
# Install additional PHP modules required by phpMyAdmin
opkg install php7-mod-json
opkg install php7-mod-session
opkg install php7-mod-zip
opkg install php7-mod-mbstring
opkg install php7-mod-ctype
opkg install php7-mod-hash

# Increase PHP memory limit
sed -i 's/memory_limit = 32M/memory_limit = 64M/' /etc/php.ini

# Download phpMyAdmin
cd /tmp
wget https://files.phpmyadmin.net/phpMyAdmin/5.1.1/phpMyAdmin-5.1.1-all-languages.tar.gz

# Extract
tar xzf phpMyAdmin-5.1.1-all-languages.tar.gz

# Move to web directory
mv phpMyAdmin-5.1.1-all-languages /www1/phpmyadmin

# Create config directory
mkdir -p /www1/phpmyadmin/tmp
chmod 777 /www1/phpmyadmin/tmp

# Remove downloaded archive
rm phpMyAdmin-5.1.1-all-languages.tar.gz
```

### Configuration

Create `/www1/phpmyadmin/config.inc.php`:

```php
<?php
$cfg['blowfish_secret'] = 'change_this_to_random_32_character_string_123456';

$i = 0;
$i++;

$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['Servers'][$i]['host'] = 'localhost';
$cfg['Servers'][$i]['compress'] = false;
$cfg['Servers'][$i]['AllowNoPassword'] = false;

$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';
$cfg['TempDir'] = '/www1/phpmyadmin/tmp';

// Memory optimization for OpenWRT
$cfg['MaxRows'] = 25;
$cfg['RowActionLinks'] = 'none';
?>
```

**Access:** `http://192.168.1.1/phpmyadmin/`

**Login:** root / (your MySQL root password)

---

## Security Hardening

### Web Server Security

**1. Disable directory listing:**

```conf
# In /etc/lighttpd/lighttpd.conf
dir-listing.activate = "disable"
```

**2. Hide server signature:**

```conf
# In /etc/lighttpd/lighttpd.conf
server.tag = ""
```

**3. Restrict access by IP (optional):**

```conf
# In /etc/lighttpd/lighttpd.conf
$HTTP["remoteip"] !~ "192.168.1.0/24" {
    url.access-deny = ( "" )
}
```

### PHP Security

**Edit `/etc/php.ini`:**

```ini
; Disable dangerous functions
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source

; Hide PHP version
expose_php = Off

; Disable remote file inclusion
allow_url_fopen = Off
allow_url_include = Off

; Increase security
open_basedir = /www1:/tmp
safe_mode_exec_dir = /usr/bin
```

### Database Security

**1. Bind to localhost only:**

```ini
# In /etc/mysql/my.cnf
bind-address = 127.0.0.1
```

**2. Remove test database:**

```bash
mysql -u root -p -e "DROP DATABASE IF EXISTS test;"
```

**3. Remove anonymous users:**

```bash
mysql -u root -p -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -p -e "FLUSH PRIVILEGES;"
```

**4. Use strong passwords:**
- Minimum 12 characters
- Mix of uppercase, lowercase, numbers, symbols

### Firewall Configuration

```bash
# Web server is accessible only from LAN (default)
# To allow external access:

uci add firewall rule
uci set firewall.@rule[-1].name='Allow-HTTP'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='80'
uci set firewall.@rule[-1].target='ACCEPT'

# For HTTPS (if configured):
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-HTTPS'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='443'
uci set firewall.@rule[-1].target='ACCEPT'

uci commit firewall
/etc/init.d/firewall restart
```

### HTTPS/SSL Configuration (Recommended)

```bash
# Install SSL support
opkg install lighttpd-mod-openssl

# Generate self-signed certificate
mkdir -p /etc/lighttpd/ssl
openssl req -new -x509 -keyout /etc/lighttpd/ssl/server.pem \
  -out /etc/lighttpd/ssl/server.pem -days 365 -nodes

# Configure SSL in lighttpd.conf
echo 'ssl.engine = "enable"' >> /etc/lighttpd/lighttpd.conf
echo 'ssl.pemfile = "/etc/lighttpd/ssl/server.pem"' >> /etc/lighttpd/lighttpd.conf

# Restart lighttpd
/etc/init.d/lighttpd restart
```

---

## Performance Optimization

### Web Server Optimization

**Lighttpd tuning for OpenWRT:**

```conf
# In /etc/lighttpd/lighttpd.conf

# Limit connections
server.max-connections = 20
server.max-worker = 2

# Enable compression (saves bandwidth)
compress.cache-dir = "/tmp/lighttpd/compress/"
compress.filetype = ("text/html", "text/plain", "text/css", "application/javascript")

# Static file caching
static-file.etags = "enable"
etag.use-inode = "disable"
etag.use-mtime = "enable"
etag.use-size = "enable"

# Reduce keepalive
server.max-keep-alive-requests = 4
server.max-keep-alive-idle = 5
```

### PHP Optimization

**Use FastCGI instead of CGI (better performance):**

```bash
# Install FastCGI
opkg install lighttpd-mod-fastcgi
opkg install php7-fastcgi

# Enable FastCGI
lighttpd-enable-mod fastcgi

# Configure in lighttpd.conf
fastcgi.server = ( ".php" =>
  (( "socket" => "/tmp/php-fastcgi.socket",
     "bin-path" => "/usr/bin/php-fcgi",
     "max-procs" => 2,
     "bin-environment" => (
       "PHP_FCGI_CHILDREN" => "1",
       "PHP_FCGI_MAX_REQUESTS" => "500"
     )
  ))
)
```

**PHP opcode caching:**

```bash
# Install OPcache
opkg install php7-mod-opcache

# Configure in php.ini
opcache.enable=1
opcache.memory_consumption=8
opcache.max_accelerated_files=200
```

### Database Optimization

**1. Optimize tables regularly:**

```bash
# Create optimization script
cat > /root/optimize-db.sh << 'EOF'
#!/bin/sh
mysqlcheck -u root -p --optimize --all-databases
EOF

chmod +x /root/optimize-db.sh

# Add to cron (weekly)
echo "0 3 * * 0 /root/optimize-db.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

**2. Use appropriate storage engines:**
- InnoDB: For transactional tables
- MyISAM: For read-heavy tables (lighter)

**3. Index properly:**
- Add indexes to frequently queried columns
- Don't over-index (increases write overhead)

### System-Wide Optimization

**Reduce logging:**

```bash
# In /etc/lighttpd/lighttpd.conf
server.errorlog = "/dev/null"
accesslog.filename = "/dev/null"

# In /etc/mysql/my.cnf
slow_query_log = 0
general_log = 0
```

**Use tmpfs for temporary files:**

```bash
# Already default in OpenWRT
# /tmp is mounted as tmpfs (RAM disk)
```

---

## Troubleshooting

### Web Server Won't Start

**Check configuration:**
```bash
# Test lighttpd config
lighttpd -t -f /etc/lighttpd/lighttpd.conf

# Check for errors
logread | grep lighttpd

# Verify port 80 is free
netstat -antp | grep :80
```

**Common issues:**
- Port 80 already in use (disable uHTTPd)
- Permission errors (check /www1 permissions)
- Configuration syntax errors

### PHP Not Working

**Check PHP-CGI:**
```bash
# Test PHP directly
php-cgi -v

# Check if PHP module loaded in lighttpd
cat /etc/lighttpd/lighttpd.conf | grep -i php

# Verify CGI module enabled
ls /etc/lighttpd/conf.d/ | grep cgi
```

**Test PHP error log:**
```bash
tail -f /var/log/php_errors.log
```

### Database Connection Errors

**Check MariaDB status:**
```bash
/etc/init.d/mysqld status
ps | grep mysql

# Try connecting manually
mysql -u root -p

# Check socket file
ls -l /var/run/mysqld.sock
```

**Common issues:**
- Wrong credentials in PHP
- Socket file missing (check my.cnf)
- Database not started
- mysqli module not installed

### Out of Memory Errors

**Check memory usage:**
```bash
free
top

# If low memory:
# - Reduce MySQL buffer sizes
# - Lower max_connections
# - Reduce PHP memory_limit
# - Use external swap
```

**Add swap on USB:**
```bash
# Create swap file
dd if=/dev/zero of=/mnt/usb/swapfile bs=1M count=512
chmod 600 /mnt/usb/swapfile
mkswap /mnt/usb/swapfile
swapon /mnt/usb/swapfile

# Make permanent
echo "/mnt/usb/swapfile none swap sw 0 0" >> /etc/fstab
```

### Slow Performance

**Identify bottleneck:**
```bash
# CPU usage
top

# Memory usage
free

# Disk I/O
iostat

# Database queries
# Enable slow query log in my.cnf
```

**Optimization steps:**
1. Use FastCGI instead of CGI
2. Enable OPcache
3. Optimize database queries
4. Add indexes to database
5. Reduce buffer sizes if low RAM
6. Use faster USB drive (USB 3.0)
7. Consider nginx instead of Lighttpd

---

## Use Cases

### Use Case 1: Home Automation Dashboard

**Simple web interface for IoT devices:**

```php
<?php
// Control GPIO pins, read sensors, display status
// Lightweight interface for home automation
?>
```

**Why OpenWRT LAMP:**
- Always-on device
- Low power consumption
- Local network access
- No cloud dependency

### Use Case 2: Network Status Monitor

**Display router statistics, connected devices, bandwidth usage:**

```bash
# Install additional packages
opkg install vnstat
opkg install collectd

# Create PHP dashboard showing:
# - Connected devices
# - Bandwidth usage
# - System resources
# - Network statistics
```

### Use Case 3: Personal Blog/Wiki

**Small personal website or documentation:**

```bash
# Install lightweight CMS
# - DokuWiki (no database required)
# - PmWiki
# - Pico CMS
```

**Limitations:**
- Max 5-10 concurrent visitors
- Static content preferred
- No large file uploads

### Use Case 4: Development/Testing

**Local PHP development environment:**

```bash
# Test PHP applications before deployment
# Learn web development
# Prototype applications
```

---

## Conclusion

Running a LAMP/LEMP stack on OpenWRT is possible but requires careful planning and resource management.

### Summary

✅ **Installation:**
- Use extroot for adequate storage
- Choose Lighttpd over Apache
- Install minimal PHP modules
- Configure MariaDB for low memory

✅ **Configuration:**
- Reduce buffer sizes for limited RAM
- Limit max connections
- Disable unnecessary logging
- Use FastCGI for better performance

✅ **Security:**
- Change default passwords
- Bind MySQL to localhost
- Disable dangerous PHP functions
- Use HTTPS when possible
- Restrict access by IP

✅ **Optimization:**
- Use opcode caching (OPcache)
- Enable compression
- Optimize database tables
- Monitor resource usage

### Best Practices

1. **Storage**: Always use external storage for database
2. **Memory**: Monitor RAM usage constantly
3. **Performance**: Keep applications simple and lightweight
4. **Security**: Harden all components
5. **Backups**: Regular backups to external media
6. **Monitoring**: Track resource usage and performance

### When NOT to Use OpenWRT LAMP

❌ **Don't use for:**
- High-traffic websites (>50 visitors/day)
- E-commerce platforms
- Large databases (>100MB)
- File upload services
- Video streaming
- Complex web applications
- Mission-critical applications

### Recommended Alternatives for Production

For serious web hosting, use:
- VPS (Virtual Private Server)
- Shared hosting
- Cloud platforms (AWS, DigitalOcean, etc.)
- Dedicated servers

### Resources

- OpenWRT Documentation: https://openwrt.org/docs/
- Lighttpd Documentation: https://www.lighttpd.net/
- MariaDB Documentation: https://mariadb.org/documentation/
- PHP Documentation: https://www.php.net/docs.php

---

*Document Version: 1.0*
*Last Updated: 2025*
*Based on: https://eko.one.pl/?p=openwrt-lamp*
*Compatible with: OpenWRT 19.07+*
*Use at your own risk - Not recommended for production environments*
