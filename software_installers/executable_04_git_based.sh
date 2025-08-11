#!/bin/sh
set -eu

# Git-based installers aggregator
# Runs available git installers in a sensible order

run_if_exists() {
  if [ -x "$1" ]; then
    echo "Running $1"
    "$1"
  else
    echo "Skipping $1 (not found or not executable)"
  fi
}

# Astal first (libraries used by others)
run_if_exists "$HOME/git_installers/astal/executable_install.sh"

# HyprPanel (Fedora-only script; it will no-op elsewhere)
if command -v dnf >/dev/null 2>&1; then
  run_if_exists "$HOME/git_installers/hyprpanel/executable_install.sh"
else
  echo "Skipping HyprPanel (not Fedora)"
fi

# Marble Shell (supports Arch and Fedora)
run_if_exists "$HOME/git_installers/marble-shell/executable_install.sh"

exit 0
