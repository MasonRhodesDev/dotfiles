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


