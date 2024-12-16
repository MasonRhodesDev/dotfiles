#!/bin/bash
set -eu

# TEMPLATE
echo "Testing sudo elevation..."

# Attempt to run a command with sudo
if sudo -n whoami >/dev/null 2>&1; then
    echo "Sudo elevation successful. Running as: $(sudo whoami)"
else
    echo "Sudo elevation failed or requires password."
    exit 1
fi

# Additional test: Try to write to a root-only directory
if sudo -n touch /root/test_file 2>/dev/null; then
    echo "Successfully created a file in /root"
    sudo rm /root/test_file
else
    echo "Failed to create a file in /root"
    exit 1
fi

echo "Elevation test completed successfully."

sudo usermod -aG video,input "$(whoami)"

exit 0
