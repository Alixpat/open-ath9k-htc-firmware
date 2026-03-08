#!/bin/bash
# install.sh — Install patched AR9271 firmware
#
# Usage: ./install.sh [firmware_file]
#   firmware_file: path to .fw file (default: auto-detect from firmware/ dir)
#
# The kernel loads firmware in this priority order:
#   1. .fw (uncompressed) — highest priority
#   2. .fw.zst
#   3. .fw.xz, .fw.gz
#
# We install the uncompressed .fw next to the stock .fw.zst.
# To revert: sudo rm /lib/firmware/ath9k_htc/htc_9271-1.4.0.fw

set -e

FW_DIR="/lib/firmware/ath9k_htc"
FW_TARGET="${FW_DIR}/htc_9271-1.4.0.fw"
FW_STOCK_ZST="${FW_DIR}/htc_9271-1.4.0.fw.zst"

# Find firmware file
if [ -n "$1" ]; then
    FW_SRC="$1"
else
    FW_SRC=$(ls -1 firmware/htc_9271-MCS*.fw 2>/dev/null | head -1)
fi

if [ -z "$FW_SRC" ] || [ ! -f "$FW_SRC" ]; then
    echo "ERROR: No firmware file found."
    echo "Usage: $0 [firmware_file]"
    echo "  or: run ./build.sh first"
    exit 1
fi

echo "=== AR9271 Firmware Install ==="
echo "  Source : $FW_SRC ($(stat -c%s "$FW_SRC") bytes)"
echo "  Target : $FW_TARGET"
echo ""

# Check running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Run as root (sudo $0 $*)"
    exit 1
fi

# Backup stock firmware (if not already done)
if [ -f "$FW_STOCK_ZST" ] && [ ! -f "${FW_STOCK_ZST}.backup" ]; then
    echo "Backing up stock firmware..."
    cp "$FW_STOCK_ZST" "${FW_STOCK_ZST}.backup"
fi

# Install (uncompressed .fw takes priority over .fw.zst)
cp "$FW_SRC" "$FW_TARGET"
echo "Installed: $FW_TARGET"

# Reload module
echo "Reloading ath9k_htc..."
modprobe -r ath9k_htc 2>/dev/null || true
sleep 1
modprobe ath9k_htc

echo ""
echo "Done. Verify with: dmesg | grep ath9k_htc"
echo "Revert with: sudo rm $FW_TARGET && sudo modprobe -r ath9k_htc && sudo modprobe ath9k_htc"
