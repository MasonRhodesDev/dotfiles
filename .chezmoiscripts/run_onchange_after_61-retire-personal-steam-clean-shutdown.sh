#!/bin/bash

set -uo pipefail

unitdir="$HOME/.config/systemd/user"
old="$unitdir/steam-clean-shutdown.service"
link="$unitdir/graphical-session.target.wants/steam-clean-shutdown.service"
packaged="/usr/lib/systemd/user/steam-clean-shutdown.service"

rm -f "$old" "$unitdir/app-.scope.d/steam-clean-shutdown.conf"
rmdir "$unitdir/app-.scope.d" 2>/dev/null || true

[ -L "$link" ] && [ "$(readlink "$link")" = "$old" ] || exit 0

echo "Retiring personal steam-clean-shutdown.service (hypr-de-gaming ships it)"
rm -f "$link"
systemctl --user daemon-reload 2>/dev/null || true
if [ -f "$packaged" ]; then
    systemctl --user enable steam-clean-shutdown.service 2>/dev/null || true
fi
exit 0
