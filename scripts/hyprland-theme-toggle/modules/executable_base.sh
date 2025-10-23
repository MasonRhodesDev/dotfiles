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

# Calculate SHA256 hash of a file
calculate_wallpaper_hash() {
    local wallpaper_path="$1"
    
    if [[ ! -f "$wallpaper_path" ]]; then
        echo ""
        return 1
    fi
    
    sha256sum "$wallpaper_path" | awk '{print $1}'
}

# Check if wallpaper has changed since last generation
wallpaper_changed() {
    local wallpaper_path="$1"
    local cache_file="$HOME/.cache/lmtt-wallpaper.hash"
    
    local current_hash=$(calculate_wallpaper_hash "$wallpaper_path")
    
    if [[ -z "$current_hash" ]]; then
        return 0  # No wallpaper found, needs generation
    fi
    
    if [[ ! -f "$cache_file" ]]; then
        return 0  # No cache, needs generation
    fi
    
    local cached_hash=$(cat "$cache_file" 2>/dev/null)
    
    if [[ "$current_hash" != "$cached_hash" ]]; then
        return 0  # Hashes differ, needs regeneration
    fi
    
    return 1  # Hashes match, no regeneration needed
}

# Update wallpaper hash cache
update_wallpaper_cache() {
    local wallpaper_path="$1"
    local cache_file="$HOME/.cache/lmtt-wallpaper.hash"
    
    local current_hash=$(calculate_wallpaper_hash "$wallpaper_path")
    
    if [[ -n "$current_hash" ]]; then
        echo "$current_hash" > "$cache_file"
        return 0
    fi
    
    return 1
}

# Generate CSS from matugen JSON output
generate_css_from_json() {
    local colors_json="$1"
    local mode="$2"
    local output_file="$3"
    
    # Create CSS file with @define-color declarations
    {
        echo "/* Centralized Material You colors for all applications */"
        echo "/* Generated for $mode mode */"
        echo ""
        echo "$colors_json" | jq -r ".colors.${mode} | to_entries[] | \"@define-color \\(.key) \\(.value);\""
        echo ""
        echo "/* Compatibility aliases */"
        echo "@define-color foreground @on_surface;"
        echo "@define-color accent @primary;"
        echo "@define-color color7 @on_surface;"
        echo "@define-color color9 @secondary;"
    } > "$output_file"
}

# Convert hex color to sRGB tuple for XDG portal
hex_to_srgb_tuple() {
    local hex="$1"
    hex="${hex#\#}"
    
    # Extract RGB components
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    
    # Convert to [0,1] range with 6 decimal precision
    printf "%.6f %.6f %.6f" \
        "$(echo "scale=6; $r/255" | bc)" \
        "$(echo "scale=6; $g/255" | bc)" \
        "$(echo "scale=6; $b/255" | bc)"
}

# Map Material You color to closest gsettings accent-color enum
map_color_to_gsettings_enum() {
    local hex="$1"
    hex="${hex#\#}"
    
    # Extract RGB components (0-255)
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    
    # Simple heuristic: find dominant channel and hue
    local max=$r
    local max_channel="r"
    
    if (( g > max )); then
        max=$g
        max_channel="g"
    fi
    
    if (( b > max )); then
        max=$b
        max_channel="b"
    fi
    
    # Calculate rough hue and saturation
    local min=$r
    (( g < min )) && min=$g
    (( b < min )) && min=$b
    
    local saturation=$((max - min))
    
    # Low saturation = slate
    if (( saturation < 30 )); then
        echo "slate"
        return
    fi
    
    # Map based on dominant channel and relationships
    case "$max_channel" in
        r)
            if (( g > b + 30 )); then
                echo "orange"  # Red+Green = Orange/Yellow
            elif (( b > g + 30 )); then
                echo "pink"    # Red+Blue = Pink/Purple
            else
                echo "red"
            fi
            ;;
        g)
            if (( b > r + 20 )); then
                echo "teal"    # Green+Blue = Teal
            elif (( r > b + 20 )); then
                echo "yellow"  # Green+Red = Yellow
            else
                echo "green"
            fi
            ;;
        b)
            if (( r > g + 20 )); then
                echo "purple"  # Blue+Red = Purple
            elif (( g > r + 20 )); then
                echo "teal"    # Blue+Green = Teal
            else
                echo "blue"
            fi
            ;;
    esac
}

# Convert hex to RGB comma-separated (for KDE color schemes)
hex_to_rgb() {
    local hex="$1"
    hex="${hex#\#}"
    
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    
    echo "$r,$g,$b"
}

