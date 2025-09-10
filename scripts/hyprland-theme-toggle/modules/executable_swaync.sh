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
    
    # Debug: Check if surface is empty
    if [[ -z "$surface" ]]; then
        log_module "$module_name" "ERROR: Surface color is empty! colors_json length: ${#colors_json}"
        # Fallback to hardcoded values based on mode
        if [[ "$mode" == "dark" ]]; then
            surface="#12131a"
            on_surface="#e3e1ec"
        else
            surface="#fbf8ff"
            on_surface="#1a1b23"
        fi
        log_module "$module_name" "Using fallback surface color: $surface"
    fi
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
    
    # Use consistent theme variables for both light and dark modes
    local shadow_opacity="0.15"
    local notification_bg="${surface}"
    local control_bg="${surface}"
    local widget_bg="${surface}"
    local text_primary="${on_surface}"
    local text_secondary="${on_surface_variant}"
    
    # Debug widget_bg value
    log_module "$module_name" "widget_bg value: '$widget_bg' (surface: '$surface')"
    
    # Generate new themed style.css - override defaults properly
    cat > "$style_file" << EOF
/* SwayNC Theme - Material You */

/* Define color variables to override defaults */
@define-color cc-bg ${control_bg};
@define-color noti-border-color transparent;
@define-color noti-bg ${notification_bg};
@define-color noti-bg-opaque ${notification_bg};
@define-color noti-bg-darker ${notification_bg};
@define-color noti-bg-hover ${notification_bg};
@define-color noti-bg-hover-opaque ${notification_bg};
@define-color noti-bg-focus ${notification_bg};
@define-color noti-close-bg ${error};
@define-color noti-close-bg-hover ${error};
@define-color text-color ${text_primary};
@define-color text-color-disabled ${text_secondary};
@define-color bg-selected ${primary};

* {
  font-family: "SF Pro Text", sans-serif;
  font-size: 14px;
}

/* Notification row */
.notification-row {
  outline: none;
  background: transparent;
}

.notification-row:focus,
.notification-row:hover {
  background: transparent;
}

/* Notification background container */
.notification-row .notification-background {
  padding: 0;
  background: transparent;
}

/* The actual notification */
.notification-row .notification-background .notification {
  background: ${notification_bg};
  border-radius: 12px;
  padding: 0;
  border: none;
  box-shadow: 0 2px 8px rgba(0, 0, 0, ${shadow_opacity});
}

/* Control Center */
.control-center {
  background: ${control_bg};
  border-radius: 16px;
  margin: 12px;
  padding: 16px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, ${shadow_opacity});
  color: ${text_primary};
}

/* Notification content */
.notification-content {
  padding: 12px;
  background: transparent;
}

.notification-content .summary {
  color: ${text_primary};
  font-size: 15px;
  font-weight: 500;
  margin-bottom: 4px;
}

.notification-content .body {
  color: ${text_secondary};
  font-size: 13px;
}

/* Close button */
.notification-row .notification-background .close-button {
  background: ${error};
  color: ${on_error};
  border-radius: 50%;
  min-width: 24px;
  min-height: 24px;
  padding: 0;
  margin: 6px;
  border: none;
  box-shadow: none;
}

.notification-row .notification-background .close-button:hover {
  opacity: 0.8;
  background: ${error};
}

/* Floating notifications */
.floating-notifications {
  background: transparent;
}

.floating-notifications.background {
  background: transparent;
}

/* Control center list */
.control-center .control-center-list {
  background: transparent;
}

.control-center .control-center-list .notification {
  background: ${widget_bg};
  border-radius: 8px;
  padding: 0;
  margin-top: 8px;
  border: 1px solid ${outline};
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

/* Widget titles */
.widget-title {
  margin-bottom: 8px;
}

.widget-title > label {
  color: ${text_primary};
  font-size: 15px;
  font-weight: 500;
}

.widget-title button {
  background: ${primary};
  color: ${on_primary};
  border-radius: 8px;
  padding: 6px 12px;
  font-size: 13px;
  border: none;
}

.widget-title button:hover {
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
}

/* Widgets */
.widget-dnd,
.widget-volume, 
.widget-backlight,
.widget-mpris {
  background: ${widget_bg};
  border-radius: 8px;
  padding: 10px;
  margin: 4px 0;
  border: 1px solid ${outline};
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

/* DND Switch */
.widget-dnd > switch {
  background: ${surface_variant};
  border-radius: 12px;
  min-height: 20px;
  min-width: 40px;
  border: none;
}

.widget-dnd > switch:checked {
  background: ${primary};
}

.widget-dnd > switch slider {
  background: ${on_surface};
  border-radius: 50%;
  min-width: 16px;
  min-height: 16px;
  margin: 2px;
}

/* Sliders */
.widget-volume scale,
.widget-backlight scale {
  min-height: 20px;
  background: transparent;
}

.widget-volume scale trough,
.widget-backlight scale trough {
  background: ${outline};
  border-radius: 4px;
  min-height: 4px;
}

.widget-volume scale highlight,
.widget-backlight scale highlight {
  background: ${primary};
  border-radius: 4px;
  min-height: 4px;
}

.widget-volume scale slider,
.widget-backlight scale slider {
  background: ${on_surface};
  border-radius: 50%;
  min-width: 14px;
  min-height: 14px;
  margin: -5px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
}

/* Media Player */
.widget-mpris-player {
  padding: 8px;
  background: transparent;
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
  background: ${surface_variant};
  color: ${text_primary};
  border-radius: 50%;
  min-width: 32px;
  min-height: 32px;
  padding: 0;
  margin: 2px;
  border: none;
}

.widget-mpris button:hover {
  background: ${outline};
}

.widget-mpris button:active {
  background: ${primary};
  color: ${on_primary};
}

/* Blank window */
.blank-window {
  background: transparent;
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