#!/bin/bash

entries="⇠ Logout\n⏾ Suspend\n⭮ Reboot\n⏻ Shutdown"

# Calculate dynamic width and height based on content
max_length=$(echo -e "$entries" | wc -L)
num_lines=$(echo -e "$entries" | wc -l)

# Width: ~8px per character + padding
dynamic_width=$((max_length * 8 + 60))
dynamic_width=$(( dynamic_width < 200 ? 200 : dynamic_width ))
dynamic_width=$(( dynamic_width > 400 ? 400 : dynamic_width ))

# Height: ~30px per line + padding for search box
dynamic_height=$((num_lines * 30 + 80))
dynamic_height=$(( dynamic_height < 150 ? 150 : dynamic_height ))
dynamic_height=$(( dynamic_height > 300 ? 300 : dynamic_height ))

selected=$(echo -e $entries|wofi --width $dynamic_width --height $dynamic_height --dmenu --cache-file /dev/null | awk '{print tolower($2)}')

case $selected in
  logout)
    hyprctl dispatch exit;;
  suspend)
    exec systemctl suspend;;
  reboot)
    exec systemctl reboot;;
  shutdown)
    exec systemctl poweroff -i;;
esac