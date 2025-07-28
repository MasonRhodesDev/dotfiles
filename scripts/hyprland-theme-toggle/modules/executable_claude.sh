#!/bin/bash

# Claude Code theme module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

claude_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    
    local module_name="Claude Code"
    
    # Check if Claude Code is installed (check both global and local installations)
    local claude_cmd=""
    if app_installed "claude"; then
        claude_cmd="claude"
    elif [[ -f "$HOME/.claude/local/claude" ]]; then
        claude_cmd="$HOME/.claude/local/claude"
    else
        log_module "$module_name" "Not installed, skipping"
        return 0
    fi
    
    # Check current theme setting
    local current_theme=$($claude_cmd config get -g theme 2>/dev/null || echo "")
    
    # Skip if theme is already set correctly
    if [[ "$current_theme" == "$mode" ]]; then
        log_module "$module_name" "Theme already set to $mode, skipping"
        return 0
    fi
    
    log_module "$module_name" "Setting theme to $mode"
    
    # Set Claude Code theme
    if $claude_cmd config set -g theme "$mode"; then
        log_module "$module_name" "Theme successfully set to $mode"
        return 0
    else
        log_module "$module_name" "Error: Failed to set theme to $mode"
        return 1
    fi
}