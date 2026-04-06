function openclaw
    if test (count $argv) -ge 1 -a "$argv[1]" = "dashboard"
        set -l output (command openclaw $argv 2>&1)
        set -l rewritten (string replace --all 'http://127.0.0.1:18789' 'https://openclaw.local' -- $output)
        echo $rewritten
    else
        command openclaw $argv
    end
end
