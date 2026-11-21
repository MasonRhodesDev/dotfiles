[[ $- == *i* ]] || return 0
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
