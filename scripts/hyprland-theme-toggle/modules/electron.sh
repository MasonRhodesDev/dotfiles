#!/bin/bash

# Electron app theme refresh module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

electron_apply_theme() {
    local wallpaper="$1"
    local mode="$2" 
    local state_file="$3"
    
    local module_name="Electron"
    
    # Temporarily disabled for performance
    log_module "$module_name" "Module disabled for performance"
    return 0
    
    log_module "$module_name" "Applying $mode theme to Electron applications"
    
    # Ensure Electron apps can use portal for theme detection
    export GTK_USE_PORTAL=1
    systemctl --user set-environment GTK_USE_PORTAL=1
    hyprctl setenv GTK_USE_PORTAL 1
    
    # List of common Electron apps to check
    local electron_apps=(
        "cursor"
        "code"
        "discord"
        "slack"
        "spotify"
    )
    
    local running_apps=()
    for app in "${electron_apps[@]}"; do
        if pgrep -x "$app" > /dev/null 2>&1; then
            running_apps+=("$app")
        fi
    done
    
    if [[ ${#running_apps[@]} -eq 0 ]]; then
        log_module "$module_name" "No running Electron apps found"
        return 0
    fi
    
    log_module "$module_name" "Running Electron apps: ${running_apps[*]}"
    
    # Handle Slack-specific theming
    local slack_running=false
    for app in "${running_apps[@]}"; do
        if [[ "$app" == "slack" ]]; then
            slack_running=true
            break
        fi
    done
    
    if [[ "$slack_running" == true ]] || [[ -d "$HOME/.config/Slack" ]]; then
        slack_apply_theme_config "$mode"
    fi
    
    # Electron apps should detect theme changes via portal/gsettings automatically
    if [[ ${#running_apps[@]} -gt 0 ]]; then
        log_module "$module_name" "Portal theme signals sent to running apps: ${running_apps[*]}"
    fi
    
    log_module "$module_name" "Electron theme environment updated"
    
    return 0
}

slack_apply_theme_config() {
    local mode="$1"
    local module_name="Slack"
    
    # Create Slack user script for theme injection if config directory exists
    if [[ -d "$HOME/.config/Slack" ]]; then
        local user_script="$HOME/.config/Slack/user.css"
        
        # Always remove any existing CSS injection first
        rm -f "$user_script" 2>/dev/null
        
        if [[ "$mode" == "dark" ]]; then
            # Only create CSS injection for dark theme if system portal is light
            # (so we override Slack's light theme with dark)
            local portal_scheme=$(gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.Settings.Read "org.gnome.desktop.interface" "color-scheme" 2>/dev/null | grep -o 'prefer-[^'\'']*' || echo "prefer-light")
            
            if [[ "$portal_scheme" == "prefer-light" ]]; then
                # Create a CSS injection for dark theme when system is light
                cat > "$user_script" << 'EOF'
/* Custom dark theme CSS injection */
document.addEventListener('DOMContentLoaded', function() {
    const darkCSS = `
    .p-client_desktop {
        background: #1a1a1a !important;
        color: #ffffff !important;
    }
    .p-workspace__sidebar {
        background: #2c2c2c !important;
    }
    `;
    
    const style = document.createElement('style');
    style.textContent = darkCSS;
    document.head.appendChild(style);
});
EOF
                log_module "$module_name" "Created dark theme CSS injection (portal theme mismatch)"
            else
                log_module "$module_name" "Skipped CSS injection - portal already dark"
            fi
        else
            log_module "$module_name" "Removed any existing dark theme CSS"
        fi
        
        # Try to send theme preference via Slack's internal settings
        local slack_prefs="$HOME/.config/Slack/storage/root-state.json"
        if [[ -f "$slack_prefs" ]] && command -v jq >/dev/null 2>&1; then
            local temp_prefs=$(mktemp)
            if [[ "$mode" == "dark" ]]; then
                jq '.theme = "dark"' "$slack_prefs" > "$temp_prefs" 2>/dev/null && mv "$temp_prefs" "$slack_prefs"
            else
                jq '.theme = "light"' "$slack_prefs" > "$temp_prefs" 2>/dev/null && mv "$temp_prefs" "$slack_prefs"
            fi
            log_module "$module_name" "Updated Slack preferences to $mode theme"
        fi
        
        log_module "$module_name" "Slack theme configuration updated"
    fi
}