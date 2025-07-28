#!/bin/bash

# Get all audio sources with their info
get_sources() {
    pw-cli ls Node | awk '
        BEGIN { RS="\tid"; FS="\n"; OFS="|" }
        {
            id = $1
            name = ""
            desc = ""
            volume = ""
            media_class = ""
            app_name = ""
            
            for (i=1; i<=NF; i++) {
                if ($i ~ /application.name =/) {
                    match($i, /"([^"]+)"/)
                    app_name = substr($i, RSTART+1, RLENGTH-2)
                }
                if ($i ~ /node.description =/) {
                    match($i, /"([^"]+)"/)
                    desc = substr($i, RSTART+1, RLENGTH-2)
                }
                if ($i ~ /media.class =/) {
                    match($i, /"([^"]+)"/)
                    media_class = substr($i, RSTART+1, RLENGTH-2)
                }
                if ($i ~ /volume.level =/) {
                    volume = $i
                    sub(/.*volume.level = /, "", volume)
                }
            }
            
            if ((media_class ~ /^Stream\/Input\/Audio$/ || media_class ~ /^Audio\/Source$/) && (app_name != "" || desc != "")) {
                name = app_name != "" ? app_name : desc
                if (volume == "") volume = "1.0"
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
                printf "%s|%s|%.0f\n", id, name, volume * 100
            }
        }
    '
}

# Show wofi menu with current volumes
selected=$(get_sources | while IFS='|' read -r id name volume; do
    printf "%s|%s|%d%%\n" "$id" "$name" "$volume"
done | column -t -s '|' | wofi --dmenu -i -p "Input Controls" --width 400 --height 300 --cache-file /dev/null)

if [ -n "$selected" ]; then
    # Extract ID from selection
    id=$(echo "$selected" | awk '{print $1}')
    
    # Show volume control menu
    action=$(echo -e "Increase 5%\nDecrease 5%\nSet to 100%\nSet to 50%\nMute" | \
        wofi --dmenu -i -p "Volume Control" --width 200 --height 200 --cache-file /dev/null)

    case "$action" in
        "Increase 5%")
            current_vol=$(pw-cli dump Node "$id" | grep volume.level | awk '{print $3}')
            new_vol=$(echo "$current_vol + 0.05" | bc)
            [ $(echo "$new_vol > 1.5" | bc) -eq 1 ] && new_vol=1.5
            pw-cli set-param "$id" Props "{volume.level: $new_vol}"
            ;;
        "Decrease 5%")
            current_vol=$(pw-cli dump Node "$id" | grep volume.level | awk '{print $3}')
            new_vol=$(echo "$current_vol - 0.05" | bc)
            [ $(echo "$new_vol < 0" | bc) -eq 1 ] && new_vol=0
            pw-cli set-param "$id" Props "{volume.level: $new_vol}"
            ;;
        "Set to 100%")
            pw-cli set-param "$id" Props "{volume.level: 1.0}"
            ;;
        "Set to 50%")
            pw-cli set-param "$id" Props "{volume.level: 0.5}"
            ;;
        "Mute")
            pw-cli set-param "$id" Props "{mute: true}"
            ;;
    esac
fi 