if type -q list-session-env
    for kv in (list-session-env)
        set -l parts (string split -m1 '=' -- $kv)
        if test (count $parts) -eq 2
            set -gx $parts[1] $parts[2]
        end
    end
end
