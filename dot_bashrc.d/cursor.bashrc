# Cursor's installer added ~/.local/bin to PATH. Redundant with ~/.bashrc, but
# kept so re-running the installer finds what it expects; path_prepend makes
# the repetition harmless.
path_prepend "$HOME/.local/bin"
