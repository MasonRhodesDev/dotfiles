# Source shared environment variables
if [ -f "$HOME/.config/environment" ]; then
    . "$HOME/.config/environment"
fi

# fnm eval (bash-specific)
if command -v fnm &> /dev/null; then
    eval "$(fnm env)"
fi
