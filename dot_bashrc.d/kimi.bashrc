# kimi-code CLI.
#
# APPENDED, not prepended: ~/.kimi-code/bin also ships its own `fd`, which
# would otherwise shadow /usr/bin/fd for every shell. Only the `kimi` name is
# actually wanted from this directory, and it is unique.
#
# kimi's installer wires up fish only (`fish_add_path` in fish/config.fish) and
# self-updates in place, so it may re-add that line after an upgrade.
path_append "$HOME/.kimi-code/bin"
