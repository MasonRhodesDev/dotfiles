#!/bin/bash
# Invalidate the drift nag cache (dot_bashrc.d/chezmoi-drift.bashrc) after every
# apply, so the banner never reports drift that this apply just reconciled.
# Deleting the files instead of running `chezmoi status` here: apply holds the
# persistent-state lock until it exits, so a nested chezmoi would block. The
# next interactive shell sees no stamp and refreshes in the background.
d=${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi-drift
rm -f "$d/status" "$d/status.new" "$d/stamp"
