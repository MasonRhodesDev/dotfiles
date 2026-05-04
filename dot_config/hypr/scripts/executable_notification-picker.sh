#!/usr/bin/env bash
# Notification inbox picker for hyprnotice.
#
# Lists every visible + inbox notification in wofi. Selecting one runs its
# default action (often opens the source app's relevant view) and dismisses;
# if the notification has named actions, they're shown as separate pickable
# entries. "Dismiss all" wipes everything.
set -euo pipefail

list=$(hyprnotice-ctl list 2>/dev/null || true)

if [ -z "$list" ] || [ "$list" = "(empty)" ]; then
    notify-send -t 1500 -a notifications "No notifications"
    exit 0
fi

# Each row is "[state] # ID (app) summary [— body]". Extract id + summary for
# the picker, prepend the action prefix invoke/dismiss to disambiguate.
formatted=$(echo "$list" | sed -nE 's/^\[(visible|inbox)\] #[[:space:]]*([0-9]+) \(([^)]*)\) (.*)$/\2\t[\1] (\3) \4/p')

menu=$({
    printf 'Dismiss all\n'
    printf -- '---\n'
    while IFS=$'\t' read -r id desc; do
        printf 'invoke\t%s\t%s\n' "$id" "$desc"
        printf 'dismiss\t%s\t%s\n' "$id" "$desc (dismiss only)"
    done <<< "$formatted"
})

pick=$(echo "$menu" | awk -F'\t' '{
    if (NF == 1) print $1;
    else if (NF == 3) print $2 " " $1 ": " $3;
}' | wofi --dmenu --prompt "notifications" --insensitive)
[ -z "$pick" ] && exit 0

case "$pick" in
    "Dismiss all")
        hyprnotice-ctl dismiss-all
        ;;
    "---")
        ;;
    *)
        # Format is "<id> <verb>: <rest>". Parse first two tokens.
        id=${pick%% *}
        rest=${pick#* }
        verb=${rest%%:*}
        case "$verb" in
            invoke)  hyprnotice-ctl invoke "$id" default ;;
            dismiss) hyprnotice-ctl dismiss "$id" ;;
            *)       echo "unknown verb: $verb" >&2; exit 1 ;;
        esac
        ;;
esac
