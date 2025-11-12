#!/bin/bash

# Reload shell configuration on every apply

# Check if user groups changed and notify
CURRENT_GROUPS=$(id -Gn)
GROUPS_CACHE="$HOME/.cache/chezmoi-user-groups"

if [ -f "$GROUPS_CACHE" ]; then
    OLD_GROUPS=$(cat "$GROUPS_CACHE")
    if [ "$CURRENT_GROUPS" != "$OLD_GROUPS" ]; then
        echo ""
        echo "WARNING: User groups have changed!"
        echo "Old groups: $OLD_GROUPS"
        echo "New groups: $CURRENT_GROUPS"
        echo "You may need to log out and back in for group changes to take full effect."
        echo ""
    fi
fi

# Update groups cache
echo "$CURRENT_GROUPS" > "$GROUPS_CACHE"
