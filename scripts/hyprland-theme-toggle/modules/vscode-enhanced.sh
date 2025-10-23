#!/bin/bash

# VS Code Material You color customization module

source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

vscode_enhanced_apply_theme() {
    local wallpaper="$1"
    local mode="$2"
    local state_file="$3"
    
    local module_name="VSCode-Enhanced"
    local colors_file="$HOME/.config/matugen/lmtt-colors.css"
    
    log_module "$module_name" "Generating Material You workbench colors for $mode theme"
    
    if [[ ! -f "$colors_file" ]]; then
        log_module "$module_name" "Colors file not found, skipping"
        return 0
    fi
    
    # Extract Material You colors
    local surface=$(grep "^@define-color surface " "$colors_file" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local on_surface=$(grep "^@define-color on_surface " "$colors_file" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local primary=$(grep "^@define-color primary " "$colors_file" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local primary_container=$(grep "^@define-color primary_container " "$colors_file" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local secondary=$(grep "^@define-color secondary " "$colors_file" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local surface_container=$(grep "^@define-color surface_container " "$colors_file" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local error=$(grep "^@define-color error " "$colors_file" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    local outline=$(grep "^@define-color outline " "$colors_file" | grep -o '#[0-9a-fA-F]\{6\}' | head -1)
    
    # Define settings paths
    local settings_files=(
        "$HOME/.vscode/settings.json"
        "$HOME/.config/Code/User/settings.json"
        "$HOME/.config/Cursor/User/settings.json"
    )
    
    local updated_count=0
    
    for settings_file in "${settings_files[@]}"; do
        if [[ -f "$settings_file" ]]; then
            # Generate Material You workbench color customizations
            local color_customizations=$(cat <<EOF
{
    "workbench.colorCustomizations": {
        "activityBar.background": "$surface_container",
        "activityBar.foreground": "$primary",
        "activityBarBadge.background": "$primary",
        "activityBarBadge.foreground": "$surface",
        "sideBar.background": "$surface",
        "sideBar.foreground": "$on_surface",
        "sideBarTitle.foreground": "$primary",
        "sideBarSectionHeader.background": "$surface_container",
        "editorGroupHeader.tabsBackground": "$surface",
        "tab.activeBackground": "$surface_container",
        "tab.activeForeground": "$primary",
        "tab.inactiveBackground": "$surface",
        "tab.inactiveForeground": "$outline",
        "tab.border": "$surface",
        "editor.background": "$surface",
        "editor.foreground": "$on_surface",
        "editorLineNumber.foreground": "$outline",
        "editorLineNumber.activeForeground": "$primary",
        "editor.selectionBackground": "$primary_container",
        "statusBar.background": "$surface_container",
        "statusBar.foreground": "$on_surface",
        "statusBar.noFolderBackground": "$surface_container",
        "titleBar.activeBackground": "$surface",
        "titleBar.activeForeground": "$on_surface",
        "button.background": "$primary",
        "button.foreground": "$surface",
        "input.background": "$surface_container",
        "input.foreground": "$on_surface",
        "input.border": "$outline",
        "focusBorder": "$primary",
        "list.activeSelectionBackground": "$primary_container",
        "list.activeSelectionForeground": "$on_surface",
        "list.hoverBackground": "$surface_container",
        "list.inactiveSelectionBackground": "$surface_container"
    }
}
EOF
)
            
            # Use jq to merge customizations if available
            if command -v jq >/dev/null 2>&1; then
                local temp_file=$(mktemp)
                echo "$color_customizations" | jq -s '.[0] * .[1]' "$settings_file" - > "$temp_file" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    mv "$temp_file" "$settings_file"
                    log_module "$module_name" "Updated $(basename "$(dirname "$(dirname "$settings_file")")")"
                    ((updated_count++))
                else
                    rm -f "$temp_file"
                    log_module "$module_name" "Failed to update $(basename "$(dirname "$(dirname "$settings_file")")")"
                fi
            else
                log_module "$module_name" "jq not available, skipping JSON merge"
            fi
        fi
    done
    
    if [[ $updated_count -eq 0 ]]; then
        log_module "$module_name" "No VS Code installations found or updated"
    else
        log_module "$module_name" "Updated $updated_count editor(s) with Material You colors"
    fi
    
    return 0
}
