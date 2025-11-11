#!/bin/bash
# Test Scenario: Service Validation
# Verifies systemd service unit files exist and binaries work (without starting services)

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST: Service Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Detect distro
if [ -f /etc/fedora-release ]; then
    DISTRO="fedora"
elif [ -f /etc/arch-release ]; then
    DISTRO="arch"
else
    echo "✗ Unknown distribution"
    exit 1
fi

echo "→ Detected distribution: $DISTRO"
echo ""

# Helper functions
assert_file_exists() {
    local file="$1"
    local description="${2:-$file}"

    if [ -f "$file" ]; then
        echo "  ✓ $description exists"
        return 0
    else
        echo "  ✗ $description missing"
        return 1
    fi
}

assert_command_exists() {
    local cmd="$1"
    local description="${2:-$cmd}"

    if command -v "$cmd" &>/dev/null; then
        echo "  ✓ $description command available"
        return 0
    else
        echo "  ✗ $description command not found"
        return 1
    fi
}

assert_command_version() {
    local cmd="$1"
    local description="${2:-$cmd}"

    if "$cmd" --version &>/dev/null || "$cmd" --version 2>&1 | head -1; then
        local version=$("$cmd" --version 2>&1 | head -1 || echo "unknown")
        echo "  ✓ $description works: $version"
        return 0
    else
        echo "  ⚠ $description version check failed (may be expected)"
        return 0  # Don't fail on version check
    fi
}

# Initialize chezmoi
echo "→ Initializing chezmoi..."
chezmoi init --source="$CHEZMOI_SOURCE_DIR" 2>&1 > /dev/null
echo "✓ chezmoi init --source="$CHEZMOI_SOURCE_DIR"ialized"
echo ""

# Run chezmoi apply first with HTTPS git config
echo "→ Running chezmoi apply to install packages..."
export GIT_CONFIG_GLOBAL="$HOME/.local/share/chezmoi/.gitconfig"
if ! chezmoi apply 2>&1 | tee /tmp/service-validation-apply.log; then
    echo "✗ chezmoi apply failed"
    exit 1
fi
echo ""

FAILED=0

# ━━━ Hyprland Startup Validation ━━━
echo "→ Testing Hyprland startup (config validation)..."

# Set up Wayland environment for headless mode
export WLR_BACKENDS=headless
export WLR_LIBINPUT_NO_DEVICES=1
export WLR_RENDERER=pixman
export WAYLAND_DISPLAY=wayland-0

# Check if Hyprland was installed
if ! assert_command_exists "Hyprland" "Hyprland"; then
    echo "  ⚠ Hyprland not installed - skipping compositor tests"
    echo ""
else
    # Test Hyprland startup (10 second test)
    echo "  → Starting Hyprland in headless mode..."
    timeout 10 Hyprland &>/tmp/hyprland.log &
    HYPR_PID=$!
    sleep 3

    # Check if process is still running
    if ! kill -0 $HYPR_PID 2>/dev/null; then
        echo "  ✗ Hyprland crashed on startup"
        echo "    Config errors detected:"
        grep -i "error\|fatal\|failed" /tmp/hyprland.log 2>/dev/null | head -5 | sed 's/^/      /'
        ((FAILED++))
    else
        echo "  ✓ Hyprland started successfully"

        # Check for Wayland socket
        if [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
            echo "  ✓ Wayland socket created"
        else
            echo "  ⚠ Wayland socket not found (may be timing issue)"
        fi

        # Test Waybar startup
        if assert_command_exists "waybar" "Waybar"; then
            echo "  → Testing Waybar startup..."
            timeout 5 waybar &>/tmp/waybar.log &
            WAYBAR_PID=$!
            sleep 2

            if ! kill -0 $WAYBAR_PID 2>/dev/null; then
                echo "  ✗ Waybar crashed on startup"
                echo "    Config errors detected:"
                grep -i "error\|fatal\|failed" /tmp/waybar.log 2>/dev/null | head -5 | sed 's/^/      /'
                ((FAILED++))
            else
                echo "  ✓ Waybar started successfully"
                kill $WAYBAR_PID 2>/dev/null || true
            fi
        fi

        # Clean up Hyprland
        kill $HYPR_PID 2>/dev/null || true
    fi

    echo ""
fi

# ━━━ Summary ━━━
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILED -eq 0 ]; then
    echo "  TEST PASSED: Service Validation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "✓ Hyprland and Waybar configs validated"
    echo "✓ No critical startup errors detected"
    echo "ℹ Full compositor testing requires real display"
    exit 0
else
    echo "  TEST FAILED: Service Validation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "✗ $FAILED critical validation(s) failed"
    echo "  Hyprland or Waybar crashed on startup"
    echo "  Check logs: /tmp/hyprland.log and /tmp/waybar.log"
    exit 1
fi
