# Node.js environment configuration

# fnm (Fast Node Manager).
#
# Two layers:
#   1. The default alias is a stable symlink (~/.local/share/fnm/aliases/default
#      -> node-versions/<ver>/installation), so its bin goes on PATH for every
#      shell, interactive or not, without running `fnm env`.
#   2. Interactive shells outside Claude Code also eval `fnm env --use-on-cd`,
#      which wraps cd (an alias to __fnmcd) and switches Node from a
#      .nvmrc / .node-version / engines.node found in the directory or any
#      parent. Claude Code shells skip it: the harness snapshots aliases and
#      cds before every tool command, and a version file naming an uninstalled
#      Node would make that cd fail (same reason go.bashrc gates gvm). Those
#      shells get the lazy wrapper below instead, so `fnm use` still works.
#
# The binary is resolved explicitly: a cargo install (this machine) lands in
# ~/.cargo/bin, which only login shells have on PATH via ~/.profile.
export FNM_DIR="$HOME/.local/share/fnm"
path_prepend "$FNM_DIR/aliases/default/bin"
_fnm=$(type -P fnm)
if [ -z "$_fnm" ]; then
    for _fnm_dir in "$HOME/.local/share/fnm" "$HOME/.cargo/bin"; do
        if [ -x "$_fnm_dir/fnm" ]; then
            path_prepend "$_fnm_dir"
            _fnm="$_fnm_dir/fnm"
            break
        fi
    done
fi
if [ -n "$_fnm" ] && [[ $- == *i* && -z ${CLAUDECODE-} ]]; then
    eval "$("$_fnm" env --use-on-cd --version-file-strategy=recursive --shell bash)"
elif [ -n "$_fnm" ]; then
    fnm() {
        local bin
        bin=$(type -P fnm) || { echo "fnm: binary not found" >&2; return 127; }
        if [ -z "${FNM_MULTISHELL_PATH-}" ]; then
            eval "$("$bin" env)"
        fi
        "$bin" "$@"
    }
fi
unset _fnm _fnm_dir

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
path_prepend "$PNPM_HOME"

# GitHub Packages (scoped npm registries at work): ~/.npmrc reads the token from NODE_AUTH_TOKEN, and
# the gh CLI login already carries read:packages, so mint it from gh instead of keeping a PAT on
# disk. Skipped when the variable is already set (CI sets it) or gh is absent.
# Interactive shells only: a `bash -lc` or SSH command shell should not pay the
# ~30 ms gh round-trip.
if [[ $- == *i* ]] && [ -z "${NODE_AUTH_TOKEN:-}" ] && command -v gh >/dev/null 2>&1; then
    NODE_AUTH_TOKEN=$(gh auth token 2>/dev/null) && export NODE_AUTH_TOKEN
fi
