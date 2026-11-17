#!/bin/bash

WEZTERM_ROOT="$HOME/.wezterm.lua"

if [ -f "$WEZTERM_ROOT" ]; then
    echo "Removing conflicting ~/.wezterm.lua"
    rm -f "$WEZTERM_ROOT"
    echo "✓ Removed ~/.wezterm.lua (use ~/.config/wezterm/ instead)"
fi
