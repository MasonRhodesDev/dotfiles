#!/bin/bash
# Check if keychain is installed
if ! command -v keychain &> /dev/null; then
    echo "Warning: keychain is not installed. Please install it using your package manager."
else
    source $HOME/.keychain/$HOSTNAME-sh
fi
