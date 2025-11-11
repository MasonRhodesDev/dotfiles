#!/bin/bash
# Test Scenario: State Tracking
# Verifies that re-runs skip already installed packages

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST: State Tracking & Skip Logic"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Initialize
echo "→ Initializing chezmoi..."
chezmoi init --source="$CHEZMOI_SOURCE_DIR" 2>&1 | tee /tmp/chezmoi-init.log
echo "✓ chezmoi init --source="$CHEZMOI_SOURCE_DIR" completed"

echo ""

# First run with HTTPS git config
echo "→ First run: Installing packages..."
export GIT_CONFIG_GLOBAL="$HOME/.local/share/chezmoi/.gitconfig"
chezmoi apply 2>&1 | tee /tmp/first-run.log
echo "✓ First run completed"

# Capture first run state
if [ -f ~/.local/state/chezmoi-installs/state.db.json ]; then
    cp ~/.local/state/chezmoi-installs/state.db.json /tmp/state-first.json
    FIRST_SUCCESS=$(jq -r '[.phases[] | .categories // {} | to_entries[] | select(.value.status == "success")] | length' /tmp/state-first.json)
    echo "  First run success count: $FIRST_SUCCESS"
else
    echo "✗ State database not created on first run"
    exit 1
fi

echo ""
echo "→ Second run: Should skip already installed packages..."
chezmoi apply 2>&1 | tee /tmp/second-run.log
echo "✓ Second run completed"

# Check for skip messages
SKIP_COUNT=$(grep -c "already installed\|skipped" /tmp/second-run.log || true)
echo "  Skip messages found: $SKIP_COUNT"

if [ "$SKIP_COUNT" -gt 0 ]; then
    echo "✓ Packages were skipped (state tracking working)"
else
    echo "⚠ No skip messages found (may indicate re-installation)"
fi

# Verify state didn't regress (categories should remain successful, not be removed)
if [ -f ~/.local/state/chezmoi-installs/state.db.json ]; then
    # Count categories that are either "success" or "skipped" (both are valid end states)
    SECOND_SUCCESS=$(jq -r '[.phases[] | .categories // {} | to_entries[] | select(.value.status == "success" or .value.status == "skipped")] | length' ~/.local/state/chezmoi-installs/state.db.json)
    echo "  Second run success/skipped count: $SECOND_SUCCESS"

    if [ "$SECOND_SUCCESS" -ge "$FIRST_SUCCESS" ]; then
        echo "✓ State maintained or improved"
    else
        echo "✗ State regressed (lost successful installations)"
        exit 1
    fi
else
    echo "✗ State database missing after second run"
    exit 1
fi

echo ""
echo "→ Checking checksums..."
CHECKSUM_COUNT=$(jq -r '[.phases[] | .categories // {} | to_entries[] | select(.value.checksum != null)] | length' ~/.local/state/chezmoi-installs/state.db.json)
echo "  Categories with checksums: $CHECKSUM_COUNT"

if [ "$CHECKSUM_COUNT" -gt 0 ]; then
    echo "✓ Checksums are being tracked"
else
    echo "⚠ No checksums found (may affect change detection)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST PASSED: State Tracking"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
