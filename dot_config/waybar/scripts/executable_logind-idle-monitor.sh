#!/bin/bash

# Get idle inhibitor status
status=$(logind-idle-control status 2>/dev/null)

# Exit code handling
if [ $? -ne 0 ]; then
    echo '{"text":"", "tooltip":"Error: logind-idle-control not available"}'
    exit 1
fi

# Output JSON based on status
if [ "$status" -eq 1 ]; then
    echo '{"text":"", "tooltip":"Idle inhibitor: Active", "class":"activated"}'
else
    echo '{"text":"", "tooltip":"Idle inhibitor: Inactive", "class":"deactivated"}'
fi
