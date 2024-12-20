#!/bin/bash

# if hyprctl clients | grep -q "class: dim_overlay"; then
#     hyprctl clients -j | jq -r '.[] | select(.class == "dim_overlay") | .address' | while read -r address; do
#         hyprctl dispatch closewindow address:"$address"
#     done
# else
#     for monitor in $(hyprctl monitors -j | jq -r '.[].name'); do
#         hyprctl dispatch exec "[monitor $monitor;workspace special:dim silent] alacritty --class dim_overlay -e sh -c 'sleep infinity'"
#     done
# fi