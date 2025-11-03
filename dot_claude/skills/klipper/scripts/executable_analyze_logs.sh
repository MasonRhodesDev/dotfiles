#!/bin/bash
# Klipper log analysis with error filtering and summary

set -e

# Source klipper helper functions
if [ -f ~/.claude/scripts/klipper-mount.sh ]; then
    source ~/.claude/scripts/klipper-mount.sh
else
    echo "Error: klipper-mount.sh not found"
    exit 1
fi

# Ensure remote access
ensure_klipper_access || exit 1

# Configuration
LINES=${1:-500}  # Default to last 500 lines, or use first argument
LOG_FILE="logs/klippy.log"

echo "Analyzing last $LINES lines of $LOG_FILE..."
echo "========================================"
echo ""

# Fetch log content
LOG_CONTENT=$(klipper_exec "tail -$LINES $LOG_FILE")

# Count different message types
ERROR_COUNT=$(echo "$LOG_CONTENT" | grep -ci "error" || true)
WARN_COUNT=$(echo "$LOG_CONTENT" | grep -ci "warn" || true)
MCU_COUNT=$(echo "$LOG_CONTENT" | grep -ci "mcu" || true)

echo "Summary:"
echo "--------"
echo "Errors:   $ERROR_COUNT"
echo "Warnings: $WARN_COUNT"
echo "MCU msgs: $MCU_COUNT"
echo ""

if [ $ERROR_COUNT -gt 0 ]; then
    echo "Errors found:"
    echo "-------------"
    echo "$LOG_CONTENT" | grep -i "error" | tail -10
    echo ""
fi

if [ $WARN_COUNT -gt 0 ]; then
    echo "Warnings found:"
    echo "---------------"
    echo "$LOG_CONTENT" | grep -i "warn" | tail -10
    echo ""
fi

# Check for specific common issues
echo "Common Issue Check:"
echo "-------------------"

if echo "$LOG_CONTENT" | grep -qi "bltouch"; then
    echo "✓ BLTouch messages detected"
fi

if echo "$LOG_CONTENT" | grep -qi "thermal runaway"; then
    echo "⚠ THERMAL RUNAWAY detected - check immediately!"
fi

if echo "$LOG_CONTENT" | grep -qi "lost communication"; then
    echo "⚠ MCU communication loss detected"
fi

if echo "$LOG_CONTENT" | grep -qi "endstop"; then
    echo "✓ Endstop messages detected"
fi

if echo "$LOG_CONTENT" | grep -qi "bed_mesh"; then
    echo "✓ Bed mesh messages detected"
fi

echo ""
echo "Analysis complete."
echo ""
echo "To view full log:"
echo "  klipper_read logs/klippy.log"
echo ""
echo "To search for specific terms:"
echo "  klipper_read logs/klippy.log | grep -i 'search_term'"