# Generate KDE color scheme file from Material You colors
generate_kde_colorscheme() {
    local colors_css="$1"
    local mode="$2"
    local output_file="$3"
    
    # Extract colors from CSS
    local surface=$(grep "^@define-color surface " "$colors_css" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local on_surface=$(grep "^@define-color on_surface " "$colors_css" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local primary=$(grep "^@define-color primary " "$colors_css" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local primary_container=$(grep "^@define-color primary_container " "$colors_css" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local on_primary=$(grep "^@define-color on_primary " "$colors_css" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local secondary=$(grep "^@define-color secondary " "$colors_css" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local tertiary=$(grep "^@define-color tertiary " "$colors_css" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local error=$(grep "^@define-color error " "$colors_css" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local surface_container=$(grep "^@define-color surface_container " "$colors_css" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local surface_bright=$(grep "^@define-color surface_bright " "$colors_css" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local outline=$(grep "^@define-color outline " "$colors_css" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    
    # Convert to RGB
    local rgb_surface=$(hex_to_rgb "$surface")
    local rgb_on_surface=$(hex_to_rgb "$on_surface")
    local rgb_primary=$(hex_to_rgb "$primary")
    local rgb_primary_container=$(hex_to_rgb "$primary_container")
    local rgb_on_primary=$(hex_to_rgb "$on_primary")
    local rgb_secondary=$(hex_to_rgb "$secondary")
    local rgb_tertiary=$(hex_to_rgb "$tertiary")
    local rgb_error=$(hex_to_rgb "$error")
    local rgb_surface_container=$(hex_to_rgb "$surface_container")
    local rgb_surface_bright=$(hex_to_rgb "$surface_bright")
    local rgb_outline=$(hex_to_rgb "$outline")
    
    # Generate KDE color scheme
    local scheme_name="LMTT-$(echo "$mode" | sed 's/.*/\u&/')"
    
    cat > "$output_file" << EOF
# Generated by lmtt (Linux Matugen Theme Toggle) for Qt/KDE applications
# Mode: $mode

[ColorEffects:Disabled]
Color=56,56,56
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=$rgb_outline
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
BackgroundAlternate=$rgb_surface_container
BackgroundNormal=$rgb_surface
DecorationFocus=$rgb_primary
DecorationHover=$rgb_primary
ForegroundActive=$rgb_primary
ForegroundInactive=$rgb_outline
ForegroundLink=$rgb_tertiary
ForegroundNegative=$rgb_error
ForegroundNeutral=$rgb_secondary
ForegroundNormal=$rgb_on_surface
ForegroundPositive=$rgb_primary
ForegroundVisited=$rgb_secondary

[Colors:Complementary]
BackgroundAlternate=$rgb_surface_container
BackgroundNormal=$rgb_surface
DecorationFocus=$rgb_primary
DecorationHover=$rgb_primary
ForegroundActive=$rgb_primary
ForegroundInactive=$rgb_outline
ForegroundLink=$rgb_tertiary
ForegroundNegative=$rgb_error
ForegroundNeutral=$rgb_secondary
ForegroundNormal=$rgb_on_surface
ForegroundPositive=$rgb_primary
ForegroundVisited=$rgb_secondary

[Colors:Header]
BackgroundAlternate=$rgb_surface_bright
BackgroundNormal=$rgb_surface_container
DecorationFocus=$rgb_primary
DecorationHover=$rgb_primary
ForegroundActive=$rgb_primary
ForegroundInactive=$rgb_outline
ForegroundLink=$rgb_tertiary
ForegroundNegative=$rgb_error
ForegroundNeutral=$rgb_secondary
ForegroundNormal=$rgb_on_surface
ForegroundPositive=$rgb_primary
ForegroundVisited=$rgb_secondary

[Colors:Header][Inactive]
BackgroundAlternate=$rgb_surface_container
BackgroundNormal=$rgb_surface_bright
DecorationFocus=$rgb_primary
DecorationHover=$rgb_primary
ForegroundActive=$rgb_primary
ForegroundInactive=$rgb_outline
ForegroundLink=$rgb_tertiary
ForegroundNegative=$rgb_error
ForegroundNeutral=$rgb_secondary
ForegroundNormal=$rgb_on_surface
ForegroundPositive=$rgb_primary
ForegroundVisited=$rgb_secondary

[Colors:Selection]
BackgroundAlternate=$rgb_primary_container
BackgroundNormal=$rgb_primary
DecorationFocus=$rgb_primary
DecorationHover=$rgb_primary
ForegroundActive=$rgb_on_primary
ForegroundInactive=$rgb_outline
ForegroundLink=$rgb_tertiary
ForegroundNegative=$rgb_error
ForegroundNeutral=$rgb_secondary
ForegroundNormal=$rgb_on_primary
ForegroundPositive=$rgb_primary
ForegroundVisited=$rgb_secondary

[Colors:Tooltip]
BackgroundAlternate=$rgb_surface_bright
BackgroundNormal=$rgb_surface_container
DecorationFocus=$rgb_primary
DecorationHover=$rgb_primary
ForegroundActive=$rgb_primary
ForegroundInactive=$rgb_outline
ForegroundLink=$rgb_tertiary
ForegroundNegative=$rgb_error
ForegroundNeutral=$rgb_secondary
ForegroundNormal=$rgb_on_surface
ForegroundPositive=$rgb_primary
ForegroundVisited=$rgb_secondary

[Colors:View]
BackgroundAlternate=$rgb_surface_container
BackgroundNormal=$rgb_surface
DecorationFocus=$rgb_primary
DecorationHover=$rgb_primary
ForegroundActive=$rgb_primary
ForegroundInactive=$rgb_outline
ForegroundLink=$rgb_tertiary
ForegroundNegative=$rgb_error
ForegroundNeutral=$rgb_secondary
ForegroundNormal=$rgb_on_surface
ForegroundPositive=$rgb_primary
ForegroundVisited=$rgb_secondary

[Colors:Window]
BackgroundAlternate=$rgb_surface_container
BackgroundNormal=$rgb_surface
DecorationFocus=$rgb_primary
DecorationHover=$rgb_primary
ForegroundActive=$rgb_primary
ForegroundInactive=$rgb_outline
ForegroundLink=$rgb_tertiary
ForegroundNegative=$rgb_error
ForegroundNeutral=$rgb_secondary
ForegroundNormal=$rgb_on_surface
ForegroundPositive=$rgb_primary
ForegroundVisited=$rgb_secondary

[General]
ColorScheme=$scheme_name
Name=$scheme_name
shadeSortColumn=true

[KDE]
contrast=4

[WM]
activeBackground=$rgb_surface_container
activeBlend=$rgb_surface_container
activeForeground=$rgb_on_surface
inactiveBackground=$rgb_surface
inactiveBlend=$rgb_surface
inactiveForeground=$rgb_outline
EOF
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