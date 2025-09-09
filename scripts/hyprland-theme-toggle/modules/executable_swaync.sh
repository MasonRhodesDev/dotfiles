#!/bin/bash

# SwayNC notification daemon theme module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

swaync_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    local colors_json="$4"
    
    local module_name="SwayNC"
    # Write directly to the config file (no longer managed by chezmoi)
    local style_file="$HOME/.config/swaync/style.css"
    
    # Check if SwayNC is installed
    if ! app_installed "swaync"; then
        log_module "$module_name" "Not installed, skipping"
        return 0
    fi
    
    log_module "$module_name" "Applying $mode theme"
    
    # Extract colors for current mode
    local surface=$(echo "$colors_json" | jq -r ".colors.${mode}.surface")
    local on_surface=$(echo "$colors_json" | jq -r ".colors.${mode}.on_surface")
    local surface_variant=$(echo "$colors_json" | jq -r ".colors.${mode}.surface_variant")
    local on_surface_variant=$(echo "$colors_json" | jq -r ".colors.${mode}.on_surface_variant")
    local primary=$(echo "$colors_json" | jq -r ".colors.${mode}.primary")
    local on_primary=$(echo "$colors_json" | jq -r ".colors.${mode}.on_primary")
    local secondary=$(echo "$colors_json" | jq -r ".colors.${mode}.secondary")
    local error=$(echo "$colors_json" | jq -r ".colors.${mode}.error")
    local on_error=$(echo "$colors_json" | jq -r ".colors.${mode}.on_error")
    local outline=$(echo "$colors_json" | jq -r ".colors.${mode}.outline")
    
    # Backup original style file if it exists
    if [[ -f "$style_file" ]]; then
        cp "$style_file" "${style_file}.backup"
    fi
    
    # Calculate values based on mode - matching waybar style
    local shadow_opacity="0.2"
    local notification_bg="${surface}"
    local control_bg="${surface}"
    local widget_bg="transparent"
    local text_primary="${on_surface}"
    local text_secondary="${on_surface_variant}"
    
    if [[ "$mode" == "light" ]]; then
        # Light theme: match waybar's semi-transparent style
        shadow_opacity="0.2"
        # Use semi-transparent background like waybar
        notification_bg="rgba(251, 248, 255, 0.9)"  # 90% opacity of #fbf8ff
        control_bg="rgba(251, 248, 255, 0.9)"  # Same as waybar
        widget_bg="transparent"  # Fully transparent for cards
        text_primary="${on_surface}"  # Use theme text color
        text_secondary="${on_surface_variant}"  # Use theme secondary text
    fi
    
    # Generate new themed style.css - clean modern design
    cat > "$style_file" << EOF
/* SwayNC Theme - Material You Design */
* {
  font-family: "SF Pro Text", sans-serif;
  font-weight: normal;
  font-size: 14px;
}

/* Control Center */
.control-center {
  background-color: ${control_bg};
  border-radius: 16px;
  margin: 12px;
  padding: 16px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, ${shadow_opacity});
  color: ${text_primary};
}

/* Widget Titles */
.control-center .widget-title > label {
  color: ${text_primary};
  font-size: 15px;
  font-weight: 500;
  margin-bottom: 8px;
}

.control-center .widget-title button {
  background-color: ${primary};
  color: ${on_primary};
  border: none;
  border-radius: 8px;
  padding: 6px 12px;
  font-size: 13px;
}

.control-center .widget-title button:hover {
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
}

/* Widget Spacing */
.widget-dnd, .widget-volume, .widget-backlight, .widget-mpris, .widget-title {
  margin-bottom: 8px;
}

/* Floating Notifications */
.floating-notifications.background .notification-row .notification-background {
  background-color: ${notification_bg};
  border-radius: 12px;
  margin: 12px;
  padding: 0;
  box-shadow: 0 3px 6px rgba(0, 0, 0, ${shadow_opacity});
  border: none;
}

.floating-notifications.background .notification-row .notification-background .notification {
  padding: 12px;
  border-radius: 12px;
}

