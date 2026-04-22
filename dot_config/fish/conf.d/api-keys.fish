# API keys from the session-env keyring bucket.
#
# The systemd --user service `api-keys.service` imports the same bucket into
# the user manager environment at login so GUI apps (Hyprland via uwsm) also
# see these. Keep the set of keys loaded here in sync with that service by
# tagging entries with `service=session-env` in the GNOME Keyring.
for name in ANTHROPIC_API_KEY OPENAI_API_KEY SLACK_USER_TOKEN
    set -gx $name (secret-tool lookup service session-env account $name)
end
