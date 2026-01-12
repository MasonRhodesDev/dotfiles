#!/usr/bin/env bash
# Toggle special workspace for current workspace with auto-dismiss on workspace change

# Get current workspace info
WS_JSON=$(hyprctl activeworkspace -j)
WS=$(echo "$WS_JSON" | jq -r '.id')
WS_NAME=$(echo "$WS_JSON" | jq -r '.name')

# If already on a special workspace, just close it and exit
if [[ "$WS_NAME" == special:* ]] || [[ "$WS" -lt 0 ]]; then
    SPECIAL_NAME="${WS_NAME#special:}"
    hyprctl dispatch togglespecialworkspace "$SPECIAL_NAME"
    exit 0
fi

# Get socket path before backgrounding
SOCKET_PATH="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"

# Toggle the special workspace for current workspace
hyprctl dispatch togglespecialworkspace "$WS"

# Start background listener
(
    socat -U - "UNIX-CONNECT:$SOCKET_PATH" | while read -r line; do
        case "$line" in
            # Regular workspace switch - close our special
            workspace\>\>*|workspacev2\>\>*)
                hyprctl dispatch togglespecialworkspace "$WS" 2>/dev/null
                break
                ;;
            # Special workspace changed - check if ours is still active
            activespecial\>\>*)
                CURRENT=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .specialWorkspace.name // empty')
                if [[ "$CURRENT" == "special:$WS" ]]; then
                    continue
                fi
                break
                ;;
        esac
    done
) &
disown
