# herdr-projects: the work-board plugin writes its launcher to
# ~/.herdr-projects/data/bin (see docs/install.md in the plugin checkout).
# Agents and hooks are handed the launcher directly; this is only so a shell,
# including the non-interactive login shell SSH starts for other machines,
# can type `herdr-projects`. path_append no-ops when the folder is absent.
path_append "$HOME/.herdr-projects/data/bin"
