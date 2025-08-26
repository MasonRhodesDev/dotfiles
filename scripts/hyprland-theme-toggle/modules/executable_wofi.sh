#!/bin/bash

# Wofi theme module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

wofi_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    
    local module_name="Wofi"
    
    # Check if Wofi is installed
    if ! app_installed "wofi"; then
        log_module "$module_name" "Not installed, skipping"
        return 0
    fi
    
    log_module "$module_name" "Using centralized colors for $mode theme"
    
    # Wofi will automatically use the updated colors from the centralized CSS file
    # No action needed - the CSS file imports from matugen/colors.css
    
    return 0
}