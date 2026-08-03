# Run heavy agent/build commands inside dev.slice (deprioritized CPU/IO,
# memory-capped) so agents/builds never starve the desktop.

dev() {
    if [ $# -eq 0 ]; then
        echo "usage: dev <command> [args...]" >&2
        return 2
    fi
    systemd-run --user --quiet --scope --slice=dev.slice --collect -- "$@"
}

# Inside a Claude Code harness shell, a `claude` function would shadow the
# binary the session itself runs under (shell snapshots re-source these
# functions) — same reason go.bashrc gates gvm on CLAUDECODE.
if [[ -z ${CLAUDECODE-} ]]; then
    claude() {
        local bin
        bin=$(type -P claude)
        if [[ -z $bin ]]; then
            echo "claude binary not found on PATH" >&2
            return 127
        fi
        systemd-run --user --quiet --scope --slice=dev.slice --collect -- "$bin" "$@"
    }
fi

# claude-restricted lives in claude-restricted.bashrc — kept OUT of chezmoi
# (its deny-list paths trip the public-repo secret-guard), like the fish
# version was.
