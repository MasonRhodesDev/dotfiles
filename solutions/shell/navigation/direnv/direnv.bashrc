[[ $- == *i* ]] || return 0
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"
