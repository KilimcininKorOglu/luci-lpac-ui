# SSH Connection Fix for OpenWrt 19.07.10

## Problem

```
Unable to negotiate with 192.168.1.1 port 22: no matching host key type found. Their offer: ssh-rsa
scp: Connection closed
```

## Cause

Modern SSH clients (OpenSSH 8.8+) have disabled `ssh-rsa` algorithm by default, but OpenWrt 19.07.10 only supports this older algorithm.

## Solution

### Option 1: Add SSH Config (Recommended)

Create or edit `~/.ssh/config`:

```bash
nano ~/.ssh/config
```

Add this configuration:

```
Host 192.168.1.1
    HostKeyAlgorithms +ssh-rsa
    PubkeyAcceptedAlgorithms +ssh-rsa
    User root
```

Save and exit (Ctrl+X, Y, Enter).

Now try again:

```bash
scp diagnose-modem.sh root@192.168.1.1:/tmp/
ssh root@192.168.1.1
```

### Option 2: One-Time Command Line Fix

Use the `-o` option to enable ssh-rsa for a single command:

```bash
# For SCP
scp -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa \
    diagnose-modem.sh root@192.168.1.1:/tmp/

# For SSH
ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa \
    root@192.168.1.1
```

### Option 3: Use Windows Command (if in WSL)

If you're on WSL and have WinSCP or another Windows SSH client:

```bash
# Copy to Windows filesystem first
cp diagnose-modem.sh /mnt/c/Users/YourUsername/Downloads/

# Then use WinSCP or FileZilla to upload to router
```

## Quick Test

After applying the fix, test the connection:

```bash
ssh root@192.168.1.1 "echo Connection successful!"
```

If successful, you should see:
```
Connection successful!
```

## Copy All Files to Router

Once SSH is working:

```bash
# Copy diagnostic script
scp diagnose-modem.sh root@192.168.1.1:/tmp/

# Copy updated luci-app-lpac package
scp luci-app-lpac_1.0.1-5_all.ipk root@192.168.1.1:/tmp/

# Connect and run
ssh root@192.168.1.1
```

## Alternative: Use Web Interface

If SSH continues to have issues, use the LuCI web interface:

1. Open `http://192.168.1.1` in browser
2. Go to **System → Software → Upload Package**
3. Upload `luci-app-lpac_1.0.1-5_all.ipk`
4. Install the package

For the diagnostic script:
1. Go to **System → File Browser** (if available)
2. Or copy-paste the script content directly in SSH if you can connect
