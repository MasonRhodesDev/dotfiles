#!/bin/bash
# Enable and start hypr-monitors systemd user service

# Function to check if a service is enabled
is_service_enabled() {
    systemctl --user is-enabled "$1" >/dev/null 2>&1
}

# Function to check if a service is active
is_service_active() {
    systemctl --user is-active "$1" >/dev/null 2>&1
}

# Check if both services are already enabled and active
if is_service_enabled "hypr-monitors.service" && is_service_enabled "hypr-monitors.path"; then
    if is_service_active "hypr-monitors.service" && is_service_active "hypr-monitors.path"; then
        echo "Hypr-monitors services are already enabled and active - nothing to do"
        exit 0
    fi
fi

# Reload systemd user daemon to pick up new service files
systemctl --user daemon-reload

# Enable services if not already enabled
if ! is_service_enabled "hypr-monitors.service"; then
    systemctl --user enable hypr-monitors.service
    echo "Enabled hypr-monitors.service"
fi

if ! is_service_enabled "hypr-monitors.path"; then
    systemctl --user enable hypr-monitors.path
    echo "Enabled hypr-monitors.path"
fi

# Start the path service (which will trigger the main service as needed)
if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
    if ! is_service_active "hypr-monitors.path"; then
        systemctl --user start hypr-monitors.path
        echo "Started hypr-monitors.path"
    fi

    # Don't start hypr-monitors.service directly - let the path trigger it
    echo "Path service will trigger monitor service as needed"
fi

echo "Hypr-monitors systemd service configuration complete"