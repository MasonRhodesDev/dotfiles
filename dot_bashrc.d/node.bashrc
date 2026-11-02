# Node.js environment configuration

# fnm (Fast Node Manager). The default alias is a stable symlink
# (~/.local/share/fnm/aliases/default -> node-versions/<ver>/installation), so
# putting its bin on PATH gives every shell node/npm/corepack without running
# `fnm env` (about 50 ms, and it minted a fresh /run/user/*/fnm_multishells
# dir per shell that path_dedupe then had to collapse).
#
# `fnm use`/`fnm install` still need the multishell environment, so the first
# call to fnm in a shell evals `fnm env` and then runs the real command; after
# that the multishell bin sits ahead of the default alias on PATH as before.
# The binary is resolved explicitly: a cargo install (this machine) lands in
# ~/.cargo/bin, which only login shells have on PATH via ~/.profile.
export FNM_DIR="$HOME/.local/share/fnm"
path_prepend "$FNM_DIR/aliases/default/bin"
fnm() {
    local bin
    bin=$(type -P fnm)
    if [ -z "$bin" ]; then
        local d
        for d in "$HOME/.local/share/fnm" "$HOME/.cargo/bin"; do
            [ -x "$d/fnm" ] && { bin="$d/fnm"; path_prepend "$d"; break; }
        done
    fi
    if [ -z "$bin" ]; then
        echo "fnm: binary not found" >&2
        return 127
    fi
    if [ -z "${FNM_MULTISHELL_PATH-}" ]; then
        eval "$("$bin" env)"
    fi
    "$bin" "$@"
}

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
