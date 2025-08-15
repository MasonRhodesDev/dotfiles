#!/bin/bash

# VS Code/Cursor theme module - direct settings.json modification

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

vscode_apply_theme() {
    local wallpaper="$1"
    local mode="$2" 
    local state_file="$3"
    
    local module_name="VSCode"
    
    log_module "$module_name" "Applying $mode theme to VS Code/Cursor"
    
    # Define settings paths for different editors
    local settings_files=(
        "$HOME/.config/Code/User/settings.json"           # VS Code
        "$HOME/.config/Cursor/User/settings.json"         # Cursor
        "$HOME/.config/Code - OSS/User/settings.json"     # VS Code OSS
        "$HOME/.config/VSCodium/User/settings.json"       # VSCodium
    )
    
    # Determine theme based on mode
    local color_theme
    if [[ "$mode" == "light" ]]; then
        color_theme="Default Light+"
    else
        color_theme="Default Dark+"
    fi
    
    local updated_count=0
    
    for settings_file in "${settings_files[@]}"; do
        if [[ -f "$settings_file" ]]; then
            # Read current settings
            local temp_file=$(mktemp)
            
            # Use jq to update the theme setting
            if jq --arg theme "$color_theme" '.["workbench.colorTheme"] = $theme' "$settings_file" > "$temp_file" 2>/dev/null; then
                mv "$temp_file" "$settings_file"
                log_module "$module_name" "Updated $(basename $(dirname $(dirname "$settings_file")))"
                ((updated_count++))
            else
                # Fallback: manual JSON editing if jq fails
                if grep -q '"workbench.colorTheme"' "$settings_file"; then
                    # Replace existing theme setting
                    sed -i "s/\"workbench.colorTheme\": \"[^\"]*\"/\"workbench.colorTheme\": \"$color_theme\"/" "$settings_file"
                    log_module "$module_name" "Updated $(basename $(dirname $(dirname "$settings_file"))) (fallback method)"
                    ((updated_count++))
                else
                    # Add theme setting to existing JSON
                    local temp_settings=$(mktemp)
                    # Remove closing brace, add theme setting, add closing brace
                    sed '$ s/}$//' "$settings_file" > "$temp_settings"
                    if [[ $(tail -1 "$temp_settings") =~ [^\s] ]]; then
                        echo "," >> "$temp_settings"
                    fi
                    echo "    \"workbench.colorTheme\": \"$color_theme\"" >> "$temp_settings"
                    echo "}" >> "$temp_settings"
                    mv "$temp_settings" "$settings_file"
                    log_module "$module_name" "Added theme setting to $(basename $(dirname $(dirname "$settings_file")))"
                    ((updated_count++))
                fi
                rm -f "$temp_file"
            fi
        fi
    done
    
    if [[ $updated_count -eq 0 ]]; then
        log_module "$module_name" "No VS Code/Cursor installations found"
    else
        log_module "$module_name" "Updated $updated_count editor(s) to $mode theme"
    fi
    
    return 0
}