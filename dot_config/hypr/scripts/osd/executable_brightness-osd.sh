#!/bin/bash

case $1 in
    "up")
        brightnessctl set +5%
        ;;
    "down")
        brightnessctl set 5%-
        ;;
esac

# Get current brightness percentage
brightness=$(brightnessctl get)
max_brightness=$(brightnessctl max)
brightness_percent=$((brightness * 100 / max_brightness))

notify-send -t 2000 -a "osd-brightness" -h string:x-canonical-private-synchronous:brightness -h int:value:$brightness_percent "☀️ $brightness_percent%" ""