# Export every entry in the session-env GNOME Keyring bucket as a fish env
# var. Same bucket is imported into the systemd --user env at login by
# `api-keys.service`, so the two paths stay in sync.
#
# Add a new var once with:
#   printf '%s' "value" | secret-tool store \
#       --label=MY_VAR service session-env account MY_VAR

if type -q list-session-env
    for kv in (list-session-env)
        set -l parts (string split -m1 '=' -- $kv)
        if test (count $parts) -eq 2
            set -gx $parts[1] $parts[2]
        end
    end
end
