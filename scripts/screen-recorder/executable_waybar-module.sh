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

# Two invocations share this script:
#   (no arg)  -> the clickable REC button, shown left of the media module
#   spacer    -> an invisible, equal-width mirror shown right of the media
#                module so the media module stays centered when REC appears.
MODE="${1:-button}"

if is_recording; then
    if [[ "$MODE" == "spacer" ]]; then
        printf '{"text": "󰑊 REC", "tooltip": "", "class": "spacer"}\n'
    else
        printf '{"text": "󰑊 REC", "tooltip": "Screen recording in progress - click to stop", "class": "recording"}\n'
    fi
else
    # Empty text makes waybar hide the module entirely: no widget rendered,
    # no reserved space, and (crucially) not clickable while idle. Recording
    # can only be started via the SHIFT+Print bind. Same for the spacer.
    printf '{"text": "", "tooltip": "", "class": "idle"}\n'
fi
