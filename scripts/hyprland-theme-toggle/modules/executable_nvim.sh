#!/bin/bash

# Neovim theme module - switches colorscheme in all running instances

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

nvim_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    # Note: No colors_json parameter since we use pre-made colorschemes
    
    local module_name="Neovim"
    
    # Determine colorscheme based on mode
    local colorscheme
    if [[ "$mode" == "light" ]]; then
        colorscheme="oxocarbon"
    else
        colorscheme="darkplus"
    fi
    
    log_module "$module_name" "Switching to $colorscheme colorscheme for $mode mode"
    
    # Method 1: Use Neovim sockets (most reliable)
    local socket_count=0
    for socket_dir in /tmp/nvim*; do
        if [[ -d "$socket_dir" ]]; then
            local socket_path="$socket_dir/0"
            if [[ -S "$socket_path" ]]; then
                # Use the new global theme function that sets both background and colorscheme
                if timeout 2 nvim --server "$socket_path" --remote-expr "_G.set_nvim_theme('$mode')" >/dev/null 2>&1; then
                    ((socket_count++))
                fi
            fi
        fi
    done
    
    # Method 2: Use nvim --remote with server addresses from running processes
    local remote_count=0
    while IFS= read -r line; do
        # Extract PID from pgrep output
        local pid=$(echo "$line" | awk '{print $1}')
        local listen_addr
        
        # Check if process has NVIM_LISTEN_ADDRESS set
        if [[ -f "/proc/$pid/environ" ]]; then
            listen_addr=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep '^NVIM_LISTEN_ADDRESS=' | cut -d= -f2)
            
            if [[ -n "$listen_addr" ]]; then
                # Use the new global theme function that sets both background and colorscheme
                if timeout 2 nvim --server "$listen_addr" --remote-expr "_G.set_nvim_theme('$mode')" >/dev/null 2>&1; then
                    ((remote_count++))
                fi
            fi
        fi
    done < <(pgrep -f "nvim --embed")
    
    # Method 3: Trigger auto-detection in instances that might not have sockets
    # The autocmd we added will detect theme changes when focus returns to nvim
    local signal_count=0
    while IFS= read -r pid; do
        # Send a harmless signal (CONT) to potentially trigger focus events
        # This is more reliable than USR1 since we're using file-based detection now
        if kill -CONT "$pid" 2>/dev/null; then
            ((signal_count++))
        fi
    done < <(pgrep -f "nvim")
    
    # Note: Nvim instances will auto-detect the theme change via the FocusGained/CursorHold autocmds
    
    local total_attempts=$((socket_count + remote_count + signal_count))
    if [[ $total_attempts -gt 0 ]]; then
        log_module "$module_name" "Updated colorscheme in $total_attempts Neovim instance(s)"
    else
        log_module "$module_name" "No running Neovim instances found"
    fi
    
    return 0
}