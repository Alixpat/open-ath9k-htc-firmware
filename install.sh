#!/bin/bash
# install.sh — Install patched AR9271 firmware
#
# Usage: ./install.sh [firmware_file]
#   firmware_file: path to .fw file (default: auto-detect from firmware/ dir)
#
# Supports both Debian (uncompressed .fw) and Ubuntu (.fw.zst) systems.
#
# The kernel loads firmware in this priority order:
#   1. .fw (uncompressed) — highest priority
#   2. .fw.zst
#   3. .fw.xz, .fw.gz
#
# On Ubuntu: stock firmware is .fw.zst, we install uncompressed .fw alongside.
# On Debian: stock firmware is .fw (uncompressed), we back it up then replace.
#
# To revert: sudo ./install.sh --restore

set -e

FW_DIR="/lib/firmware/ath9k_htc"
FW_NAME="htc_9271-1.4.0.fw"
FW_TARGET="${FW_DIR}/${FW_NAME}"
BACKUP_SUFFIX=".orig"

# Handle --restore
if [ "$1" = "--restore" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: Run as root (sudo $0 --restore)"
        exit 1
    fi
    restored=0
    # Restore uncompressed backup
    if [ -f "${FW_TARGET}${BACKUP_SUFFIX}" ]; then
        echo "Restoring ${FW_TARGET} from backup..."
        mv "${FW_TARGET}${BACKUP_SUFFIX}" "$FW_TARGET"
        restored=1
    # If no uncompressed backup, just remove our installed .fw (stock .zst will take over)
    elif [ -f "$FW_TARGET" ] && [ -f "${FW_TARGET}.zst" ]; then
        echo "Removing installed firmware (stock .zst will be used)..."
        rm "$FW_TARGET"
        restored=1
    fi
    # Restore compressed backups
    for ext in .zst .xz .gz; do
        if [ -f "${FW_TARGET}${ext}${BACKUP_SUFFIX}" ]; then
            echo "Restoring ${FW_TARGET}${ext} from backup..."
            mv "${FW_TARGET}${ext}${BACKUP_SUFFIX}" "${FW_TARGET}${ext}"
            restored=1
        fi
    done
    if [ "$restored" -eq 0 ]; then
        echo "No backups found to restore."
        exit 1
    fi
    echo "Reloading ath9k_htc..."
    modprobe -r ath9k_htc 2>/dev/null || true
    sleep 1
    modprobe ath9k_htc
    echo "Done. Stock firmware restored."
    exit 0
fi

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

# Detect what stock firmware exists
echo "Detecting stock firmware format..."
has_fw=0
has_compressed=0
if [ -f "$FW_TARGET" ]; then
    has_fw=1
    echo "  Found: $FW_TARGET ($(stat -c%s "$FW_TARGET") bytes)"
fi
for ext in .zst .xz .gz; do
    if [ -f "${FW_TARGET}${ext}" ]; then
        has_compressed=1
        echo "  Found: ${FW_TARGET}${ext} ($(stat -c%s "${FW_TARGET}${ext}") bytes)"
    fi
done

if [ "$has_fw" -eq 0 ] && [ "$has_compressed" -eq 0 ]; then
    echo "  No existing firmware found in $FW_DIR (fresh install)"
fi

# Backup existing firmware (only if not already backed up)
# Back up uncompressed .fw if it exists (Debian case)
if [ -f "$FW_TARGET" ] && [ ! -f "${FW_TARGET}${BACKUP_SUFFIX}" ]; then
    echo "Backing up $FW_TARGET -> ${FW_TARGET}${BACKUP_SUFFIX}"
    cp "$FW_TARGET" "${FW_TARGET}${BACKUP_SUFFIX}"
fi
# Back up any compressed variants (Ubuntu/other cases)
for ext in .zst .xz .gz; do
    if [ -f "${FW_TARGET}${ext}" ] && [ ! -f "${FW_TARGET}${ext}${BACKUP_SUFFIX}" ]; then
        echo "Backing up ${FW_TARGET}${ext} -> ${FW_TARGET}${ext}${BACKUP_SUFFIX}"
        cp "${FW_TARGET}${ext}" "${FW_TARGET}${ext}${BACKUP_SUFFIX}"
    fi
done

# Install (uncompressed .fw takes priority over all compressed variants)
cp "$FW_SRC" "$FW_TARGET"
echo ""
echo "Installed: $FW_TARGET"

# Reload module
echo "Reloading ath9k_htc..."
modprobe -r ath9k_htc 2>/dev/null || true
sleep 1
modprobe ath9k_htc

echo ""
echo "Done. Verify with: dmesg | grep ath9k_htc"
echo "Revert with: sudo $0 --restore"
