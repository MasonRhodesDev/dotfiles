#!/bin/bash

# Chezmoi Daemon - Monitor for dotfile changes and provide interactive prompts
# Author: Mason Rhodes

DAEMON_DIR="{{ .chezmoi.homeDir }}/.cache/chezmoi-daemon"
HASH_FILE="$DAEMON_DIR/ignore-hash"
LOCK_FILE="$DAEMON_DIR/daemon.lock"
LOG_FILE="$DAEMON_DIR/daemon.log"

USE_AGS=true

# Ensure daemon directory exists
mkdir -p "$DAEMON_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Check if daemon is already running
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log "Daemon already running with PID $pid"
            exit 0
        else
            log "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Clean up on exit
cleanup() {
    rm -f "$LOCK_FILE"
    log "Daemon stopped"
}
trap cleanup EXIT INT TERM

# Get current chezmoi status and calculate hash
get_changes_hash() {
    cd {{ .chezmoi.homeDir }}/.local/share/chezmoi
    local status_output=$(chezmoi status 2>/dev/null)
    local diff_output=$(chezmoi diff 2>/dev/null)
    
    if [ -z "$status_output" ]; then
        echo ""
    else
        echo "$status_output$diff_output" | sha256sum | cut -d' ' -f1
    fi
}

# Get detailed change information
get_change_details() {
    cd {{ .chezmoi.homeDir }}/.local/share/chezmoi
    
    local status_output=$(chezmoi status 2>/dev/null)
    local file_count=$(echo "$status_output" | wc -l)
    
    if [ -z "$status_output" ]; then
        echo "No changes detected"
        return 1
    fi
    
    local synopsis="Changes detected in $file_count file(s):"
    local changed_files=""
    
    # Parse chezmoi status output
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local status=$(echo "$line" | cut -c1-2)
            local file=$(echo "$line" | cut -c4-)
            
            case "$status" in
                "A ") changed_files="$changed_files\n  + Added: $file" ;;
                "M ") changed_files="$changed_files\n  ~ Modified: $file" ;;
                "D ") changed_files="$changed_files\n  - Deleted: $file" ;;
                *) changed_files="$changed_files\n  ? Changed: $file" ;;
            esac
        fi
    done <<< "$status_output"
    
    echo -e "$synopsis$changed_files"
}

# Show GUI notification for changes
show_change_notification() {
    local current_hash="$1"
    
    # Get change details for notification
    local change_details=$(get_change_details)
    if [ $? -ne 0 ]; then
        log "No detailed changes found"
        return 0
    fi
    
    # Check if AGS should be used
    if [ "${USE_AGS:-false}" = "true" ]; then
        if command -v ags &> /dev/null; then
            log "Using AGS for change notification"
            "{{ .chezmoi.homeDir }}/.local/share/chezmoi/chezmoi-daemon/ags-notify.js" "$change_details" "$current_hash" &
            return 0
        else
            log "AGS not available, falling back to notify-send"
        fi
    fi
    
    # Use notify-send for simple notification
    if command -v notify-send &> /dev/null; then
        log "Using notify-send for change notification"
        notify-send "Chezmoi Changes Detected" "$change_details" \
            --icon=dialog-information \
            --urgency=normal \
            --expire-time=10000
        return 0
    else
        log "notify-send not available, logging changes instead"
        log "Changes detected: $change_details"
        return 1
    fi
}

# Set up login/unlock triggers
setup_triggers() {
    log "Setting up login/unlock triggers"
    
    # Create desktop autostart entry for login trigger
    local autostart_dir="{{ .chezmoi.homeDir }}/.config/autostart"
    mkdir -p "$autostart_dir"
    
    cat > "$autostart_dir/chezmoi-daemon-trigger.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Chezmoi Daemon Trigger
Exec={{ .chezmoi.homeDir }}/scripts/chezmoi-daemon.sh check
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
X-MATE-Autostart-enabled=true
StartupNotify=false
EOF

    # For Hyprland, add to hyprland config if not already present
    local hypr_config="{{ .chezmoi.homeDir }}/.config/hypr/hyprland.conf"
    if [ -f "$hypr_config" ] && ! grep -q "chezmoi-daemon.sh" "$hypr_config"; then
        echo "exec-once = {{ .chezmoi.homeDir }}/scripts/chezmoi-daemon.sh check" >> "$hypr_config"
    fi
    
    log "Triggers set up successfully"
}

# Main daemon logic
check_for_changes() {
    log "Checking for changes..."
    
    local current_hash=$(get_changes_hash)
    
    # If no changes, exit
    if [ -z "$current_hash" ]; then
        log "No changes detected"
        return 0
    fi
    
    # Check if this hash was previously ignored
    if [ -f "$HASH_FILE" ]; then
        local ignored_hash=$(cat "$HASH_FILE")
        if [ "$current_hash" = "$ignored_hash" ]; then
            log "Changes match ignored hash, skipping notification"
            return 0
        fi
    fi
    
    log "New changes detected (hash: $current_hash)"
    
    # Get change details
    local change_details=$(get_change_details)
    if [ $? -ne 0 ]; then
        log "No detailed changes found"
        return 0
    fi
    
    # Show notification if we have a display
    if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
        show_change_notification "$current_hash"
    else
        log "No display available, logging changes: $change_details"
    fi
}

# Main execution
main() {
    check_lock
    log "Chezmoi daemon started"
    
    case "${1:-check}" in
        "check")
            check_for_changes
            ;;
        "daemon")
            log "Running in daemon mode"
            while true; do
                check_for_changes
                sleep 3600  # Check every hour in daemon mode
            done
            ;;
        "force")
            log "Force check requested"
            rm -f "$HASH_FILE"  # Remove ignore hash
            check_for_changes
            ;;
        "trigger")
            if [ "$2" = "--force" ]; then
                log "Manual trigger requested (forced)"
                rm -f "$HASH_FILE"  # Remove ignore hash
            else
                log "Manual trigger requested"
            fi
            check_for_changes
            ;;
        "setup")
            log "Setting up chezmoi daemon"
            
            # Run git installers first
            log "Running git installers..."
            local git_installers_dir="{{ .chezmoi.homeDir }}/.local/share/chezmoi/git_installers"
            if [ -d "$git_installers_dir" ]; then
                for installer_dir in "$git_installers_dir"/*; do
                    if [ -d "$installer_dir" ] && [ -f "$installer_dir/install.sh" ]; then
                        local installer_name=$(basename "$installer_dir")
                        log "Running installer: $installer_name"
                        cd "$installer_dir"
                        chmod +x install.sh
                        ./install.sh 2>&1 | while read line; do log "[$installer_name] $line"; done
                    fi
                done
            fi
            
            setup_triggers
            # Enable systemd services
            systemctl --user enable chezmoi-daemon.timer
            systemctl --user start chezmoi-daemon.timer
            systemctl --user enable chezmoi-daemon.service
            log "Chezmoi daemon setup complete"
            ;;
        *)
            echo "Usage: $0 [check|daemon|force|trigger|setup]"
            echo "  check         - Check once and exit (default)"
            echo "  daemon        - Run continuously with hourly checks"  
            echo "  force         - Force check ignoring previous ignore hash"
            echo "  trigger       - Manual trigger for testing/API integration"
            echo "  trigger --force - Force manual trigger ignoring ignore hash"
            echo "  setup         - Set up daemon, triggers, and systemd services"
            exit 1
            ;;
    esac
}

main "$@"