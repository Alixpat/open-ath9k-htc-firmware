#!/bin/bash
# patch_rate.sh — Patch AR9271 firmware to force a specific MCS rate for injection
#
# Usage: ./patch_rate.sh [MCS_INDEX]
#   MCS_INDEX: 0-7 (default: 0 for maximum range)
#
# MCS Rate Table (HT20, single stream):
#   MCS0 =  6.5 Mbit/s  (BPSK,   1/2) — max range, ~2-3 Mbit/s useful
#   MCS1 = 13.0 Mbit/s  (QPSK,   1/2) — good range, ~5-6 Mbit/s useful
#   MCS2 = 19.5 Mbit/s  (QPSK,   3/4) — balanced
#   MCS3 = 26.0 Mbit/s  (16-QAM, 1/2) — default in most wifibroadcast builds
#   MCS4 = 39.0 Mbit/s  (16-QAM, 3/4) — short range, high throughput
#   MCS5 = 52.0 Mbit/s  (64-QAM, 2/3) — very short range
#   MCS6 = 58.5 Mbit/s  (64-QAM, 3/4) — very short range
#   MCS7 = 65.0 Mbit/s  (64-QAM, 5/6) — minimum range, max throughput

set -e

MCS_INDEX="${1:-0}"
FW_SRC="target_firmware/wlan/if_owl.c"

# Validate MCS index
if [[ ! "$MCS_INDEX" =~ ^[0-7]$ ]]; then
    echo "ERROR: MCS index must be between 0 and 7"
    echo "Usage: $0 [MCS_INDEX]"
    exit 1
fi

# Rate index (rix) mapping from ar5416Phy.c rate table
# Index 12 = MCS0, 13 = MCS1, ..., 22 = MCS7 (with some gaps for HGI variants)
declare -A MCS_TO_RIX=(
    [0]="0x0c"   # index 12 — MCS0  6.5 Mb  BPSK
    [1]="0x0d"   # index 13 — MCS1   13 Mb  QPSK
    [2]="0x0e"   # index 14 — MCS2 19.5 Mb  QPSK
    [3]="0x0f"   # index 15 — MCS3   26 Mb  16-QAM
    [4]="0x10"   # index 16 — MCS4   39 Mb  16-QAM
    [5]="0x12"   # index 18 — MCS5   52 Mb  64-QAM (skip HGI index 17)
    [6]="0x14"   # index 20 — MCS6 58.5 Mb  64-QAM (skip HGI index 19)
    [7]="0x16"   # index 22 — MCS7   65 Mb  64-QAM (skip HGI index 21)
)

declare -A MCS_TO_RATE=(
    [0]="6.5"  [1]="13"   [2]="19.5" [3]="26"
    [4]="39"   [5]="52"   [6]="58.5" [7]="65"
)

RIX="${MCS_TO_RIX[$MCS_INDEX]}"
RATE="${MCS_TO_RATE[$MCS_INDEX]}"

if [ ! -f "$FW_SRC" ]; then
    echo "ERROR: $FW_SRC not found. Run this script from the firmware repo root."
    exit 1
fi

echo "=== AR9271 Firmware Rate Patch ==="
echo "  MCS index : $MCS_INDEX"
echo "  Rate      : ${RATE} Mbit/s (HT20)"
echo "  rix value : $RIX"
echo ""

# Check if already patched
if grep -q "PATCHED_MCS" "$FW_SRC"; then
    echo "WARNING: File already patched, reverting first..."
    git checkout -- "$FW_SRC" 2>/dev/null || true
fi

# Patch the multicast/injection rate in if_owl.c
# Stock firmware uses rix = 0xb (54 Mb OFDM legacy)
# Goodwin patch uses rix = 0x0f (MCS3 26 Mb)
# We replace with the selected MCS
sed -i "s/bf->bf_rcs\[0\]\.rix   = 0x[0-9a-fA-F]\+;/bf->bf_rcs[0].rix   = ${RIX}; \/\/ PATCHED_MCS${MCS_INDEX} = ${RATE}Mb/" "$FW_SRC"

# Verify
if grep -q "PATCHED_MCS${MCS_INDEX}" "$FW_SRC"; then
    echo "OK: Patched successfully"
    grep "PATCHED_MCS" "$FW_SRC"
else
    echo "ERROR: Patch failed!"
    exit 1
fi
