#!/bin/bash

# List of applications to modify
apps="vivaldi vivaldi-stable chromium slack code"

# Wayland arguments to remove
wayland_args=("--enable-features=UseOzonePlatform" "--ozone-platform=wayland")

# Function to find .desktop file for an app based on its executable path
find_desktop_file() {
    local exec_path="$1"
    local desktop_files=$(find /usr/share/applications ~/.local/share/applications -name "*.desktop" 2>/dev/null)
    
    for file in $desktop_files; do
        if grep -q "^Exec=.*$(basename "$exec_path")" "$file"; then
            echo "$file"
            return 0
        fi
    done
    
    # Special case for vivaldi-stable
    if [[ "$(basename "$exec_path")" == "vivaldi" ]]; then
        for file in $desktop_files; do
            if grep -q "^Exec=.*vivaldi-stable" "$file"; then
                echo "$file"
                return 0
            fi
        done
    fi
    
    return 1
}

# Function to remove specific arguments from the Exec line
remove_args_from_exec() {
    local line="$1"
    shift
    local args_to_remove=("$@")
    
    # Remove "Exec=" prefix
    line="${line#Exec=}"
    
    # For each argument to remove
    for arg in "${args_to_remove[@]}"; do
        # Remove the argument (with space before or after)
        line="${line//$arg /}"
        line="${line// $arg/}"
    done
    
    # Add back the Exec= prefix
    echo "Exec=$line"
}

# Process each app
for app in $apps; do
    # Check if the app is installed
    app_path=$(which "$app" 2>/dev/null)
    if [ -z "$app_path" ]; then
        echo "$app is not installed. Skipping."
        continue
    fi

    echo "Processing $app..."

    # Find the .desktop file
    desktop_file=$(find_desktop_file "$app_path")
    if [ -z "$desktop_file" ]; then
        echo "No .desktop file found for $app. Skipping."
        continue
    fi

    echo "Found .desktop file: $desktop_file"

    modified=false
    
    # Create a temporary file
    temp_file=$(mktemp)
    
    # Process the file line by line
    while IFS= read -r line; do
        if [[ $line =~ ^Exec= ]]; then
            # Check if any of the Wayland args are present
            contains_wayland_args=false
            for arg in "${wayland_args[@]}"; do
                if [[ "$line" == *"$arg"* ]]; then
                    contains_wayland_args=true
                    break
                fi
            done
            
            if [ "$contains_wayland_args" = true ]; then
                # Remove the Wayland arguments
                new_line=$(remove_args_from_exec "$line" "${wayland_args[@]}")
                echo "Modified: $new_line"
                echo "$new_line" >> "$temp_file"
                modified=true
            else
                echo "No Wayland args found in: $line"
                echo "$line" >> "$temp_file"
            fi
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$desktop_file"
    
    # If modifications were made, replace the original file
    if [ "$modified" = true ]; then
        echo "Updating: $desktop_file"
        sudo mv "$temp_file" "$desktop_file"
    else
        echo "No changes needed for: $desktop_file"
        rm "$temp_file"
    fi
done

echo "Script completed. Wayland arguments have been removed from application launchers." 