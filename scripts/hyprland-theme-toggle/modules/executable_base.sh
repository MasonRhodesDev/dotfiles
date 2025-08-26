#!/bin/bash

# Base module functions for theme system

# Check if an application is installed
app_installed() {
    local app_name="$1"
    command -v "$app_name" >/dev/null 2>&1
}

# Check if theme files exist and are newer than wallpaper
theme_cached() {
    local config_file="$1"
    local wallpaper="$2"
    local state_file="$3"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # Check if config is newer than wallpaper and state file
    if [[ "$config_file" -nt "$wallpaper" && "$config_file" -nt "$state_file" ]]; then
        return 0
    else
        return 1
    fi
}

# Get current theme state
get_theme_state() {
    local state_file="$1"
    cat "$state_file" 2>/dev/null || echo "dark"
}

# Log module activity
log_module() {
    local module="$1"
    local action="$2"
    echo "[$module] $action"
}

# Performance monitoring functions
start_timer() {
    date +%s.%N
}

end_timer() {
    local start_time="$1"
    local end_time=$(date +%s.%N)
    echo "scale=3; $end_time - $start_time" | bc
}

log_performance() {
    local module="$1" 
    local duration="$2"
    local threshold="0.250"
    
    # Check if duration exceeds threshold
    if (( $(echo "$duration > $threshold" | bc -l) )); then
        echo "⚠️  [$module] Performance warning: ${duration}s (>${threshold}s threshold)"
    else
        echo "✓ [$module] Completed in ${duration}s"
    fi
}

# Run module with performance monitoring
run_module_with_timing() {
    local module_script="$1"
    local module_name="$2"
    local wallpaper="$3"
    local mode="$4"
    local state_file="$5"
    local colors_json="$6"
    
    local start_time=$(start_timer)
    
    # Source and execute the module
    source "$module_script"
    "${module_name}_apply_theme" "$wallpaper" "$mode" "$state_file" "$colors_json"
    local exit_code=$?
    
    local duration=$(end_timer "$start_time")
    log_performance "$module_name" "$duration"
    
    return $exit_code
}