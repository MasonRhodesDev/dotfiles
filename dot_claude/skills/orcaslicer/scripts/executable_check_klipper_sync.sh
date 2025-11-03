#!/bin/bash
# Check OrcaSlicer and Klipper G-code sync status

set -e

echo "OrcaSlicer / Klipper G-code Sync Checker"
echo "========================================="
echo ""

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed"
    echo "Install with: sudo dnf install jq"
    exit 1
fi

# Source klipper helper functions
if [ -f ~/.claude/scripts/klipper-mount.sh ]; then
    source ~/.claude/scripts/klipper-mount.sh
else
    echo "Warning: klipper-mount.sh not found"
    echo "Cannot access remote Klipper config"
    KLIPPER_AVAILABLE=false
fi

# OrcaSlicer machine profile path
MACHINE_PROFILE="$HOME/.config/OrcaSlicer/user/default/machine/[E3V2] Ender-3 V2.json"

if [ ! -f "$MACHINE_PROFILE" ]; then
    echo "Error: E3V2 machine profile not found at:"
    echo "  $MACHINE_PROFILE"
    exit 1
fi

echo "1. Checking OrcaSlicer Configuration"
echo "------------------------------------"

# Extract G-code from OrcaSlicer profile
START_GCODE=$(jq -r '.machine_start_gcode // "Not found"' "$MACHINE_PROFILE")
END_GCODE=$(jq -r '.machine_end_gcode // "Not found"' "$MACHINE_PROFILE")
PRINT_HOST=$(jq -r '.print_host // "Not configured"' "$MACHINE_PROFILE")
GCODE_FLAVOR=$(jq -r '.gcode_flavor // "Not specified"' "$MACHINE_PROFILE")

echo "Print Host: $PRINT_HOST"
echo "G-code Flavor: $GCODE_FLAVOR"
echo ""

echo "Start G-code:"
echo "$START_GCODE"
echo ""

echo "End G-code:"
echo "$END_GCODE"
echo ""

# Extract macro calls
START_MACROS=$(echo "$START_GCODE" | grep -oE '[A-Z_]+' | sort -u)
END_MACROS=$(echo "$END_GCODE" | grep -oE '[A-Z_]+' | sort -u)

echo "Macros called at start: $START_MACROS"
echo "Macros called at end: $END_MACROS"
echo ""

# Check if Klipper is available
if [ "$KLIPPER_AVAILABLE" != "false" ]; then
    if ensure_klipper_access; then
        echo "2. Checking Klipper Configuration"
        echo "---------------------------------"

        # Check if macros exist in Klipper
        for macro in $START_MACROS $END_MACROS; do
            if [ "$macro" = "G28" ] || [ "$macro" = "G29" ] || [ "$macro" = "G0" ] || [ "$macro" = "G1" ]; then
                # Skip standard G-codes
                continue
            fi

            echo -n "Checking macro: $macro... "

            if klipper_exec "grep -r \"gcode_macro $macro\" config/" > /dev/null 2>&1; then
                echo "✓ Found"
            else
                echo "✗ NOT FOUND"
            fi
        done
        echo ""

        # Check START_PRINT macro details if it exists
        if echo "$START_MACROS" | grep -q "START_PRINT"; then
            echo "3. Analyzing START_PRINT Macro"
            echo "-------------------------------"

            START_PRINT_CONTENT=$(klipper_exec "cat config/klipper-macros/start_end.cfg" 2>/dev/null | grep -A 30 "\[gcode_macro START_PRINT\]" || echo "Cannot read macro")

            if [ "$START_PRINT_CONTENT" != "Cannot read macro" ]; then
                # Extract parameter names from macro definition
                MACRO_PARAMS=$(echo "$START_PRINT_CONTENT" | grep -oE "params\.[A-Z_]+" | sed 's/params\.//' | sort -u)

                echo "Macro parameters defined: $MACRO_PARAMS"

                # Extract parameters from OrcaSlicer G-code
                SLICER_PARAMS=$(echo "$START_GCODE" | grep "START_PRINT" | grep -oE '[A-Z_]+=' | sed 's/=//' | sort -u)

                echo "Slicer sends parameters: $SLICER_PARAMS"
                echo ""

                # Check for mismatches
                MISMATCH=false
                for param in $SLICER_PARAMS; do
                    if ! echo "$MACRO_PARAMS" | grep -q "$param"; then
                        echo "⚠ Warning: Slicer sends $param but macro doesn't use it"
                        MISMATCH=true
                    fi
                done

                for param in $MACRO_PARAMS; do
                    if ! echo "$SLICER_PARAMS" | grep -q "$param"; then
                        echo "⚠ Warning: Macro expects $param but slicer doesn't send it"
                        MISMATCH=true
                    fi
                done

                if [ "$MISMATCH" = "false" ]; then
                    echo "✓ Parameters match between OrcaSlicer and Klipper"
                fi
            else
                echo "Cannot read START_PRINT macro from Klipper config"
            fi
            echo ""
        fi

        # Check print host IP
        echo "4. Checking Network Configuration"
        echo "----------------------------------"

        ORCA_IP=$(echo "$PRINT_HOST" | cut -d':' -f1)
        ORCA_PORT=$(echo "$PRINT_HOST" | cut -d':' -f2)

        echo "OrcaSlicer connects to: $ORCA_IP:$ORCA_PORT"
        echo "Klipper SSH host: printer@192.168.1.216"
        echo ""

        echo -n "Testing Moonraker API... "
        if curl -s "http://$ORCA_IP:$ORCA_PORT/server/info" > /dev/null 2>&1; then
            echo "✓ Reachable"
        else
            echo "✗ Cannot connect"
            echo "  Check that printer is on and Moonraker is running"
        fi
        echo ""

    else
        echo "Cannot access Klipper (ensure_klipper_access failed)"
        echo "Skipping Klipper configuration checks"
        echo ""
    fi
fi

echo "5. Recommendations"
echo "------------------"

echo "✓ Use 'klipper' G-code flavor: $([ "$GCODE_FLAVOR" = "klipper" ] && echo "YES" || echo "NO - change to klipper")"
echo "✓ START_PRINT macro exists: $(echo "$START_MACROS" | grep -q "START_PRINT" && echo "Called" || echo "NOT CALLED")"
echo "✓ END_PRINT macro exists: $(echo "$END_MACROS" | grep -q "END_PRINT" && echo "Called" || echo "NOT CALLED")"
echo ""

if [ "$GCODE_FLAVOR" != "klipper" ]; then
    echo "⚠ Recommendation: Set gcode_flavor to 'klipper' in machine profile"
fi

if ! echo "$START_MACROS" | grep -q "START_PRINT"; then
    echo "⚠ Recommendation: Use START_PRINT macro instead of raw G-code"
fi

echo ""
echo "Sync check complete."
