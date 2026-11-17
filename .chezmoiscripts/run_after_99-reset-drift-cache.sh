#!/bin/bash
d=${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi-drift
rm -f "$d/status" "$d/status.new" "$d/stamp"
