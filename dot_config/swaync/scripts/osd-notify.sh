#!/bin/bash

# Custom OSD notification script that creates centered notifications
# Usage: osd-notify.sh "title" "message"

title="$1"
message="$2"

# Create a temporary notification using zenity or custom method
# This creates a centered OSD-style notification
yad --notification \
    --image="dialog-information" \
    --text="$title\n$message" \
    --timeout=2 \
    --no-buttons \
    --center \
    --width=300 \
    --height=300 \
    --no-escape \
    --skip-taskbar \
    --on-top \
    --undecorated &