#!/bin/bash

case $1 in
    "play-pause")
        playerctl play-pause
        sleep 0.1  # Brief delay to allow state change
        status=$(playerctl status 2>/dev/null)
        if [[ $status == "Playing" ]]; then
            notify-send -t 2000 -a "osd-media" -h string:x-canonical-private-synchronous:media "▶️ Playing" ""
        elif [[ $status == "Paused" ]]; then
            notify-send -t 2000 -a "osd-media" -h string:x-canonical-private-synchronous:media "⏸️ Paused" ""
        elif [[ $status == "Stopped" ]]; then
            notify-send -t 2000 -a "osd-media" -h string:x-canonical-private-synchronous:media "⏹️ Stopped" ""
        else
            notify-send -t 2000 -a "osd-media" -h string:x-canonical-private-synchronous:media "🎵 Media" "Toggle"
        fi
        ;;
    "stop")
        playerctl stop
        notify-send -t 2000 -a "osd-media" -h string:x-canonical-private-synchronous:media "⏹️ Stopped" ""
        ;;
    "next")
        playerctl next
        sleep 0.1
        title=$(playerctl metadata title 2>/dev/null)
        artist=$(playerctl metadata artist 2>/dev/null)
        if [[ -n "$title" ]]; then
            notify-send -t 3000 -a "osd-media" -h string:x-canonical-private-synchronous:media "⏭️ Next Track" "$artist - $title"
        else
            notify-send -t 2000 -a "osd-media" -h string:x-canonical-private-synchronous:media "⏭️ Next" ""
        fi
        ;;
    "previous")
        playerctl previous
        sleep 0.1
        title=$(playerctl metadata title 2>/dev/null)
        artist=$(playerctl metadata artist 2>/dev/null)
        if [[ -n "$title" ]]; then
            notify-send -t 3000 -a "osd-media" -h string:x-canonical-private-synchronous:media "⏮️ Previous Track" "$artist - $title"
        else
            notify-send -t 2000 -a "osd-media" -h string:x-canonical-private-synchronous:media "⏮️ Previous" ""
        fi
        ;;
esac