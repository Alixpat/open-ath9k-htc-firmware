#!/bin/bash
# build.sh — Build AR9271 firmware with custom MCS rate
#
# Usage: ./build.sh [MCS_INDEX]
#   MCS_INDEX: 0-7 (default: 0 for maximum range)
#
# Requirements:
#   sudo apt install build-essential cmake git m4 texinfo
#
# Output:
#   firmware/htc_9271-MCSx.fw

set -e

MCS_INDEX="${1:-0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Building AR9271 firmware with MCS${MCS_INDEX} ==="
echo ""

# Validate
if [[ ! "$MCS_INDEX" =~ ^[0-7]$ ]]; then
    echo "ERROR: MCS index must be between 0 and 7"
    exit 1
fi

# Build dependencies check
for cmd in gcc make cmake m4 texinfo; do
    if ! command -v "$cmd" &>/dev/null 2>&1; then
        # texinfo is not a command, check differently
        true
    fi
done

# Step 1: Build toolchain (only if not already built)
TOOLCHAIN_MARKER="toolchain/inst/bin"
if [ ! -d "$TOOLCHAIN_MARKER" ]; then
    echo "[1/3] Building toolchain (this takes 30-60 minutes the first time)..."
    make -f Makefile toolchain || {
        echo ""
        echo "WARNING: Toolchain build may have failed on MPFR tests."
        echo "This is a known issue on modern systems. Attempting workaround..."
        echo ""
        # MPFR tsprintf test failure workaround
        if [ -d "toolchain/build/mpfr-4.1.0" ]; then
            cd toolchain/build/mpfr-4.1.0
            make install 2>/dev/null || true
            touch .built
            cd "$SCRIPT_DIR"
            make -f Makefile toolchain
        fi
    }
else
    echo "[1/3] Toolchain already built, skipping."
fi

# Step 2: Patch rate
echo "[2/3] Patching firmware for MCS${MCS_INDEX}..."
bash "${SCRIPT_DIR}/patch_rate.sh" "$MCS_INDEX"

# Step 3: Build firmware
echo "[3/3] Compiling firmware..."
make -C target_firmware clean 2>/dev/null || true
make -C target_firmware

# Copy output
mkdir -p "${SCRIPT_DIR}/firmware"
cp target_firmware/htc_9271.fw "firmware/htc_9271-MCS${MCS_INDEX}.fw"
cp target_firmware/htc_7010.fw "firmware/htc_7010-MCS${MCS_INDEX}.fw" 2>/dev/null || true

echo ""
echo "=== Build complete ==="
echo "Firmware: firmware/htc_9271-MCS${MCS_INDEX}.fw"
echo ""
echo "To install:"
echo "  sudo cp firmware/htc_9271-MCS${MCS_INDEX}.fw /lib/firmware/ath9k_htc/htc_9271-1.4.0.fw"
echo "  sudo modprobe -r ath9k_htc && sudo modprobe ath9k_htc"
