export GVM_ROOT="$HOME/.gvm"
# GVM overrides cd() with a function that hard-fails when GVM_ROOT isn't in
# the environment. Claude Code snapshots shell functions (not env) and cds
# before every command, so loading GVM there breaks every tool command
# (2026-07-13). Skip it in non-interactive and Claude Code shells.
if [[ $- == *i* && -z "${CLAUDECODE:-}" && -s "$GVM_ROOT/scripts/gvm" ]]; then
    source "$GVM_ROOT/scripts/gvm"
fi
