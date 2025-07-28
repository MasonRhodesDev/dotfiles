#!/bin/bash

# Check if another instance is running and replace it
check_running_instance() {
    # Get the PID of the current script
    CURRENT_PID=$$
    
    # Find other instances of this script
    SCRIPT_NAME=$(basename "$0")
    OTHER_PIDS=$(pgrep -f "$SCRIPT_NAME" | grep -v "$CURRENT_PID" || true)
    
    if [ -n "$OTHER_PIDS" ]; then
        echo "Found other instances of $SCRIPT_NAME (PIDs: $OTHER_PIDS). This PID: $CURRENT_PID. Exiting..." >&2
        exit 0;
    fi
}

# Run the check at startup
check_running_instance

MONITOR_DESC="Dell Inc. DELL S3422DWG HSRTS63"
CONF_FILE="$HOME/.config/hypr/configs/monitors.conf"

BUILT_IN_MONITOR="eDP-2"

# Store the last known best mode
LAST_BEST_MODE=""

# Function to get the best mode for the monitor
get_best_mode() {
    # Check if the monitor is connected first
    if ! hyprctl monitors -j | jq -e --arg desc "$MONITOR_DESC" '.[] | select(.description == $desc)' > /dev/null; then
        echo "Monitor not connected or not found" >&2
        return 1
    fi

    # Get the available modes - more verbose for debugging
    echo "Fetching modes for $MONITOR_DESC..." >&2
    modes_json=$(hyprctl monitors -j | jq --arg desc "$MONITOR_DESC" '.[] | select(.description == $desc) | .availableModes')
    
    if [ "$modes_json" = "null" ] || [ -z "$modes_json" ]; then
        echo "No modes found for monitor" >&2
        return 1
    fi
    
    echo "Available modes:" >&2
    echo "$modes_json" | jq -r '.[]' >&2
    
    # Parse modes and find the best one
    best_mode=$(echo "$modes_json" | jq -r '.[]' | awk -F'[@x]' '
    {
        width = $1;
        height = $2;
        gsub(/Hz/, "", $3);
        rate = $3;
        
        # Calculate score (resolution * refresh rate)
        score = width * height * rate;
        
        # Keep track of the highest score
        if (score > max_score) {
            max_score = score;
            best_mode = $0;
        }
    }
    END {
        print best_mode;
    }')
    
    echo "Selected best mode: $best_mode" >&2
    echo "$best_mode"
}

# Function to get the monitor name from hyprctl
get_monitor_name() {
    hyprctl monitors -j | jq -r --arg desc "$MONITOR_DESC" '.[] | select(.description == $desc) | .name'
}

# Function to format the mode string correctly
format_mode_string() {
    local mode="$1"
    # Check if the mode already has the correct format (contains 'x' and '@')
    if [[ "$mode" == *x*@* ]]; then
        echo "$mode"
    else
        # Try to parse and reformat
        local width height rate
        read -r width height rate <<< $(echo "$mode" | awk '{print $1, $2, $3}')
        if [[ -n "$width" && -n "$height" && -n "$rate" ]]; then
            echo "${width}x${height}@${rate}"
        else
            # Return original if parsing fails
            echo "$mode"
        fi
    fi
}

# Function to set the primary monitor using xrandr and GTK settings
set_primary_monitor() {
    local monitor_name="$1"
    if [ -n "$monitor_name" ]; then
        echo "Setting $monitor_name as primary monitor..." >&2
        sleep 1  # Wait for 1 second before running xrandr
        
        # Set as X11 primary monitor
        xrandr --output "$monitor_name" --primary
        echo "X11 primary monitor set to $monitor_name" >&2
        
        # Set as Hyprland/Wayland primary monitor
        hyprctl keyword monitor "$monitor_name,preferred,auto,1,mirror,$BUILT_IN_MONITOR"
        hyprctl dispatch focusmonitor "$monitor_name"
        echo "Hyprland primary monitor set to $monitor_name" >&2
        
        # Set workspace 1 to this monitor to make it the default
        hyprctl keyword workspace "1, monitor:$monitor_name, default:true"
        echo "Set workspace 1 as default on $monitor_name" >&2
        
        # Set as GTK primary monitor
        if command -v gsettings &> /dev/null; then
            # Get the current monitor configuration
            current_monitors=$(hyprctl monitors -j | jq -r '.[].name' | tr '\n' ',' | sed 's/,$//')
            
            # Set the primary monitor for GTK applications
            gsettings set org.gnome.desktop.interface primary-monitor "$monitor_name"
            echo "GTK primary monitor set to $monitor_name" >&2
            
            # Additional GTK settings that might help with primary monitor recognition
            gsettings set org.gnome.mutter.dynamic-workspaces true
            gsettings set org.gnome.desktop.wm.preferences focus-new-windows 'smart'
            
            # Set the monitor configuration for GTK
            if [ -n "$current_monitors" ]; then
                gsettings set org.gnome.settings-daemon.plugins.xrandr active-monitors "[$current_monitors]"
                echo "GTK monitor configuration updated" >&2
            fi
        else
            echo "gsettings not found, skipping GTK primary monitor configuration" >&2
        fi
    else
        echo "Could not determine monitor name for primary monitor settings" >&2
    fi
}

# Function to update the monitor configuration
update_monitor_config() {
    local best_mode=$(get_best_mode)
    local status=$?
    
    if [ $status -eq 0 ] && [ -n "$best_mode" ]; then
        # Format the mode string correctly
        best_mode=$(format_mode_string "$best_mode")
        
        # Check if the mode has changed
        if [ "$best_mode" != "$LAST_BEST_MODE" ]; then
            echo "Found new best mode: $best_mode (previous: $LAST_BEST_MODE)" >&2
            LAST_BEST_MODE="$best_mode"
            
            # Check if the marker exists in the file
            if grep -q "^#####  Generated by monitors.sh #####$" "$CONF_FILE"; then
                # Create a temporary file with the updated content
                {
                    # Process the file line by line
                    marker_found=0
                    while IFS= read -r line; do
                        # If we find the marker, print it and add our config
                        if [[ "$line" == "#####  Generated by monitors.sh #####" ]]; then
                            echo "$line"
                            echo "monitor = desc:$MONITOR_DESC,$best_mode,0x0,1,bitdepth,10,vrr,2"
                            marker_found=1
                        # Skip old monitor config lines after the marker
                        elif [[ $marker_found -eq 1 && "$line" == "monitor = desc:$MONITOR_DESC"* ]]; then
                            continue
                        # Skip xrandr command line as we'll add it later
                        elif [[ "$line" == "exec = xrandr --output"* ]]; then
                            continue
                        # Print all other lines
                        else
                            echo "$line"
                        fi
                    done < "$CONF_FILE"
                    
                    # If marker wasn't found, add it at the end
                    if [[ $marker_found -eq 0 ]]; then
                        echo ""
                        echo "#####  Generated by monitors.sh #####"
                        echo "monitor = desc:$MONITOR_DESC,$best_mode,0x0,1,bitdepth,10,vrr,2"
                    fi
                } > "$CONF_FILE.tmp"
                
                # Replace the original file
                mv "$CONF_FILE.tmp" "$CONF_FILE"
            else
                # Marker doesn't exist, append it and the configuration
                echo -e "\n#####  Generated by monitors.sh #####" >> "$CONF_FILE"
                echo "monitor = desc:$MONITOR_DESC,$best_mode,0x0,1,bitdepth,10,vrr,2" >> "$CONF_FILE"
            fi
            
            # Reload Hyprland configuration
            hyprctl reload
            echo "Configuration updated with new mode: $best_mode" >&2
            
            # Get the monitor name and set it as primary
            local monitor_name=$(get_monitor_name)
            set_primary_monitor "$monitor_name"
        else
            echo "Mode unchanged: $best_mode" >&2
        fi
    else
        echo "Could not determine best mode for monitor (status: $status)" >&2
        # Try to get all monitors for debugging
        echo "Available monitors:" >&2
        hyprctl monitors -j | jq -r '.[] | .description' >&2
    fi
}

# Force update on startup
echo "Forcing initial configuration update..." >&2
update_monitor_config

# Get the Hyprland Instance Signature
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    echo "HYPRLAND_INSTANCE_SIGNATURE is not set. Make sure Hyprland is running." >&2
    exit 1
fi

# Use the correct socket path according to Hyprland documentation
SOCKET_PATH="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

if [ ! -e "$SOCKET_PATH" ]; then
    echo "Socket not found at $SOCKET_PATH. Make sure Hyprland is running." >&2
    exit 1
fi

echo "Using Hyprland socket: $SOCKET_PATH" >&2

# Handle events function
handle_event() {
    local event="$1"
    echo "Event received: $event" >&2
    
    case "$event" in
        monitoradded*|monitorremoved*|monitoraddedv2*|configreloaded*)
            echo "Monitor change detected, checking configuration..." >&2
            sleep 1  # Give the system a moment to recognize the monitor
            update_monitor_config
            ;;
    esac
}

# Set up udev monitor for display changes
setup_udev_monitor() {
    # Monitor for drm (Direct Rendering Manager) events which are related to display changes
    udevadm monitor --udev --subsystem-match=drm | while read -r line; do
        echo "udev display event detected: $line" >&2
        if echo "$line" | grep -q "change"; then
            sleep 1  # Give the system a moment to recognize the monitor
            update_monitor_config
        fi
    done
}

# Start udev monitor in background
setup_udev_monitor &
UDEV_MONITOR_PID=$!

# Cleanup function to kill background processes on exit
cleanup() {
    echo "Cleaning up..." >&2
    kill $UDEV_MONITOR_PID 2>/dev/null
    exit 0
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# Watch for Hyprland events using the recommended approach from the documentation
socat -U - UNIX-CONNECT:"$SOCKET_PATH" | while read -r line; do
    handle_event "$line"
done
