#!/bin/bash

# Theme restoration script for Hyprland reload
# Restores the last applied theme or defaults to dark mode

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$HOME/.cache/theme_state"
THEME_SWITCHER="$SCRIPT_DIR/theme-toggle-modular.sh"

# Function to get the current theme state with fallback
get_theme_with_fallback() {
    if [[ -f "$STATE_FILE" ]]; then
        local current_state=$(cat "$STATE_FILE" 2>/dev/null | tr -d '\n\r' | tr '[:upper:]' '[:lower:]')
        
        # Validate the state is either light or dark
        if [[ "$current_state" == "light" || "$current_state" == "dark" ]]; then
            echo "$current_state"
            return 0
        fi
    fi
    
    # Fallback to dark and create state file
    echo "dark" > "$STATE_FILE"
    echo "dark"
}

# Main execution
main() {
    echo "Theme restore: Checking current theme state..."
    
    THEME_MODE=$(get_theme_with_fallback)
    
    echo "Theme restore: Applying $THEME_MODE theme"
    
    # Call the main theme switcher with the determined mode
    if [[ -x "$THEME_SWITCHER" ]]; then
        "$THEME_SWITCHER" "$THEME_MODE"
        exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            echo "Theme restore: Successfully applied $THEME_MODE theme"
        else
            echo "Theme restore: Error applying theme (exit code: $exit_code)"
        fi
    else
        echo "Theme restore: Error - Theme switcher not found or not executable: $THEME_SWITCHER"
        exit 1
    fi
}

# Run main function
main "$@"