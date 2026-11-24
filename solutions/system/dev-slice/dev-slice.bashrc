__dev_slice_run() {
    if [ -n "${XDG_RUNTIME_DIR-}" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then
        systemd-run --user --quiet --scope --slice=dev.slice --collect -- "$@"
    else
        "$@"
    fi
}

dev() {
    if [ $# -eq 0 ]; then
        echo "usage: dev <command> [args...]" >&2
        return 2
    fi
    __dev_slice_run "$@"
}
