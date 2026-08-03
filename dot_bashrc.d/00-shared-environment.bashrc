# Source shared environment variables
if [ -f "$HOME/.config/environment" ]; then
    . "$HOME/.config/environment"
fi

# fnm env eval lives in node.bashrc (with FNM_PATH + PNPM) — was duplicated here.
