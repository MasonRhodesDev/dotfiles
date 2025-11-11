#!/bin/bash
# Test Scenario: Basic Installation
# Verifies that packages install without critical errors

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST: Basic Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Initialize chezmoi (source is already copied in Docker)
echo "→ Initializing chezmoi..."
if chezmoi init --source="$CHEZMOI_SOURCE_DIR" 2>&1 | tee /tmp/chezmoi-init.log; then
    echo "✓ chezmoi init --source="$CHEZMOI_SOURCE_DIR" completed"
else
    echo "✗ chezmoi init --source="$CHEZMOI_SOURCE_DIR" failed"
    exit 1
fi

echo ""

# Run chezmoi apply with HTTPS git config
echo "→ Running chezmoi apply..."
export GIT_CONFIG_GLOBAL="$HOME/.local/share/chezmoi/.gitconfig"
if chezmoi apply 2>&1 | tee /tmp/chezmoi-apply.log; then
    echo "✓ chezmoi apply completed (exit 0)"
else
    EXIT_CODE=$?
    echo "✗ chezmoi apply failed with exit code: $EXIT_CODE"
    exit 1
fi

echo ""
echo "→ Checking state database..."
if [ -f ~/.local/state/chezmoi-installs/state.db.json ]; then
    echo "✓ State database exists"

    # Check if any categories succeeded or failed
    SUCCESS_COUNT=$(jq -r '[.phases[] | .categories // {} | to_entries[] | select(.value.status == "success")] | length' ~/.local/state/chezmoi-installs/state.db.json)
    FAILED_COUNT=$(jq -r '[.phases[] | .categories // {} | to_entries[] | select(.value.status == "failed")] | length' ~/.local/state/chezmoi-installs/state.db.json)
    TOTAL_COUNT=$(jq -r '[.phases[] | .categories // {} | to_entries[]] | length' ~/.local/state/chezmoi-installs/state.db.json)

    echo "  Success: $SUCCESS_COUNT categories"
    echo "  Failed: $FAILED_COUNT categories"
    echo "  Total: $TOTAL_COUNT categories"

    # Test passes if:
    # 1. At least one category succeeded (normal case), OR
    # 2. No categories defined at all (valid empty installation)
    if [ "$FAILED_COUNT" -gt 0 ]; then
        echo "✗ Some categories failed"
        exit 1
    elif [ "$TOTAL_COUNT" -eq 0 ]; then
        echo "✓ No categories defined (valid empty installation)"
    elif [ "$SUCCESS_COUNT" -gt 0 ]; then
        echo "✓ At least one category installed successfully"
    else
        echo "✗ Categories exist but none succeeded"
        exit 1
    fi
else
    echo "✗ State database not created"
    exit 1
fi

echo ""
echo "→ Checking installation logs..."
if ls ~/.cache/dotfiles-install/*.log >/dev/null 2>&1; then
    LOG_COUNT=$(ls ~/.cache/dotfiles-install/*.log 2>/dev/null | wc -l)
    echo "✓ Found $LOG_COUNT log file(s)"
else
    echo "⚠ No log files found (may be expected if all skipped)"
fi

echo ""
echo "→ Checking lock file cleanup..."
if [ -f ~/.local/state/chezmoi-installs/install.lock ]; then
    echo "⚠ Lock file still exists (may indicate incomplete cleanup)"
else
    echo "✓ Lock file properly cleaned up"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST PASSED: Basic Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
