#!/bin/bash 

# Check if bun is installed before setting up environment
if [ -d "$HOME/.bun" ]; then
    export BUN_INSTALL="$HOME/.bun"
    export PATH=$BUN_INSTALL/bin:$PATH
fi