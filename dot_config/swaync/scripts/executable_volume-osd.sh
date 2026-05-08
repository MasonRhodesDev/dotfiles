#!/bin/bash

case $1 in
    "up")
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 1%+
        ;;
    "down")
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 1%-
        ;;
    "mute")
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
esac

# Get current volume and mute status
volume=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
if [[ $volume == *"MUTED"* ]]; then
    # Send OSD notification with special app-name for targeting
    notify-send -t 2000 -a "osd-volume" -h string:x-canonical-private-synchronous:volume -h int:value:0 "🔇 MUTED" ""
else
    # Extract volume percentage
    vol_percent=$(echo $volume | awk '{print int($2*100)}')
    notify-send -t 2000 -a "osd-volume" -h string:x-canonical-private-synchronous:volume -h int:value:$vol_percent "🔊 $vol_percent%" ""
fi