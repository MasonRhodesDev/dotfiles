#!/bin/bash

# Modular environment-based theme toggle
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$HOME/.cache/theme_state"
WALLPAPER_PATH="$HOME/Pictures/forrest.png"
MODULES_DIR="$SCRIPT_DIR/modules"

# Source base functions
source "$MODULES_DIR/base.sh"

# Check if specific mode was provided as argument
if [[ $# -eq 1 && ($1 == "dark" || $1 == "light") ]]; then
    NEW_STATE="$1"
    MATUGEN_MODE="$1"
    echo "Setting to $NEW_STATE mode using modular approach..."
else
    # Toggle mode based on current state
    CURRENT_STATE=$(get_theme_state "$STATE_FILE")
    
    if [ "$CURRENT_STATE" = "light" ]; then
        NEW_STATE="dark"
        MATUGEN_MODE="dark"
    else
        NEW_STATE="light" 
        MATUGEN_MODE="light"
    fi
    
    echo "Switching to $NEW_STATE mode using modular approach..."
fi

# Update state file
echo "$NEW_STATE" > "$STATE_FILE"

# Generate matugen colors for the new mode (always regenerate base colors)
echo "Generating Material You colors from wallpaper..."
matugen image "$WALLPAPER_PATH" --mode "$MATUGEN_MODE" --type scheme-expressive

# Check if matugen succeeded
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to generate colors with matugen"
    exit 1
fi

echo "Applying themes to installed applications..."

# Create array to store module information
declare -a modules
declare -a pids
declare -A module_names

# Collect modules (excluding base.sh)
for module in "$MODULES_DIR"/*.sh; do
    if [[ "$(basename "$module")" == "base.sh" ]]; then
        continue
    fi
    
    module_name=$(basename "$module" .sh)
    modules+=("$module")
    module_names["$module"]="$module_name"
done

# Run modules in parallel with performance monitoring
for module in "${modules[@]}"; do
    module_name="${module_names[$module]}"
    
    # Run module in background with timing
    (
        # Source base functions in subshell
        source "$MODULES_DIR/base.sh"
        
        # Check if module function exists
        source "$module"
        if declare -f "${module_name}_apply_theme" >/dev/null; then
            run_module_with_timing "$module" "$module_name" "$WALLPAPER_PATH" "$NEW_STATE" "$STATE_FILE"
        else
            echo "Warning: ${module_name}_apply_theme function not found in $module"
        fi
    ) &
    
    pids+=($!)
done

# Wait for all modules to complete and collect results
for pid in "${pids[@]}"; do
    wait "$pid"
done

echo ""
echo "Theme switched to $NEW_STATE mode!"
echo "All applications should automatically detect the theme change."