.floating-notifications.background .notification-row .notification-background .notification .notification-content .summary {
  color: ${text_primary};
  font-size: 15px;
  font-weight: 500;
  margin-bottom: 4px;
}

.floating-notifications.background .notification-row .notification-background .notification .notification-content .body {
  color: ${text_secondary};
  font-size: 13px;
}

.floating-notifications.background .notification-row .notification-background .close-button {
  margin: 6px;
  border-radius: 50%;
  background-color: ${error};
  color: ${on_error};
  min-width: 20px;
  min-height: 20px;
  border: none;
}

.floating-notifications.background .notification-row .notification-background .close-button:hover {
  opacity: 0.8;
}

/* Control Center Notifications */
.control-center .notification-row .notification-background {
  background-color: ${widget_bg};
  border-radius: 8px;
  margin-top: 8px;
  border: none;
}

.control-center .notification-row .notification-background:hover {
  background-color: rgba(0, 0, 0, 0.08);
}

.control-center .notification-row .notification-background .notification {
  padding: 10px;
  border-radius: 8px;
}

.control-center .notification-row .notification-background .notification .notification-content .summary {
  color: ${text_primary};
  font-size: 14px;
  font-weight: 500;
  margin-bottom: 2px;
}

.control-center .notification-row .notification-background .notification .notification-content .body {
  color: ${text_secondary};
  font-size: 13px;
}

/* Do Not Disturb Switch */
.widget-dnd > switch {
  border-radius: 12px;
  background-color: ${surface_variant};
  border: none;
  min-height: 20px;
}

.widget-dnd > switch:checked {
  background-color: ${primary};
}

/* Volume and Backlight Sliders */
.widget-volume, .widget-backlight {
  background: ${widget_bg};
  border-radius: 8px;
  padding: 10px;
  margin: 4px 0;
}

.widget-volume scale trough, .widget-backlight scale trough {
  background-color: ${outline};
  border-radius: 4px;
  min-height: 4px;
}

.widget-volume scale highlight, .widget-backlight scale highlight {
  background-color: ${primary};
  border-radius: 4px;
}

.widget-volume scale slider, .widget-backlight scale slider {
  background-color: ${on_surface};
  border-radius: 50%;
  min-width: 14px;
  min-height: 14px;
  margin: -5px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
}

/* Media Player Widget */
.widget-mpris {
  background: ${widget_bg};
  border-radius: 8px;
  padding: 10px;
  margin: 4px 0;
}

.widget-mpris-player {
  padding: 8px;
  border-radius: 6px;
}

.widget-mpris-title {
  color: ${text_primary};
  font-weight: 500;
  font-size: 14px;
  margin-bottom: 2px;
}

.widget-mpris-subtitle {
  color: ${text_secondary};
  font-size: 12px;
}

.widget-mpris button {
  background-color: rgba(0, 0, 0, 0.08);
  color: ${text_primary};
  border: none;
  border-radius: 50%;
  padding: 0;
  min-width: 32px;
  min-height: 32px;
  margin: 2px;
}

.widget-mpris button:hover {
  background-color: rgba(0, 0, 0, 0.12);
}

.widget-mpris button:active {
  background-color: ${primary};
  color: ${on_primary};
}
EOF
    
    log_module "$module_name" "Generated themed style.css"
    
    # Try CSS reload first, restart if it fails
    if pgrep -x swaync >/dev/null; then
        log_module "$module_name" "Attempting CSS reload"
        if swaync-client -rs 2>&1 | grep -q "CSS reload success: true"; then
            log_module "$module_name" "CSS reload successful"
        else
            log_module "$module_name" "CSS reload failed, restarting SwayNC"
            pkill -x swaync
            sleep 0.2
            swaync >/dev/null 2>&1 &
            log_module "$module_name" "SwayNC restarted"
        fi
    else
        log_module "$module_name" "SwayNC not running, starting it"
        swaync >/dev/null 2>&1 &
    fi
    
    return 0
}