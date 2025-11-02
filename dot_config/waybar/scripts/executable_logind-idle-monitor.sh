#!/bin/bash
set -euo pipefail

SESSION=$(loginctl session-status 2>/dev/null | head -1 | awk '{print $1}')
if [[ -z "$SESSION" ]]; then
    echo '{"text":"󰀦","tooltip":"No session detected","class":"error"}'
    exit 1
fi

$HOME/.local/bin/logind-idle-control monitor 2>/dev/null | while IFS= read -r state; do
    if [[ "$state" == "1" ]]; then
        echo '{"text":"󰅶","tooltip":"Idle inhibitor: ACTIVE\nClick to disable","class":"enabled","alt":"enabled"}'
    else
        echo '{"text":"󰾪","tooltip":"Idle inhibitor: INACTIVE\nClick to enable","class":"disabled","alt":"disabled"}'
    fi
done

