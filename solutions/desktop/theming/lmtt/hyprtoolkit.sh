#!/bin/bash

strip() { echo "${1#\#}"; }

cat > ~/.config/hypr/hyprtoolkit.conf << EOF

background = 0xFF$(strip "$LMTT_BACKGROUND")
base = 0xFF$(strip "$LMTT_SURFACE_CONTAINER_LOW")
text = 0xFF$(strip "$LMTT_ON_SURFACE")
alternate_base = 0xFF$(strip "$LMTT_SURFACE_CONTAINER_HIGH")
bright_text = 0xFF$(strip "$LMTT_ON_SURFACE")
link_text = 0xFF$(strip "$LMTT_OUTLINE")
accent = 0xFF$(strip "$LMTT_PRIMARY")
accent_secondary = 0xFF$(strip "$LMTT_SECONDARY")
icon_theme = breeze-dark
EOF
