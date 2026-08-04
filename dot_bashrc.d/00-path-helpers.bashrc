# Idempotent PATH helpers. Loaded first (00-) so every later bashrc.d file
# and ~/.bashrc itself can use them.
#
# Why these exist: PATH is assembled by ~/.profile, ~/.bashrc, every file in
# ~/.bashrc.d, ~/.local/bin/env, and any third-party installer that blindly
# prepends. The hand-rolled guards used previously were adjacency regexes
# (`[[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]`) which stop matching the
# moment anything interleaves between the two entries — so they refire and
# PATH grows on every nested shell.

# Drop every occurrence of a directory from PATH.
path_remove() {
    local dir=$1 result= entry
    local IFS=:
    for entry in $PATH; do
        [ "$entry" = "$dir" ] && continue
        result="${result:+$result:}$entry"
    done
    PATH=$result
}

# Move a directory to the front of PATH (no-op if it does not exist).
path_prepend() {
    [ -d "$1" ] || return 0
    path_remove "$1"
    PATH="$1${PATH:+:$PATH}"
    export PATH
}

# Move a directory to the end of PATH (no-op if it does not exist).
# Prefer this for vendored tool dirs that ship their own copies of system
# binaries — see ~/.kimi-code/bin, which carries its own `fd`.
path_append() {
    [ -d "$1" ] || return 0
    path_remove "$1"
    PATH="${PATH:+$PATH:}$1"
    export PATH
}

# Collapse duplicate entries (first occurrence wins, so precedence is kept)
# and drop entries that no longer exist. Called at the very end of ~/.bashrc,
# which is the only point that sees the final PATH — ~/.local/bin/env runs
# after the ~/.bashrc.d loop.
path_dedupe() {
    local result= entry seen_fnm=0
    local IFS=:
    for entry in $PATH; do
        [ -n "$entry" ] || continue
        [ -d "$entry" ] || continue
        # `eval "$(fnm env)"` in node.bashrc mints a fresh
        # /run/user/*/fnm_multishells/<pid>_<timestamp>/bin for every shell and
        # prepends it. Those dirs are distinct and all genuinely exist, so plain
        # deduplication cannot collapse them and PATH grows by one entry per
        # nesting level. fnm prepends, so the first one seen belongs to this
        # shell; every later one is an inherited parent's and is dropped.
        case $entry in
            */fnm_multishells/*)
                [ "$seen_fnm" -eq 1 ] && continue
                seen_fnm=1
                ;;
        esac
        case ":$result:" in
            *":$entry:"*) continue ;;
        esac
        result="${result:+$result:}$entry"
    done
    PATH=$result
    export PATH
}
