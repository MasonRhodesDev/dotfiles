function dev --description 'Run a command in dev.slice (deprioritized CPU/IO, memory-capped)'
    if test (count $argv) -eq 0
        echo "usage: dev <command> [args...]" >&2
        return 2
    end
    systemd-run --user --quiet --scope --slice=dev.slice --collect -- $argv
end
