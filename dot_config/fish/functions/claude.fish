function claude --description 'Claude Code inside dev.slice so agents/builds never starve the desktop'
    set -l bin (command -s claude)
    if test -z "$bin"
        echo "claude binary not found on PATH" >&2
        return 127
    end
    systemd-run --user --quiet --scope --slice=dev.slice --collect -- $bin $argv
end
