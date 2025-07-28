#!/bin/bash
# Wait for waybar and Hyprland to start before starting other applications

# Wait for Hyprland to start
while ! pgrep -f Hyprland; do
    sleep 1
done

# Wait for waybar to start
# while ! pgrep -f waybar; do
#     sleep 1
# done
sleep 5

# Read the state of the lid
# lid_state=$(cat /proc/acpi/button/lid/LID0/state)

# # Check if the state contains "closed"
# if [[ $lid_state == *"closed"* ]]; then
#   ~/.config/hypr/disable-or-suspend.js --state=on --id=eDP-1
# else
#   echo "The lid is open"
# fi

# ~/.config/hypr/configs/monitors.sh~


swaybg -i $WALLPAPER_PATH -m fill &
