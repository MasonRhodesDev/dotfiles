# Node.js environment configuration

# fnm (Fast Node Manager). `fnm env` mints a fresh
# /run/user/*/fnm_multishells/<pid>_<timestamp>/bin per shell and prepends it,
# so nested shells accumulate stale-but-existing copies; path_dedupe in
# ~/.bashrc collapses them down to this shell's.
if [ -d "$HOME/.local/share/fnm" ]; then
    path_prepend "$HOME/.local/share/fnm"
    eval "$(fnm env)"
fi

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
path_prepend "$PNPM_HOME"
