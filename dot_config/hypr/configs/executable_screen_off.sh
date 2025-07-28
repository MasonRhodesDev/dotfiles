#!/bin/bash

# Check if the session is locked
if loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p LockedHint | grep -q 'yes'; then
  echo "Session is locked. Skipping DPMS off."
  hyprctl dispatch dpms off
fi