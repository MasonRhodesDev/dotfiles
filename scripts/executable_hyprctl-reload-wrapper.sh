#!/bin/bash
# Wrapper for hyprctl reload that restarts waybar to prevent freeze
# Known issue: https://github.com/Alexays/Waybar/issues/4451

/usr/bin/hyprctl reload "$@"
exit_code=$?

if [ $exit_code -eq 0 ]; then
    (sleep 1 && systemctl --user restart waybar) &
fi

exit $exit_code
