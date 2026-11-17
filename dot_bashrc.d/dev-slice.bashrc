dev() {
    if [ $# -eq 0 ]; then
        echo "usage: dev <command> [args...]" >&2
        return 2
    fi
    systemd-run --user --quiet --scope --slice=dev.slice --collect -- "$@"
}

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
