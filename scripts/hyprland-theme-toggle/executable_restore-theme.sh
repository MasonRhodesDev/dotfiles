#!/bin/bash

# Theme restoration script - run at login to restore last theme state

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$HOME/.cache/theme_state"
MODULES_DIR="$SCRIPT_DIR/modules"

# Source base functions
source "$MODULES_DIR/base.sh"

# Get the last theme state
if [[ -f "$STATE_FILE" ]]; then
    CURRENT_STATE=$(cat "$STATE_FILE" 2>/dev/null | tr -d '\n' | head -1)
else
    CURRENT_STATE="dark"  # Default to dark mode
fi

# Validate state
if [[ "$CURRENT_STATE" != "light" && "$CURRENT_STATE" != "dark" ]]; then
    CURRENT_STATE="dark"
fi

echo "Restoring theme state: $CURRENT_STATE"

# Apply the current state without toggling
"$SCRIPT_DIR/theme-toggle-modular.sh" "$CURRENT_STATE"