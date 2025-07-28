#!/bin/bash

# List of applications to modify
apps="vivaldi chromium slack code"

# Wayland arguments to add (as an array)
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
    return 1
}

# Function to check if an argument is already present in the Exec line
is_arg_present() {
    local line="$1"
    local arg="$2"
    [[ "$line" == *"$arg"* ]]
}

# Function to modify Exec line
modify_exec_line() {
    local line="$1"
    local new_args="$2"
    
    # Remove "Exec=" prefix and any surrounding quotes
    line="${line#Exec=}"
    line="${line#\"}"
    line="${line%\"}"
    
    # Split the Exec line into parts
    local parts=()
    read -ra parts <<< "$line"
    
    # Reconstruct the Exec line with Wayland args right after the executable
    local new_line="Exec=${parts[0]} $new_args"
    for ((i=1; i<${#parts[@]}; i++)); do
        new_line+=" ${parts[i]}"
    done
    
    echo "$new_line"
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

    # Check if NoDisplay=true is present
    if grep -q "^NoDisplay=true" "$desktop_file"; then
        echo "Skipping hidden application: $desktop_file"
        continue
    fi

    modified=false
    
    # Create a temporary file
    temp_file=$(mktemp)
    
    # Process the file line by line
    while IFS= read -r line; do
        if [[ $line =~ ^Exec= ]]; then
            new_args=""
            for arg in "${wayland_args[@]}"; do
                if ! is_arg_present "$line" "$arg"; then
                    new_args+=" $arg"
                    modified=true
                fi
            done
            
            if [ -n "$new_args" ]; then
                line=$(modify_exec_line "$line" "$new_args")
                echo "Modified: $line"
            else
                echo "No changes needed for: $line"
            fi
        fi
        echo "$line" >> "$temp_file"
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

echo "Script completed."