#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/modules/base.sh" ]]; then
    source "$SCRIPT_DIR/modules/base.sh"
else
    PIDFILE="/tmp/gpu-screen-recorder.pid"
    is_recording() {
        if [[ -f "$PIDFILE" ]]; then
            local pid=$(cat "$PIDFILE" 2>/dev/null)
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                return 0
            fi
        fi
        return 1
    }
fi

if is_recording; then
    icon="󰑊"
    class="recording"
    tooltip="Screen recording in progress - click to stop"
    text="$icon REC"
else
    icon="󰻃"
    class="idle"
    tooltip="Screen recorder idle - click to start recording"
    text="$icon"
fi

printf '{"text": "%s", "tooltip": "%s", "class": "%s"}\n' "$text" "$tooltip" "$class"
