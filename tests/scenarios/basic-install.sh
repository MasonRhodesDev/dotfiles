#!/bin/bash
# Test Scenario: Basic Installation
# Verifies that packages install without critical errors

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST: Basic Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Run chezmoi apply
echo "→ Running chezmoi apply..."
if chezmoi apply --force 2>&1 | tee /tmp/chezmoi-apply.log; then
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

    # Check if any categories succeeded
    SUCCESS_COUNT=$(jq -r '[.phases[] | .categories // {} | to_entries[] | select(.value.status == "success")] | length' ~/.local/state/chezmoi-installs/state.db.json)
    FAILED_COUNT=$(jq -r '[.phases[] | .categories // {} | to_entries[] | select(.value.status == "failed")] | length' ~/.local/state/chezmoi-installs/state.db.json)

    echo "  Success: $SUCCESS_COUNT categories"
    echo "  Failed: $FAILED_COUNT categories"

    if [ "$SUCCESS_COUNT" -gt 0 ]; then
        echo "✓ At least one category installed successfully"
    else
        echo "✗ No categories installed successfully"
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
