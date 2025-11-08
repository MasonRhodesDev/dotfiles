#!/bin/bash

# Steam Window Manager for Hyprland
# Listens to window open events and manages Steam window sizes

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

handle_event() {
    local event="$1"

    case "$event" in
        openwindow*)
            # Event format: openwindow>>ADDRESS,WORKSPACENAME,CLASS,TITLE
            local data="${event#openwindow>>}"
            local address="${data%%,*}"
            local rest="${data#*,}"
            local workspace="${rest%%,*}"
            rest="${rest#*,}"
            local class="${rest%%,*}"
            local title="${rest#*,}"

            # Handle Steam Friends List
            if [[ "$class" == "steam" && "$title" == "Friends List" ]]; then
                echo "Detected Friends List opening: $address"
                sleep 0.5  # Brief delay to let window fully initialize

                # Friends List should be the active window when it opens
                # Move it left first (swaps position with window to its left)
                hyprctl dispatch movewindow l
                echo "Moved Friends List to the left"

                sleep 0.2

                # Then resize the active window to 400px width
                hyprctl dispatch resizeactive exact 400 100%
                echo "Resized Friends List to 400px width"
            fi

            # Handle Steam chat windows
            if [[ "$class" == "steam" && "$title" != "Steam" && "$title" != "Friends List" && -n "$title" ]]; then
                echo "Detected Steam chat window: $title"
                sleep 0.1

                # Float chat windows
                hyprctl dispatch togglefloating address:0x$address

                echo "Floated chat window: $title"
            fi
            ;;
    esac
}

echo "Starting Steam Window Manager..."
echo "Listening on: $SOCKET"

socat -U - UNIX-CONNECT:"$SOCKET" | while read -r line; do
    handle_event "$line"
done
