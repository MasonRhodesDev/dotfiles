# Node.js environment configuration

# fnm (Fast Node Manager). Resolve the binary explicitly rather than assuming
# it is already on PATH: installer-based setups put it in ~/.local/share/fnm,
# but a cargo install (this machine) leaves it in ~/.cargo/bin, which reaches
# PATH only via ~/.profile — and only login shells read that. A non-login shell
# (systemd user unit, `bash -i` from a non-login parent) therefore used to fail
# with "bash: fnm: command not found" here. Note ~/.local/share/fnm also holds
# fnm's own data (aliases/, node-versions/), so `-d` on it proves nothing about
# the binary; test for `-x`.
#
# `fnm env` mints a fresh /run/user/*/fnm_multishells/<pid>_<timestamp>/bin per
# shell and prepends it, so nested shells accumulate stale-but-existing copies;
# path_dedupe in ~/.bashrc collapses them down to this shell's.
_fnm=$(command -v fnm 2>/dev/null)
if [ -z "$_fnm" ]; then
    for _fnm_dir in "$HOME/.local/share/fnm" "$HOME/.cargo/bin"; do
        if [ -x "$_fnm_dir/fnm" ]; then
            path_prepend "$_fnm_dir"
            _fnm="$_fnm_dir/fnm"
            break
        fi
    done
fi
[ -n "$_fnm" ] && eval "$("$_fnm" env)"
unset _fnm _fnm_dir

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
path_prepend "$PNPM_HOME"
