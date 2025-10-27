# eSIM lpac Quectel Modem Patching Guide

## Table of Contents
1. [Overview](#overview)
2. [Why Patching is Needed](#why-patching-is-needed)
3. [Prerequisites](#prerequisites)
4. [Understanding the Issues](#understanding-the-issues)
5. [Patch 1: AT Command Driver](#patch-1-at-command-driver)
6. [Patch 2: Transmission Size Reduction](#patch-2-transmission-size-reduction)
7. [Complete Patching Procedure](#complete-patching-procedure)
8. [Building lpac After Patching](#building-lpac-after-patching)
9. [Verification](#verification)
10. [Alternative: Using lpac-quectel Fork](#alternative-using-lpac-quectel-fork)
11. [Troubleshooting](#troubleshooting)
12. [Future Status](#future-status)
13. [References](#references)

---

## Overview

This guide explains the necessary patches required to use **lpac** (Local Profile Assistant Client) with **Quectel modems** for eSIM profile management. Stock lpac has compatibility issues with Quectel modems that cause unreliable AT command transmission and buffer overflow problems.

**Two patches required:**
1. **AT Command Driver patch** - Improves AT command reliability
2. **Transmission Size Reduction** - Prevents buffer overflow

**Affected Quectel Modems:**
- EC25 series
- EM12 series
- RM500Q series
- Other Quectel modems with eSIM/eUICC support

---

## Why Patching is Needed

### Problem 1: Unreliable AT Commands

**Symptoms:**
- AT+APDU commands timeout or fail
- Inconsistent eUICC responses
- Profile download failures
- Sporadic communication errors

**Root Cause:**
- Quectel modems handle AT+APDU commands differently
- Timing issues in stock lpac AT driver
- Need specific handling for Quectel firmware

### Problem 2: Buffer Overflow

**Symptoms:**
- Large APDU commands fail
- Profile download aborts mid-transfer
- "Modem busy" or timeout errors

**Root Cause:**
- Quectel modem buffers are smaller than default lpac assumes
- Large segments overflow modem's AT command buffer
- Need to reduce Maximum Segment Size (MSS)

---

## Prerequisites

### Required Tools

```bash
# Git for repository management
git

# Build tools
cmake
make
gcc

# lpac dependencies
libpcsclite-dev
libcurl4-openssl-dev

# Text editor
vim  # or nano, emacs, etc.

# Patch utility (optional)
patch
```

### Knowledge Requirements

- Basic C programming understanding (to review patches)
- Git usage (cloning, branches, merging)
- Text file editing
- Building software from source

---

## Understanding the Issues

### AT Command Timing

**Normal lpac behavior:**
1. Send AT+APDU command
2. Wait for response
3. Parse response

**Quectel-specific issue:**
- Needs longer timeouts
- Requires specific command formatting
- May need retry logic

### Buffer Size Constraints

**Default lpac MSS:** ~250+ bytes
**Quectel modem buffer:** Limited capacity
**Result:** Commands overflow buffer, modem rejects or corrupts data

**Solution:** Reduce MSS to 60 bytes
- Smaller chunks
- Slower but reliable
- No buffer overflow

---

## Patch 1: AT Command Driver

### Understanding the Patch

**File to modify:** `drivers/at.c`

**Changes needed:**
- Improved AT command formatting
- Better timeout handling
- Quectel-specific workarounds

### Option A: Manual Patch from Fork

**Step 1: View differences**

**lpac-quectel fork:** Available but not officially documented in source

The guide mentions merging from `lpac-quectel` fork but doesn't provide a direct link. Based on the lpac ecosystem:

```bash
# Clone official lpac
git clone https://github.com/estkme-group/lpac.git lpac-official
cd lpac-official

# Add Quectel fork as remote (if available)
# Note: Actual fork URL may vary - check lpac GitHub issues/forks
git remote add quectel https://github.com/[quectel-fork-author]/lpac.git
git fetch quectel

# View differences
git diff HEAD quectel/main -- drivers/at.c
```

**Step 2: Apply changes manually**

Open `drivers/at.c` in your editor and make necessary modifications based on the diff.

### Option B: Patch File Approach

**If patch file available (future):**

```bash
# Download patch file
wget https://example.com/lpac-quectel-at-driver.patch

# Apply patch
cd lpac
patch -p1 < lpac-quectel-at-driver.patch
```

### Manual Modifications (Example Pattern)

**Common changes needed in `drivers/at.c`:**

```c
// Example: Increase timeout for Quectel modems
// Original:
#define AT_TIMEOUT_MS 1000

// Modified:
#define AT_TIMEOUT_MS 3000  // Longer timeout for Quectel

// Example: Add retry logic
// Original:
if (send_at_command(cmd) != 0) {
    return -1;
}

// Modified:
int retries = 3;
while (retries > 0) {
    if (send_at_command(cmd) == 0) {
        break;
    }
    retries--;
    usleep(100000);  // Wait 100ms before retry
}
if (retries == 0) {
    return -1;
}

// Example: Flush buffer before command (Quectel-specific)
// Add before AT command:
tcflush(fd, TCIOFLUSH);  // Clear input/output buffers
```

**Note:** Actual patch content varies. Check lpac-quectel fork or GitHub issues for specific changes.

---

## Patch 2: Transmission Size Reduction

### File to Modify

**File:** `euicc/euicc.c`

**Parameter:** `ctx->es10x_mss`

### Locate the Code

**Open file:**

```bash
cd lpac
vim euicc/euicc.c
# or
nano euicc/euicc.c
```

**Search for MSS setting:**

```bash
# In vim:
/es10x_mss

# Or search manually for line containing:
ctx->es10x_mss =
```

### Original Code

**Default value (approximately):**

```c
// Original - default MSS value
ctx->es10x_mss = 244;  // or similar large value
```

**Location context:**
```c
int euicc_init(struct euicc_ctx *ctx)
{
    // ... initialization code ...

    // Maximum Segment Size for ES10x commands
    ctx->es10x_mss = 244;  // ← FIND THIS LINE

    // ... more initialization ...
}
```

### Modified Code

**Change to:**

```c
// Modified for Quectel modems
ctx->es10x_mss = 60;
```

**Complete modified section:**

```c
int euicc_init(struct euicc_ctx *ctx)
{
    // ... initialization code ...

    // Maximum Segment Size for ES10x commands
    // Reduced to 60 for Quectel modem compatibility
    ctx->es10x_mss = 60;

    // ... more initialization ...
}
```

### Save Changes

```bash
# Save and exit (vim)
:wq

# Save and exit (nano)
Ctrl+X, Y, Enter
```

---

## Complete Patching Procedure

### Step-by-Step Instructions

```bash
# 1. Clone lpac repository
cd ~/esim-tools
git clone https://github.com/estkme-group/lpac.git
cd lpac

# 2. PATCH 1: AT Command Driver
# Note: Manual merge from lpac-quectel fork needed
# Option A: If you have access to Quectel fork
git remote add quectel [QUECTEL_FORK_URL]
git fetch quectel
git diff HEAD quectel/main -- drivers/at.c > at-driver.patch
# Review patch
cat at-driver.patch
# Apply manually or use patch tool
patch -p1 < at-driver.patch

# Option B: Manual editing
vim drivers/at.c
# Make Quectel-specific modifications
# (See example patterns above)

# 3. PATCH 2: Transmission Size Reduction
vim euicc/euicc.c
# Find: ctx->es10x_mss = [original_value];
# Change to: ctx->es10x_mss = 60;

# 4. Verify changes
grep -n "es10x_mss" euicc/euicc.c
# Should show:
# [line_number]:    ctx->es10x_mss = 60;

# 5. Check diff (optional)
git diff

# 6. Ready to build
# (See next section)
```

---

## Building lpac After Patching

### Configure and Build

```bash
# Still in lpac directory

# Configure with AT APDU support
cmake . -DLPAC_WITH_APDU_AT=1

# Build
make

# Verify binary created
ls -lh output/lpac
```

**Expected output:**

```
-rwxr-xr-x 1 user user 2.5M Oct 15 14:30 output/lpac
```

### Test Build

```bash
# Test help
output/lpac --help

# Test chip info (if modem connected)
export LPAC_APDU=at
export AT_DEVICE=/dev/ttyUSB2
output/lpac chip info
```

---

## Verification

### Verify Patch 1 (AT Driver)

**Test AT command communication:**

```bash
# Stop ModemManager
sudo systemctl stop ModemManager

# Set environment
export LPAC_APDU=at
export AT_DEVICE=/dev/ttyUSB2

# Test chip info multiple times
for i in {1..5}; do
    echo "Test $i:"
    output/lpac chip info | jq -r '.eidValue'
done
```

**Expected:** Consistent EID value all 5 times (no failures)

### Verify Patch 2 (MSS Reduction)

**Test profile download:**

```bash
# Attempt profile download
output/lpac profile download -s "smdp.io" -m "TEST-ACTIVATION-CODE"
```

**Expected:** Download proceeds without buffer overflow errors

**Check for success indicators:**
- No "modem busy" errors
- No timeout errors
- Profile downloads completely

### Functional Test

**Complete test sequence:**

```bash
#!/bin/bash
# test-quectel-patches.sh

export LPAC_APDU=at
export AT_DEVICE=/dev/ttyUSB2

echo "=== Test 1: Chip Info (5 times) ==="
for i in {1..5}; do
    echo -n "Attempt $i: "
    if output/lpac chip info > /dev/null 2>&1; then
        echo "OK"
    else
        echo "FAILED"
    fi
done

echo ""
echo "=== Test 2: List Profiles ==="
output/lpac profile list | jq

echo ""
echo "=== Test 3: Get EID ==="
output/lpac chip info | jq -r '.eidValue'

echo ""
echo "All tests completed"
```

**Run test:**
```bash
chmod +x test-quectel-patches.sh
./test-quectel-patches.sh
```

---

## Alternative: Using lpac-quectel Fork

### If Fork is Available

**Instead of patching manually, use pre-patched fork:**

```bash
# Clone Quectel-specific fork (if available)
git clone https://github.com/[quectel-fork-author]/lpac.git lpac-quectel
cd lpac-quectel

# Patches already applied in fork
# Build directly
cmake . -DLPAC_WITH_APDU_AT=1
make
```

**Advantages:**
- Patches already integrated
- Tested configuration
- Community support

**Check for fork:**
- Browse lpac GitHub forks
- Search GitHub for "lpac quectel"
- Check lpac issues for community forks

---

## Troubleshooting

### Patch 1 Issues

**Problem:** Can't find lpac-quectel fork

**Solution:**
- Check lpac GitHub issues for Quectel discussions
- Search for community forks
- Apply manual modifications based on error patterns

**Problem:** AT commands still unreliable after patch

**Solutions:**

1. **Increase timeout further:**
   ```c
   #define AT_TIMEOUT_MS 5000  // Try even longer
   ```

2. **Add more retries:**
   ```c
   int retries = 5;  // More attempts
   ```

3. **Check modem firmware version:**
   ```bash
   echo -e "ATI\r" | sudo tee /dev/ttyUSB2
   # Ensure latest Quectel firmware
   ```

### Patch 2 Issues

**Problem:** Profile download still fails with large segments

**Solution:**

1. **Reduce MSS further:**
   ```c
   ctx->es10x_mss = 40;  // Even smaller
   ```

2. **Try incremental values:**
   - Start at 60
   - If fails, try 50
   - Then 40
   - Find optimal balance

**Problem:** Downloads extremely slow

**Solution:**
- MSS of 60 is optimal
- Too small (e.g., 20) causes excessive overhead
- Balance between reliability and speed

### Build Issues

**Problem:** Compilation errors after patching

**Solutions:**

1. **Check syntax:**
   ```bash
   # Verify C syntax
   gcc -fsyntax-only drivers/at.c
   ```

2. **Revert and retry:**
   ```bash
   git checkout drivers/at.c euicc/euicc.c
   # Re-apply patches carefully
   ```

3. **Clean build:**
   ```bash
   make clean
   rm -rf CMakeCache.txt CMakeFiles/
   cmake . -DLPAC_WITH_APDU_AT=1
   make
   ```

---

## Future Status

### Upstream Integration

**Current status (per documentation):**
- Patches are temporary workaround
- TODO: Create proper patch file
- TODO: Push changes upstream to main lpac

**Expected future:**
- Quectel patches merged into official lpac
- No manual patching needed
- Automatic Quectel modem detection

### Checking for Updates

```bash
# Update your lpac repository
cd lpac
git fetch origin
git log --oneline origin/main | head -10

# Look for Quectel-related commits
git log --grep="quectel" --grep="at.c" --all

# Check issues for Quectel support status
# Visit: https://github.com/estkme-group/lpac/issues
```

### Contributing

**If you improve patches:**
- Open pull request to lpac repository
- Document Quectel-specific behavior
- Share patch files with community

---

## References

### Official Resources

**lpac Repository:**
- Main: https://github.com/estkme-group/lpac
- Issues: https://github.com/estkme-group/lpac/issues

**Original Guide:**
- Soprani.ca Wiki: https://wiki.soprani.ca/eSIM%20Adapter/lpac%20via%20USB%20modem/PatchingForQuectel

### Related Documentation

- lpac AT APDU driver documentation
- Quectel AT command manual
- eUICC/SGP.22 specifications

### Community

- lpac GitHub Discussions
- OpenWRT Forum (eSIM topics)
- Quectel Forums

---

## Summary

Quectel modems require two patches for reliable lpac operation:

**Patch 1: AT Command Driver (`drivers/at.c`)**
- Improves command reliability
- Better timeout handling
- Quectel-specific workarounds
- Source: lpac-quectel fork (merge needed)

**Patch 2: MSS Reduction (`euicc/euicc.c`)**
- Change: `ctx->es10x_mss = 60;`
- Prevents buffer overflow
- Smaller segments for Quectel modem limits

**Quick Patch Procedure:**

```bash
# Clone lpac
git clone https://github.com/estkme-group/lpac.git
cd lpac

# Patch 1: Merge from lpac-quectel fork
# (or apply manual AT driver improvements)

# Patch 2: Edit euicc/euicc.c
vim euicc/euicc.c
# Change: ctx->es10x_mss = 60;

# Build
cmake . -DLPAC_WITH_APDU_AT=1
make

# Test
export LPAC_APDU=at AT_DEVICE=/dev/ttyUSB2
output/lpac chip info
```

**Status:**
- Temporary patches required
- Future: Will be integrated upstream
- Check lpac repository for updates

These patches enable reliable eSIM profile management on Quectel modems via lpac.

---

*This guide is based on the Soprani.ca wiki documentation and lpac project development status.*
