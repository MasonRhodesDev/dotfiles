#!/bin/bash

# Modular environment-based theme toggle
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$HOME/.cache/theme_state"
WALLPAPER_PATH="$HOME/Pictures/forrest.png"
MODULES_DIR="$SCRIPT_DIR/modules"
LOCKFILE="/tmp/theme-toggle.lock"

# Check if another instance is running
if [ -f "$LOCKFILE" ]; then
    echo "Theme toggle already running, exiting..."
    exit 0
fi

# Create lockfile and ensure it's removed on exit
touch "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT INT TERM

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

# Generate matugen colors JSON for the new mode
echo "Generating Material You colors from wallpaper..."
COLORS_JSON=$(matugen --json hex --dry-run image "$WALLPAPER_PATH" --mode "$MATUGEN_MODE" --type scheme-expressive)

# Check if matugen succeeded
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to generate colors with matugen"
    exit 1
fi

echo "Applying themes to installed applications..."

# Create arrays to store module information
declare -a modules
declare -a pids
declare -A module_names
declare -A pid_to_module

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
            run_module_with_timing "$module" "$module_name" "$WALLPAPER_PATH" "$NEW_STATE" "$STATE_FILE" "$COLORS_JSON"
        else
            echo "Warning: ${module_name}_apply_theme function not found in $module"
        fi
    ) &
    
    pid=$!
    pids+=($pid)
    pid_to_module["$pid"]="$module_name"
done

# Wait for all modules to complete with timeout
TIMEOUT=10  # 10 seconds timeout
SLEEP_INTERVAL=0.1

echo "Waiting for modules to complete (timeout: ${TIMEOUT}s)..."
echo "Started ${#pids[@]} background processes with PIDs: ${pids[*]}"

# Global timeout - track elapsed time across all processes
start_time=$(date +%s.%N)

while true; do
    # Check if any processes are still running
    running_pids=()
    for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            running_pids+=("$pid")
        fi
    done
    
    # If no processes running, we're done
    if [[ ${#running_pids[@]} -eq 0 ]]; then
        echo "All modules completed normally"
        break
    fi
    
    # Check global timeout
    current_time=$(date +%s.%N)
    elapsed=$(echo "$current_time - $start_time" | bc -l)
    
    if (( $(echo "$elapsed >= $TIMEOUT" | bc -l) )); then
        echo "⚠️  Global timeout of ${TIMEOUT}s exceeded, killing remaining modules..."
        for pid in "${running_pids[@]}"; do
            module_name="${pid_to_module["$pid"]}"
            echo "⚠️  Killing '$module_name' (PID $pid)"
            kill -TERM "$pid" 2>/dev/null || true
        done
        
        # Give processes 0.5s to terminate gracefully
        sleep 0.5
        
        # Force kill any remaining processes
        for pid in "${running_pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                module_name="${pid_to_module["$pid"]}"
                kill -KILL "$pid" 2>/dev/null || true
                echo "⚠️  Force killed '$module_name' (PID $pid)"
            fi
        done
        break
    fi
    
    sleep $SLEEP_INTERVAL
done

echo ""
echo "Theme switched to $NEW_STATE mode!"
echo "All applications should automatically detect the theme change."
echo "Script exiting..."
exit 0