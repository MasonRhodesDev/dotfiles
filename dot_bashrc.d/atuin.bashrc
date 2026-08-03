# Atuin shell history: Ctrl-R fuzzy search (fish history imported).
# --disable-up-arrow keeps up-arrow as plain local history.
# Must load after 10-fzf.bashrc so atuin's Ctrl-R binding wins.
command -v atuin >/dev/null && eval "$(atuin init bash --disable-up-arrow)"
