if [[ -z ${CLAUDECODE-} ]]; then
    claude() {
        local bin
        bin=$(type -P claude)
        if [[ -z $bin ]]; then
            echo "claude binary not found on PATH" >&2
            return 127
        fi
        __dev_slice_run "$bin" "$@"
    }
fi
