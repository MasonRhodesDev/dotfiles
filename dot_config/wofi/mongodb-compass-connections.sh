#!/bin/bash

MONGODB_COMPASS_CONNECTIONS_FOLDER_ID=20180d61-ed98-4fed-8bcb-b16401212e6b

entries=$(bw list items --folderid $MONGODB_COMPASS_CONNECTIONS_FOLDER_ID)

selected=$(echo -e $entries | jq -r '.[] | .name' | wofi --width 250 --height 210 --dmenu --cache-file /dev/null)

selected_conn_str=$(bw get item $(echo -e $entries | jq -r ".[] | select(.name == \"$selected\") | .id") | jq -r '.fields[] | select(.name == "compass") | .value')

if [ -n "$selected_conn_str" ]; then
  mongodb-compass $selected_conn_str
else
  notify-send "No connection string found" --urgency=critical
fi
