#!/bin/bash
# Lid switch handler that monitors lid state and triggers kanshi profile switches

while true; do
    LID_STATE=$(cat /proc/acpi/button/lid/LID0/state | awk '{print $2}')
    
    if [ "$LID_STATE" = "closed" ]; then
        # Only switch if not already on lid_closed profile
        if [ ! -f /tmp/lid_closed_active ]; then
            echo "$(date): Lid closed - switching to lid_closed profile"
            kanshictl switch lid_closed 2>&1 | logger -t lid-handler
            if [ $? -eq 0 ]; then
                echo "$(date): Successfully switched to lid_closed profile"
                touch /tmp/lid_closed_active
                rm -f /tmp/lid_open_active
            else
                echo "$(date): Failed to switch to lid_closed profile"
            fi
        fi
    elif [ "$LID_STATE" = "open" ]; then
        # Only switch if not already on lid_open profile  
        if [ ! -f /tmp/lid_open_active ]; then
            echo "$(date): Lid opened - switching to lid_open profile"
            kanshictl switch lid_open 2>&1 | logger -t lid-handler
            if [ $? -eq 0 ]; then
                echo "$(date): Successfully switched to lid_open profile"
                touch /tmp/lid_open_active
                rm -f /tmp/lid_closed_active
            else
                echo "$(date): Failed to switch to lid_open profile"
            fi
        fi
    fi
    
    sleep 2
done