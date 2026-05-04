#!/usr/bin/env bash
# Trigger hyprnotice to re-read ~/.config/matugen/lmtt-colors.css.
# Sent after lmtt's built-in modules have regenerated the file.
exec pkill -HUP -x hyprnotice
