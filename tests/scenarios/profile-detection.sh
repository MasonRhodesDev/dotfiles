#!/bin/bash
# Test Scenario: Profile Detection
# Verifies correct profile is detected and appropriate packages install

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST: Profile Detection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check hostname
HOSTNAME=$(cat /etc/hostname 2>/dev/null || hostname)
echo "→ Current hostname: $HOSTNAME"

# Detect expected profile
if [[ "$HOSTNAME" == *"work"* ]]; then
    EXPECTED_PROFILE="work"
else
    EXPECTED_PROFILE="personal"
fi
echo "  Expected profile: $EXPECTED_PROFILE"

# Check chezmoi data
echo ""
echo "→ Checking chezmoi profile data..."
CHEZMOI_PROFILE=$(chezmoi data | grep -A1 'profile' | grep 'type' | awk '{print $2}' | tr -d '",')

if [ -z "$CHEZMOI_PROFILE" ]; then
    echo "✗ Could not determine profile from chezmoi data"
    exit 1
fi

echo "  Detected profile: $CHEZMOI_PROFILE"

if [ "$CHEZMOI_PROFILE" = "$EXPECTED_PROFILE" ]; then
    echo "✓ Profile correctly detected"
else
    echo "✗ Profile mismatch (expected: $EXPECTED_PROFILE, got: $CHEZMOI_PROFILE)"
    exit 1
fi

# Run installation
echo ""
echo "→ Running installation with profile: $CHEZMOI_PROFILE..."
chezmoi apply --force 2>&1 | tee /tmp/profile-test.log

# Check which profile scripts ran
echo ""
echo "→ Checking which profile scripts executed..."

if [ "$EXPECTED_PROFILE" = "work" ]; then
    # Work profile: work script should run, personal should exit early
    if grep -q "Work Profile Installation" /tmp/profile-test.log; then
        echo "✓ Work profile script executed"
    else
        echo "⚠ Work profile script may not have run"
    fi

    if grep -q "Not a personal machine" /tmp/profile-test.log || grep -q "Personal Profile Installation" /tmp/profile-test.log; then
        echo "✓ Personal profile script correctly skipped"
    else
        echo "⚠ Could not verify personal profile skip"
    fi
else
    # Personal profile: personal script should run, work should exit early
    if grep -q "Personal Profile Installation" /tmp/profile-test.log; then
        echo "✓ Personal profile script executed"
    else
        echo "⚠ Personal profile script may not have run"
    fi

    if grep -q "Not a work machine" /tmp/profile-test.log || grep -q "Work Profile Installation" /tmp/profile-test.log; then
        echo "✓ Work profile script correctly skipped"
    else
        echo "⚠ Could not verify work profile skip"
    fi
fi

# Check state database for profile-specific categories
if [ -f ~/.local/state/chezmoi-installs/state.db.json ]; then
    echo ""
    echo "→ Checking installed categories..."

    if [ "$EXPECTED_PROFILE" = "work" ]; then
        WORK_CATS=$(jq -r '.phases["profile-work"].categories // {} | keys[]' ~/.local/state/chezmoi-installs/state.db.json 2>/dev/null | wc -l)
        echo "  Work categories processed: $WORK_CATS"

        if [ "$WORK_CATS" -gt 0 ]; then
            echo "✓ Work-specific categories were processed"
        else
            echo "⚠ No work categories found (may be expected if none defined)"
        fi
    else
        PERSONAL_CATS=$(jq -r '.phases["profile-personal"].categories // {} | keys[]' ~/.local/state/chezmoi-installs/state.db.json 2>/dev/null | wc -l)
        echo "  Personal categories processed: $PERSONAL_CATS"

        if [ "$PERSONAL_CATS" -gt 0 ]; then
            echo "✓ Personal-specific categories were processed"
        else
            echo "⚠ No personal categories found (may be expected if none defined)"
        fi
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST PASSED: Profile Detection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
