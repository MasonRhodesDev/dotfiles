#!/bin/bash
# Set XWayland primary to ultrawide monitor (detected by model)
# This fixes games launching on the wrong monitor in multi-monitor setups

ULTRAWIDE_MODEL="S3422DWG"

# Get output name from hyprctl (has reliable model info)
ULTRAWIDE_OUTPUT=$(hyprctl monitors -j | jq -r '.[] | select(.model | contains("'"$ULTRAWIDE_MODEL"'")) | .name')

if [[ -n "$ULTRAWIDE_OUTPUT" ]]; then
    xrandr --output "$ULTRAWIDE_OUTPUT" --primary
    echo "$(date): Set $ULTRAWIDE_OUTPUT as XWayland primary"
else
    echo "$(date): Ultrawide monitor ($ULTRAWIDE_MODEL) not found"
fi
