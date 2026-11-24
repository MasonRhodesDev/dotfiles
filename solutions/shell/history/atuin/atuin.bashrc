[[ $- == *i* ]] || return 0
command -v atuin >/dev/null && eval "$(atuin init bash --disable-up-arrow)"
