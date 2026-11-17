export GVM_ROOT="$HOME/.gvm"
if [[ $- == *i* && -z "${CLAUDECODE:-}" && -s "$GVM_ROOT/scripts/gvm" ]]; then
    source "$GVM_ROOT/scripts/gvm"
fi
