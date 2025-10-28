# Build Fix for OpenWrt 19.07.10 SDK

## Problem

The build script was failing when trying to compile `curl` dependency with the following error:

```
make: *** [/home/kerem/xe300-19.07.10-sdk/sdk/include/toplevel.mk:220: package/feeds/base/curl/compile] Error 2
```

Root cause: The `ca-certificates` package (a dependency of curl) was failing because it needed Python 2 (`python` command) but only Python 3 was installed on the build system.

## Solution

Modified `xe300-19.07.10/build-lpac.sh` to create a Python symlink in the SDK's host bin directory before compiling dependencies:

```bash
# Create python symlink for OpenWrt 19.07.10 (needs python, not python3)
mkdir -p staging_dir/host/bin
if [ ! -f "staging_dir/host/bin/python" ]; then
    ln -sf "$(which python3)" "staging_dir/host/bin/python" || log_warn "Could not create python symlink"
    export PATH="${SDK_DIR}/staging_dir/host/bin:$PATH"
    log_info "Created python -> python3 symlink for SDK build"
fi
```

This allows the OpenWrt 19.07.10 SDK build system to use Python 3 when it looks for the `python` command.

## Additional Fix

Also ensured the host's newer CMake (3.28.3) is used instead of the SDK's old CMake (3.15.1) since lpac requires CMake >= 3.23:

```bash
# Ensure we use host's CMake (not SDK's old CMake 3.15)
export PATH="/usr/bin:${PATH}"
```

## Build Results

- Binary: `lpac` (83KB stripped) - ELF 32-bit MSB MIPS executable
- IPK Package: `lpac_2.3.0-19_mips_24kc.ipk` (120KB)
- Architecture: MIPS 24Kc (GL-XE300 / OpenWrt 19.07.10)
- Driver: AT driver (Quectel modems)

## Files Modified

- `xe300-19.07.10/build-lpac.sh`:
  - Lines 198-204: Added Python symlink creation in `setup_dependencies()`
  - Lines 364-370: Added host CMake preference in `compile()`

## Testing

Build completed successfully:
```bash
bash xe300-19.07.10/build-lpac.sh
```

Output:
- Binary: `xe300-19.07.10/output/lpac`
- IPK: `xe300-19.07.10/output/lpac_2.3.0-19_mips_24kc.ipk`
- Drivers: `xe300-19.07.10/output/driver/*.so`
- Deploy script: `xe300-19.07.10/output/deploy.sh`

## Notes

This fix is specific to OpenWrt 19.07.10 SDK which uses old tooling that expects Python 2. Newer OpenWrt versions (21.02+) may not need this workaround.
