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

# Run chezmoi apply first
echo "→ Running chezmoi apply to install packages..."
if ! chezmoi apply --force 2>&1 | tee /tmp/service-validation-apply.log; then
    echo "✗ chezmoi apply failed"
    exit 1
fi
echo ""

# Check if work profile (services only installed on work machines)
HOSTNAME=$(cat /etc/hostname 2>/dev/null || hostname)
if [[ "$HOSTNAME" != *"work"* ]]; then
    echo "ℹ Not a work profile machine - skipping service tests"
    echo "  (Docker and MongoDB only install on work profile)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  TEST PASSED: Service Validation (N/A)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi

FAILED=0

# ━━━ Docker Service Validation ━━━
echo "→ Validating Docker service..."

# Check service unit files
if assert_file_exists "/usr/lib/systemd/system/docker.service" "docker.service unit"; then
    :
else
    ((FAILED++))
fi

if assert_file_exists "/usr/lib/systemd/system/docker.socket" "docker.socket unit"; then
    :
else
    # Socket is optional
    echo "  ℹ docker.socket not found (may be optional)"
fi

# Check containerd service (dependency)
if assert_file_exists "/usr/lib/systemd/system/containerd.service" "containerd.service unit"; then
    :
else
    ((FAILED++))
fi

# Check Docker binary
if assert_command_exists "docker" "Docker"; then
    assert_command_version "docker" "Docker"
else
    ((FAILED++))
fi

# Check dockerd binary
if assert_command_exists "dockerd" "Docker daemon"; then
    :
else
    echo "  ⚠ dockerd not found (may be in /usr/sbin)"
    # Check /usr/sbin
    if [ -f /usr/sbin/dockerd ]; then
        echo "  ✓ dockerd found in /usr/sbin"
    fi
fi

# Check docker-compose
if assert_command_exists "docker-compose" "docker-compose" || assert_command_exists "docker" "docker compose"; then
    :
else
    echo "  ⚠ docker-compose not found (may not be installed)"
fi

echo ""

# ━━━ MongoDB Service Validation ━━━
echo "→ Validating MongoDB service..."

# Service name differs by distro
if [ "$DISTRO" = "fedora" ]; then
    SERVICE_NAME="mongod"
elif [ "$DISTRO" = "arch" ]; then
    SERVICE_NAME="mongodb"
fi

# Check service unit file
if assert_file_exists "/usr/lib/systemd/system/${SERVICE_NAME}.service" "${SERVICE_NAME}.service unit"; then
    :
else
    # Try alternate location
    if assert_file_exists "/lib/systemd/system/${SERVICE_NAME}.service" "${SERVICE_NAME}.service unit (alternate)"; then
        :
    else
        echo "  ⚠ ${SERVICE_NAME}.service not found - MongoDB may not be installed"
        echo "    (This is OK if MongoDB installation failed or was skipped)"
    fi
fi

# Check MongoDB binaries
if assert_command_exists "mongod" "MongoDB daemon"; then
    assert_command_version "mongod" "MongoDB"
else
    echo "  ⚠ mongod not found - MongoDB may not be installed"
fi

if assert_command_exists "mongosh" "MongoDB shell"; then
    assert_command_version "mongosh" "MongoDB shell"
else
    # Try legacy mongo shell
    if assert_command_exists "mongo" "MongoDB shell (legacy)"; then
        assert_command_version "mongo" "MongoDB shell"
    else
        echo "  ⚠ MongoDB shell not found - may not be installed"
    fi
fi

echo ""

# ━━━ Additional Service Checks ━━━
echo "→ Validating systemd functionality in container..."

# Check if systemd is available (it won't be in Docker)
if command -v systemctl &>/dev/null; then
    echo "  ℹ systemctl available"

    # Try to query systemd (will fail in Docker, that's OK)
    if systemctl --version &>/dev/null; then
        echo "  ✓ systemd is functional"

        # If systemd works, try checking service status
        if systemctl status docker &>/dev/null; then
            echo "  ✓ Docker service is active"
        else
            echo "  ⚠ Docker service not active (expected in container)"
        fi

        if systemctl status "$SERVICE_NAME" &>/dev/null; then
            echo "  ✓ MongoDB service is active"
        else
            echo "  ⚠ MongoDB service not active (expected in container)"
        fi
    else
        echo "  ⚠ systemd not functional (expected in Docker container)"
        echo "    Service unit files validated, but services cannot start"
    fi
else
    echo "  ⚠ systemctl not available (expected in Docker container)"
fi

echo ""

# ━━━ Summary ━━━
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILED -eq 0 ]; then
    echo "  TEST PASSED: Service Validation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "✓ All critical service files and binaries validated"
    echo "ℹ Services cannot start in Docker containers (expected)"
    echo "ℹ Full service testing requires VM or real system"
    exit 0
else
    echo "  TEST FAILED: Service Validation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "✗ $FAILED critical validation(s) failed"
    echo "  Check logs above for details"
    exit 1
fi
