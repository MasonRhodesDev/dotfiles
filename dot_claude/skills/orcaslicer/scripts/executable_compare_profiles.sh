#!/bin/bash
# Compare two OrcaSlicer profiles with readable diff output

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <profile1.json> <profile2.json>"
    echo ""
    echo "Examples:"
    echo "  $0 \"profile1.json\" \"profile2.json\""
    echo "  $0 ~/.config/OrcaSlicer/user/default/process/[E3V2]\ 0.20mm\ Structural.json \\"
    echo "     ~/.config/OrcaSlicer/system/Creality/process/0.20mm\ Standard\ @Creality\ Ender3V2.json"
    exit 1
fi

PROFILE1="$1"
PROFILE2="$2"

# Check files exist
if [ ! -f "$PROFILE1" ]; then
    echo "Error: Profile 1 not found: $PROFILE1"
    exit 1
fi

if [ ! -f "$PROFILE2" ]; then
    echo "Error: Profile 2 not found: $PROFILE2"
    exit 1
fi

# Check jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed"
    echo "Install with: sudo dnf install jq"
    exit 1
fi

echo "Comparing profiles:"
echo "  Profile 1: $(basename "$PROFILE1")"
echo "  Profile 2: $(basename "$PROFILE2")"
echo ""

# Extract profile names from JSON
NAME1=$(jq -r '.name // "Unknown"' "$PROFILE1")
NAME2=$(jq -r '.name // "Unknown"' "$PROFILE2")

echo "  Name 1: $NAME1"
echo "  Name 2: $NAME2"
echo ""

# Check for inheritance
INHERITS1=$(jq -r '.inherits // "None"' "$PROFILE1")
INHERITS2=$(jq -r '.inherits // "None"' "$PROFILE2")

echo "Inheritance:"
echo "  $NAME1 inherits: $INHERITS1"
echo "  $NAME2 inherits: $INHERITS2"
echo ""

# Create sorted JSON for comparison
TEMP1=$(mktemp)
TEMP2=$(mktemp)
trap "rm -f \"$TEMP1\" \"$TEMP2\"" EXIT

jq -S . "$PROFILE1" > "$TEMP1"
jq -S . "$PROFILE2" > "$TEMP2"

# Check if identical
if diff -q "$TEMP1" "$TEMP2" > /dev/null; then
    echo "✓ Profiles are identical"
    exit 0
fi

echo "Differences found:"
echo "=================="
echo ""

# Show side-by-side diff with color if possible
if command -v colordiff &> /dev/null; then
    diff -u "$TEMP1" "$TEMP2" | colordiff | tail -n +3 || true
else
    diff -u "$TEMP1" "$TEMP2" | tail -n +3 || true
fi

echo ""
echo "Legend:"
echo "  - lines: Only in Profile 1 ($NAME1)"
echo "  + lines: Only in Profile 2 ($NAME2)"
echo ""

# Count differences
ADDED=$(diff "$TEMP1" "$TEMP2" | grep "^>" | wc -l)
REMOVED=$(diff "$TEMP1" "$TEMP2" | grep "^<" | wc -l)

echo "Summary: $REMOVED settings removed, $ADDED settings added"
