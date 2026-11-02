# zoxide — smarter cd (`z <fragment>`), replaces fish's frecent-dir feel.
# Interactive shells only.
[[ $- == *i* ]] || return 0
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
