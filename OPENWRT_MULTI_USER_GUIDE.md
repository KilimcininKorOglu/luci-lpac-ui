# OpenWRT Multi-User Account Management Guide

## Table of Contents
1. [Overview](#overview)
2. [Understanding OpenWRT User System](#understanding-openwrt-user-system)
3. [Default User Accounts](#default-user-accounts)
4. [User Account Types](#user-account-types)
5. [Prerequisites and Requirements](#prerequisites-and-requirements)
6. [Manual User Creation](#manual-user-creation)
7. [Using Shadow Utilities](#using-shadow-utilities)
8. [Group Management](#group-management)
9. [User Permissions and Access Control](#user-permissions-and-access-control)
10. [SSH Access Configuration](#ssh-access-configuration)
11. [Practical Examples](#practical-examples)
12. [Advanced Configuration](#advanced-configuration)
13. [Troubleshooting](#troubleshooting)
14. [Security Best Practices](#security-best-practices)
15. [References](#references)

---

## Overview

OpenWRT is a lightweight Linux distribution designed for embedded devices and routers. Unlike traditional Linux systems, OpenWRT is not inherently designed as a multi-user system. However, additional user accounts can be created for security isolation, service accounts, or administrative purposes.

**Key Points:**
- OpenWRT uses standard Linux user management files (`/etc/passwd`, `/etc/shadow`, `/etc/group`)
- Default installation runs most services as root
- Multi-user support requires manual configuration or optional packages
- User management differs between OpenWRT versions (Backfire vs. modern versions)

**Use Cases:**
- Creating separate administrative accounts
- Isolating services with dedicated user accounts
- Setting up SFTP/SSH users with restricted access
- Running daemons with limited privileges
- Educational or development environments

---

## Understanding OpenWRT User System

### Linux User Management Files

OpenWRT uses three primary files for user management:

#### 1. /etc/passwd
Stores user account information:
```
username:password:UID:GID:comment:home:shell
```

**Fields:**
- `username`: Account login name
- `password`: Password field (`*` or `x`)
  - `*` = No password set (older OpenWRT)
  - `x` = Password in /etc/shadow (modern OpenWRT)
- `UID`: User ID number (0 = root, 1-999 = system, 1000+ = regular users)
- `GID`: Primary group ID
- `comment`: User description (GECOS field)
- `home`: Home directory path
- `shell`: Login shell (`/bin/ash` for login, `/bin/false` for no login)

#### 2. /etc/shadow
Stores encrypted passwords (Attitude Adjustment and later):
```
username:encrypted_password:lastchange:min:max:warn:inactive:expire:reserved
```

**Fields:**
- `username`: Account name
- `encrypted_password`: Hashed password
- `lastchange`: Days since Jan 1, 1970 of last password change
- `min`: Minimum days between password changes
- `max`: Maximum days before password must be changed
- `warn`: Days before expiration to warn
- `inactive`: Days after expiration before account is disabled
- `expire`: Account expiration date
- `reserved`: Reserved field

#### 3. /etc/group
Stores group information:
```
groupname:password:GID:members
```

**Fields:**
- `groupname`: Group name
- `password`: Group password (usually `x` or `*`)
- `GID`: Group ID number
- `members`: Comma-separated list of usernames

### OpenWRT Version Differences

| Version | Shadow File | User Creation Method |
|---------|-------------|----------------------|
| Backfire (10.03) | No /etc/shadow | Only /etc/passwd entry needed |
| Attitude Adjustment (12.09+) | Uses /etc/shadow | Both /etc/passwd and /etc/shadow entries required |
| Modern (15.05+) | Uses /etc/shadow | Both files required + optional shadow-utils |

---

## Default User Accounts

### System Users

View existing users:
```bash
cat /etc/passwd
```

**Default accounts:**

1. **root**
   - UID: 0
   - Purpose: Superuser account
   - Login: Enabled (default shell: /bin/ash)
   - Used by: Most OpenWRT services and processes

2. **nobody**
   - UID: 65534
   - Purpose: Unprivileged user for services
   - Login: Disabled (/bin/false)
   - Used by: Services requiring minimal privileges

3. **daemon**
   - UID: 1-2 (varies)
   - Purpose: Background service account
   - Login: Disabled
   - Used by: System daemons

4. **ftp**
   - Purpose: FTP service account (if vsftpd installed)
   - Login: Disabled

5. **network**
   - Purpose: Network services
   - Login: Disabled
   - Used by: Network-related processes

### View Current Users

```bash
# List all users
cat /etc/passwd

# List only loginable users
grep -v '/bin/false' /etc/passwd

# Count total users
wc -l /etc/passwd

# View user groups
cat /etc/group
```

---

## User Account Types

### 1. Loginable Users

Users who can:
- Log in via SSH
- Access the shell
- Execute commands
- Manage files

**Characteristics:**
- Shell: `/bin/ash` (OpenWRT's default shell)
- Home directory: Typically `/tmp` or `/home/username`
- UID: Usually 1000+

### 2. Non-Loginable Users (Service Accounts)

Users who cannot:
- Log in interactively
- Access shell directly

**Characteristics:**
- Shell: `/bin/false` or `/sbin/nologin`
- Purpose: Run specific services or daemons
- UID: Usually 1-999

**Common uses:**
- Web server accounts
- Database services
- Application isolation

---

## Prerequisites and Requirements

### Storage Requirements

User accounts require minimal space, but consider:
- Each user entry: ~100 bytes
- Home directories: Variable (if not using /tmp)
- User files and data: Depends on usage

### Check Available Space

```bash
df -h
```

### Persistent Storage Recommendation

For production multi-user systems:
- Use overlay filesystem (default in OpenWRT)
- Consider external storage for /home directories
- Ensure sufficient flash space for configuration

### Required Files

```bash
# Verify essential files exist
ls -la /etc/passwd /etc/shadow /etc/group

# Create missing files if necessary
touch /etc/shadow
chmod 600 /etc/shadow
```

---

## Manual User Creation

### Method 1: Loginable User (Modern OpenWRT)

**For Attitude Adjustment (12.09) and later versions:**

```bash
# Create user "alice" with UID 1000
echo "alice:x:1000:65534:Alice User:/tmp:/bin/ash" >> /etc/passwd

# Create shadow entry
echo "alice:*:0:0:99999:7:::" >> /etc/shadow

# Set password
passwd alice
```

**Step-by-step breakdown:**

1. **Add /etc/passwd entry:**
   ```bash
   echo "alice:x:1000:65534:Alice User:/tmp:/bin/ash" >> /etc/passwd
   ```
   - `alice`: Username
   - `x`: Password stored in /etc/shadow
   - `1000`: User ID
   - `65534`: Group ID (nobody group)
   - `Alice User`: Full name/comment
   - `/tmp`: Home directory (volatile, cleared on reboot)
   - `/bin/ash`: Login shell

2. **Add /etc/shadow entry:**
   ```bash
   echo "alice:*:0:0:99999:7:::" >> /etc/shadow
   ```
   - `alice`: Username
   - `*`: No password set (will be changed by passwd)
   - `0`: Password changed today
   - `0`: No minimum age
   - `99999`: No maximum age
   - `7`: Warn 7 days before expiration
   - Empty fields: No inactive period, no expiration

3. **Set password:**
   ```bash
   passwd alice
   ```
   Enter and confirm the new password.

### Method 2: Loginable User (Backfire 10.03)

**For older Backfire version:**

```bash
# Create user with password placeholder
echo "alice:*:1000:65534:Alice User:/tmp:/bin/ash" >> /etc/passwd

# Set password
passwd alice
```

**Note:** Backfire doesn't use /etc/shadow, so password is stored in /etc/passwd.

### Method 3: Non-Loginable User (Service Account)

**Modern OpenWRT:**

```bash
# Create service account for web server
echo "www-data:x:1001:65534:Web Server:/var/www:/bin/false" >> /etc/passwd
echo "www-data:*:0:0:99999:7:::" >> /etc/shadow
```

**Key difference:** Shell is `/bin/false` to prevent interactive login.

### Method 4: User with Persistent Home Directory

```bash
# Create home directory
mkdir -p /home/bob
chown bob:nobody /home/bob
chmod 755 /home/bob

# Create user with /home directory
echo "bob:x:1002:65534:Bob User:/home/bob:/bin/ash" >> /etc/passwd
echo "bob:*:0:0:99999:7:::" >> /etc/shadow
passwd bob
```

### Automated User Creation Script

```bash
#!/bin/sh
# /usr/bin/create_user.sh - Create OpenWRT user account

create_user() {
    local username="$1"
    local fullname="$2"
    local uid="$3"
    local gid="${4:-65534}"  # Default to nobody group
    local home="${5:-/tmp}"
    local shell="${6:-/bin/ash}"

    # Check if user already exists
    if grep -q "^$username:" /etc/passwd; then
        echo "Error: User $username already exists"
        return 1
    fi

    # Add to /etc/passwd
    echo "$username:x:$uid:$gid:$fullname:$home:$shell" >> /etc/passwd

    # Add to /etc/shadow (if it exists)
    if [ -f /etc/shadow ]; then
        echo "$username:*:0:0:99999:7:::" >> /etc/shadow
    fi

    echo "User $username created successfully"
    echo "Set password with: passwd $username"
}

# Usage: create_user username "Full Name" UID [GID] [home] [shell]
# Example: create_user alice "Alice Smith" 1000
create_user "$@"
```

**Usage:**
```bash
chmod +x /usr/bin/create_user.sh

# Create loginable user
/usr/bin/create_user.sh alice "Alice Smith" 1000

# Create service account
/usr/bin/create_user.sh webapp "Web Application" 1001 65534 /var/www /bin/false
```

---

## Using Shadow Utilities

### Installation

For advanced user management, install shadow utilities:

```bash
opkg update
opkg install shadow-useradd shadow-userdel shadow-groupadd shadow-groupdel shadow-usermod
```

**Packages:**
- `shadow-useradd`: Add users
- `shadow-userdel`: Delete users
- `shadow-groupadd`: Add groups
- `shadow-groupdel`: Delete groups
- `shadow-usermod`: Modify users
- `shadow-passwd`: Password management (usually included)

### Using useradd

```bash
# Basic user creation
useradd -m -s /bin/ash alice

# Create user with specific UID and GID
useradd -u 1000 -g 100 -m -s /bin/ash bob

# Create system user (no home, no login)
useradd -r -s /bin/false webserver

# Create user with home directory and set password
useradd -m -s /bin/ash charlie
passwd charlie
```

**Common useradd options:**
- `-m`: Create home directory
- `-s SHELL`: Set login shell
- `-u UID`: Specify user ID
- `-g GID`: Specify primary group
- `-G GROUPS`: Additional groups (comma-separated)
- `-d HOME`: Home directory path
- `-c COMMENT`: User description
- `-r`: Create system account

### Using usermod

```bash
# Change user shell
usermod -s /bin/sh alice

# Add user to additional groups
usermod -G adm,sudo alice

# Change home directory
usermod -d /home/alice -m alice

# Lock user account
usermod -L alice

# Unlock user account
usermod -U alice

# Change UID
usermod -u 2000 alice
```

### Using userdel

```bash
# Delete user (keep home directory)
userdel alice

# Delete user and home directory
userdel -r alice

# Force delete even if logged in
userdel -f alice
```

### Using groupadd

```bash
# Create new group
groupadd developers

# Create group with specific GID
groupadd -g 1500 admins

# Create system group
groupadd -r services
```

### Using groupdel

```bash
# Delete group
groupdel developers
```

---

## Group Management

### Creating Groups Manually

```bash
# Add new group to /etc/group
echo "developers:x:1500:" >> /etc/group

# Add group with members
echo "admins:x:1501:alice,bob" >> /etc/group
```

### Default Groups

```bash
# View all groups
cat /etc/group
```

**Common groups:**
- `root` (GID 0): Root user group
- `nobody` (GID 65534): Unprivileged users
- `network` (GID 101): Network management
- `audio`, `video`, `storage`: Hardware access groups

### Adding Users to Groups

```bash
# Method 1: Edit /etc/group directly
# Change: developers:x:1500:
# To:     developers:x:1500:alice,bob

# Method 2: Using usermod (if shadow-usermod installed)
usermod -a -G developers alice

# Method 3: Using addgroup (if busybox-extra installed)
addgroup alice developers
```

### View User's Groups

```bash
# Show groups for current user
groups

# Show groups for specific user
groups alice

# Detailed group membership
id alice
```

### Group-Based Access Control Example

```bash
# Create admin group
groupadd -g 1500 admins

# Add users to admin group
usermod -a -G admins alice
usermod -a -G admins bob

# Set directory permissions for admin group
mkdir /etc/admin-config
chgrp admins /etc/admin-config
chmod 770 /etc/admin-config

# Now only root and admins group can access
```

---

## User Permissions and Access Control

### File Ownership

```bash
# Change file owner
chown alice /path/to/file

# Change owner and group
chown alice:developers /path/to/file

# Recursive ownership change
chown -R alice:developers /home/alice
```

### Directory Permissions

```bash
# Give user access to specific directory
mkdir /var/user_data
chown alice:nobody /var/user_data
chmod 755 /var/user_data  # rwxr-xr-x
```

### Sudo Configuration

Install and configure sudo:

```bash
opkg install sudo

# Create sudoers file
cat > /etc/sudoers <<'EOF'
# User privilege specification
root    ALL=(ALL:ALL) ALL

# Allow alice to run all commands
alice   ALL=(ALL:ALL) ALL

# Allow bob to run specific commands without password
bob     ALL=(ALL) NOPASSWD: /sbin/wifi, /sbin/reboot

# Allow admins group full access
%admins ALL=(ALL:ALL) ALL
EOF

# Set correct permissions
chmod 440 /etc/sudoers
```

### Process Ownership

Run processes as specific user:

```bash
# Run command as user
su -c "command" alice

# Start service as user
start-stop-daemon -S -c alice:nobody -x /usr/bin/service
```

---

## SSH Access Configuration

### Enable SSH for Users

Edit `/etc/config/dropbear` (OpenWRT's SSH server):

```bash
uci set dropbear.@dropbear[0].PasswordAuth='on'
uci set dropbear.@dropbear[0].RootPasswordAuth='on'
uci set dropbear.@dropbear[0].Port='22'
uci commit dropbear
/etc/init.d/dropbear restart
```

### SSH Key Authentication

```bash
# Create .ssh directory for user
mkdir -p /home/alice/.ssh
chmod 700 /home/alice/.ssh

# Add authorized keys
cat > /home/alice/.ssh/authorized_keys <<'EOF'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... alice@laptop
EOF

chmod 600 /home/alice/.ssh/authorized_keys
chown -R alice:nobody /home/alice/.ssh
```

### Restrict SSH Access

```bash
# Allow only specific users (using OpenSSH)
echo "AllowUsers root alice bob" >> /etc/ssh/sshd_config

# Deny specific users
echo "DenyUsers guest test" >> /etc/ssh/sshd_config

# For Dropbear (OpenWRT default), use firewall rules or PAM
```

### SFTP-Only Users

```bash
# Create SFTP-only user
useradd -m -s /bin/false sftpuser
passwd sftpuser

# Create upload directory
mkdir -p /home/sftpuser/upload
chown sftpuser:nobody /home/sftpuser/upload

# Configure Dropbear or OpenSSH for SFTP chroot (advanced)
```

---

## Practical Examples

### Example 1: Web Developer Account

```bash
# Create developer user with home directory
useradd -m -s /bin/ash -c "Web Developer" webdev
passwd webdev

# Create web directory
mkdir -p /var/www/html
chown -R webdev:nobody /var/www/html

# Add to www-data group (if exists)
usermod -a -G www-data webdev

# Allow SSH access with key
mkdir -p /home/webdev/.ssh
cat > /home/webdev/.ssh/authorized_keys <<EOF
ssh-rsa AAAAB3Nza... developer@workstation
EOF
chown -R webdev:nobody /home/webdev/.ssh
chmod 700 /home/webdev/.ssh
chmod 600 /home/webdev/.ssh/authorized_keys
```

### Example 2: Database Service Account

```bash
# Create non-loginable database user
useradd -r -s /bin/false -c "MySQL Service" mysql

# Create database directory
mkdir -p /var/lib/mysql
chown mysql:nobody /var/lib/mysql
chmod 700 /var/lib/mysql

# Run MySQL as mysql user (in init script)
start-stop-daemon -S -c mysql:nobody -x /usr/bin/mysqld
```

### Example 3: Guest User with Limited Access

```bash
# Create guest account
useradd -m -s /bin/ash -c "Guest User" guest
echo "guest:guest123" | chpasswd

# Restrict to specific directory
mkdir -p /home/guest/sandbox
chown guest:nobody /home/guest/sandbox

# Limit resource usage (if shell supports)
cat > /home/guest/.profile <<'EOF'
# Limited environment
export PATH=/usr/bin:/bin
ulimit -f 10240  # Max file size 10MB
ulimit -u 10     # Max 10 processes
EOF
```

### Example 4: Admin User with Sudo

```bash
# Create admin user
useradd -m -s /bin/ash -c "System Administrator" sysadmin
passwd sysadmin

# Install and configure sudo
opkg install sudo

# Add to sudoers
echo "sysadmin ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Test sudo access
su - sysadmin
sudo wifi status
```

### Example 5: Multiple Users for Family Router

```bash
#!/bin/sh
# Setup family members with individual accounts

# Parents with admin access
create_family_user() {
    local name="$1"
    local uid="$2"
    local admin="$3"

    useradd -u $uid -m -s /bin/ash -c "$name" $name
    echo "$name:changeme123" | chpasswd

    if [ "$admin" = "yes" ]; then
        usermod -a -G admins $name
    fi

    echo "Created user: $name (UID: $uid, Admin: $admin)"
}

# Create admin group
groupadd -g 1500 admins

# Create family accounts
create_family_user "dad" 1000 yes
create_family_user "mom" 1001 yes
create_family_user "alice" 1002 no
create_family_user "bob" 1003 no

echo "Family accounts created. Default password: changeme123"
echo "Users should change passwords immediately."
```

---

## Advanced Configuration

### User Quota Management

Install quota tools:
```bash
opkg install quota-tools

# Enable quotas on filesystem (if supported)
# Note: Limited support on embedded systems
```

### PAM Configuration

For advanced authentication (if PAM available):
```bash
opkg install libpam

# Configure PAM modules in /etc/pam.d/
```

### Centralized Authentication (LDAP)

```bash
# Install LDAP client
opkg install libnss-ldap libpam-ldap

# Configure /etc/ldap.conf
# Configure /etc/nsswitch.conf
```

### User Environment Customization

```bash
# System-wide profile
cat > /etc/profile.d/custom.sh <<'EOF'
# Custom environment for all users
export EDITOR=vi
alias ll='ls -la'
EOF

# Per-user profile
cat > /home/alice/.profile <<'EOF'
# Alice's custom environment
export PS1='\u@\h:\w\$ '
alias update='opkg update'
EOF
```

### Login Banner

```bash
# Set login banner
cat > /etc/banner <<'EOF'
 _____________________________________
|                                     |
|  Welcome to OpenWRT Router          |
|  Unauthorized access prohibited     |
|_____________________________________|

EOF

# Set pre-login message
cat > /etc/motd <<'EOF'
System Status:
- Last login: Check /var/log/
- Security updates: Run opkg update
EOF
```

---

## Troubleshooting

### User Cannot Log In

**Problem:** Created user cannot SSH into router.

**Solutions:**

1. **Verify user exists:**
   ```bash
   grep username /etc/passwd
   ```

2. **Check password is set:**
   ```bash
   passwd username
   ```

3. **Verify shell is valid:**
   ```bash
   grep username /etc/passwd
   # Should show /bin/ash, not /bin/false
   ```

4. **Check SSH configuration:**
   ```bash
   uci show dropbear
   # Ensure PasswordAuth is enabled
   ```

5. **Check shadow file permissions:**
   ```bash
   ls -la /etc/shadow
   # Should be: -rw------- (600)
   chmod 600 /etc/shadow
   ```

### Password Changes Not Persisting

**Problem:** Password resets after reboot.

**Solution:**
```bash
# Ensure changes are committed to persistent storage
sync

# Verify overlay filesystem
df -h | grep overlay

# If overlay is full, free up space
opkg remove unused-package
```

### UID/GID Conflicts

**Problem:** User creation fails due to duplicate UID.

**Solution:**
```bash
# Check existing UIDs
cut -d: -f3 /etc/passwd | sort -n

# Use next available UID
NEXT_UID=$(awk -F: '{print $3}' /etc/passwd | sort -n | tail -1)
NEW_UID=$((NEXT_UID + 1))
useradd -u $NEW_UID newuser
```

### Permission Denied Errors

**Problem:** User cannot access files or directories.

**Solutions:**

1. **Check file ownership:**
   ```bash
   ls -la /path/to/file
   chown username:group /path/to/file
   ```

2. **Check permissions:**
   ```bash
   chmod 644 /path/to/file  # rw-r--r--
   chmod 755 /path/to/dir   # rwxr-xr-x
   ```

3. **Check group membership:**
   ```bash
   groups username
   usermod -a -G requiredgroup username
   ```

### Shadow Utils Not Working

**Problem:** useradd command not found.

**Solution:**
```bash
# Install shadow utilities
opkg update
opkg install shadow-useradd

# If still not found, check PATH
echo $PATH
export PATH=$PATH:/usr/sbin
```

---

## Security Best Practices

### 1. Disable Root SSH Login

```bash
# Edit Dropbear config
uci set dropbear.@dropbear[0].RootPasswordAuth='off'
uci commit dropbear
/etc/init.d/dropbear restart

# Create admin user with sudo instead
```

### 2. Use Strong Passwords

```bash
# Install password quality checker
opkg install libpwquality

# Generate strong password
dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 | head -c 16
```

### 3. Implement Account Lockout

```bash
# After 3 failed login attempts (if PAM available)
# Edit /etc/pam.d/common-auth
auth required pam_tally2.so deny=3 unlock_time=600
```

### 4. Regular Audit

```bash
# Check for unauthorized users
cat /etc/passwd

# Review sudo access
cat /etc/sudoers

# Check last logins
last

# Monitor active sessions
who
```

### 5. Principle of Least Privilege

```bash
# Run services as dedicated users, not root
# Create service-specific accounts
# Grant minimal necessary permissions
```

### 6. Remove Unused Accounts

```bash
# Delete old or unused accounts
userdel -r olduser

# Lock inactive accounts instead of deleting
usermod -L inactiveuser
```

### 7. Secure Home Directories

```bash
# Ensure home directories have correct permissions
chmod 700 /home/username

# Prevent other users from reading files
umask 077
```

---

## References

### Official Documentation
- **OpenWRT User Guide:** https://openwrt.org/docs/guide-user/
- **Linux User Management:** https://www.kernel.org/doc/html/latest/admin-guide/

### Related Pages
- **eko.one.pl OpenWRT Multi-User:** https://eko.one.pl/?p=openwrt-multiuser
- **OpenWRT Security:** https://openwrt.org/docs/guide-user/security/

### Tools and Packages
- **shadow-utils:** https://github.com/shadow-maint/shadow
- **BusyBox adduser:** https://busybox.net/
- **Dropbear SSH:** https://matt.ucc.asn.au/dropbear/dropbear.html

### Community Resources
- **OpenWRT Forum:** https://forum.openwrt.org/
- **eko.one.pl Forum:** https://eko.one.pl/forum/

---

## Summary

Multi-user account management in OpenWRT provides:

**Key Capabilities:**
- Create loginable and non-loginable users
- Service account isolation
- Group-based access control
- SSH/SFTP user management

**Manual Method (Modern OpenWRT):**
```bash
echo "username:x:UID:GID:Comment:/home:/bin/ash" >> /etc/passwd
echo "username:*:0:0:99999:7:::" >> /etc/shadow
passwd username
```

**Using Shadow Utilities:**
```bash
opkg install shadow-useradd shadow-usermod
useradd -m -s /bin/ash username
passwd username
```

**Important Considerations:**
- OpenWRT is not designed for extensive multi-user environments
- Storage limitations on embedded devices
- Most services run as root by default
- Security hardening required for production use

**Best Practices:**
- Use strong passwords
- Disable root SSH login
- Implement sudo for administrative tasks
- Regular security audits
- Minimal privilege principle

**Version-Specific Notes:**
- Backfire (10.03): Only /etc/passwd required
- Attitude Adjustment (12.09+): Both /etc/passwd and /etc/shadow required
- Modern versions: Support shadow-utils for enhanced management

---

*This guide is based on the eko.one.pl OpenWRT multi-user documentation and standard Linux user management practices.*
